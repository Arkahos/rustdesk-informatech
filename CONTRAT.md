# CONTRAT — binaire InformaTech Assistance (fork RustDesk 1.5.0)

Fiche d'intégration pour la session ArkaFactory (recette « prise-en-main » du
kit, hub Tauri). Décrit le binaire produit par ce dépôt : comment le
télécharger, l'installer en silencieux, le détecter et le piloter.

> ✅ **État** : build `v1.5.0-informatech.0` réussi, release publiée avec l'exe
> et le .msi, SHA-256 renseignés ci-dessous. Reste la vérif `--get-id` en
> portable sur le PC d'Adrien (§7).

---

## 1. Dépôt et release

| | |
|---|---|
| Dépôt (public, AGPL-3.0) | https://github.com/Arkahos/rustdesk-informatech |
| Branche de travail | `informatech` (depuis le tag amont `1.5.0`) |
| Tag de release | `v1.5.0-informatech.0` (incrémenter `.N` pour republier) |
| Page de release (prévue) | https://github.com/Arkahos/rustdesk-informatech/releases/tag/v1.5.0-informatech.0 |

### Fichiers de la release (nommage figé dans le workflow)

| Fichier | Rôle |
|---|---|
| `informatech-assistance-1.5.0-x86_64.exe` | **Exe à déployer** : installeur portable auto-extractible (RustDesk « portable packer »). C'est ce fichier que le hub télécharge et lance avec `--silent-install`. |
| `informatech-assistance-1.5.0-x86_64.msi` | Variante MSI (même contenu), fournie si besoin d'un déploiement MSI. |

**URL de téléchargement directe de l'exe** (prévue) :
```
https://github.com/Arkahos/rustdesk-informatech/releases/download/v1.5.0-informatech.0/informatech-assistance-1.5.0-x86_64.exe
```

### SHA-256 (build v1.5.0-informatech.0)

```
8d465c5cc8e4e35f55dbf4f1d3c5f2e0426f109a7a0cfb7dc7cb2c0a69ad5bd8  informatech-assistance-1.5.0-x86_64.exe
4594ea5adb6ba58605b5433d88c14061c73e7fb4e44b8771151ae8fdec8dee4c  informatech-assistance-1.5.0-x86_64.msi
```

---

## 2. Installation en service (`--silent-install`)

Commande (élévation requise, lancée par le hub) :
```
informatech-assistance-1.5.0-x86_64.exe --silent-install
```

Résultat après installation :

