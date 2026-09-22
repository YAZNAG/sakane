import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:immobilier/core/dependencies/dependencies.dart';
import 'package:immobilier/features/baux/ui/components/baux_commun.dart';
import 'package:immobilier/features/calendrier_bien/ui/components/outils_calendrier.dart';
import 'package:immobilier/features/ventes/ui/components/ventes_commun.dart';
import 'package:immobilier/models/owner.dart';
import 'package:immobilier/models/vente.dart';
import 'package:immobilier/repository/repository.dart';
import 'package:signature/signature.dart';

// Outils du mandat de vente (عقد وساطة عقارية) : choix d'un proprietaire,
// choix d'un mandat libre, signature du proprietaire.

/// « Signé le … » en vert, ou « Non signé » en orange.
class PastilleSignature extends StatelessWidget {
  final MandatVente mandat;

  const PastilleSignature({super.key, required this.mandat});

  @override
  Widget build(BuildContext context) {
    if (mandat.signe) {
      return PastilleBail(
        texte: mandat.signeLe == null ? 'Signé' : 'Signé le ${dateBail(mandat.signeLe)}',
        couleur: CouleursVente.aVendre,
        icone: Icons.draw_outlined,
      );
    }
    return const PastilleBail(texte: 'Non signé', couleur: CouleursVente.sansMandat, icone: Icons.edit_off_outlined);
  }
}

/// Resume d'un mandat : proprietaire, bien, prix, signature.
class ResumeMandat extends StatelessWidget {
  final MandatVente mandat;
  final VoidCallback? onTap;
  final Widget? fin;

  const ResumeMandat({super.key, required this.mandat, this.onTap, this.fin});

  @override
  Widget build(BuildContext context) {
    final m = mandat;
    final lieu = [
      if ((m.adresseBien ?? '').isNotEmpty) m.adresseBien!,
      if ((m.ville ?? '').isNotEmpty) m.ville!,
    ].join(' — ');
    return CarteBail(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: CouleursVente.fondTeinte, borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.assignment_outlined, color: CouleursVente.teinte),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(m.proprietaireNom.isEmpty ? 'Propriétaire' : m.proprietaireNom,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5, color: CouleursBail.texte)),
                if (lieu.isNotEmpty)
                  Text(lieu,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12.5, color: CouleursBail.texteDoux)),
                if ((m.titreFoncier ?? '').isNotEmpty)
                  Text('Titre foncier : ${m.titreFoncier}',
                      style: const TextStyle(fontSize: 12.5, color: CouleursBail.texteDoux)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    PastilleSignature(mandat: m),
                    if ((m.typeBien ?? '').isNotEmpty) PastilleBail(texte: m.typeBien!, couleur: CouleursBail.texteDoux),
                    if (m.prixDemande != null) PastilleBail(texte: prixVente(m.prixDemande), couleur: CouleursVente.teinte),
                  ],
                ),
              ],
            ),
          ),
          if (fin != null) fin!,
        ],
      ),
    );
  }
}

// ── Choix d'un proprietaire ────────────────────────────────────────

/// Liste des proprietaires avec recherche. Rend null si l'agent prefere
/// saisir un nouveau proprietaire.
Future<Owner?> choisirProprietaire(BuildContext context) {
  return showModalBottomSheet<Owner>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => const _ChoixProprietaire(),
  );
}

class _ChoixProprietaire extends StatefulWidget {
  const _ChoixProprietaire();

  @override
  State<_ChoixProprietaire> createState() => _ChoixProprietaireState();
}

class _ChoixProprietaireState extends State<_ChoixProprietaire> {
  List<Owner>? _tous;
  String? _erreur;
  String _recherche = '';

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    setState(() => _erreur = null);
    try {
      final liste = await Dependencies.get<Repository>().fetchOwners();
      liste.sort((a, b) => (a.name ?? '').toLowerCase().compareTo((b.name ?? '').toLowerCase()));
      if (mounted) setState(() => _tous = liste);
    } catch (ex) {
      if (mounted) setState(() => _erreur = messageErreurBail(ex));
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = _recherche.trim().toLowerCase();
    final liste = (_tous ?? const <Owner>[])
        .where((o) => q.isEmpty || '${o.name ?? ''} ${o.tel ?? ''}'.toLowerCase().contains(q))
        .toList();
    return _FeuilleListe(
      titre: 'Choisir le propriétaire',
      indication: 'Nom ou téléphone…',
      onRecherche: (t) => setState(() => _recherche = t),
      entete: ListTile(
        leading: const CircleAvatar(
          backgroundColor: CouleursVente.fondTeinte,
          child: Icon(Icons.person_add_alt_1_outlined, color: CouleursVente.teinte),
        ),
        title: const Text('Nouveau propriétaire', style: TextStyle(fontWeight: FontWeight.w700)),
        subtitle: const Text('Saisir son nom, sa CIN… (sa fiche sera créée)'),
        onTap: () => Navigator.of(context).pop(),
      ),
      chargement: _tous == null && _erreur == null,
      erreur: _erreur,
      onReessayer: _charger,
      vide: q.isEmpty ? 'Aucun propriétaire enregistré.' : 'Aucun propriétaire ne correspond.',
      enfants: [
        for (final o in liste)
          ListTile(
            leading: CircleAvatar(
              backgroundColor: CouleursBail.fond,
              child: Text((o.name ?? '?').trim().isEmpty ? '?' : o.name!.trim().characters.first.toUpperCase(),
                  style: const TextStyle(color: CouleursBail.texte, fontWeight: FontWeight.w800)),
            ),
            title: Text(o.name ?? 'Propriétaire'),
            subtitle: (o.tel ?? '').isEmpty ? null : Text(o.tel!),
            onTap: () => Navigator.of(context).pop(o),
          ),
      ],
    );
  }
}

