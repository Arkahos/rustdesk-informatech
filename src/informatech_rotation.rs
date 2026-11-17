//! InformaTech (A12): the OPMD service rotates its permanent password after each session, so a password handed to
//! InformaTech Admin serves once (D4, option C). Contract: InformaTech's « A4 §12 » (F1-F5) and Scylla's conditions.
//!
//! - Configured by `--informatech-rotation` (elevated), which reads ONE line of JSON `{ "url", "jeton" }` from stdin:
//!   the token never appears on a command line. `--informatech-rotation --effacer` clears it. The state lives in a
//!   machine folder, `<system drive>\ProgramData\InformaTech\OPMD` (drive asked to Windows, never %ProgramData%),
//!   readable by SYSTEM and Administrators only (protected DACL): the elevated kit agent creates and writes it, the
//!   SYSTEM service reads it and rewrites the state file in place (Argos A12 P2/P3).
//! - Scylla 17/11: nobody takes a folder over. A level that already exists must already be trusted (a real folder
//!   owned by SYSTEM or Administrators); one a user created first, or a link, is left alone and rotation stays off on
//!   that PC (`--informatech-rotation` exits 3), like the connection log. Nothing is removed recursively, ever.
//! - Runs in the `--server` process (SYSTEM), with its state on disk because `--server` is respawned often:
//!   rotates at start (service start, and after `--close-connections`, which ends `--server`), and 3 minutes after the
//!   last authorized connection closed by itself (an authorized reconnect within that time cancels it). Never while an
//!   authorized connection is open. Every trigger draws a NEW password, even if one is still pending: a pending value
//!   may already have reached the server and been used (lost 204), so only the 5-minute retry re-POSTs it (Argos P2).
//! - A new password: 24 characters [A-Za-z0-9] from the OS RNG, applied locally first, kept pending, then POSTed to
//!   `<url>/v1/acces/mot-de-passe { jeton, motDePasse }`: 204 done; 410/404/401 stop and clear; 400 kept, no retry until
//!   the next trigger; 429/5xx/network kept, same value retried every 5 minutes, at most 24 hours.
//! - Logs carry fixed event names only (`journal` takes `&'static str`): never the token, the URL or a password.

use hbb_common::{config::Config, rand::rngs::OsRng, rand::RngCore, ResultType};
use serde_derive::{Deserialize, Serialize};
use std::path::PathBuf;
use std::time::{Duration, SystemTime, UNIX_EPOCH};

const FICHIER: &str = "informatech-rotation.json";
const LONGUEUR: usize = 24;
const ALPHABET: &[u8] = b"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789";
const GRACE_S: u64 = 180;
const REESSAI_S: u64 = 300;
const PLAFOND_S: u64 = 24 * 3600;
const PAS: Duration = Duration::from_secs(15);

#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
pub(crate) struct Etat {
    pub url: String,
    pub jeton: String,
    /// The password applied locally and not yet acknowledged by the server.
    pub en_attente: Option<String>,
    /// When it became pending (seconds since epoch).
    pub depuis: Option<u64>,
    pub dernier_essai: Option<u64>,
    /// A 400 answer: no retry until the next trigger.
    pub suspendu: bool,
}

/// What the background loop should do now.
#[derive(Debug, PartialEq)]
pub(crate) enum Action {
    Rien,
    /// Make a new password, apply it, POST it.
    Tourner,
    /// POST the pending password again.
    Reessayer,
}

/// Pure decision. `fin_derniere` = when the authorized-connection count last dropped to 0 (None if none since start).
/// A trigger (start, end of the grace) always means a NEW password; only the retry timer re-POSTs the pending one.
pub(crate) fn decider(etat: &Etat, connexions: usize, fin_derniere: Option<u64>, maintenant: u64, demarrage: bool) -> Action {
    if connexions > 0 {
        return Action::Rien;
    }
    if demarrage || fin_derniere.is_some_and(|t| maintenant >= t + GRACE_S) {
        return Action::Tourner;
    }
    if etat.en_attente.is_none() || etat.suspendu {
        return Action::Rien;
    }
    let depuis = etat.depuis.unwrap_or(maintenant);
    if maintenant.saturating_sub(depuis) >= PLAFOND_S {
        return Action::Rien;
    }
    if maintenant >= etat.dernier_essai.unwrap_or(0) + REESSAI_S {
        Action::Reessayer
    } else {
        Action::Rien
    }
}