| | |
|---|---|
| Dossier d'installation | `C:\Program Files\InformaTech\` |
| Exécutable installé | `C:\Program Files\InformaTech\InformaTech.exe` |
| Nom du service Windows | **`InformaTech`** (nom = nom d'affichage) |

> L'exe interne du build s'appelle `rustdesk.exe` ; `--silent-install` le copie
> dans `C:\Program Files\InformaTech\` **en le renommant `InformaTech.exe`**.
> Tous les processus runtime portent donc le nom `InformaTech.exe`.

---

## 3. Processus (détection d'état par le hub)

Tous les processus sont des instances de `InformaTech.exe` distinguées par leur
**premier argument** :

| Processus | Lancé par | Rôle |
|---|---|---|
| `InformaTech.exe --service` | le gestionnaire de services Windows | service principal |
| `InformaTech.exe --server` | le service | cœur (écoute des connexions) |
| `InformaTech.exe --tray` | le service/session | icône de zone de notification — **masquée** (hide-tray=Y), le processus peut ne pas tourner |
| `InformaTech.exe --cm` | le serveur, à chaque connexion entrante | **gestionnaire de connexions** — fenêtre **masquée** (hide_cm) |

> **Détection d'une connexion en cours** : présence d'un processus
> `InformaTech.exe` avec l'argument **`--cm`**. Il est lancé quand une session
> distante est acceptée et se termine à la fin de la session. Sa fenêtre est
> masquée (opacité 0 + minimisée), mais le processus existe bien.

---

## 4. Emplacements config et journaux

Config (format TOML, nommé d'après `APP_NAME` = `InformaTech`) :

| Contexte | Chemin |
|---|---|
| Service (SYSTEM) | `C:\Windows\System32\config\systemprofile\AppData\Roaming\InformaTech\config\` |
| Utilisateur courant | `%APPDATA%\InformaTech\config\` |

Fichiers principaux : `InformaTech.toml` (identité/clé, dont l'**ID** en
`enc_id`), `InformaTech2.toml` (options). Le mot de passe permanent y est stocké
chiffré. *(Vérifié : un `--get-id` en portable crée bien `InformaTech.toml`.)*

Journaux : `...\InformaTech\log\<mode>\` (dossier `log` en minuscule, un
sous-dossier par mode, ex. `log\get-id\`). Même racine que la config.

---

## 5. Options en ligne de commande (inchangées vs RustDesk officiel)

Toutes conservées à l'identique :

| Option | Effet |
|---|---|
| `--silent-install` | installe en service, sans UI |
| `--password <mdp>` | définit le mot de passe permanent |
| `--get-id` | affiche l'identifiant du poste sur la sortie standard |
| `--option <clé> [valeur]` | lit/écrit une option de config |
| `--uninstall` | désinstalle |
| `--connect <id> --password <mdp>` | se connecte à un poste (côté viewer) |
| `--file-transfer` | session de transfert de fichiers |

Séquence type côté hub (poste client) :
```
informatech-assistance-1.5.0-x86_64.exe --silent-install
"C:\Program Files\InformaTech\InformaTech.exe" --password <mdp-genere>
"C:\Program Files\InformaTech\InformaTech.exe" --get-id      # -> ID a enregistrer
```

---

## 6. Comportement de marque et différences constatées

- **Tray masquée** : `hide-tray=Y` → pas d'icône de zone de notification.
- **Fenêtre de connexion masquée** : `allow-hide-cm=Y` + `approve-mode=password`
  + `verification-method=use-permanent-password` → `password_security::hide_cm()`
  vrai → la fenêtre `--cm` démarre masquée. Le poste contrôlé n'affiche donc
  **rien** nativement ; le hub InformaTech porte la bannière « connecté » + Couper.
- **Mode d'approbation = mot de passe permanent uniquement** (conséquence des
  réglages ci-dessus) : une connexion entrante est acceptée automatiquement si
  le bon mot de passe permanent est fourni, sans clic sur le poste contrôlé.
  C'est voulu (prise en main non assistée autorisée par le hub).
- **Métadonnées de l'exe** (Propriétés → Détails) : ProductName
  « InformaTech Assistance », FileDescription « InformaTech Assistance »,
  CompanyName « InformaTech ».
- **Serveurs** : rendezvous/relay publics RustDesk **inchangés**.

### Décisions structurantes (choix du plus simple, cf. CLAUDE.md)

- **`APP_NAME` = `InformaTech`** (sans espace ni suffixe), pas
  « InformaTech Assistance ». Raison : l'installeur Windows valide le nom en
  `[A-Za-z0-9-]+` (garde-fou anti-injection `validate_install_app_name`) et
  l'utilise tel quel pour le nom de service, le dossier d'install et le nom de
  l'exe. Un espace casserait `--silent-install`. Conséquence : le **titre de
  fenêtre** (côté viewer, intégré au hub) affiche « InformaTech », pas
  « InformaTech Assistance ». Le libellé long reste présent dans les métadonnées
  de l'exe. Le poste contrôlé étant invisible, ce titre ne s'y voit jamais.
  → Si le titre long est souhaité côté viewer, c'est un ajout séparable
  (nom d'affichage distinct de `APP_NAME`), non fait ici.
- **Icône** : icône dédiée « InformaTech Assistance » de Jax (D-128, validée le
  15/10 ; source dans ArkaClaudeBrandDesigner `informatech/brand/04-assets/assistance/`).
  Remplacée dans `res/icon.ico`, `res/tray-icon.ico`,
  `flutter/windows/runner/resources/app_icon.ico` (.ico 7 tailles), `res/icon.png`
  (1024 px) et `flutter/assets/icon.svg`. **Effective à partir du build
  `v1.5.0-informatech.1`** ; le build `.0` porte encore le monogramme.
- **MSI conservé** (produit facilement par les étapes amont). Si inutile, il
  peut être retiré du workflow.

---

## 7. Vérifications effectuées

- ✅ Build `v1.5.0-informatech.0` réussi, release publiée (exe + msi).
- ✅ SHA-256 de l'exe téléchargé = SHA-256 du build (asset intègre).
- ✅ `--get-id` en portable répond un ID (`8235564` lors du test), crée bien la
   config isolée sous `%APPDATA%\InformaTech\` (namespace séparé → coexiste sans
   conflit avec un RustDesk officiel déjà installé, cas observé sur le PC de test).
- Non testé (hors périmètre, demande `--silent-install` interdit sur le PC
   d'Adrien) : installation réelle en service, masquage effectif tray/fenêtre en
   conditions, titre de fenêtre côté viewer. À valider lors de l'intégration hub.
