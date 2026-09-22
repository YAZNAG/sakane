import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:immobilier/core/dependencies/dependencies.dart';
import 'package:immobilier/features/baux/ui/components/baux_commun.dart';
import 'package:immobilier/models/client.dart';
import 'package:immobilier/repository/repository.dart';
import 'package:immobilier/routes.dart';

/// Message d'un locataire sur liste noire.
String messageListeNoireBail(Client client) {
  final motif = client.listeNoire?.motif;
  return "Ce client est sur la liste noire${(motif ?? '').isEmpty ? '' : ' : $motif'}. "
      "Impossible de lui louer un bien.";
}

/// Choix du locataire parmi les clients, ou creation d'un nouveau client
/// (meme ecran que pour une reservation). [titre] et [listeNoireBloquante]
/// servent aux autres usages (visiteur d'un bien en vente).
Future<Client?> choisirLocataire(BuildContext context,
    {String titre = 'Choisir le locataire', bool listeNoireBloquante = true}) {
  return showModalBottomSheet<Client>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ChoixLocataire(titre: titre, listeNoireBloquante: listeNoireBloquante),
  );
}

class _ChoixLocataire extends StatefulWidget {
  final String titre;
  final bool listeNoireBloquante;

  const _ChoixLocataire({required this.titre, required this.listeNoireBloquante});

  @override
  State<_ChoixLocataire> createState() => _ChoixLocataireState();
}

class _ChoixLocataireState extends State<_ChoixLocataire> {
  List<Client>? _clients;
  String? _erreur;
  String _texte = '';

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    setState(() => _erreur = null);
    try {
      final clients = await Dependencies.get<Repository>().getClients();
      if (mounted) setState(() => _clients = clients);
    } catch (ex) {
      if (mounted) setState(() => _erreur = messageErreurBail(ex));
    }
  }

  List<Client> get _filtres {
    final tous = _clients ?? const <Client>[];
    final q = _texte.trim().toLowerCase();
    if (q.isEmpty) return tous;
    final chiffres = q.replaceAll(RegExp(r'\D'), '');
    return tous.where((c) {
      if (c.fullName.toLowerCase().contains(q)) return true;
      if ('${c.firstName ?? ''} ${c.lastName ?? ''}'.toLowerCase().contains(q)) return true;
      if ((c.identityNumber ?? '').toLowerCase().contains(q)) return true;
      return chiffres.length >= 3 && (c.tel ?? '').replaceAll(RegExp(r'\D'), '').contains(chiffres);
    }).toList();
  }

  void _choisir(Client c) {
    if (c.listeNoire != null && widget.listeNoireBloquante) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(messageListeNoireBail(c)),
        backgroundColor: CouleursBail.retard,
      ));
      return;
    }
    Navigator.of(context).pop(c);
  }

  Future<void> _nouveau() async {
    final navigateur = Navigator.of(context);
    final res = await GoRouter.of(context).push(Routes.addClient);
    if (res is Client && mounted) navigateur.pop(res);
  }

  @override
  Widget build(BuildContext context) {
    final liste = _filtres;
    return DraggableScrollableSheet(
      initialChildSize: .85,
      minChildSize: .5,
      maxChildSize: .95,
      expand: false,
      builder: (context, controleur) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: CouleursBail.bordure, borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(widget.titre,
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: CouleursBail.texte)),
                  ),
                  ElevatedButton.icon(
                    onPressed: _nouveau,
                    icon: const Icon(Icons.person_add_alt_1, size: 18),
                    label: const Text('Nouveau'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: CouleursBail.teinte,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                onChanged: (v) => setState(() => _texte = v),
                decoration: InputDecoration(
                  hintText: 'Nom, téléphone ou CIN…',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  isDense: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: _clients == null
                  ? Center(
                      child: _erreur == null
                          ? const CircularProgressIndicator(color: CouleursBail.teinte)
                          : Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(_erreur!, textAlign: TextAlign.center, style: const TextStyle(color: CouleursBail.retard)),
                                TextButton(onPressed: _charger, child: const Text('Réessayer')),
                              ],
                            ),
                    )
                  : liste.isEmpty
                      ? const Center(
                          child: Text('Aucun client trouvé', style: TextStyle(color: CouleursBail.texteDoux)),
                        )
                      : ListView.separated(
                          controller: controleur,
                          padding: const EdgeInsets.fromLTRB(8, 4, 8, 24),
                          itemCount: liste.length,
                          separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey.shade200),
                          itemBuilder: (_, i) => _ligne(liste[i]),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _ligne(Client c) {
    final noire = c.listeNoire != null;
    final nom = '${c.firstName ?? ''} ${c.lastName ?? ''}'.trim();
    return ListTile(
      onTap: () => _choisir(c),
      leading: CircleAvatar(
        backgroundColor: (noire ? CouleursBail.retard : CouleursBail.teinte).withValues(alpha: .12),
        child: noire
            ? const Icon(Icons.block, color: CouleursBail.retard, size: 20)
            : Text(nom.isEmpty ? '?' : nom.characters.first.toUpperCase(),
                style: const TextStyle(color: CouleursBail.teinte, fontWeight: FontWeight.w800)),
      ),
      title: Text(nom.isEmpty ? 'Client' : nom,
          style: TextStyle(fontWeight: FontWeight.w700, color: noire ? Colors.black45 : CouleursBail.texte)),
      subtitle: Text(
        [
          if ((c.tel ?? '').isNotEmpty) c.tel!,
          if ((c.identityNumber ?? '').isNotEmpty) c.identityNumber!,
          if (noire) 'Liste noire${(c.listeNoire!.motif ?? '').isEmpty ? '' : ' : ${c.listeNoire!.motif}'}',
        ].join(' • '),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 12.5, color: noire ? CouleursBail.retard : CouleursBail.texteDoux),
      ),
    );
  }
}
