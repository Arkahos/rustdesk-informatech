// InformaTech: OPMD viewer home screen, direction B « Clients » (Jax, D-136). Replaces the stock home and tab bar:
// custom title bar, one search/ID field, the list of machines (engine's recent list in 0.1.0), server status footer.
// No upstream branding anywhere.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/models/peer_model.dart';
import 'package:flutter_hbb/models/platform_model.dart';
import 'package:window_manager/window_manager.dart';

const _nuit = Color(0xFF05060F);
const _nuit2 = Color(0xFF0A1433);
const _surface = Color(0xFF0E1A3D);
const _menthe = Color(0xFF6FF3D6);
const _texte2 = Color(0xFFB9C3E6);
const _texte3 = Color(0xFF8C98C2);
const _ambre = Color(0xFFF2B84B);
const _trait = Color(0x1FFFFFFF);
const _police = 'Poppins';
const _mono = TextStyle(fontFamily: 'Cascadia Mono', fontFamilyFallback: ['Consolas', 'monospace']);

/// Engine version shown in the footer (0.x only, team rule).
const kOpmdVersion = '0.1.0';

/// « 203 133 650 »: digits grouped by 3.
String opmdIdGroupe(String id) {
  final d = id.replaceAll(' ', '');
  if (!RegExp(r'^\d+$').hasMatch(d)) return id;
  final b = StringBuffer();
  for (var i = 0; i < d.length; i++) {
    if (i > 0 && (d.length - i) % 3 == 0) b.write(' ');
    b.write(d[i]);
  }
  return b.toString();
}

/// Digits only, 6 to 12 of them: the field holds an ID to connect to, not a search.
String? opmdIdSaisi(String texte) {
  final d = texte.replaceAll(RegExp(r'[\s-]'), '');
  return RegExp(r'^\d{6,12}$').hasMatch(d) ? d : null;
}

/// While the field holds only digits, shows them as « 203 133 650 » (groups of 3 from the left, as typed).
class _GroupeurId extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final brut = newValue.text.replaceAll(' ', '');
    if (brut.isEmpty || !RegExp(r'^\d+$').hasMatch(brut)) return newValue;
    final b = StringBuffer();
    for (var i = 0; i < brut.length; i++) {
      if (i > 0 && i % 3 == 0) b.write(' ');
      b.write(brut[i]);
    }
    final texte = b.toString();
    final curseur = newValue.selection.end.clamp(0, newValue.text.length);
    final avant = newValue.text.substring(0, curseur).replaceAll(' ', '').length;
    final pos = avant == 0 ? 0 : avant + (avant - 1) ~/ 3;
    return TextEditingValue(text: texte, selection: TextSelection.collapsed(offset: pos));
  }
}

class OpmdHomePage extends StatefulWidget {
  const OpmdHomePage({Key? key}) : super(key: key);

  @override
  State<OpmdHomePage> createState() => _OpmdHomePageState();
}

class _OpmdHomePageState extends State<OpmdHomePage> {
  final _champ = TextEditingController();
  final _focus = FocusNode();
  Timer? _minuterie;
  bool? _serveurOk;

  @override
  void initState() {
    super.initState();
    gFFI.recentPeersModel.addListener(_maj);
    bind.mainLoadRecentPeers();
    _champ.addListener(_maj);
    _lireStatut();
    _minuterie = Timer.periodic(const Duration(seconds: 3), (_) => _lireStatut());
  }