/// What a POST answer means.
#[derive(Debug, PartialEq)]
pub(crate) enum Issue {
    Fait,
    Arreter,
    Suspendre,
    Reessayer,
}

pub(crate) fn issue(statut: Option<u16>) -> Issue {
    match statut {
        Some(200..=299) => Issue::Fait,
        Some(401) | Some(404) | Some(410) => Issue::Arreter,
        Some(400) => Issue::Suspendre,
        _ => Issue::Reessayer,
    }
}

pub(crate) fn nouveau_mot_de_passe() -> String {
    let mut out = String::with_capacity(LONGUEUR);
    let mut octet = [0u8; 1];
    while out.len() < LONGUEUR {
        OsRng.fill_bytes(&mut octet);
        // 62 * 4 = 248: reject 248..=255 so every character is equally likely.
        if octet[0] < 248 {
            out.push(ALPHABET[(octet[0] % 62) as usize] as char);
        }
    }
    out
}

/// One line of JSON from stdin: `{ "url": "https://…", "jeton": "…" }`.
pub(crate) fn lire_configuration(ligne: &str) -> Result<Etat, &'static str> {
    #[derive(Deserialize)]
    struct Entree {
        url: String,
        jeton: String,
    }
    let e: Entree = serde_json::from_str(ligne.trim()).map_err(|_| "invalid JSON")?;
    let url = e.url.trim().trim_end_matches('/').to_owned();
    let hote = url.strip_prefix("https://").ok_or("url must be https")?;
    if hote.is_empty() || hote.contains(['/', '?', '#', '@', ' ']) || url.len() > 200 {
        return Err("url must be https://<host>");
    }
    if e.jeton.is_empty() || e.jeton.len() > 512 || e.jeton.chars().any(|c| c.is_control() || c.is_whitespace()) {
        return Err("invalid token");
    }
    Ok(Etat { url, jeton: e.jeton, ..Default::default() })
}

fn maintenant() -> u64 {
    SystemTime::now().duration_since(UNIX_EPOCH).map(|d| d.as_secs()).unwrap_or(0)
}

/// None when Windows does not give its system directory: then no state is read or written.
fn dossier() -> Option<PathBuf> {
    let systeme = systeme32("")?;
    crate::informatech_journal::sous_programdata(systeme.to_str()?, "OPMD").map(PathBuf::from)
}

fn chemin() -> Option<PathBuf> {
    dossier().map(|d| d.join(FICHIER))
}

/// Who owns a folder or file of the state (Argos A12 re-check 2).
#[derive(Debug, Clone, Copy, PartialEq)]
pub(crate) enum Proprietaire {
    Systeme,
    Administrateurs,
    Autre,
    Inconnu,
}

/// The service trusts a folder or file only if it is no junction/symlink and SYSTEM or Administrators own it: under
/// ProgramData a standard user may create the folder first (keeping WRITE_DAC as its owner) or plant a junction.
pub(crate) fn digne_de_confiance(reparse: bool, proprietaire: Proprietaire) -> bool {
    !reparse && matches!(proprietaire, Proprietaire::Systeme | Proprietaire::Administrateurs)
}

fn est_reparse(p: &std::path::Path) -> bool {
    use std::os::windows::fs::MetadataExt;
    // FILE_ATTRIBUTE_REPARSE_POINT; unreadable counts as untrusted.
    std::fs::symlink_metadata(p).map(|m| m.file_attributes() & 0x400 != 0).unwrap_or(true)
}

