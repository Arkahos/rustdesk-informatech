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
    return peers
        .where((p) => '${p.alias} ${p.hostname} ${p.id}'.toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
  }

  Widget _entete() {
    final estId = opmdIdSaisi(_champ.text) != null;
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _champ,
            focusNode: _focus,
            autofocus: true,
            onSubmitted: (_) => _valider(),
            inputFormatters: [LengthLimitingTextInputFormatter(64)],
            style: estId ? _mono.copyWith(color: Colors.white, fontSize: 15) : const TextStyle(color: Colors.white, fontSize: 15),
            cursorColor: _menthe,
            decoration: InputDecoration(
              hintText: 'Client, poste ou identifiant',
              hintStyle: const TextStyle(color: _texte3),
              prefixIcon: const Icon(Icons.search, color: _texte3, size: 20),
              filled: true,
              fillColor: _surface,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _trait)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _trait)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _menthe)),
            ),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          height: 48,
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: _menthe,
              foregroundColor: _nuit,
              disabledBackgroundColor: _menthe.withOpacity(0.35),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            onPressed: estId ? _valider : null,
            child: const Text('Se connecter'),
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
            style: const TextStyle(color: _texte2, fontSize: 12),
          ),
          const Spacer(),
          const Text('Moteur OPMD $kOpmdVersion', style: TextStyle(color: _texte3, fontSize: 12)),
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
          _BoutonFenetre(icone: Icons.remove, onTap: () => windowManager.minimize()),
          _BoutonFenetre(
            icone: Icons.crop_square,
            onTap: () async => await windowManager.isMaximized() ? windowManager.unmaximize() : windowManager.maximize(),
          ),
          _BoutonFenetre(icone: Icons.close, danger: true, onTap: () => windowManager.close()),
        ],
      ),
    );
  }
}

class _BoutonFenetre extends StatefulWidget {
  final IconData icone;
  final VoidCallback onTap;
  final bool danger;
  const _BoutonFenetre({required this.icone, required this.onTap, this.danger = false});

  @override
  State<_BoutonFenetre> createState() => _BoutonFenetreState();
}

class _BoutonFenetreState extends State<_BoutonFenetre> {
  bool _survol = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _survol = true),
      onExit: (_) => setState(() => _survol = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          width: 46,
          height: 40,
          color: _survol ? (widget.danger ? const Color(0xFFC62F3B) : _trait) : Colors.transparent,
          child: Icon(widget.icone, size: 16, color: _survol ? Colors.white : _texte2),
        ),
      ),
    );
  }
}

class _LigneEntete extends StatelessWidget {
  const _LigneEntete();

  @override
  Widget build(BuildContext context) {
    const s = TextStyle(color: _texte3, fontSize: 12, fontWeight: FontWeight.w600);
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
                  Text(peer.hostname.isEmpty ? 'Poste sans nom' : peer.hostname, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _texte2, fontSize: 12.5)),
                ],
              ),
            ),
            SizedBox(width: 150, child: Text(opmdIdGroupe(peer.id), style: _mono.copyWith(color: _texte2, fontSize: 13))),
            SizedBox(
              width: 150,
              child: Align(
                alignment: Alignment.centerRight,
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
          ],
        ),
      ),
    );
  }
}
