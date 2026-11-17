//! InformaTech (S-076 C, Adrien 17/11): the OPMD service keeps a local log of every AUTHORIZED incoming connection,
//! also when nobody is logged on to Windows. The client's Hub reads it at the next logon, shows it and reports it
//! (Zoro); it is the only trace that also sees a connection that did not go through InformaTech's server.
//!
//! - Written by the `--server` process (SYSTEM): one line when an authorized connection opens, one when it closes.
//! - File: `<system drive>\ProgramData\InformaTech\OPMD-journal\connexions.jsonl`, UTF-8, one JSON object per line,
//!   `\n` ended. The drive is the one of Windows' own system directory, asked to Windows (never an environment
//!   variable): the Hub finds the file the same way.
//!   The folder is NOT A12's (`OPMD`, SYSTEM and Administrators only): the Hub reads the log as the logged-on user,
//!   so this one adds a read-only entry for BUILTIN\Users. The parent keeps A12's two entries: a user opens the file by
//!   its full path (bypass traverse checking), and cannot plant anything next to it.
//! - Lines (format agreed with Zoro, 17/11; `t` = seconds since 1970 UTC):
//!   `{"v":1,"evt":"debut","id":"<16 hex>","t":…,"type":"controle","pair":"…","nom":"…","ip":"…"|null,"sessionOuverte":true|false}`
//!   `{"v":1,"evt":"fin","id":"<same>","t":…}`
//!   A « debut » with no « fin » means the engine stopped, the PC was cut, or the log went off meanwhile. The engine
//!   writes a « fin » only after its « debut » (Argos P4-1); one can still stand alone in a file once the one-year
//!   rule dropped its « debut »: a reader ignores it (Zoro's does). `sessionOuverte` is read when the connection is
//!   authorized (Argos P4-2). Nothing secret is ever written. `pair`
//!   and `nom` are what the remote side DECLARES: a reader shows them as such, never as a verified identity.
//! - Scylla's ruling (17/11): a level that is not trusted (not a real folder, a reparse point, an owner other than
//!   SYSTEM or Administrators) is never taken over, reset, deleted or written through: the connection is simply not
//!   logged and one fixed event says so. The service only creates what is missing, only touches what already passed
//!   the trust check, and deletes nothing but its own temporary file.
//! - Best effort: the session's path only drops a message in a bounded queue; a thread of its own writes. A failure
//!   never blocks, delays or ends a session, and is not retried in a loop.
//! - The log is the client's record: nothing in the engine removes it (it survives « retirer » and an uninstall).
//!   Kept lines stay byte-identical; above 256 KB only the most recent lines stay (at most 500).
//! - Bounded life (Styx 17/11, the log holds the remote side's address): a line older than one year goes the next
//!   time the file is re-created (service start, or the cap). A clock that reads 0 drops nothing, and a line dated in
//!   the future is kept.
//! - Visible when off (Scylla 17/11): `HKLM\SOFTWARE\InformaTech\OPMD-journal`, `etat` = `actif` | `hors-service`
//!   and `t` (seconds since 1970 UTC), written by the service at start and on every change. A standard user reads it
//!   and cannot write it; the Hub reports it. Absent means unknown (older engine, service never started), not « actif ».

#![cfg_attr(not(windows), allow(dead_code))]

use serde_derive::Serialize;
use std::path::Path;

/// Folder name under `%ProgramData%\InformaTech`, and file name: pinned by the Hub (Zoro).
pub(crate) const DOSSIER: &str = "OPMD-journal";
pub(crate) const FICHIER: &str = "connexions.jsonl";
const TEMPORAIRE: &str = "connexions.tmp";
const MAX_OCTETS: usize = 256 * 1024;
const LIGNES_GARDEES: usize = 500;
const MAX_LIGNE: usize = 1024;
const MAX_TEXTE: usize = 64;
/// Styx 17/11: how long a line may stay in the log, in seconds (365 days).
const DUREE_DE_VIE: u64 = 365 * 24 * 3600;
/// The two words of the published state (see the module's header), pinned with the Hub.
pub(crate) const ETAT_ACTIF: &str = "actif";
pub(crate) const ETAT_HORS_SERVICE: &str = "hors-service";

pub(crate) fn etat(pret: bool) -> &'static str {
    if pret {
        ETAT_ACTIF
    } else {
        ETAT_HORS_SERVICE
    }
}

/// `<drive>\ProgramData\InformaTech\<nom>` from Windows' system directory (`C:\Windows\System32`); None when that is
/// not a path on a lettered drive. The connection log (`OPMD-journal`) and A12's state (`OPMD`) both live there:
/// never found through an environment variable a user could set (Scylla 17/11).
pub(crate) fn sous_programdata(systeme: &str, nom: &str) -> Option<String> {
    let o = systeme.as_bytes();
    (o.len() >= 3 && o[0].is_ascii_alphabetic() && o[1] == b':' && o[2] == b'\\')
        .then(|| format!("{}\\ProgramData\\InformaTech\\{nom}", &systeme[..2]))
}

/// The log's folder from Windows' system directory (`C:\Windows\System32` → `C:\ProgramData\InformaTech\OPMD-journal`).
pub(crate) fn dossier_du_journal(systeme: &str) -> Option<String> {
    sous_programdata(systeme, DOSSIER)
}