fn proprietaire(p: &std::path::Path) -> Proprietaire {
    use windows::core::HSTRING;
    use windows::Win32::Foundation::{LocalFree, HLOCAL};
    use windows::Win32::Security::Authorization::{GetNamedSecurityInfoW, SE_FILE_OBJECT};
    use windows::Win32::Security::{IsWellKnownSid, WinBuiltinAdministratorsSid, WinLocalSystemSid, OWNER_SECURITY_INFORMATION, PSECURITY_DESCRIPTOR, PSID};
    let chemin = HSTRING::from(p.as_os_str());
    let mut owner = PSID::default();
    let mut sd = PSECURITY_DESCRIPTOR::default();
    // SAFETY: out-pointers to locals; the descriptor is freed below and `owner` points into it.
    let r = unsafe { GetNamedSecurityInfoW(&chemin, SE_FILE_OBJECT, OWNER_SECURITY_INFORMATION, Some(&mut owner), None, None, None, &mut sd) };
    if r.0 != 0 || owner.is_invalid() {
        return Proprietaire::Inconnu;
    }
    // SAFETY: `owner` is valid while `sd` lives.
    let resultat = unsafe {
        if IsWellKnownSid(owner, WinLocalSystemSid).as_bool() {
            Proprietaire::Systeme
        } else if IsWellKnownSid(owner, WinBuiltinAdministratorsSid).as_bool() {
            Proprietaire::Administrateurs
        } else {
            Proprietaire::Autre
        }
    };
    // SAFETY: `sd` was allocated by GetNamedSecurityInfoW with LocalAlloc.
    unsafe {
        let _ = LocalFree(Some(HLOCAL(sd.0)));
    }
    resultat
}

pub(crate) fn fiable(p: &std::path::Path) -> bool {
    digne_de_confiance(est_reparse(p), proprietaire(p))
}

/// The state's folders and file, from the top, all trusted.
fn etat_fiable() -> bool {
    let (Some(d), Some(p)) = (dossier(), chemin()) else {
        return false;
    };
    d.parent().is_some_and(fiable) && fiable(&d) && fiable(&p)
}

/// The two folder levels (`InformaTech`, then `OPMD`), trusted, without touching anything.
fn dossiers_fiables(d: &std::path::Path) -> bool {
    d.parent().is_some_and(fiable) && fiable(d)
}

/// A Windows tool by its full System32 path, asked to Windows itself: no PATH search, no environment variable a
/// user could set, no shell (Scylla 17/11).
pub(crate) fn systeme32(programme: &str) -> Option<PathBuf> {
    use std::os::windows::ffi::OsStringExt;
    use windows::Win32::System::SystemInformation::GetSystemDirectoryW;
    let mut tampon = [0u16; 260];
    // SAFETY: the buffer is a local array; the call writes at most its length.
    let n = unsafe { GetSystemDirectoryW(Some(&mut tampon)) } as usize;
    if n == 0 || n >= tampon.len() {
        return None;
    }
    Some(PathBuf::from(std::ffi::OsString::from_wide(&tampon[..n])).join(programme))
}

/// Runs `takeown.exe` or `icacls.exe` (file name with its extension) from System32.
pub(crate) fn commande_ok(programme: &str, args: &[&std::ffi::OsStr]) -> bool {
    let Some(exe) = systeme32(programme) else {
        return false;
    };
    std::process::Command::new(exe)
        .args(args)
        .stdout(std::process::Stdio::null())
        .stderr(std::process::Stdio::null())
        .status()
        .is_ok_and(|s| s.success())
}

/// Elevated writer only (`--informatech-rotation`): each missing level (`InformaTech`, then `OPMD`) is created closed
/// (owner Administrators, SYSTEM and Administrators only, nothing inherited, in the same call); a level that exists
/// must already be trusted, and gets the same DACL again. Never takes a folder over (no takeown), never removes one:
/// an untrusted level refuses the whole configuration (Scylla 17/11). Only paths go on the command lines, never a
/// secret.
fn proteger(d: &std::path::Path) -> ResultType<()> {
    let niveaux = [d.parent().map(|x| x.to_path_buf()), Some(d.to_path_buf())];
    for n in niveaux.into_iter().flatten() {
        match std::fs::symlink_metadata(&n) {
            Err(e) if e.kind() == std::io::ErrorKind::NotFound => creer_dossier_ferme(&n, "BA", false)?,
            Err(e) => return Err(e.into()),
            Ok(_) => {}
        }
        if !fiable(&n) {
            hbb_common::anyhow::bail!("state folder not trusted");
        }
        poser_dacl(&n, false)?;
    }
    Ok(())
}

