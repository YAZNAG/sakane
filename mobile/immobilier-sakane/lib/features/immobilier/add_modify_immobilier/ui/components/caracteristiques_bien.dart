import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:immobilier/features/home/ui/components/accueil_commun.dart';
import 'package:immobilier/features/immobilier/add_modify_immobilier/ui/components/assistant_bien_commun.dart';
import 'package:immobilier/models/formulaire_bien.dart';

/// Les caractéristiques propres au type de bien choisi, dans le langage de
/// l'assistant : les mêmes champs que le reste de l'étape.
///
/// Un appartement se décrit par ses salons et ses balcons, un terrain par
/// son titre et sa viabilisation. Le serveur dit quels champs poser ; ce
/// widget les affiche selon leur nature — un nombre, un texte, un oui/non,
/// un choix — et rend les valeurs saisies.
class ChampsCaracteristiques extends StatefulWidget {
  final List<ChampCaracteristique> champs;

  /// Les valeurs déjà connues du bien.
  final Map<String, dynamic> valeurs;

  /// Appelé à chaque saisie : la carte complète, débarrassée des vides.
  final ValueChanged<Map<String, dynamic>> onChange;

  const ChampsCaracteristiques({
    super.key,
    required this.champs,
    required this.valeurs,
    required this.onChange,
  });

  @override
  State<ChampsCaracteristiques> createState() => _ChampsCaracteristiquesState();
}

class _ChampsCaracteristiquesState extends State<ChampsCaracteristiques> {
  final Map<String, TextEditingController> _controleurs = {};
  late final Map<String, dynamic> _valeurs = {...widget.valeurs};

  static final List<TextInputFormatter> _chiffres = [
    FilteringTextInputFormatter.digitsOnly,
  ];
  static final List<TextInputFormatter> _decimal = [
    FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
  ];

  @override
  void didUpdateWidget(ChampsCaracteristiques ancien) {
    super.didUpdateWidget(ancien);
    // Le type de bien a changé : ses champs ne sont plus les mêmes. Ce qui
    // a été saisi pour un champ encore demandé reste.
    final cles = widget.champs.map((c) => c.cle).toSet();
    final aRetirer = _valeurs.keys.where((k) => !cles.contains(k)).toList(growable: false);
    if (aRetirer.isEmpty) return;
    for (final cle in aRetirer) {
      _valeurs.remove(cle);
      _controleurs.remove(cle)?.dispose();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => widget.onChange({..._valeurs}));
  }