/// THE security descriptor an InformaTech machine folder is CREATED with (Scylla 17/11: no window between the
/// creation and the closing of the folder, when it would inherit ProgramData's rights and a user could plant something
/// in it): owner `proprietaire` (`SY` the service, `BA` the elevated writer), a protected DACL (nothing inherited) with
/// SYSTEM and Administrators full control, and, with `lecture_utilisateurs`, read + execute for BUILTIN\Users (the
/// connection log's folder only, read by the unelevated Hub). The same entries `poser_dacl` sets on a folder that
/// already exists.
pub(crate) fn sddl_dossier(proprietaire: &str, lecture_utilisateurs: bool) -> String {
    let utilisateurs = if lecture_utilisateurs { "(A;OICI;FRFX;;;BU)" } else { "" };
    format!("O:{proprietaire}D:P(A;OICI;FA;;;SY)(A;OICI;FA;;;BA){utilisateurs}")
}

#[derive(Serialize)]
struct Debut<'a> {
    v: u8,
    evt: &'static str,
    id: &'a str,
    t: u64,
    #[serde(rename = "type")]
    genre: &'static str,
    pair: &'a str,
    nom: &'a str,
    ip: Option<&'a str>,
    #[serde(rename = "sessionOuverte")]
    session_ouverte: bool,
}

#[derive(Serialize)]
struct Fin<'a> {
    v: u8,
    evt: &'static str,
    id: &'a str,
    t: u64,
}

/// The log's word for a connection kind (`AuthConnType::as_str`). With S-072 only « controle » can open; the others
/// are named so that a different build would still be told apart.
pub(crate) fn genre(conn_type: &str) -> &'static str {
    match conn_type {
        "remote" => "controle",
        "file_transfer" => "fichiers",
        "port_forward" => "tunnel",
        "view_camera" => "camera",
        "terminal" => "terminal",
        _ => "autre",
    }
}

/// What the peer announces about itself is its own text: no control character, no bidirectional or invisible
/// formatting character (Scylla 17/11: a right-to-left override can make a reader show « gpj.exe » as « exe.jpg »),
/// 64 characters at most.
pub(crate) fn nettoyer(s: &str) -> String {
    s.chars().filter(|c| !c.is_control() && !format_invisible(*c)).take(MAX_TEXTE).collect()
}

/// Every Unicode format character (general category Cf, Scylla 18/11: bidirectional controls, zero-width characters,
/// the soft hyphen, the tag characters U+E0000-E007F that can spell hidden text, …), the Mongolian vowel separator,
/// and the line and paragraph separators (Argos P4: not `is_control`, yet a reader may break the line there). The
/// list is Unicode 15's Cf, written out (std has no general category); the tag block is taken whole.
fn format_invisible(c: char) -> bool {
    matches!(
        c,
        '\u{00AD}'
            | '\u{0600}'..='\u{0605}'
            | '\u{061C}'
            | '\u{06DD}'
            | '\u{070F}'
            | '\u{0890}'..='\u{0891}'
            | '\u{08E2}'
            | '\u{180E}'
            | '\u{200B}'..='\u{200F}'
            | '\u{2028}'..='\u{202E}'
            | '\u{2060}'..='\u{2064}'
            | '\u{2066}'..='\u{206F}'
            | '\u{FEFF}'
            | '\u{FFF9}'..='\u{FFFB}'
            | '\u{110BD}'
            | '\u{110CD}'
            | '\u{13430}'..='\u{1343F}'
            | '\u{1BCA0}'..='\u{1BCA3}'
            | '\u{1D173}'..='\u{1D17A}'
            | '\u{E0000}'..='\u{E007F}'
    )
}

pub(crate) fn ligne_debut(id: &str, t: u64, genre: &'static str, pair: &str, nom: &str, ip: &str, session_ouverte: bool) -> String {
    let (pair, nom, ip) = (nettoyer(pair), nettoyer(nom), nettoyer(ip));
    let ligne = Debut { v: 1, evt: "debut", id, t, genre, pair: &pair, nom: &nom, ip: (!ip.is_empty()).then_some(ip.as_str()), session_ouverte };
    serde_json::to_string(&ligne).unwrap_or_default()
}

pub(crate) fn ligne_fin(id: &str, t: u64) -> String {
    serde_json::to_string(&Fin { v: 1, evt: "fin", id, t }).unwrap_or_default()
}

/// The `t` of a line this module could have written, None for anything else.
fn instant(l: &[u8]) -> Option<u64> {
    if l.is_empty() || l.len() > MAX_LIGNE {
        return None;
    }
    let Ok(serde_json::Value::Object(o)) = serde_json::from_slice::<serde_json::Value>(l) else {
        return None;
    };
    let notre = o.get("v").and_then(|v| v.as_u64()) == Some(1)
        && matches!(o.get("evt").and_then(|v| v.as_str()), Some("debut") | Some("fin"))
        && o.get("id").and_then(|v| v.as_str()).is_some_and(|i| i.len() == 16 && i.bytes().all(|b| b.is_ascii_hexdigit()));
    o.get("t").and_then(|v| v.as_u64()).filter(|_| notre)
}

/// A line this module could have written: the only ones kept when the file is re-created.
pub(crate) fn ligne_valide(l: &[u8]) -> bool {
    instant(l).is_some()
}

/// Styx 17/11: a line dated more than one year before `maintenant`. Never with a clock that reads 0, never for a
/// line dated in the future. (A clock set far ahead would still age the lines: nothing here can tell.)
pub(crate) fn perimee(t: u64, maintenant: u64) -> bool {
    maintenant != 0 && t.saturating_add(DUREE_DE_VIE) < maintenant
}