/// Creates ONE folder (never its parents) with the security descriptor of `sddl_dossier`, in one call: the folder never
/// exists with ProgramData's inherited rights (Scylla 17/11). Fails if the name already exists.
pub(crate) fn creer_dossier_ferme(p: &std::path::Path, proprietaire: &str, lecture_utilisateurs: bool) -> ResultType<()> {
    use windows::core::HSTRING;
    use windows::Win32::Foundation::{LocalFree, HLOCAL};
    use windows::Win32::Security::Authorization::{ConvertStringSecurityDescriptorToSecurityDescriptorW, SDDL_REVISION_1};
    use windows::Win32::Security::{PSECURITY_DESCRIPTOR, SECURITY_ATTRIBUTES};
    use windows::Win32::Storage::FileSystem::CreateDirectoryW;
    let sddl = HSTRING::from(crate::informatech_journal::sddl_dossier(proprietaire, lecture_utilisateurs));
    let mut sd = PSECURITY_DESCRIPTOR::default();
    // SAFETY: `sddl` is a NUL-terminated wide string that outlives the call; `sd` is a local out-parameter.
    unsafe { ConvertStringSecurityDescriptorToSecurityDescriptorW(&sddl, SDDL_REVISION_1, &mut sd, None) }?;
    let sa = SECURITY_ATTRIBUTES {
        nLength: std::mem::size_of::<SECURITY_ATTRIBUTES>() as u32,
        lpSecurityDescriptor: sd.0,
        bInheritHandle: false.into(),
    };
    // SAFETY: `sa` and the descriptor it points to live through the call.
    let cree = unsafe { CreateDirectoryW(&HSTRING::from(p.as_os_str()), Some(&sa)) };
    // SAFETY: `sd` was allocated by ConvertStringSecurityDescriptorToSecurityDescriptorW with LocalAlloc.
    unsafe {
        let _ = LocalFree(Some(HLOCAL(sd.0)));
    }
    cree?;
    Ok(())
}

/// THE closed DACL of InformaTech's machine folders, in one place (Scylla 17/11: the connection log's parent gets the
/// same two entries as this writer's, from one function): SYSTEM and Administrators full, nothing inherited.
/// `lecture_utilisateurs` adds ONE entry, read + execute for BUILTIN\Users: only the folder of the connection log
/// (informatech_journal.rs), which the client's Hub reads without elevation. `/L`: icacls works on the path itself,
/// never through a link. ONE icacls call (Scylla 17/11: the former `/reset` first gave the folder ProgramData's
/// inherited rights for a moment, where a user could create something in it). No `/reset` is needed: these folders
/// are created closed by this code, or were already trusted (owned by SYSTEM or Administrators), so any explicit
/// entry on them was set by SYSTEM or an administrator. Refuses if the folder is not trusted afterwards.
pub(crate) fn poser_dacl(n: &std::path::Path, lecture_utilisateurs: bool) -> ResultType<()> {
    use std::ffi::OsStr;
    let c = n.as_os_str();
    let mut droits = vec![c, OsStr::new("/inheritance:r"), OsStr::new("/grant:r"), OsStr::new("*S-1-5-18:(OI)(CI)F"), OsStr::new("*S-1-5-32-544:(OI)(CI)F")];
    if lecture_utilisateurs {
        droits.push(OsStr::new("*S-1-5-32-545:(OI)(CI)RX"));
    }
    droits.push(OsStr::new("/L"));
    let ok = commande_ok("icacls.exe", &droits);
    if !ok || !fiable(n) {
        hbb_common::anyhow::bail!("state folder not trusted");
    }
    Ok(())
}

fn lire() -> Option<Etat> {
    let p = chemin()?;
    if std::fs::symlink_metadata(&p).is_err() {
        return None;
    }
    if !etat_fiable() {
        journal("state file ignored: folder or file not owned by SYSTEM/Administrators, or a link");
        return None;
    }
    let texte = std::fs::read_to_string(&p).ok()?;
    serde_json::from_str(&texte).ok()
}

/// Elevated configuration (`--informatech-rotation`): the folders are created closed or must already be trusted,
/// then the state file is written.
fn configurer(e: &Etat) -> ResultType<()> {
    let Some(d) = dossier() else {
        hbb_common::anyhow::bail!("no system directory");
    };
    proteger(&d)?;
    ecrire(e)
}