  @override
  void dispose() {
    gFFI.recentPeersModel.removeListener(_maj);
    _minuterie?.cancel();
    _champ.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _maj() {
    if (mounted) setState(() {});
  }

  Future<void> _lireStatut() async {
    try {
      final s = jsonDecode(await bind.mainGetConnectStatus()) as Map<String, dynamic>;
      final ok = (s['status_num'] as int?) == 1;
      if (mounted && ok != _serveurOk) setState(() => _serveurOk = ok);
    } catch (_) {}
  }

  void _connecter(String id) {
    if (id.isEmpty) return;
    connect(context, id);
  }

  void _valider() {
    final id = opmdIdSaisi(_champ.text);
    if (id != null) {
      _connecter(id);
      return;
    }
    final liste = _filtres();
    if (liste.length == 1) _connecter(liste.first.id);
  }

  List<Peer> _filtres() {
    final q = _champ.text.trim().toLowerCase();
    final peers = gFFI.recentPeersModel.peers;
    if (q.isEmpty || opmdIdSaisi(q) != null) return peers;
    // The field groups digits by 3, the stored ID has no spaces.
    final chiffres = q.replaceAll(' ', '');
    if (RegExp(r'^\d+$').hasMatch(chiffres)) return peers.where((p) => p.id.contains(chiffres)).toList();
    return peers
        .where((p) => '${p.alias} ${p.hostname} ${p.id}'.toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final page = Scaffold(
      backgroundColor: _nuit,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_nuit2, _nuit],
          ),
        ),
        child: Column(
          children: [
            const _BarreTitre(),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(28, 22, 28, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _entete(),
                    const SizedBox(height: 18),
                    Expanded(child: _liste()),
                  ],
                ),
              ),
            ),
            _pied(),
          ],
        ),
      ),
    );
    // Charter font (D-20) for this screen only; IDs keep their monospace style.
    final theme = Theme.of(context);
    return Theme(
      data: theme.copyWith(
        textTheme: theme.textTheme.apply(fontFamily: _police),
        primaryTextTheme: theme.primaryTextTheme.apply(fontFamily: _police),
      ),
      child: page,
    );
  }

  Widget _entete() {
    final estId = opmdIdSaisi(_champ.text) != null;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(
          height: 48,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Postes accessibles',
              style: TextStyle(fontFamily: _police, color: Colors.white, fontSize: 19, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        const SizedBox(width: 24),
        const Spacer(),
        SizedBox(
          width: 380,
          child: Semantics(
            label: 'Chercher un client, un poste ou un identifiant',
            child: TextField(
              controller: _champ,
              focusNode: _focus,
              autofocus: true,
              onSubmitted: (_) => _valider(),
              inputFormatters: [LengthLimitingTextInputFormatter(64), _GroupeurId()],
              style: RegExp(r'^[\d ]+$').hasMatch(_champ.text) ? _mono.copyWith(color: Colors.white, fontSize: 15) : const TextStyle(color: Colors.white, fontSize: 15),
              cursorColor: _menthe,
              decoration: InputDecoration(
                hintText: 'Client, poste ou identifiant',
                hintStyle: const TextStyle(color: _texte3),
                // A blank helper keeps the row height steady while the hint comes and goes.
                helperText: estId ? 'Entrée pour se connecter' : ' ',
                helperStyle: const TextStyle(color: _menthe, fontSize: 13),
                prefixIcon: const Icon(Icons.search, color: _texte3, size: 20),
                filled: true,
                fillColor: _surface,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _trait)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _trait)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _menthe, width: 2)),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        _Anneau(
          rayon: 10,
          child: SizedBox(
            height: 48,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: _menthe,
                foregroundColor: _nuit,
                disabledBackgroundColor: _menthe.withOpacity(0.35),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                textStyle: const TextStyle(fontFamily: _police, fontWeight: FontWeight.w600, fontSize: 14),
              ),
              onPressed: estId ? _valider : null,
              child: const Text('Se connecter'),
            ),
          ),
        ),
      ],
    );
  }

  Widget _liste() {
    final liste = _filtres();
    if (gFFI.recentPeersModel.peers.isEmpty) {
      return const Center(
        child: Text(
          'Aucun poste accessible pour l’instant. Crée un code dans InformaTech Hub › À distance.',
          style: TextStyle(color: _texte2, fontSize: 14),
          textAlign: TextAlign.center,
        ),
      );
    }
    if (liste.isEmpty) {
      return Center(child: Text('Aucun poste ne correspond à « ${_champ.text.trim()} ».', style: const TextStyle(color: _texte2)));
    }
    return Container(
      decoration: BoxDecoration(
        color: _surface.withOpacity(0.55),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _trait),
      ),
      child: Column(
        children: [
          const _LigneEntete(),
          Expanded(
            child: ListView.separated(
              itemCount: liste.length,
              separatorBuilder: (_, __) => const Divider(height: 1, color: _trait),
              itemBuilder: (_, i) => _LignePoste(peer: liste[i], onConnecter: () => _connecter(liste[i].id)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pied() {
    final ok = _serveurOk;
    return Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: _trait))),
      child: Row(
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: ok == false ? _ambre : _menthe)),
          const SizedBox(width: 8),
          Text(
            ok == null ? 'Connexion au serveur InformaTech…' : (ok ? 'Serveur InformaTech joignable' : 'Serveur injoignable'),
            style: const TextStyle(color: _texte2, fontSize: 13),
          ),
          const Spacer(),
          const Text('Moteur OPMD $kOpmdVersion', style: TextStyle(color: _texte3, fontSize: 13)),
        ],
      ),
    );
  }
}

/// 40 px title bar: D-128 icon, « InformaTech » + « Bureau à distance », window buttons. Drags the window.
class _BarreTitre extends StatelessWidget {
  const _BarreTitre();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: Row(
        children: [
          Expanded(
            child: DragToMoveArea(
              child: Padding(
                padding: const EdgeInsets.only(left: 14),
                child: Row(
                  children: [
                    loadIcon(20),
                    const SizedBox(width: 10),
                    const Text('InformaTech', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(width: 8),
                    const Text('Bureau à distance', style: TextStyle(color: _texte3, fontSize: 13)),
                  ],
                ),
              ),
            ),
          ),
          _BoutonFenetre(icone: Icons.remove, libelle: 'Réduire', onTap: () => windowManager.minimize()),
          _BoutonFenetre(
            icone: Icons.crop_square,
            libelle: 'Agrandir',
            onTap: () async => await windowManager.isMaximized() ? windowManager.unmaximize() : windowManager.maximize(),
          ),
          _BoutonFenetre(icone: Icons.close, libelle: 'Fermer', danger: true, onTap: () => windowManager.close()),
        ],
      ),
    );
  }
}