/// The content to keep from an existing file: its valid lines that are not older than one year, untouched; when
/// they weigh more than the cap, only the most recent ones (at most `LIGNES_GARDEES`, and half the cap, so the next
/// trim is not one line away).
pub(crate) fn garder(contenu: &[u8], maintenant: u64) -> Vec<u8> {
    let valides: Vec<&[u8]> =
        contenu.split(|b| *b == b'\n').filter(|l| instant(l).is_some_and(|t| !perimee(t, maintenant))).collect();
    let total: usize = valides.iter().map(|l| l.len() + 1).sum();
    let mut premier = 0;
    if total > MAX_OCTETS {
        premier = valides.len();
        let mut octets = 0;
        while premier > 0 && valides.len() - premier < LIGNES_GARDEES && octets + valides[premier - 1].len() + 1 <= MAX_OCTETS / 2 {
            premier -= 1;
            octets += valides[premier].len() + 1;
        }
    }
    let mut sortie = Vec::with_capacity(total.min(MAX_OCTETS));
    for l in &valides[premier..] {
        sortie.extend_from_slice(l);
        sortie.push(b'\n');
    }
    sortie
}

/// What an existing log holds; empty when there is no log yet. Scylla 17/11: a log that cannot be read (locked,
/// an I/O error) or that is far too big to be ours is an ERROR, never an empty content: the caller then does not
/// re-create the file (that would empty the client's record) and logs nothing until the next try.
pub(crate) fn lire(p: &Path) -> std::io::Result<Vec<u8>> {
    match std::fs::metadata(p) {
        Err(e) if e.kind() == std::io::ErrorKind::NotFound => Ok(Vec::new()),
        Err(e) => Err(e),
        Ok(m) if m.len() > (4 * MAX_OCTETS) as u64 => {
            Err(std::io::Error::new(std::io::ErrorKind::InvalidData, "log far bigger than this module writes"))
        }
        Ok(_) => std::fs::read(p),
    }
}

/// One message for the writer, its log id already drawn for a « debut ».
pub(crate) enum Evenement {
    Debut { conn_id: i32, id: String, ligne: String },
    Fin { conn_id: i32, t: u64 },
}

/// The writer's step (Argos P4-1): a connection is remembered only once its « debut » is in the log, so a « fin » is
/// never written alone (a « debut » skipped while the log was off, then a « fin » after it came back). `ecrire`
/// appends one line and says whether it did. Pure, for the tests.
pub(crate) fn traiter(ouvertes: &mut std::collections::HashMap<i32, String>, evenement: Evenement, ecrire: &mut dyn FnMut(&str) -> bool) {
    match evenement {
        Evenement::Debut { conn_id, id, ligne } => {
            if ecrire(&ligne) {
                ouvertes.insert(conn_id, id);
            }
        }
        Evenement::Fin { conn_id, t } => {
            if let Some(id) = ouvertes.remove(&conn_id) {
                ecrire(&ligne_fin(&id, t));
            }
        }
    }
}

/// What the trust check says of one level of the path (the parent folder, the log folder, the log file).
#[derive(Debug, Clone, Copy, PartialEq)]
pub(crate) enum Niveau {
    /// Nothing there: the service may create it.
    Absent,
    /// A real folder or file (no reparse point) owned by SYSTEM or Administrators.
    Fiable,
    /// Anything else: a link, an owner that is a user, something unreadable.
    Douteux,
}

#[derive(Debug, PartialEq)]
pub(crate) enum Plan {
    /// Log, creating what is missing.
    Ecrire { creer_parent: bool, creer_dossier: bool },
    /// Do not log, and touch nothing: no takeover, no reset, no delete (Scylla 17/11).
    Passer,
}

/// What the service does given the three levels. One untrusted level is enough to do nothing at all.
pub(crate) fn plan(parent: Niveau, dossier: Niveau, fichier: Niveau) -> Plan {
    use Niveau::*;
    match (parent, dossier, fichier) {
        (Douteux, _, _) | (_, Douteux, _) | (_, _, Douteux) => Plan::Passer,
        // Something that exists under a level that does not: not a state to act on.
        (Absent, Fiable, _) | (_, Absent, Fiable) => Plan::Passer,
        (p, d, _) => Plan::Ecrire { creer_parent: p == Absent, creer_dossier: d == Absent },
    }
}

/// Re-creates the log of folder `d` from `ancien` (see `garder`): written to a brand-new temporary file in the same
/// (trusted) folder, flushed to disk, then renamed over the log (Windows: MoveFileExW with REPLACE_EXISTING, one
/// volume). A crash before the rename leaves the old log whole and a temporary file that the next call removes; a
/// failed rename (the log held open without delete sharing) leaves the old log whole too. Nothing else in the folder
/// is touched. The only thing deleted is this module's own temporary file, one file, never a folder and never
/// recursively: if that name is anything else (a folder, a link), this fails and nothing is logged.
pub(crate) fn recreer(d: &Path, ancien: &[u8], maintenant: u64) -> std::io::Result<()> {
    use std::io::Write;
    let tmp = d.join(TEMPORAIRE);
    match std::fs::symlink_metadata(&tmp) {
        Ok(m) if m.is_file() => std::fs::remove_file(&tmp)?,
        Ok(_) => return Err(std::io::Error::new(std::io::ErrorKind::AlreadyExists, "temporary name taken by something else")),
        Err(e) if e.kind() == std::io::ErrorKind::NotFound => {}
        Err(e) => return Err(e),
    }
    let mut f = std::fs::OpenOptions::new().write(true).create_new(true).open(&tmp)?;
    f.write_all(&garder(ancien, maintenant))?;
    f.sync_all()?;
    drop(f);
    std::fs::rename(&tmp, d.join(FICHIER))
}

/// Appends one line to the log `recreer` made (never creates the file), and trims it when it passes the cap.
pub(crate) fn ajouter(d: &Path, ligne: &str, maintenant: u64) -> std::io::Result<()> {
    use std::io::Write;
    let p = d.join(FICHIER);
    let mut f = std::fs::OpenOptions::new().append(true).open(&p)?;
    // One write per line: a line is whole or absent (a torn one is dropped at the next start).
    f.write_all(format!("{ligne}\n").as_bytes())?;
    f.sync_data()?;
    let taille = f.metadata()?.len() as usize;
    drop(f);
    if taille > MAX_OCTETS {
        recreer(d, &lire(&p)?, maintenant)?;
    }
    Ok(())
}

