import 'package:flutter/material.dart';
import 'package:immobilier/core/constants/app_colors.dart';
import 'package:immobilier/features/home/ui/components/accueil_commun.dart';
import 'package:immobilier/models/realestate.dart';

/// Criteres de filtrage de la liste des biens.
class CriteresBiens {
  String recherche;

  /// tous | disponible | reserve | nettoyage — et, pour les anciens
  /// appels, a_nettoyer et en_cours, que « nettoyage » réunit.
  String etat;
  String type; // 'tous' ou le code renvoye par l'API (type_transaction.code)
  int? secteurId;
  bool sansSecteur;
  int? proprietaireId;
  double? prixMin;
  double? prixMax;
  int? chambres; // 1, 2, 3, 4 (4 = 4 et plus)

  CriteresBiens({
    this.recherche = '',
    this.etat = 'tous',
    this.type = 'tous',
    this.secteurId,
    this.sansSecteur = false,
    this.proprietaireId,
    this.prixMin,
    this.prixMax,
    this.chambres,
  });

  /// Vrai si au moins un filtre du panneau repliable est actif.
  bool get filtresAvancesActifs =>
      type != 'tous' ||
      secteurId != null ||
      sansSecteur ||
      proprietaireId != null ||
      prixMin != null ||
      prixMax != null ||
      chambres != null;

  int get nombreFiltresActifs {
    var n = 0;
    if (type != 'tous') n++;
    if (secteurId != null || sansSecteur) n++;
    if (proprietaireId != null) n++;
    if (prixMin != null || prixMax != null) n++;
    if (chambres != null) n++;
    return n;
  }

  void reinitialiser() {
    type = 'tous';
    secteurId = null;
    sansSecteur = false;
    proprietaireId = null;
    prixMin = null;
    prixMax = null;
    chambres = null;
  }

  /// Reserve / disponible / nettoyage ne valent que pour la courte duree.
  bool get etatsApplicables => type != 'rent-long' && type != 'selle';

  /// Les mêmes critères, avec un état différent : c'est ainsi que les
  /// puces se comptent sans dupliquer la règle de filtrage.
  CriteresBiens copie({String? etat}) => CriteresBiens(
        recherche: recherche,
        etat: etat ?? this.etat,
        type: type,
        secteurId: secteurId,
        sansSecteur: sansSecteur,
        proprietaireId: proprietaireId,
        prixMin: prixMin,
        prixMax: prixMax,
        chambres: chambres,
      );

  /// Nombre de biens que donnerait un état, les autres critères inchangés.
  int compterEtat(List<Realestate> biens, String etat) =>
      copie(etat: etat).appliquer(biens).length;

  /// Applique tous les criteres a une liste de biens.
  List<Realestate> appliquer(List<Realestate> biens) {
    return biens.where((b) {
      // recherche sur le nom, l'adresse, le secteur ou la reference
      if (recherche.isNotEmpty) {
        final q = recherche.toLowerCase();
        final titre = (b.title ?? '').toLowerCase();
        final adresse = (b.address?.address ?? '').toLowerCase();
        final secteur = (b.secteur?.name ?? '').toLowerCase();
        final reference = b.referenceLisible.toLowerCase();
        if (!titre.contains(q) &&
            !adresse.contains(q) &&
            !secteur.contains(q) &&
            !reference.contains(q)) {
          return false;
        }
      }

      // etat operationnel
      switch (etatsApplicables ? etat : 'tous') {
        case 'disponible':
          // cleaningStatus absent = ancienne API : on considere le bien propre.
          if (b.booking != null) return false;
          if (b.cleaningStatus != null && b.cleaningStatus != 'cleaned') return false;
          break;
        case 'reserve':
          if (b.booking == null) return false;
          break;
        case 'nettoyage':
          // À nettoyer ou nettoyage en cours : un seul geste à faire.
          if (b.booking != null || !(b.aNettoyer || b.enNettoyage)) return false;
          break;
        case 'a_nettoyer':
          if (b.booking != null || b.cleaningStatus != 'to_clean') return false;
          break;
        case 'en_cours':
          if (b.booking != null || b.cleaningStatus != 'cleaning') return false;
          break;
      }

      // type de transaction
      if (type != 'tous' && b.typeTransaction?.value != type) return false;

      // secteur
      if (sansSecteur && b.secteur?.id != null) return false;
      if (secteurId != null && b.secteur?.id != secteurId) return false;

      // proprietaire
      if (proprietaireId != null && b.owner?.id != proprietaireId) return false;

      // prix par nuit
      final prix = (b.price ?? 0).toDouble();
      if (prixMin != null && prix < prixMin!) return false;
      if (prixMax != null && prix > prixMax!) return false;

      // nombre de chambres (4 signifie 4 et plus)
      if (chambres != null) {
        final ch = b.nbRooms ?? 0;
        if (chambres == 4 ? ch < 4 : ch != chambres) return false;
      }

      return true;
    }).toList();
  }
}

