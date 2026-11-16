//! InformaTech (A12): the OPMD service rotates its permanent password after each session, so a password handed to
//! InformaTech Admin serves once (D4, option C). Contract: InformaTech's « A4 §12 » (F1-F5) and Scylla's conditions.
//!
//! - Configured by `--informatech-rotation` (elevated), which reads ONE line of JSON `{ "url", "jeton" }` from stdin:
//!   the token never appears on a command line. `--informatech-rotation --effacer` clears it.
//! - Runs in the `--server` process (SYSTEM), with its state on disk because `--server` is respawned often:
//!   rotates at start (service start, and after `--close-connections`, which ends `--server`), and 3 minutes after the
//!   last authorized connection closed by itself (an authorized reconnect within that time cancels it). Never while an
//!   authorized connection is open.
//! - A new password: 24 characters [A-Za-z0-9] from the OS RNG, applied locally first, kept pending, then POSTed to
//!   `<url>/v1/acces/mot-de-passe { jeton, motDePasse }`: 204 done; 410/404/401 stop and clear; 400 kept, no retry until
//!   the next trigger; 429/5xx/network kept, same value retried every 5 minutes, at most 24 hours.
//! - Logs carry fixed event names only (`journal` takes `&'static str`): never the token, the URL or a password.

use hbb_common::{config::Config, rand::rngs::OsRng, rand::RngCore, ResultType};
use serde::{Deserialize, Serialize};
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
pub(crate) fn decider(etat: &Etat, connexions: usize, fin_derniere: Option<u64>, maintenant: u64, demarrage: bool) -> Action {
    if connexions > 0 {
        return Action::Rien;
    }
    let declencheur = demarrage || fin_derniere.is_some_and(|t| maintenant >= t + GRACE_S);
    if etat.en_attente.is_some() {
        let depuis = etat.depuis.unwrap_or(maintenant);
        if maintenant.saturating_sub(depuis) >= PLAFOND_S && !declencheur {
            return Action::Rien;
        }
        if etat.suspendu && !declencheur {
            return Action::Rien;
        }
        let dernier = etat.dernier_essai.unwrap_or(0);
        if declencheur || maintenant >= dernier + REESSAI_S {
            return Action::Reessayer;
        }
        return Action::Rien;
    }
    if declencheur {
        Action::Tourner
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

fn chemin() -> PathBuf {
    Config::path(FICHIER)
}

fn lire() -> Option<Etat> {
    let texte = std::fs::read_to_string(chemin()).ok()?;
    serde_json::from_str(&texte).ok()
}

fn ecrire(e: &Etat) -> ResultType<()> {
    let p = chemin();
    if let Some(d) = p.parent() {
        std::fs::create_dir_all(d)?;
    }
    let tmp = p.with_extension("tmp");
    std::fs::write(&tmp, serde_json::to_vec(e)?)?;
    std::fs::rename(&tmp, &p)?;
    Ok(())
}

fn effacer_fichier() {
    let _ = std::fs::remove_file(chemin());
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

/// `--informatech-rotation [--effacer]` (elevated, installed). Reads the configuration from stdin.
pub fn commande(args: &[String]) -> Result<(), &'static str> {
    if args.iter().any(|a| a == "--effacer") {
        effacer_fichier();
        return Ok(());
    }
    let mut ligne = String::new();
    std::io::stdin().read_line(&mut ligne).map_err(|_| "cannot read stdin")?;
    let e = lire_configuration(&ligne)?;
    ecrire(&e).map_err(|_| "cannot write the state file")?;
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
                    if action == Action::Tourner || demarrage || fin_derniere.is_some() {
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
        assert_eq!(decider(&e, 0, None, 1000 + 300, false), Action::Reessayer);
        assert_eq!(decider(&e, 0, None, PLAFOND_S + 10, false), Action::Rien, "past 24 h: wait for a trigger");
        assert_eq!(decider(&e, 0, None, PLAFOND_S + 10, true), Action::Reessayer, "a trigger retries the SAME value");
        e.suspendu = true;
        e.depuis = Some(1000);
        assert_eq!(decider(&e, 0, None, 1000 + 600, false), Action::Rien, "400: until the next trigger");
        assert_eq!(decider(&e, 0, Some(1000), 1000 + 600, false), Action::Reessayer);
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