// ── Choix d'un mandat libre ────────────────────────────────────────

/// Les mandats qui ne sont encore lies a aucun bien, avec recherche.
Future<MandatVente?> choisirMandatLibre(BuildContext context) {
  return showModalBottomSheet<MandatVente>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => const _ChoixMandat(),
  );
}

class _ChoixMandat extends StatefulWidget {
  const _ChoixMandat();

  @override
  State<_ChoixMandat> createState() => _ChoixMandatState();
}

class _ChoixMandatState extends State<_ChoixMandat> {
  List<MandatVente>? _mandats;
  String? _erreur;
  String _recherche = '';
  Timer? _attente;
  int _requete = 0;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  @override
  void dispose() {
    _attente?.cancel();
    super.dispose();
  }

  Future<void> _charger() async {
    final numero = ++_requete;
    setState(() => _erreur = null);
    try {
      final liste = await Dependencies.get<Repository>().fetchMandatsVente(libres: true, recherche: _recherche);
      if (mounted && numero == _requete) setState(() => _mandats = liste);
    } catch (ex) {
      if (mounted && numero == _requete) setState(() => _erreur = messageErreurBail(ex));
    }
  }

  void _surRecherche(String texte) {
    _recherche = texte;
    _attente?.cancel();
    _attente = Timer(const Duration(milliseconds: 400), () {
      if (mounted) _charger();
    });
  }

  @override
  Widget build(BuildContext context) {
    final liste = _mandats ?? const <MandatVente>[];
    return _FeuilleListe(
      titre: 'Mandats sans bien',
      indication: 'Propriétaire, adresse, titre foncier…',
      onRecherche: _surRecherche,
      chargement: _mandats == null && _erreur == null,
      erreur: _erreur,
      onReessayer: _charger,
      vide: _recherche.trim().isEmpty
          ? "Aucun mandat libre.\nCréez un « Nouveau mandat »."
          : 'Aucun mandat ne correspond.',
      enfants: [
        for (final m in liste)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
            child: ResumeMandat(
              mandat: m,
              onTap: () => Navigator.of(context).pop(m),
              fin: const Icon(Icons.chevron_right, color: CouleursBail.texteDoux),
            ),
          ),
      ],
    );
  }
}

/// Feuille de choix commune : titre, recherche, liste.
class _FeuilleListe extends StatelessWidget {
  final String titre;
  final String indication;
  final ValueChanged<String> onRecherche;
  final Widget? entete;
  final bool chargement;
  final String? erreur;
  final VoidCallback onReessayer;
  final String vide;
  final List<Widget> enfants;

  const _FeuilleListe({
    required this.titre,
    required this.indication,
    required this.onRecherche,
    required this.chargement,
    required this.erreur,
    required this.onReessayer,
    required this.vide,
    required this.enfants,
    this.entete,
  });

  @override
  Widget build(BuildContext context) {
    final hauteur = MediaQuery.sizeOf(context).height * .85;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: hauteur,
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 8, 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(titre,
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: CouleursBail.texte)),
                    ),
                    IconButton(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.close)),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
                child: TextField(
                  onChanged: onRecherche,
                  decoration: InputDecoration(
                    hintText: indication,
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
              ),
              if (entete != null) ...[entete!, const Divider(height: 1)],
              Expanded(child: _contenu()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _contenu() {
    if (chargement) return const Center(child: CircularProgressIndicator(color: CouleursVente.teinte));
    if (erreur != null && enfants.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(erreur!, textAlign: TextAlign.center, style: const TextStyle(color: CouleursBail.retard)),
              const SizedBox(height: 10),
              OutlinedButton(onPressed: onReessayer, child: const Text('Réessayer')),
            ],
          ),
        ),
      );
    }
    if (enfants.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Text(vide, textAlign: TextAlign.center, style: const TextStyle(color: CouleursBail.texteDoux)),
        ),
      );
    }
    return ListView(padding: const EdgeInsets.only(top: 8, bottom: 20), children: enfants);
  }
}

// ── Signature du proprietaire ──────────────────────────────────────