/// Recherche, puces d'état et ligne de filtres, au-dessus de la liste.
///
/// Les puces disent le nombre qu'elles donneront : on voit avant de
/// toucher s'il reste quelque chose à voir. La ligne de filtres résume
/// en clair ce qui est appliqué — « Agadir · 2 chambres » — pour qu'un
/// filtre oublié ne passe pas pour une liste vide.
class FiltresBiens extends StatefulWidget {
  final CriteresBiens criteres;
  final List<Realestate> tousLesBiens;
  final int nombreAffiche;
  final VoidCallback onChange;

  /// Le clavier s'ouvre sur la recherche des l'affichage : l'ecran a ete
  /// atteint par la loupe, l'utilisateur vient pour chercher.
  final bool rechercheOuverte;

  const FiltresBiens({
    super.key,
    required this.criteres,
    required this.tousLesBiens,
    required this.nombreAffiche,
    required this.onChange,
    this.rechercheOuverte = false,
  });

  @override
  State<FiltresBiens> createState() => _FiltresBiensState();
}

class _FiltresBiensState extends State<FiltresBiens> {
  final _rechercheController = TextEditingController();
  bool _panneauOuvert = false;

  @override
  void initState() {
    super.initState();
    _rechercheController.text = widget.criteres.recherche;
  }

  @override
  void dispose() {
    _rechercheController.dispose();
    super.dispose();
  }

  void _maj(VoidCallback modification) {
    setState(modification);
    widget.onChange();
  }

  /// Types de transaction distincts presents dans la liste.
  List<MapEntry<String, String>> get _types {
    final m = <String, String>{};
    for (final b in widget.tousLesBiens) {
      final t = b.typeTransaction;
      if (t?.value != null) m[t!.value!] = t.name ?? t.value!;
    }
    final l = m.entries.toList()..sort((a, b) => a.value.compareTo(b.value));
    return l;
  }

  /// Secteurs distincts presents dans la liste.
  List<MapEntry<int, String>> get _secteurs {
    final m = <int, String>{};
    for (final b in widget.tousLesBiens) {
      final sec = b.secteur;
      if (sec?.id != null) m[sec!.id!] = sec.name ?? 'Sans nom';
    }
    final l = m.entries.toList()..sort((a, b) => a.value.compareTo(b.value));
    return l;
  }

  /// Proprietaires distincts presents dans la liste.
  List<MapEntry<int, String>> get _proprietaires {
    final m = <int, String>{};
    for (final b in widget.tousLesBiens) {
      final o = b.owner;
      if (o?.id != null) m[o!.id!] = o.name ?? 'Sans nom';
    }
    final l = m.entries.toList()..sort((a, b) => a.value.compareTo(b.value));
    return l;
  }