#[cfg(windows)]
mod service {
    use super::*;
    use crate::informatech_rotation::{commande_ok, creer_dossier_ferme, fiable, niveau, poser_dacl, systeme32};
    use hbb_common::rand::{rngs::OsRng, RngCore};
    use std::collections::HashMap;
    use std::path::PathBuf;
    use std::sync::mpsc::{sync_channel, Receiver, SyncSender};
    use std::sync::OnceLock;
    use std::time::{Duration, Instant};

    enum Message {
        Debut { conn_id: i32, t: u64, genre: &'static str, pair: String, nom: String, ip: String, session_ouverte: bool },
        Fin { conn_id: i32, t: u64 },
    }

    /// The session's side only does `try_send` on this bounded queue: full or absent, the message is dropped.
    static FILE: OnceLock<SyncSender<Message>> = OnceLock::new();
    const ATTENTE: usize = 256;
    /// After a failure the folder is looked at again at most this often, and only when a connection needs it.
    const NOUVEL_ESSAI: Duration = Duration::from_secs(600);

    /// None when Windows does not give its system directory: nothing is logged then (and the state says so).
    fn dossier() -> Option<PathBuf> {
        dossier_du_journal(systeme32("")?.to_str()?).map(PathBuf::from)
    }

    /// Where the service says whether it logs (see the module's header). Machine-wide, written by SYSTEM only.
    const CLE_ETAT: &str = r"SOFTWARE\InformaTech\OPMD-journal";

    /// Publishes the state for the client's Hub. Called at start and when the state changes, never per connection.
    /// Rights (Scylla 17/11): the key is created by this service, as SYSTEM, under HKLM\SOFTWARE (64-bit view: the
    /// service is a 64-bit process) and takes that hive's inherited rights: SYSTEM and Administrators full,
    /// BUILTIN\Users read only. A standard user can therefore read « hors-service » and cannot forge « actif ». The
    /// parent `SOFTWARE\InformaTech` is the engine installer's (InstallState), created elevated, same inherited rights.
    /// The Hub must read anything but these two words, a value of another type, or a `t` in the future as « inconnu ».
    fn publier(pret: bool) {
        use winreg::{enums::HKEY_LOCAL_MACHINE, RegKey};
        let ecrit = RegKey::predef(HKEY_LOCAL_MACHINE).create_subkey(CLE_ETAT).and_then(|(cle, _)| {
            cle.set_value("etat", &etat(pret))?;
            cle.set_value("t", &maintenant())
        });
        if ecrit.is_err() {
            journal("the state of the connection log could not be published");
        }
    }

    fn maintenant() -> u64 {
        std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).map(|d| d.as_secs()).unwrap_or(0)
    }

    /// Fixed event names only: never a peer's text. Called at most once per failure, never per connection.
    fn journal(evenement: &'static str) {
        hbb_common::log::warn!("informatech journal: {evenement}");
    }

    /// True when the log is ready to be appended to. Order (Scylla 17/11): the trust check FIRST, on the three
    /// levels; an untrusted one ends here with nothing touched. Then only: create what is missing, already closed
    /// (`creer_dossier_ferme`: the folder is born with its owner and protected DACL, and fails if the name appeared
    /// meanwhile), check again that what was created is ours, and only then set the DACL again (one icacls call on a
    /// path that has just passed the check, `/L`) and the owner. No takeown: a folder that needs one is not trusted,
    /// hence skipped. Nothing is ever removed here but the module's own temporary file.
    fn preparer(d: &Path) -> bool {
        use std::ffi::OsStr;
        let Some(parent) = d.parent() else {
            return false;
        };
        let p = d.join(FICHIER);
        let Plan::Ecrire { creer_parent, creer_dossier } = plan(niveau(parent), niveau(d), niveau(&p)) else {
            return false;
        };
        if creer_parent && (creer_dossier_ferme(parent, "SY", false).is_err() || !fiable(parent) || poser_dacl(parent, false).is_err()) {
            return false;
        }
        if creer_dossier && creer_dossier_ferme(d, "SY", true).is_err() {
            return false;
        }
        if !fiable(d)
            || poser_dacl(d, true).is_err()
            || !commande_ok("icacls.exe", &[d.as_os_str(), OsStr::new("/setowner"), OsStr::new("*S-1-5-18"), OsStr::new("/L")])
            || !fiable(d)
        {
            return false;
        }
        // Unreadable: nothing re-created, nothing logged, state « hors-service » (never an emptied log).
        let Ok(ancien) = (if creer_dossier { Ok(Vec::new()) } else { lire(&p) }) else {
            return false;
        };
        recreer(d, &ancien, maintenant()).is_ok() && fiable(&p)
    }