/// Fait signer le proprietaire sur un pave plein ecran, envoie la
/// signature puis rouvre le contrat signe. Rend le mandat a jour, ou null.
Future<MandatVente?> faireSignerMandat(BuildContext context, MandatVente mandat) async {
  final png = await Navigator.of(context).push<Uint8List>(MaterialPageRoute(
    fullscreenDialog: true,
    builder: (_) => PaveSignaturePage(
      titre: 'Signature du propriétaire',
      nom: mandat.proprietaireNom,
      mention: 'Je confirme confier la vente de mon bien à l’agence (عقد وساطة عقارية).',
    ),
  ));
  if (png == null || !context.mounted) return null;

  final navigateur = Navigator.of(context, rootNavigator: true);
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Center(child: CircularProgressIndicator(color: Colors.white)),
  );
  MandatVente? signe;
  String? erreur;
  try {
    signe = await Dependencies.get<Repository>().signerMandatVente(mandat.id, png);
  } catch (ex) {
    erreur = messageErreurBail(ex);
  }
  navigateur.pop();
  if (!context.mounted) return signe;
  if (signe == null) {
    afficherMessage(context, erreur ?? "La signature n'a pas pu être enregistrée.", erreur: true);
    return null;
  }
  afficherMessage(context, 'Mandat signé.');
  await voirContratMandat(context, signe, titre: 'Mandat signé');
  return signe;
}

/// Le PDF du mandat dans la visionneuse de l'application.
Future<void> voirContratMandat(BuildContext context, MandatVente m, {String titre = 'Mandat de vente'}) =>
    ouvrirPdfBail(context, () => Dependencies.get<Repository>().telechargerMandatVente(m.id), titre);

/// Pave de signature plein ecran ; rend l'image PNG.
class PaveSignaturePage extends StatefulWidget {
  final String titre;
  final String nom;
  final String? mention;

  /// Libelle d'un bouton qui ferme le pave sans signature (ex. « Signer plus tard »).
  final String? plusTard;

  /// Message quand on valide un pave vide.
  final String messageVide;

  const PaveSignaturePage({
    super.key,
    required this.titre,
    this.nom = '',
    this.mention,
    this.plusTard,
    this.messageVide = "Le propriétaire n'a pas encore signé.",
  });

  @override
  State<PaveSignaturePage> createState() => _PaveSignaturePageState();
}

class _PaveSignaturePageState extends State<PaveSignaturePage> {
  final SignatureController _controleur = SignatureController(
    penStrokeWidth: 4,
    penColor: Colors.black,
    exportBackgroundColor: Colors.white,
  );
  bool _enCours = false;

  @override
  void initState() {
    super.initState();
    _controleur.addListener(_actualiser);
  }

  void _actualiser() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controleur.removeListener(_actualiser);
    _controleur.dispose();
    super.dispose();
  }

  Future<void> _valider() async {
    if (_controleur.isEmpty) {
      afficherMessage(context, widget.messageVide, erreur: true);
      return;
    }
    setState(() => _enCours = true);
    final octets = await _controleur.toPngBytes();
    if (!mounted) return;
    setState(() => _enCours = false);
    if (octets != null) Navigator.of(context).pop(octets);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CouleursBail.fond,
      appBar: AppBar(
        title: Text(widget.titre, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        centerTitle: true,
        elevation: 0,
        foregroundColor: Colors.white,
        backgroundColor: CouleursVente.teinte,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.nom.isNotEmpty)
                Text(widget.nom,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: CouleursBail.texte)),
              if (widget.mention != null) ...[
                const SizedBox(height: 4),
                Text(widget.mention!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12.5, color: CouleursBail.texteDoux)),
              ],
              const SizedBox(height: 12),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, contraintes) => Container(
                    clipBehavior: Clip.hardEdge,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: CouleursVente.teinte, width: 1.6),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Stack(
                      children: [
                        Signature(
                          controller: _controleur,
                          width: contraintes.maxWidth,
                          height: contraintes.maxHeight,
                          backgroundColor: Colors.white,
                        ),
                        if (_controleur.isEmpty)
                          const IgnorePointer(
                            child: Center(
                              child: Text('Signez ici avec le doigt',
                                  style: TextStyle(fontSize: 16, color: CouleursBail.aVenir)),
                            ),
                          ),
                        const Positioned(
                          left: 24,
                          right: 24,
                          bottom: 40,
                          child: IgnorePointer(child: Divider(color: CouleursBail.bordure, thickness: 1.4)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 52,
                      child: OutlinedButton.icon(
                        onPressed: _enCours ? null : _controleur.clear,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Effacer'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: CouleursBail.texte,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: SizedBox(
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: _enCours ? null : _valider,
                        icon: const Icon(Icons.check),
                        label: const Text('Valider la signature',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: CouleursVente.teinte,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (widget.plusTard != null) ...[
                const SizedBox(height: 6),
                TextButton(
                  onPressed: _enCours ? null : () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(foregroundColor: CouleursBail.texteDoux),
                  child: Text(widget.plusTard!, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