/// The state file, written in place by the elevated command or by the SYSTEM service (Scylla 17/11: the service
/// never creates, takes over or cleans a folder). Only into trusted folders: a brand-new temporary file next to the
/// state file, then renamed over it. The only thing ever removed is a leftover of that temporary file, one plain
/// file; anything else under that name refuses the write.
fn ecrire(e: &Etat) -> ResultType<()> {
    let (Some(d), Some(p)) = (dossier(), chemin()) else {
        hbb_common::anyhow::bail!("no system directory");
    };
    if !dossiers_fiables(&d) || (std::fs::symlink_metadata(&p).is_ok() && !fiable(&p)) {
        hbb_common::anyhow::bail!("state folder not trusted");
    }
    let tmp = p.with_extension("tmp");
    match std::fs::symlink_metadata(&tmp) {
        Ok(m) if m.is_file() => std::fs::remove_file(&tmp)?,
        Ok(_) => hbb_common::anyhow::bail!("temporary name taken by something else"),
        Err(e) if e.kind() == std::io::ErrorKind::NotFound => {}
        Err(e) => return Err(e.into()),
    }
    ecrire_neuf(&tmp, &serde_json::to_vec(e)?)?;
    std::fs::rename(&tmp, &p)?;
    Ok(())
}

/// A brand-new file only: never write into a file someone else created (it would keep their owner and DACL).
pub(crate) fn ecrire_neuf(p: &std::path::Path, octets: &[u8]) -> ResultType<()> {
    use std::io::Write;
    let mut f = std::fs::OpenOptions::new().write(true).create_new(true).open(p)?;
    f.write_all(octets)?;
    f.sync_all()?;
    Ok(())
}

fn effacer_fichier() {
    if let Some(p) = chemin() {
        let _ = std::fs::remove_file(p);
    }
}

#[cfg(not(test))]
fn journal(evenement: &'static str) {
    hbb_common::log::info!("informatech rotation: {evenement}");
}

#[cfg(test)]
thread_local! {
    static JOURNAL: std::cell::RefCell<Vec<&'static str>> = const { std::cell::RefCell::new(Vec::new()) };
}

#[cfg(test)]
fn journal(evenement: &'static str) {
    JOURNAL.with(|j| j.borrow_mut().push(evenement));
}

/// The side effects, swappable in tests.
pub(crate) trait Effets {
    fn appliquer(&mut self, mot_de_passe: &str) -> bool;
    /// HTTP status, None on a network error.
    fn poster(&mut self, url: &str, jeton: &str, mot_de_passe: &str) -> Option<u16>;
}

struct Reels;

impl Effets for Reels {
    fn appliquer(&mut self, mot_de_passe: &str) -> bool {
        Config::set_permanent_password(mot_de_passe)
    }

    fn poster(&mut self, url: &str, jeton: &str, mot_de_passe: &str) -> Option<u16> {
        // Certificates checked against the OS store; never the « accept invalid certificate » fallback.
        let client = reqwest::blocking::Client::builder()
            .timeout(Duration::from_secs(30))
            .redirect(reqwest::redirect::Policy::none())
            .https_only(true)
            .build()
            .ok()?;
        let corps = serde_json::json!({ "jeton": jeton, "motDePasse": mot_de_passe });
        client
            .post(format!("{url}/v1/acces/mot-de-passe"))
            .json(&corps)
            .send()
            .ok()
            .map(|r| r.status().as_u16())
    }
}

/// One step of the state machine; returns the new state (None = cleared).
pub(crate) fn pas(etat: Etat, action: Action, maintenant: u64, effets: &mut impl Effets) -> Option<Etat> {
    let mut e = etat;
    match action {
        Action::Rien => return Some(e),
        Action::Tourner => {
            let mdp = nouveau_mot_de_passe();
            if !effets.appliquer(&mdp) {
                journal("local change refused (changing the password is disabled)");
                return Some(e);
            }
            journal("new password applied locally");
            // A previous pending value is dropped: it may already be in use (lost 204).
            e.en_attente = Some(mdp);
            e.depuis = Some(maintenant);
            e.suspendu = false;
        }
        Action::Reessayer => {
            e.suspendu = false;
        }
    }
    let Some(mdp) = e.en_attente.clone() else { return Some(e) };
    e.dernier_essai = Some(maintenant);
    match issue(effets.poster(&e.url, &e.jeton, &mdp)) {
        Issue::Fait => {
            journal("password registered by the server");
            e.en_attente = None;
            e.depuis = None;
            Some(e)
        }
        Issue::Arreter => {
            journal("server refused the token: rotation stopped and cleared");
            None
        }
        Issue::Suspendre => {
            journal("server rejected the request (400): kept until the next trigger");
            e.suspendu = true;
            Some(e)
        }
        Issue::Reessayer => {
            if e.depuis.is_some_and(|d| maintenant.saturating_sub(d) >= PLAFOND_S) {
                journal("still not registered after 24 h: retries stopped until the next trigger");
            } else {
                journal("server unreachable: retry in 5 minutes");
            }
            Some(e)
        }
    }
}