    fn boucle(rx: Receiver<Message>) {
        let Some(d) = dossier() else {
            journal("connections are not logged: Windows did not give its system directory");
            publier(false);
            // The queue is still emptied, so the sessions' side never sees it full for good.
            while rx.recv().is_ok() {}
            return;
        };
        let mut ouvertes: HashMap<i32, String> = HashMap::new();
        let mut pret = preparer(&d);
        let mut dernier_essai = Instant::now();
        if !pret {
            journal("connections are not logged: the log folder is not trusted or cannot be prepared");
        }
        publier(pret);
        // Appends one line when the log is ready; true when the line is in the log.
        let mut ecrire = |ligne: &str| -> bool {
            if !pret && dernier_essai.elapsed() >= NOUVEL_ESSAI {
                pret = preparer(&d);
                dernier_essai = Instant::now();
                if pret {
                    publier(true);
                }
            }
            if !pret || ligne.is_empty() {
                return false;
            }
            // Looked at again before every write: an untrusted level means skip, never repair.
            if !(fiable(&d) && fiable(&d.join(FICHIER))) || ajouter(&d, ligne, maintenant()).is_err() {
                pret = false;
                dernier_essai = Instant::now();
                journal("connections are not logged: the log is not trusted or cannot be written");
                publier(false);
                return false;
            }
            true
        };
        while let Ok(message) = rx.recv() {
            let evenement = match message {
                Message::Debut { conn_id, t, genre, pair, nom, ip, session_ouverte } => {
                    let mut octets = [0u8; 8];
                    OsRng.fill_bytes(&mut octets);
                    let id = hex::encode(octets);
                    let ligne = ligne_debut(&id, t, genre, &pair, &nom, &ip, session_ouverte);
                    Evenement::Debut { conn_id, id, ligne }
                }
                Message::Fin { conn_id, t } => Evenement::Fin { conn_id, t },
            };
            traiter(&mut ouvertes, evenement, &mut ecrire);
        }
    }

    /// Started once in the `--server` process: the writer thread (it runs icacls, away from any session).
    pub fn demarrer() {
        let (tx, rx) = sync_channel(ATTENTE);
        if FILE.set(tx).is_ok() {
            std::thread::spawn(move || boucle(rx));
        }
    }

    /// An authorized connection has just opened. Never blocks.
    pub fn debut(conn_id: i32, conn_type: &str, pair: &str, nom: &str, ip: &str) {
        if let Some(tx) = FILE.get() {
            // Argos P4-2: whether a Windows session is open is read here, at the authorization, not later in the
            // writer.
            let session_ouverte = !crate::platform::is_prelogin();
            let _ = tx.try_send(Message::Debut {
                conn_id,
                t: maintenant(),
                genre: genre(conn_type),
                pair: nettoyer(pair),
                nom: nettoyer(nom),
                ip: nettoyer(ip),
                session_ouverte,
            });
        }
    }

    /// That connection has closed. Never blocks.
    pub fn fin(conn_id: i32) {
        if let Some(tx) = FILE.get() {
            let _ = tx.try_send(Message::Fin { conn_id, t: maintenant() });
        }
    }
}

#[cfg(windows)]
pub use service::{debut, demarrer, fin};

#[cfg(test)]
mod tests {
    use super::*;

    const ID: &str = "0123456789abcdef";

    fn dossier_d_essai(nom: &str) -> std::path::PathBuf {
        let d = std::env::temp_dir().join(format!("informatech-journal-{nom}-{}", std::process::id()));
        let _ = std::fs::remove_dir_all(&d);
        std::fs::create_dir_all(&d).unwrap();
        d
    }

    #[test]
    fn lines_have_the_agreed_shape() {
        let l = ligne_debut(ID, 1_763_340_000, genre("remote"), "123 456 789", "PC-ATELIER", "203.0.113.7", false);
        let v: serde_json::Value = serde_json::from_str(&l).unwrap();
        let attendu = serde_json::json!({"v": 1, "evt": "debut", "id": ID, "t": 1_763_340_000u64, "type": "controle",
            "pair": "123 456 789", "nom": "PC-ATELIER", "ip": "203.0.113.7", "sessionOuverte": false});
        assert_eq!(v, attendu);
        assert!(!l.contains('\n'));
        // No address known: null, not an empty string.
        let sans_ip: serde_json::Value = serde_json::from_str(&ligne_debut(ID, 1, "controle", "p", "n", "", true)).unwrap();
        assert!(sans_ip["ip"].is_null());
        assert_eq!(sans_ip["sessionOuverte"], true);
        let fin: serde_json::Value = serde_json::from_str(&ligne_fin(ID, 2)).unwrap();
        assert_eq!(fin, serde_json::json!({"v": 1, "evt": "fin", "id": ID, "t": 2}));
        // Both are lines the module accepts back.
        assert!(ligne_valide(l.as_bytes()) && ligne_valide(ligne_fin(ID, 2).as_bytes()));
        for (t, g) in [("remote", "controle"), ("file_transfer", "fichiers"), ("port_forward", "tunnel"), ("view_camera", "camera"), ("terminal", "terminal")] {
            assert_eq!(genre(t), g);
        }
    }

    #[test]
    fn peer_text_has_no_bidi_or_invisible_formatting() {
        // Scylla 17/11: right-to-left override, isolates, marks, zero-width characters and the BOM go.
        let nom = "PC\u{202E}exe.jpg\u{2066}x\u{2069}\u{200B}\u{200F}\u{061C}\u{FEFF}\u{2060}y";
        assert_eq!(nettoyer(nom), "PCexe.jpgxy");
        // Argos P4: line and paragraph separators, soft hyphen, Mongolian vowel separator.
        assert_eq!(nettoyer("a\u{2028}b\u{2029}c\u{00AD}d\u{180E}e"), "abcde");
        // Scylla 18/11: the whole Cf category, tag characters (hidden text) included.
        assert_eq!(nettoyer("x\u{E0001}\u{E0068}\u{E0069}\u{E007F}\u{0600}\u{06DD}\u{2064}\u{13430}\u{1D173}y"), "xy");
        // Ordinary accents, other scripts and emoji stay.
        assert_eq!(nettoyer("Poste d’Élodie · 王 🙂"), "Poste d’Élodie · 王 🙂");
    }