class _BoutonFenetre extends StatefulWidget {
  final IconData icone;
  final String libelle;
  final VoidCallback onTap;
  final bool danger;
  const _BoutonFenetre({required this.icone, required this.libelle, required this.onTap, this.danger = false});

  @override
  State<_BoutonFenetre> createState() => _BoutonFenetreState();
}

class _BoutonFenetreState extends State<_BoutonFenetre> {
  bool _survol = false;
  bool _focus = false;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.libelle,
      child: Tooltip(
        message: widget.libelle,
        waitDuration: const Duration(milliseconds: 600),
        excludeFromSemantics: true,
        child: FocusableActionDetector(
          mouseCursor: SystemMouseCursors.click,
          onShowHoverHighlight: (v) => setState(() => _survol = v),
          onShowFocusHighlight: (v) => setState(() => _focus = v),
          actions: {ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) => widget.onTap())},
          child: GestureDetector(
            onTap: widget.onTap,
            child: Container(
              width: 46,
              height: 40,
              decoration: BoxDecoration(
                color: _survol ? (widget.danger ? const Color(0xFFC62F3B) : _trait) : Colors.transparent,
                // Inset ring: the 40 px bar has no room for a 2 px offset outside the button.
                border: _focus ? Border.all(color: _menthe, width: 2) : null,
              ),
              child: Icon(widget.icone, size: 16, color: _survol || _focus ? Colors.white : _texte2),
            ),
          ),
        ),
      ),
    );
  }
}

/// 2 px mint ring, 2 px outside [child], while keyboard focus is inside it (D-136 review). Takes no layout space.
class _Anneau extends StatefulWidget {
  final Widget child;
  final double rayon;
  const _Anneau({required this.child, required this.rayon});

  @override
  State<_Anneau> createState() => _AnneauState();
}

class _AnneauState extends State<_Anneau> {
  bool _focus = false;

  @override
  void initState() {
    super.initState();
    FocusManager.instance.addHighlightModeListener(_mode);
  }

  @override
  void dispose() {
    FocusManager.instance.removeHighlightModeListener(_mode);
    super.dispose();
  }

  void _mode(FocusHighlightMode _) {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final visible = _focus && FocusManager.instance.highlightMode == FocusHighlightMode.traditional;
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onFocusChange: (v) => setState(() => _focus = v),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          widget.child,
          if (visible)
            Positioned(
              left: -4,
              top: -4,
              right: -4,
              bottom: -4,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(color: _menthe, width: 2),
                    borderRadius: BorderRadius.circular(widget.rayon + 4),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _LigneEntete extends StatelessWidget {
  const _LigneEntete();

  @override
  Widget build(BuildContext context) {
    const s = TextStyle(color: _texte3, fontSize: 13, fontWeight: FontWeight.w600);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: _trait))),
      child: const Row(
        children: [
          Expanded(flex: 5, child: Text('Client · poste', style: s)),
          SizedBox(width: 150, child: Text('Identifiant', style: s)),
          SizedBox(width: 150),
        ],
      ),
    );
  }
}

/// One machine: client name first (alias given by the Hub, else « Client non rattaché »), poste + ID in monospace,
/// one action. 0.1.0 has no access/live data in the engine: every row gets the mint outline « Se connecter ».
class _LignePoste extends StatelessWidget {
  final Peer peer;
  final VoidCallback onConnecter;
  const _LignePoste({required this.peer, required this.onConnecter});

  @override
  Widget build(BuildContext context) {
    final client = peer.alias.trim();
    return InkWell(
      canRequestFocus: false,
      onDoubleTap: onConnecter,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        child: Row(
          children: [
            Expanded(
              flex: 5,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    client.isEmpty ? 'Client non rattaché' : client,
                    overflow: TextOverflow.ellipsis,
                    style: client.isEmpty
                        ? const TextStyle(color: _texte2, fontStyle: FontStyle.italic, fontSize: 14)
                        : const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  const SizedBox(height: 3),
                  Text(peer.hostname.isEmpty ? 'Poste sans nom' : peer.hostname, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _texte2, fontSize: 13)),
                ],
              ),
            ),
            SizedBox(width: 150, child: Text(opmdIdGroupe(peer.id), style: _mono.copyWith(color: _texte2, fontSize: 13))),
            SizedBox(
              width: 150,
              child: Align(
                alignment: Alignment.centerRight,
                child: _Anneau(
                  rayon: 8,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _menthe,
                      side: const BorderSide(color: _menthe),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: onConnecter,
                    child: const Text('Se connecter'),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