  @override
  void dispose() {
    for (final c in _controleurs.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _controleur(ChampCaracteristique champ) {
    return _controleurs.putIfAbsent(champ.cle, () {
      final v = _valeurs[champ.cle];
      return TextEditingController(text: v == null ? '' : _enTexte(v));
    });
  }

  String _enTexte(dynamic valeur) =>
      valeur is double && valeur == valeur.roundToDouble()
          ? valeur.round().toString()
          : valeur.toString();

  void _poser(String cle, dynamic valeur) {
    setState(() {
      if (valeur == null || (valeur is String && valeur.trim().isEmpty)) {
        _valeurs.remove(cle);
      } else {
        _valeurs[cle] = valeur;
      }
    });
    widget.onChange({..._valeurs});
  }

  @override
  Widget build(BuildContext context) {
    if (widget.champs.isEmpty) return const SizedBox.shrink();

    final nombres = widget.champs.where((c) => c.estNombre).toList();
    final choix = widget.champs.where((c) => c.type == 'choix').toList();
    final textes = widget.champs.where((c) => c.type == 'texte').toList();
    final ouiNon = widget.champs.where((c) => c.type == 'booleen').toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Les nombres deux par deux, comme les chambres et les salles de bain.
        for (var i = 0; i < nombres.length; i += 2) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _nombre(nombres[i])),
              const SizedBox(width: 12),
              if (i + 1 < nombres.length)
                Expanded(child: _nombre(nombres[i + 1]))
              else
                const Expanded(child: SizedBox()),
            ],
          ),
          const SizedBox(height: 16),
        ],
        for (final champ in choix) ...[
          _choix(champ),
          const SizedBox(height: 16),
        ],
        for (final champ in textes) ...[
          ChampTexteBien(
            libelle: champ.libelle,
            indication: 'Préciser',
            controller: _controleur(champ),
            onChange: (v) => _poser(champ.cle, v.trim()),
          ),
          const SizedBox(height: 16),
        ],
        if (ouiNon.isNotEmpty) ...[
          const LibelleChampBien('Le bien possède'),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final champ in ouiNon)
                PuceEquipementBien(
                  texte: champ.libelle,
                  choisi: _valeurs[champ.cle] == true,
                  onTap: () => _poser(
                      champ.cle, _valeurs[champ.cle] == true ? null : true),
                ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _nombre(ChampCaracteristique champ) {
    final entier = champ.type == 'entier';
    return ChampTexteBien(
      libelle: champ.libelle,
      indication: '0',
      controller: _controleur(champ),
      clavier: entier
          ? TextInputType.number
          : const TextInputType.numberWithOptions(decimal: true),
      formats: entier ? _chiffres : _decimal,
      unite: champ.unite,
      onChange: (v) {
        final propre = v.trim().replaceAll(',', '.');
        if (propre.isEmpty) {
          _poser(champ.cle, null);
          return;
        }
        _poser(champ.cle, entier ? int.tryParse(propre) : double.tryParse(propre));
      },
    );
  }

  /// Deux ou trois réponses tiennent en boutons collés ; au-delà, une liste.
  Widget _choix(ChampCaracteristique champ) {
    final valeur = _valeurs[champ.cle]?.toString();

    if (champ.options.length <= 3) {
      return ChampSegmenteBien<String>(
        libelle: champ.libelle,
        valeur: valeur,
        choix: [for (final o in champ.options) ChoixSegmenteBien(o, o)],
        onChange: (v) => _poser(champ.cle, v == valeur ? null : v),
      );
    }

    return ChampListeBien<String>(
      libelle: champ.libelle,
      indication: 'Choisir',
      valeur: champ.options.contains(valeur) ? valeur : null,
      choix: [
        for (final o in champ.options)
          DropdownMenuItem(
            value: o,
            child: Text(o, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChange: (v) => _poser(champ.cle, v),
    );
  }
}

/// Le titre d'un groupe de caractéristiques : « Propre aux appartements ».
String titreCaracteristiques(String? nomDuType) {
  final nom = (nomDuType ?? '').trim();
  if (nom.isEmpty) return 'Caractéristiques du type';
  return 'Propre aux ${nom.toLowerCase()}';
}

/// Les familles d'équipements telles qu'elles s'affichent, même quand le
/// serveur ne les a pas nommées.
const Map<String, String> famillesEquipementsParDefaut = {
  'interieur': 'Intérieur',
  'exterieur': 'Extérieur',
  'confort': 'Confort et énergie',
  'equipements': 'Électroménager',
  'securite': 'Sécurité',
  'services': 'Services et immeuble',
};

/// Une famille d'équipements prête à l'affichage.
class FamilleAffichee {
  final String code;
  final String libelle;
  final List<int> ids;

  const FamilleAffichee({
    required this.code,
    required this.libelle,
    required this.ids,
  });
}

/// Le fond très pâle d'un en-tête de famille.
const Color fondFamilleEquipement = Color(0xFFF6F8F9);

/// Dit si une recherche retient ce texte.
bool correspondRecherche(String? texte, String motif) {
  if (motif.trim().isEmpty) return true;
  return (texte ?? '').toLowerCase().contains(motif.trim().toLowerCase());
}

/// Le gris des libellés, repris de l'accueil pour rester dans la charte.
const Color texteDouxCaracteristiques = texteDouxAccueil;