    #[test]
    fn peer_text_is_bounded_and_cannot_break_a_line() {
        let nom = format!("a\nb\r\u{0}\u{1b}[31m{}", "é".repeat(200));
        let l = ligne_debut(ID, 1, "controle", "p\n{\"v\":1}", &nom, "1.2.3.4\n", true);
        assert!(!l.contains('\n') && !l.contains('\r'));
        let v: serde_json::Value = serde_json::from_str(&l).unwrap();
        assert_eq!(v["nom"].as_str().unwrap().chars().count(), 64);
        assert!(v["nom"].as_str().unwrap().starts_with("ab[31m"));
        assert_eq!(v["pair"], "p{\"v\":1}");
        assert_eq!(v["ip"], "1.2.3.4");
        // The longest line the module can write still passes its own check.
        let long = ligne_debut(ID, u64::MAX, "controle", &"\"".repeat(64), &"\\".repeat(64), &"\"".repeat(64), true);
        assert!(long.len() <= MAX_LIGNE && ligne_valide(long.as_bytes()));
    }

    #[test]
    fn only_our_own_lines_are_kept() {
        let bonne = ligne_fin(ID, 5);
        for mauvaise in [
            "", "pas du json", "[1]", "{\"v\":2,\"evt\":\"fin\",\"id\":\"0123456789abcdef\",\"t\":1}",
            "{\"v\":1,\"evt\":\"autre\",\"id\":\"0123456789abcdef\",\"t\":1}", "{\"v\":1,\"evt\":\"fin\",\"id\":\"0123\",\"t\":1}",
            "{\"v\":1,\"evt\":\"fin\",\"id\":\"0123456789abcdeg\",\"t\":1}", "{\"v\":1,\"evt\":\"fin\",\"id\":\"0123456789abcdef\",\"t\":-1}",
            "{\"v\":1,\"evt\":\"fin\",\"id\":\"0123456789abcdef\"",
        ] {
            assert!(!ligne_valide(mauvaise.as_bytes()), "{mauvaise}");
        }
        let trop_longue = format!("{{\"v\":1,\"evt\":\"fin\",\"id\":\"{ID}\",\"t\":1,\"x\":\"{}\"}}", "a".repeat(MAX_LIGNE));
        assert!(!ligne_valide(trop_longue.as_bytes()));
        // A torn last line, a stranger's text and invalid UTF-8 go; the valid lines stay byte for byte, in order.
        let mut contenu = format!("{bonne}\nintrus\n{}\n", ligne_debut(ID, 6, "controle", "p", "n", "", true)).into_bytes();
        contenu.extend_from_slice(b"\xff\xfe\n{\"v\":1,\"evt\":\"fin\",\"id\":\"0123");
        let garde = garder(&contenu, 0);
        assert_eq!(garde, format!("{bonne}\n{}\n", ligne_debut(ID, 6, "controle", "p", "n", "", true)).into_bytes());
        assert!(garder(b"", 0).is_empty());
    }

    /// Styx 17/11: the log keeps the remote side's address, so a line lives one year at most.
    #[test]
    fn a_line_lives_one_year() {
        const AN: u64 = 365 * 24 * 3600;
        let maintenant = 1_763_340_000u64;
        assert!(!perimee(maintenant, maintenant));
        assert!(!perimee(maintenant - AN, maintenant), "exactly one year old: kept");
        assert!(perimee(maintenant - AN - 1, maintenant));
        assert!(perimee(0, maintenant));
        // A clock that reads 0 drops nothing; a line dated in the future is kept; no overflow at the end of time.
        assert!(!perimee(0, 0) && !perimee(5, 0));
        assert!(!perimee(maintenant + 10 * AN, maintenant));
        assert!(!perimee(u64::MAX, maintenant) && !perimee(u64::MAX, u64::MAX));
        assert!(perimee(1, u64::MAX));
        let vieille_debut = ligne_debut(ID, maintenant - AN - 1, "controle", "p", "n", "203.0.113.7", true);
        let vieille_fin = ligne_fin(ID, maintenant - AN - 1);
        let limite = ligne_fin(ID, maintenant - AN);
        let recente = ligne_debut("fedcba9876543210", maintenant - 60, "controle", "p", "n", "203.0.113.7", true);
        let future = ligne_fin("fedcba9876543210", maintenant + AN);
        let contenu = format!("{vieille_debut}\n{vieille_fin}\n{limite}\n{recente}\n{future}\n");
        // Old lines go, the others stay byte for byte and in order; the address goes with its line.
        let garde = String::from_utf8(garder(contenu.as_bytes(), maintenant)).unwrap();
        assert_eq!(garde, format!("{limite}\n{recente}\n{future}\n"));
        // With a clock at 0 everything stays.
        assert_eq!(garder(contenu.as_bytes(), 0), contenu.as_bytes());
        // The file on disk follows: re-creating it a year later leaves only what is still young.
        let d = dossier_d_essai("un-an");
        recreer(&d, contenu.as_bytes(), 0).unwrap();
        assert_eq!(std::fs::read_to_string(d.join(FICHIER)).unwrap(), contenu);
        recreer(&d, &lire(&d.join(FICHIER)).unwrap(), maintenant).unwrap();
        assert_eq!(std::fs::read_to_string(d.join(FICHIER)).unwrap(), garde);
        recreer(&d, &lire(&d.join(FICHIER)).unwrap(), maintenant + 2 * AN + 1).unwrap();
        assert_eq!(std::fs::read_to_string(d.join(FICHIER)).unwrap(), "");
        std::fs::remove_dir_all(&d).unwrap();
    }