/// `--informatech-rotation [--effacer]` (elevated, installed). Reads the configuration from stdin. On failure: the
/// exit code (Scylla 17/11: the elevated caller reads nothing else) and a fixed sentence: 2 the input is refused,
/// 3 the state cannot be written (an untrusted folder included).
pub fn commande(args: &[String]) -> Result<(), (i32, &'static str)> {
    if args.iter().any(|a| a == "--effacer") {
        effacer_fichier();
        return Ok(());
    }
    let mut ligne = String::new();
    std::io::stdin().read_line(&mut ligne).map_err(|_| (2, "cannot read stdin"))?;
    let e = lire_configuration(&ligne).map_err(|m| (2, m))?;
    configurer(&e).map_err(|_| (3, "cannot write the state file"))?;
    Ok(())
}

/// Started once in the `--server` process: rotates at start, then watches connection ends and retries.
pub fn demarrer(nb_connexions: fn() -> usize) {
    std::thread::spawn(move || {
        let mut demarrage = true;
        let mut avant = nb_connexions();
        let mut fin_derniere: Option<u64> = None;
        loop {
            let n = nb_connexions();
            let t = maintenant();
            if n > 0 {
                fin_derniere = None;
            } else if avant > 0 {
                fin_derniere = Some(t);
            }
            avant = n;
            if let Some(e) = lire() {
                let action = decider(&e, n, fin_derniere, t, demarrage);
                if action != Action::Rien {
                    if action == Action::Tourner {
                        fin_derniere = None;
                    }
                    match pas(e, action, t, &mut Reels) {
                        Some(nouveau) => {
                            if ecrire(&nouveau).is_err() {
                                journal("cannot write the state file");
                            }
                        }
                        None => effacer_fichier(),
                    }
                }
            }
            demarrage = false;
            std::thread::sleep(PAS);
        }
    });
}

#[cfg(test)]
mod tests {
    use super::*;