  /// « Agadir · 2 chambres » : ce qui est filtré, dit en clair.
  String get _resume {
    final c = widget.criteres;
    final morceaux = <String>[];

    if (c.type != 'tous') {
      final t = _types.where((e) => e.key == c.type).map((e) => e.value);
      morceaux.add(t.isEmpty ? c.type : t.first);
    }
    if (c.sansSecteur) {
      morceaux.add('Sans secteur');
    } else if (c.secteurId != null) {
      final s = _secteurs.where((e) => e.key == c.secteurId).map((e) => e.value);
      if (s.isNotEmpty) morceaux.add(s.first);
    }
    if (c.proprietaireId != null) {
      final p =
          _proprietaires.where((e) => e.key == c.proprietaireId).map((e) => e.value);
      if (p.isNotEmpty) morceaux.add(p.first);
    }
    if (c.prixMin != null || c.prixMax != null) {
      final min = c.prixMin?.round();
      final max = c.prixMax?.round();
      if (min != null && max != null) {
        morceaux.add('$min – $max MAD');
      } else if (min != null) {
        morceaux.add('dès $min MAD');
      } else {
        morceaux.add("jusqu'à $max MAD");
      }
    }
    if (c.chambres != null) {
      morceaux.add(c.chambres == 4 ? '4 chambres et +' : '${c.chambres} chambres');
    }

    return morceaux.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.criteres;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 10),
        _champRecherche(c),
        const SizedBox(height: 10),
        if (c.etatsApplicables) _puces(c),
        const SizedBox(height: 8),
        _ligneFiltres(c),
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 200),
          crossFadeState: _panneauOuvert
              ? CrossFadeState.showFirst
              : CrossFadeState.showSecond,
          firstChild: _panneau(c),
          secondChild: const SizedBox(width: double.infinity),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  // ── La recherche ─────────────────────────────────────────────────

  Widget _champRecherche(CriteresBiens c) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: bordureAccueil),
        boxShadow: ombreAccueil,
      ),
      child: TextField(
        controller: _rechercheController,
        autofocus: widget.rechercheOuverte,
        textInputAction: TextInputAction.search,
        onChanged: (v) => _maj(() => c.recherche = v.trim()),
        style: const TextStyle(fontSize: 14, color: texteAccueil),
        decoration: InputDecoration(
          hintText: 'Nom, adresse, secteur…',
          hintStyle: const TextStyle(fontSize: 14, color: texteDouxAccueil),
          prefixIcon: const Icon(Icons.search_rounded, size: 21, color: texteDouxAccueil),
          suffixIcon: c.recherche.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.close_rounded, size: 19, color: texteDouxAccueil),
                  tooltip: 'Effacer la recherche',
                  onPressed: () {
                    _rechercheController.clear();
                    _maj(() => c.recherche = '');
                  },
                ),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
        ),
      ),
    );
  }

  // ── Les puces d'état ─────────────────────────────────────────────

  Widget _puces(CriteresBiens c) {
    final biens = widget.tousLesBiens;
    return SizedBox(
      height: 34,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _puce(c, 'tous', 'Tous', c.compterEtat(biens, 'tous')),
          _puce(c, 'disponible', 'Disponibles', c.compterEtat(biens, 'disponible')),
          _puce(c, 'reserve', 'Réservés', c.compterEtat(biens, 'reserve')),
          _puce(c, 'nettoyage', 'Nettoyage', c.compterEtat(biens, 'nettoyage')),
        ],
      ),
    );
  }

  Widget _puce(CriteresBiens c, String valeur, String libelle, int nombre) {
    // Les anciens codes de nettoyage tombent sous la même puce.
    final actif = c.etat == valeur ||
        (valeur == 'nettoyage' && (c.etat == 'a_nettoyer' || c.etat == 'en_cours'));
    return Padding(
      padding: const EdgeInsets.only(right: 7),
      child: Material(
        color: actif ? texteAccueil : Colors.white,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: () => _maj(() => c.etat = valeur),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: actif ? texteAccueil : bordureAccueil),
            ),
            alignment: Alignment.center,
            child: Text(
              '$libelle · $nombre',
              maxLines: 1,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: actif ? FontWeight.w700 : FontWeight.w500,
                color: actif ? Colors.white : texteAccueil,
                fontFeatures: chiffresTabulaires,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── La ligne de filtres ──────────────────────────────────────────

  Widget _ligneFiltres(CriteresBiens c) {
    final actifs = c.nombreFiltresActifs;
    final teinte = actifs > 0 ? AppColors.primaryColor : texteDouxAccueil;
    final resume = _resume;

    return Row(
      children: [
        Material(
          color: actifs > 0
              ? AppColors.primaryColor.withValues(alpha: .1)
              : Colors.white,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            onTap: () => setState(() => _panneauOuvert = !_panneauOuvert),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: actifs > 0
                      ? AppColors.primaryColor.withValues(alpha: .35)
                      : bordureAccueil,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(_panneauOuvert ? Icons.expand_less_rounded : Icons.tune_rounded,
                      size: 16, color: teinte),
                  const SizedBox(width: 5),
                  Text(
                    actifs > 0 ? 'Filtres · $actifs' : 'Filtres',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: teinte,
                      fontFeatures: chiffresTabulaires,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            resume.isEmpty
                ? '${widget.nombreAffiche} affiché${widget.nombreAffiche > 1 ? 's' : ''}'
                : resume,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, color: texteDouxAccueil),
          ),
        ),
        if (actifs > 0 || c.recherche.isNotEmpty || c.etat != 'tous')
          TextButton(
            onPressed: () {
              _rechercheController.clear();
              _maj(() {
                widget.criteres.reinitialiser();
                widget.criteres.recherche = '';
                widget.criteres.etat = 'tous';
              });
            },
            style: TextButton.styleFrom(
              foregroundColor: texteDouxAccueil,
              padding: const EdgeInsets.symmetric(horizontal: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('Effacer', style: TextStyle(fontSize: 12.5)),
          ),
      ],
    );
  }

  // ── Le panneau des filtres avancés ───────────────────────────────

  Widget _panneau(CriteresBiens c) {
    final prixMax = widget.tousLesBiens
        .map((b) => (b.price ?? 0).toDouble())
        .fold<double>(0, (a, b) => a > b ? a : b);
    final borneHaute = prixMax > 0 ? (prixMax / 50).ceil() * 50.0 : 1000.0;

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: bordureAccueil),
        borderRadius: BorderRadius.circular(rayonAccueil),
        boxShadow: ombreAccueil,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_types.length > 1) ...[
            _titre("Type"),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                _choix('tous', 'Tous', c.type, (v) => _maj(() => c.type = v)),
                ..._types.map((t) =>
                    _choix(t.key, t.value, c.type, (v) => _maj(() => c.type = v))),
              ],
            ),
            const SizedBox(height: 14),
          ],

          if (_secteurs.isNotEmpty) ...[
            _titre("Secteur"),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                _choixInt(null, 'Tous', c.secteurId,
                    (v) => _maj(() => c.secteurId = v)),
                ..._secteurs.map((e) => _choixInt(
                    e.key, e.value, c.secteurId,
                    (v) => _maj(() => c.secteurId = v))),
              ],
            ),
            const SizedBox(height: 14),
          ],

          if (_proprietaires.isNotEmpty) ...[
            _titre("Propriétaire"),
            DropdownButtonFormField<int?>(
              initialValue: c.proprietaireId,
              isExpanded: true,
              decoration: InputDecoration(
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              hint: const Text("Tous les propriétaires",
                  style: TextStyle(fontSize: 13)),
              items: [
                const DropdownMenuItem<int?>(
                  value: null,
                  child: Text("Tous les propriétaires",
                      style: TextStyle(fontSize: 13)),
                ),
                ..._proprietaires.map((e) => DropdownMenuItem<int?>(
                      value: e.key,
                      child: Text(e.value, style: const TextStyle(fontSize: 13)),
                    )),
              ],
              onChanged: (v) => _maj(() => c.proprietaireId = v),
            ),
            const SizedBox(height: 14),
          ],

          _titre("Prix par nuit (MAD)"),
          RangeSlider(
            min: 0,
            max: borneHaute,
            divisions: (borneHaute / 10).round().clamp(1, 100),
            activeColor: AppColors.primaryColor,
            values: RangeValues(
              (c.prixMin ?? 0).clamp(0, borneHaute),
              (c.prixMax ?? borneHaute).clamp(0, borneHaute),
            ),
            labels: RangeLabels(
              "${(c.prixMin ?? 0).round()}",
              "${(c.prixMax ?? borneHaute).round()}",
            ),
            onChanged: (v) => _maj(() {
              c.prixMin = v.start <= 0 ? null : v.start;
              c.prixMax = v.end >= borneHaute ? null : v.end;
            }),
          ),
          const SizedBox(height: 6),

          _titre("Chambres"),
          Wrap(
            spacing: 7,
            children: [
              _choixInt(null, 'Toutes', c.chambres, (v) => _maj(() => c.chambres = v)),
              _choixInt(1, '1', c.chambres, (v) => _maj(() => c.chambres = v)),
              _choixInt(2, '2', c.chambres, (v) => _maj(() => c.chambres = v)),
              _choixInt(3, '3', c.chambres, (v) => _maj(() => c.chambres = v)),
              _choixInt(4, '4 et +', c.chambres, (v) => _maj(() => c.chambres = v)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _titre(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 7),
        child: Text(
          t,
          style: const TextStyle(
              fontSize: 13, fontWeight: FontWeight.w700, color: texteAccueil),
        ),
      );

  Widget _choix(String valeur, String libelle, String actuel,
      void Function(String) onTap) {
    final actif = actuel == valeur;
    return ChoiceChip(
      label: Text(libelle, style: const TextStyle(fontSize: 12.5)),
      selected: actif,
      onSelected: (_) => onTap(valeur),
      selectedColor: AppColors.primaryColor,
      labelStyle: TextStyle(color: actif ? Colors.white : texteAccueil),
      backgroundColor: Colors.white,
      side: BorderSide(color: actif ? AppColors.primaryColor : bordureAccueil),
      showCheckmark: false,
    );
  }

  Widget _choixInt(int? valeur, String libelle, int? actuel,
      void Function(int?) onTap) {
    final actif = actuel == valeur;
    return ChoiceChip(
      label: Text(libelle, style: const TextStyle(fontSize: 12.5)),
      selected: actif,
      onSelected: (_) => onTap(valeur),
      selectedColor: AppColors.primaryColor,
      labelStyle: TextStyle(color: actif ? Colors.white : texteAccueil),
      backgroundColor: Colors.white,
      side: BorderSide(color: actif ? AppColors.primaryColor : bordureAccueil),
      showCheckmark: false,
    );
  }
}