    /// Scylla 17/11: a machine folder is created closed, in one call (no inherited right at any moment).
    #[test]
    fn folders_are_created_closed() {
        assert_eq!(sddl_dossier("SY", true), "O:SYD:P(A;OICI;FA;;;SY)(A;OICI;FA;;;BA)(A;OICI;FRFX;;;BU)");
        assert_eq!(sddl_dossier("BA", false), "O:BAD:P(A;OICI;FA;;;SY)(A;OICI;FA;;;BA)");
        // `P`: protected, nothing inherited from ProgramData (where Users may create folders and files).
        for s in [sddl_dossier("SY", false), sddl_dossier("BA", true)] {
            assert!(s.contains("D:P("), "{s}");
            assert!(!s.contains(";;;WD)") && !s.contains(";;;AU)") && !s.contains(";;;CO)"), "{s}");
        }
        assert_eq!(sous_programdata(r"C:\Windows\System32\", "OPMD").as_deref(), Some(r"C:\ProgramData\InformaTech\OPMD"));
        assert_eq!(sous_programdata(r"\\?\C:\Windows", "OPMD"), None);
    }

    /// Scylla 17/11: the state the Hub reads, and where the log lives (the same rule as the Hub's reader).
    #[test]
    fn the_state_words_and_the_folder_are_pinned() {
        assert_eq!(etat(true), "actif");
        assert_eq!(etat(false), "hors-service");
        assert_eq!(dossier_du_journal(r"C:\Windows\System32").as_deref(), Some(r"C:\ProgramData\InformaTech\OPMD-journal"));
        assert_eq!(dossier_du_journal(r"d:\WINDOWS\system32\").as_deref(), Some(r"d:\ProgramData\InformaTech\OPMD-journal"));
        for refuse in ["", "C:", "C:Windows", r"\\serveur\partage\System32", "/usr/lib", r"1:\Windows", r"é:\Windows"] {
            assert_eq!(dossier_du_journal(refuse), None, "{refuse}");
        }
    }

    #[test]
    fn above_the_cap_only_the_most_recent_lines_stay() {
        let ligne = |i: usize| ligne_debut(&format!("{i:016x}"), i as u64, "controle", &"p".repeat(32), &"n".repeat(32), "203.0.113.7", true);
        let n = MAX_OCTETS / ligne(0).len() + 50;
        let contenu: String = (0..n).map(|i| ligne(i) + "\n").collect();
        assert!(contenu.len() > MAX_OCTETS);
        let garde = garder(contenu.as_bytes(), 0);
        let lignes: Vec<&str> = std::str::from_utf8(&garde).unwrap().lines().collect();
        assert_eq!(lignes.len(), LIGNES_GARDEES);
        assert!(garde.len() <= MAX_OCTETS / 2);
        // The most recent ones, unchanged and in order.
        assert_eq!(lignes[LIGNES_GARDEES - 1], ligne(n - 1));
        assert_eq!(lignes[0], ligne(n - LIGNES_GARDEES));
        // Under the cap nothing is dropped.
        let petit: String = (0..600).map(|i| ligne_fin(&format!("{i:016x}"), i as u64) + "\n").collect();
        assert_eq!(garder(petit.as_bytes(), 0), petit.as_bytes());
    }

    /// Argos P4-1: a « fin » is written only for a connection whose « debut » is in the log.
    #[test]
    fn a_fin_is_never_written_without_its_debut() {
        let mut ouvertes = std::collections::HashMap::new();
        let mut ecrites: Vec<String> = Vec::new();
        let debut = |conn_id: i32, id: &str| Evenement::Debut { conn_id, id: id.to_owned(), ligne: ligne_debut(id, 1, "controle", "p", "n", "", true) };
        let a = "000000000000000a";
        let b = "000000000000000b";
        // The log is off when connection 1 opens: its « debut » is not written.
        traiter(&mut ouvertes, debut(1, a), &mut |_| false);
        // It comes back: connection 2 opens and is written.
        traiter(&mut ouvertes, debut(2, b), &mut |l| {
            ecrites.push(l.to_owned());
            true
        });
        // Both close: only connection 2's « fin » is written; a « fin » for a connection never seen writes nothing.
        for conn_id in [1, 2, 3] {
            traiter(&mut ouvertes, Evenement::Fin { conn_id, t: 5 }, &mut |l| {
                ecrites.push(l.to_owned());
                true
            });
        }
        assert_eq!(ecrites, vec![ligne_debut(b, 1, "controle", "p", "n", "", true), ligne_fin(b, 5)]);
        assert!(ouvertes.is_empty());
        // A « fin » whose write fails is not retried: the connection is forgotten all the same.
        traiter(&mut ouvertes, debut(4, a), &mut |_| true);
        traiter(&mut ouvertes, Evenement::Fin { conn_id: 4, t: 6 }, &mut |_| false);
        assert!(ouvertes.is_empty());
    }

    /// Scylla 17/11: an untrusted level (a reparse point, a folder a user owns: `Douteux`, told by
    /// informatech_rotation::digne_de_confiance, tested there) means nothing is touched.
    #[test]
    fn an_untrusted_level_means_do_nothing() {
        use Niveau::*;
        for a in [Absent, Fiable, Douteux] {
            for b in [Absent, Fiable, Douteux] {
                assert_eq!(plan(Douteux, a, b), Plan::Passer, "parent");
                assert_eq!(plan(a, Douteux, b), Plan::Passer, "folder pre-created by a user, or a junction");
                assert_eq!(plan(a, b, Douteux), Plan::Passer, "file planted under the log's name");
            }
        }
        // The service creates only what is missing.
        assert_eq!(plan(Absent, Absent, Absent), Plan::Ecrire { creer_parent: true, creer_dossier: true });
        assert_eq!(plan(Fiable, Absent, Absent), Plan::Ecrire { creer_parent: false, creer_dossier: true });
        assert_eq!(plan(Fiable, Fiable, Absent), Plan::Ecrire { creer_parent: false, creer_dossier: false });
        assert_eq!(plan(Fiable, Fiable, Fiable), Plan::Ecrire { creer_parent: false, creer_dossier: false });
        // Something under a level that does not exist: not a state to act on.
        assert_eq!(plan(Absent, Fiable, Absent), Plan::Passer);
        assert_eq!(plan(Fiable, Absent, Fiable), Plan::Passer);
    }

    #[test]
    fn the_log_is_recreated_without_touching_anything_else() {
        let d = dossier_d_essai("recreer");
        std::fs::write(d.join(FICHIER), format!("intrus\n{}\n{{\"v\":1,\"evt\":\"fin\",\"id\"", ligne_fin(ID, 1))).unwrap();
        std::fs::write(d.join("autre.txt"), "x").unwrap();
        std::fs::create_dir_all(d.join("sous-dossier").join("x")).unwrap();
        // A leftover of an interrupted trim is the one thing this module deletes.
        std::fs::write(d.join(TEMPORAIRE), "reste d'un arrêt").unwrap();
        recreer(&d, &lire(&d.join(FICHIER)).unwrap(), 0).unwrap();
        // Its valid lines stay, byte for byte; the neighbours are still there.
        assert_eq!(std::fs::read_to_string(d.join(FICHIER)).unwrap(), format!("{}\n", ligne_fin(ID, 1)));
        assert_eq!(std::fs::read_to_string(d.join("autre.txt")).unwrap(), "x");
        assert!(d.join("sous-dossier").join("x").is_dir());
        assert!(!d.join(TEMPORAIRE).exists());
        ajouter(&d, &ligne_fin(ID, 2), 0).unwrap();
        ajouter(&d, &ligne_fin(ID, 3), 0).unwrap();
        assert_eq!(std::fs::read_to_string(d.join(FICHIER)).unwrap(), format!("{}\n{}\n{}\n", ligne_fin(ID, 1), ligne_fin(ID, 2), ligne_fin(ID, 3)));
        // The temporary name taken by a folder: refused, the folder and its content are left alone, the log unchanged.
        std::fs::create_dir_all(d.join(TEMPORAIRE).join("garde")).unwrap();
        assert!(recreer(&d, b"", 0).is_err());
        assert!(d.join(TEMPORAIRE).join("garde").is_dir());
        assert_eq!(std::fs::read_to_string(d.join(FICHIER)).unwrap().lines().count(), 3);
        std::fs::remove_dir_all(&d).unwrap();
    }

    #[test]
    fn appending_never_creates_the_file_and_trims_past_the_cap() {
        let d = dossier_d_essai("ajouter");
        assert!(ajouter(&d, &ligne_fin(ID, 1), 0).is_err());
        assert!(!d.join(FICHIER).exists());
        recreer(&d, &[], 0).unwrap();
        let ligne = |i: usize| ligne_debut(&format!("{i:016x}"), i as u64, "controle", &"p".repeat(32), &"n".repeat(32), "203.0.113.7", true);
        let n = MAX_OCTETS / (ligne(0).len() + 1);
        let presque: String = (0..n).map(|i| ligne(i) + "\n").collect();
        std::fs::write(d.join(FICHIER), &presque).unwrap();
        ajouter(&d, &ligne(n), 0).unwrap();
        let apres = std::fs::read_to_string(d.join(FICHIER)).unwrap();
        assert!(apres.len() <= MAX_OCTETS / 2);
        assert_eq!(apres.lines().count(), LIGNES_GARDEES);
        assert_eq!(apres.lines().last().unwrap(), ligne(n));
        // A log far bigger than anything this module writes is not read back: an error, never an empty content.
        std::fs::write(d.join(FICHIER), vec![b'a'; 4 * MAX_OCTETS + 1]).unwrap();
        assert_eq!(lire(&d.join(FICHIER)).unwrap_err().kind(), std::io::ErrorKind::InvalidData);
        // ... and appending to it does not empty it either: the append fails before any re-creation.
        let avant = std::fs::metadata(d.join(FICHIER)).unwrap().len();
        assert!(ajouter(&d, &ligne_fin(ID, 9), 0).is_err());
        assert_eq!(std::fs::metadata(d.join(FICHIER)).unwrap().len(), avant + ligne_fin(ID, 9).len() as u64 + 1);
        // No log yet: an empty content, not an error.
        assert!(lire(&d.join("absent.jsonl")).unwrap().is_empty());
        std::fs::remove_dir_all(&d).unwrap();
    }

    /// Scylla 17/11: re-creating never loses the log. A leftover temporary file (a crash before the rename) is
    /// removed and the log is whole; a log that cannot be read is never replaced.
    #[test]
    fn re_creating_never_loses_the_log() {
        let d = dossier_d_essai("sans-perte");
        let lignes = format!("{}\n{}\n", ligne_fin(ID, 1), ligne_fin(ID, 2));
        std::fs::write(d.join(FICHIER), &lignes).unwrap();
        // A crash after the temporary file was written, before the rename: the log is untouched.
        std::fs::write(d.join(TEMPORAIRE), "moitié d'une copie").unwrap();
        assert_eq!(std::fs::read_to_string(d.join(FICHIER)).unwrap(), lignes);
        // The next re-creation removes the leftover and keeps every line.
        recreer(&d, &lire(&d.join(FICHIER)).unwrap(), 0).unwrap();
        assert_eq!(std::fs::read_to_string(d.join(FICHIER)).unwrap(), lignes);
        assert!(!d.join(TEMPORAIRE).exists());
        // The temporary name is a link or a folder: refused, the log is untouched.
        std::fs::create_dir(d.join(TEMPORAIRE)).unwrap();
        assert!(recreer(&d, b"", 0).is_err());
        assert_eq!(std::fs::read_to_string(d.join(FICHIER)).unwrap(), lignes);
        std::fs::remove_dir_all(&d).unwrap();
    }
}