    fn configure() -> Etat {
        lire_configuration(r#"{"url":"https://informatech-hub.example","jeton":"tok-SECRET-123"}"#).unwrap()
    }

    struct Faux {
        appliques: Vec<String>,
        postes: Vec<String>,
        reponses: Vec<Option<u16>>,
        accepter: bool,
    }

    impl Effets for Faux {
        fn appliquer(&mut self, m: &str) -> bool {
            self.appliques.push(m.to_owned());
            self.accepter
        }
        fn poster(&mut self, url: &str, jeton: &str, m: &str) -> Option<u16> {
            assert_eq!((url, jeton), ("https://informatech-hub.example", "tok-SECRET-123"));
            self.postes.push(m.to_owned());
            self.reponses.remove(0)
        }
    }

    fn faux(reponses: Vec<Option<u16>>) -> Faux {
        Faux { appliques: vec![], postes: vec![], reponses, accepter: true }
    }

    #[test]
    fn mot_de_passe_24_alphanumeriques_differents() {
        let a = nouveau_mot_de_passe();
        let b = nouveau_mot_de_passe();
        assert_eq!(a.len(), 24);
        assert!(a.bytes().all(|c| c.is_ascii_alphanumeric()));
        assert_ne!(a, b);
    }

    #[test]
    fn configuration_https_et_jeton_seulement() {
        let e = configure();
        assert_eq!(e.url, "https://informatech-hub.example");
        assert!(e.en_attente.is_none());
        for mauvais in [
            r#"{"url":"http://x.example","jeton":"t"}"#,
            r#"{"url":"https://x.example/chemin","jeton":"t"}"#,
            r#"{"url":"https://user@x.example","jeton":"t"}"#,
            r#"{"url":"https://","jeton":"t"}"#,
            r#"{"url":"https://x.example","jeton":""}"#,
            r#"{"url":"https://x.example","jeton":"a b"}"#,
            r#"{"url":"https://x.example","jeton":"a\nb"}"#,
            "pas du json",
        ] {
            assert!(lire_configuration(mauvais).is_err(), "{mauvais}");
        }
        assert_eq!(lire_configuration(r#"{"url":"https://x.example/","jeton":"t"}"#).unwrap().url, "https://x.example");
    }

    #[test]
    fn jamais_pendant_une_connexion_et_grace_de_3_minutes() {
        let e = configure();
        assert_eq!(decider(&e, 1, None, 1000, true), Action::Rien, "never during an open connection");
        assert_eq!(decider(&e, 0, None, 1000, true), Action::Tourner, "at start");
        assert_eq!(decider(&e, 0, None, 1000, false), Action::Rien);
        assert_eq!(decider(&e, 0, Some(1000), 1000 + 179, false), Action::Rien, "grace running");
        assert_eq!(decider(&e, 0, Some(1000), 1000 + 180, false), Action::Tourner, "grace over");
        assert_eq!(decider(&e, 2, Some(1000), 5000, false), Action::Rien, "reconnected within the grace");
    }

    #[test]
    fn en_attente_reessaye_toutes_les_5_minutes_au_plus_24_h() {
        let mut e = configure();
        e.en_attente = Some("X".repeat(24));
        e.depuis = Some(0);
        e.dernier_essai = Some(1000);
        assert_eq!(decider(&e, 0, None, 1000 + 299, false), Action::Rien);
        assert_eq!(decider(&e, 0, None, 1000 + 300, false), Action::Reessayer, "the timer re-POSTs the pending value");
        assert_eq!(decider(&e, 0, None, PLAFOND_S + 10, false), Action::Rien, "past 24 h: wait for a trigger");
        e.suspendu = true;
        e.depuis = Some(1000);
        assert_eq!(decider(&e, 0, None, 1000 + 600, false), Action::Rien, "400: until the next trigger");
    }

    #[test]
    fn un_declencheur_tire_toujours_un_nouveau_mot_de_passe() {
        // Argos P2: a pending value may have reached the server (lost 204) and been used for a session.
        let mut e = configure();
        e.en_attente = Some("X".repeat(24));
        e.depuis = Some(1000);
        e.dernier_essai = Some(1000);
        assert_eq!(decider(&e, 0, None, 1001, true), Action::Tourner, "start");
        assert_eq!(decider(&e, 0, Some(2000), 2180, false), Action::Tourner, "end of the grace");
        e.suspendu = true;
        assert_eq!(decider(&e, 0, None, 1001, true), Action::Tourner, "a 400 is lifted by a trigger with a new value");
        let mut f = faux(vec![Some(204)]);
        let n = pas(e, Action::Tourner, 3000, &mut f).unwrap();
        assert_eq!(f.appliques.len(), 1);
        assert_ne!(f.appliques[0], "X".repeat(24), "a new value, applied locally");
        assert_eq!(f.postes, f.appliques, "and that new value is the one posted");
        assert!(n.en_attente.is_none() && !n.suspendu);
    }

    #[test]
    fn dossier_fiable_seulement_sans_lien_et_a_systeme_ou_admins() {
        use Proprietaire::*;
        assert!(digne_de_confiance(false, Systeme));
        assert!(digne_de_confiance(false, Administrateurs));
        assert!(!digne_de_confiance(false, Autre), "created first by a standard user");
        assert!(!digne_de_confiance(false, Inconnu));
        assert!(!digne_de_confiance(true, Systeme), "a junction, whoever owns it");
        assert!(!digne_de_confiance(true, Administrateurs));
    }

    #[test]
    fn proprietaires_reels() {
        // ProgramData belongs to SYSTEM; a folder the test user creates belongs to that user.
        assert_eq!(proprietaire(std::path::Path::new(r"C:\ProgramData")), Proprietaire::Systeme);
        let d = std::env::temp_dir().join(format!("a12-proprio-{}", std::process::id()));
        std::fs::create_dir_all(&d).unwrap();
        assert_eq!(proprietaire(&d), Proprietaire::Autre);
        assert!(!fiable(&d));
        assert!(!est_reparse(&d));
        std::fs::remove_dir(&d).unwrap();
        assert!(est_reparse(&d), "missing counts as untrusted");
    }

    #[test]
    fn un_fichier_deja_plante_n_est_jamais_ecrit() {
        let d = std::env::temp_dir().join(format!("a12-plante-{}", std::process::id()));
        std::fs::create_dir_all(&d).unwrap();
        let tmp = d.join("informatech-rotation.tmp");
        std::fs::write(&tmp, b"planted").unwrap();
        assert!(ecrire_neuf(&tmp, b"SECRET").is_err(), "an existing file is refused");
        assert_eq!(std::fs::read(&tmp).unwrap(), b"planted", "and left untouched");
        std::fs::remove_file(&tmp).unwrap();
        ecrire_neuf(&tmp, b"neuf").unwrap();
        assert_eq!(std::fs::read(&tmp).unwrap(), b"neuf");
        std::fs::remove_file(&tmp).unwrap();
        std::fs::remove_dir(&d).unwrap();
    }

    /// Scylla 17/11: a folder a user created is never taken over, nor written into, and nothing in it is removed.
    #[test]
    fn un_dossier_cree_par_un_utilisateur_n_est_jamais_repris() {
        let d = std::env::temp_dir().join(format!("a12-utilisateur-{}", std::process::id()));
        std::fs::create_dir_all(d.join("OPMD").join("dedans")).unwrap();
        std::fs::write(d.join("OPMD").join("dedans").join("x"), b"x").unwrap();
        // The test user owns both levels: not trusted, so proteger refuses and touches nothing.
        assert!(proteger(&d.join("OPMD")).is_err());
        assert!(d.join("OPMD").join("dedans").join("x").is_file());
        std::fs::remove_dir_all(&d).unwrap();
    }

    #[test]
    fn issues_http() {
        assert_eq!(issue(Some(204)), Issue::Fait);
        assert_eq!(issue(Some(410)), Issue::Arreter);
        assert_eq!(issue(Some(404)), Issue::Arreter);
        assert_eq!(issue(Some(401)), Issue::Arreter);
        assert_eq!(issue(Some(400)), Issue::Suspendre);
        assert_eq!(issue(Some(429)), Issue::Reessayer);
        assert_eq!(issue(Some(503)), Issue::Reessayer);
        assert_eq!(issue(None), Issue::Reessayer);
    }

    #[test]
    fn local_d_abord_puis_meme_valeur_reessayee() {
        let mut f = faux(vec![None, Some(204)]);
        let e = pas(configure(), Action::Tourner, 100, &mut f).unwrap();
        assert_eq!(f.appliques.len(), 1, "applied locally first");
        assert_eq!(e.en_attente.as_deref(), Some(f.appliques[0].as_str()), "kept pending after a network error");
        let e = pas(e, Action::Reessayer, 500, &mut f).unwrap();
        assert_eq!(f.postes[0], f.postes[1], "the retry POSTs the same value");
        assert_eq!(f.appliques.len(), 1, "no second local change");
        assert!(e.en_attente.is_none());
    }

    #[test]
    fn refus_du_jeton_efface_et_changement_local_refuse() {
        let mut f = faux(vec![Some(410)]);
        assert!(pas(configure(), Action::Tourner, 100, &mut f).is_none());
        let mut f = Faux { accepter: false, ..faux(vec![]) };
        let e = pas(configure(), Action::Tourner, 100, &mut f).unwrap();
        assert!(e.en_attente.is_none() && f.postes.is_empty(), "nothing posted if the local change failed");
    }

    #[test]
    fn le_journal_ne_contient_ni_jeton_ni_mot_de_passe() {
        JOURNAL.with(|j| j.borrow_mut().clear());
        let mut f = faux(vec![None, Some(400), Some(204), Some(410)]);
        let e = pas(configure(), Action::Tourner, 100, &mut f).unwrap();
        let e = pas(e, Action::Reessayer, 500, &mut f).unwrap();
        let e = pas(e, Action::Reessayer, 900, &mut f).unwrap();
        let _ = pas(e, Action::Tourner, 1300, &mut f);
        let lignes = JOURNAL.with(|j| j.borrow().clone());
        assert!(lignes.len() >= 5);
        let tout = lignes.join("\n");
        assert!(!tout.contains("tok-SECRET-123"));
        assert!(!tout.contains("informatech-hub.example"));
        for m in f.appliques.iter().chain(f.postes.iter()) {
            assert!(!tout.contains(m.as_str()));
        }
    }
}
