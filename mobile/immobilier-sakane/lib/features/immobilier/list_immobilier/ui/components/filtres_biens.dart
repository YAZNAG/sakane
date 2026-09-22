import 'package:flutter/material.dart';
import 'package:immobilier/core/constants/app_colors.dart';
import 'package:immobilier/models/realestate.dart';

/// Criteres de filtrage de la liste des biens.
class CriteresBiens {
  String recherche;
  String etat; // tous | disponible | reserve | a_nettoyer | en_cours
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

  /// Applique tous les criteres a une liste de biens.
  List<Realestate> appliquer(List<Realestate> biens) {
    return biens.where((b) {
      // recherche sur le nom ou l'adresse
      if (recherche.isNotEmpty) {
        final q = recherche.toLowerCase();
        final titre = (b.title ?? '').toLowerCase();
        final adresse = (b.address?.address ?? '').toLowerCase();
        final secteur = (b.secteur?.name ?? '').toLowerCase();
        if (!titre.contains(q) && !adresse.contains(q) && !secteur.contains(q)) {
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

/// Barre de recherche, pastilles d'etat et panneau de filtres repliable.
class FiltresBiens extends StatefulWidget {
  final CriteresBiens criteres;
  final List<Realestate> tousLesBiens;
  final int nombreAffiche;
  final VoidCallback onChange;

  const FiltresBiens({
    super.key,
    required this.criteres,
    required this.tousLesBiens,
    required this.nombreAffiche,
    required this.onChange,
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

  @override
  Widget build(BuildContext context) {
    final c = widget.criteres;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),

        // ---- recherche ----
        TextField(
          controller: _rechercheController,
          onChanged: (v) => _maj(() => c.recherche = v.trim()),
          decoration: InputDecoration(
            hintText: "Rechercher par nom, adresse ou secteur...",
            prefixIcon: const Icon(Icons.search, size: 21),
            suffixIcon: c.recherche.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.close, size: 19),
                    onPressed: () {
                      _rechercheController.clear();
                      _maj(() => c.recherche = '');
                    },
                  ),
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
          ),
        ),
        const SizedBox(height: 10),

        // ---- pastilles d'etat (courte duree seulement) ----
        if (c.etatsApplicables) SizedBox(
          height: 34,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _pastille('tous', 'Tous', Icons.apps),
              _pastille('disponible', 'Disponibles', Icons.check_circle_outline,
                  couleur: Colors.green.shade600),
              _pastille('reserve', 'Réservés', Icons.event_busy,
                  couleur: Colors.red.shade600),
              _pastille('a_nettoyer', 'À nettoyer', Icons.hourglass_empty,
                  couleur: Colors.blueGrey.shade700),
              _pastille('en_cours', 'En cours', Icons.cleaning_services,
                  couleur: Colors.orange.shade700),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // ---- ligne : compteur + bouton filtres ----
        Row(
          children: [
            Text(
              "${widget.nombreAffiche} bien${widget.nombreAffiche > 1 ? 's' : ''}"
              "${widget.nombreAffiche != widget.tousLesBiens.length ? ' sur ${widget.tousLesBiens.length}' : ''}",
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
            const Spacer(),
            if (c.filtresAvancesActifs)
              TextButton.icon(
                onPressed: () => _maj(() => c.reinitialiser()),
                icon: const Icon(Icons.close, size: 15),
                label: const Text("Réinitialiser", style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.grey.shade700,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            const SizedBox(width: 4),
            TextButton.icon(
              onPressed: () => setState(() => _panneauOuvert = !_panneauOuvert),
              icon: Icon(
                _panneauOuvert ? Icons.expand_less : Icons.tune,
                size: 17,
              ),
              label: Text(
                c.nombreFiltresActifs > 0
                    ? "Filtres (${c.nombreFiltresActifs})"
                    : "Filtres",
                style: const TextStyle(fontSize: 12.5),
              ),
              style: TextButton.styleFrom(
                foregroundColor: c.nombreFiltresActifs > 0
                    ? AppColors.primaryColor
                    : Colors.grey.shade700,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ),

        // ---- panneau repliable ----
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 200),
          crossFadeState: _panneauOuvert
              ? CrossFadeState.showFirst
              : CrossFadeState.showSecond,
          firstChild: _panneau(c),
          secondChild: const SizedBox(width: double.infinity),
        ),
        const SizedBox(height: 6),
      ],
    );
  }

  Widget _pastille(String valeur, String libelle, IconData icone, {Color? couleur}) {
    final actif = widget.criteres.etat == valeur;
    final c = couleur ?? AppColors.primaryColor;
    return Padding(
      padding: const EdgeInsets.only(right: 7),
      child: InkWell(
        onTap: () => _maj(() => widget.criteres.etat = valeur),
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: actif ? c : Colors.white,
            border: Border.all(color: actif ? c : Colors.grey.shade300),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              Icon(icone, size: 14, color: actif ? Colors.white : c),
              const SizedBox(width: 5),
              Text(
                libelle,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: actif ? FontWeight.bold : FontWeight.normal,
                  color: actif ? Colors.white : Colors.grey.shade800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _panneau(CriteresBiens c) {
    final prixMax = widget.tousLesBiens
        .map((b) => (b.price ?? 0).toDouble())
        .fold<double>(0, (a, b) => a > b ? a : b);
    final borneHaute = prixMax > 0 ? (prixMax / 50).ceil() * 50.0 : 1000.0;

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(10),
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
                  borderRadius: BorderRadius.circular(8),
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
              fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87),
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
      labelStyle: TextStyle(color: actif ? Colors.white : Colors.grey.shade800),
      backgroundColor: Colors.white,
      side: BorderSide(color: actif ? AppColors.primaryColor : Colors.grey.shade300),
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
      labelStyle: TextStyle(color: actif ? Colors.white : Colors.grey.shade800),
      backgroundColor: Colors.white,
      side: BorderSide(color: actif ? AppColors.primaryColor : Colors.grey.shade300),
      showCheckmark: false,
    );
  }
}
