import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:immobilier/core/constants/app_colors.dart';
import 'package:immobilier/features/home/ui/components/accueil_commun.dart';

/// Le cadre de l'assistant « Ajouter un bien » : la barre des cinq étapes,
/// les champs, les puces, la barre d'actions du bas.
///
/// Tout l'assistant se sert d'ici, pour que les cinq écrans se ressemblent
/// et qu'une teinte changée le soit partout à la fois. La charte est celle
/// de l'accueil — fond #F4F6F8, cartes blanches, bordure fine — reprise de
/// `accueil_commun.dart`.

/// Le vert de la marque : l'étape faite, le bouton plein, le choix retenu.
const Color principaleBien = AppColors.primaryColor;

/// Le vert très clair d'un choix retenu : segment actif, puce cochée.
const Color fondPrincipaleBien = Color(0xFFE6F2ED);

/// Le bleu très clair du bandeau d'information des photos.
const Color fondInfoBien = Color(0xFFEAF2FA);
const Color texteInfoBien = Color(0xFF2F6394);

/// Le rayon d'un champ : plus serré que celui d'une carte.
const double rayonChampBien = 12;

/// Les initiales d'un nom : « Hassan Ait Ali » → « HA ».
String initialesBien(String? nom) {
  final mots = (nom ?? '').trim().split(RegExp(r'\s+')).where((m) => m.isNotEmpty).toList();
  if (mots.isEmpty) return '?';
  if (mots.length == 1) return mots.first.characters.first.toUpperCase();
  return '${mots.first.characters.first}${mots[1].characters.first}'.toUpperCase();
}

/// « +212 6 12 •• •• 08 » : le milieu du numéro est masqué. Le début dit
/// de quel opérateur il s'agit, la fin suffit à reconnaître la fiche.
String telephoneMasqueBien(String? tel) {
  final brut = (tel ?? '').trim();
  if (brut.isEmpty) return '';
  final chiffres = brut.replaceAll(RegExp(r'[^0-9]'), '');
  if (chiffres.length < 8) return brut;

  // Numéro marocain écrit avec son indicatif : « +212 6 12 •• •• 08 ».
  if (brut.startsWith('+') && chiffres.length >= 11) {
    final pays = chiffres.substring(0, chiffres.length - 9);
    final n = chiffres.substring(chiffres.length - 9);
    return '+$pays ${n.substring(0, 1)} ${n.substring(1, 3)} •• •• ${n.substring(7)}';
  }
  // Numéro national : « 06 12 •• •• 08 ».
  if (chiffres.length == 10) {
    return '${chiffres.substring(0, 2)} ${chiffres.substring(2, 4)} •• •• ${chiffres.substring(8)}';
  }
  return '${chiffres.substring(0, 2)} •• •• ${chiffres.substring(chiffres.length - 2)}';
}

// ── La barre des cinq étapes ───────────────────────────────────────

/// Les cinq étapes de l'assistant, dans l'ordre, avec la clé qu'en garde
/// le brouillon. L'écran Dossiers lit cette même clé pour annoncer
/// « à l'étape n » : les deux numérotations restent d'accord.
const List<String> clesEtapesBien = ['base', 'location', 'details', 'features', 'images'];

const List<String> nomsEtapesBien = [
  'Informations générales',
  'Localisation',
  'Détails',
  'Équipements',
  'Photos',
];

/// Le libellé du bouton « Suivant : … », qui annonce où l'on va.
const List<String> suivantsEtapesBien = [
  'Suivant : localisation',
  'Suivant : détails',
  'Suivant : équipements',
  'Suivant : photos',
];

/// Cinq segments arrondis sous l'AppBar, puis le nom de l'étape.
///
/// Le segment fait ou en cours est vert, celui à venir gris : d'un coup
/// d'œil on sait combien il reste à remplir.
class BarreEtapesBien extends StatelessWidget implements PreferredSizeWidget {
  /// De 0 à 4.
  final int etape;

  const BarreEtapesBien({super.key, required this.etape});

  @override
  Size get preferredSize => const Size.fromHeight(46);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: fondAccueil,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: List.generate(nomsEtapesBien.length, (i) {
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: i == nomsEtapesBien.length - 1 ? 0 : 5),
                  child: Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: i <= etape ? principaleBien : bordureAccueil,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 7),
          // La barre fait 46 px de haut : un très grand réglage de police
          // ne doit pas la faire déborder sous l'AppBar.
          MediaQuery.withClampedTextScaling(
            maxScaleFactor: 1.2,
            child: Text(
              nomsEtapesBien[etape.clamp(0, nomsEtapesBien.length - 1)],
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: principaleBien,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Les champs ─────────────────────────────────────────────────────

/// Le libellé en petit gras posé au-dessus d'un champ.
class LibelleChampBien extends StatelessWidget {
  final String texte;

  const LibelleChampBien(this.texte, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        texte,
        style: const TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w800,
          color: texteAccueil,
        ),
      ),
    );
  }
}

/// Un libellé, un champ, et de quoi glisser une mention dessous.
class ChampBien extends StatelessWidget {
  final String libelle;
  final Widget enfant;

  /// Sous le champ, à gauche : le compteur de caractères, une précision.
  final String? mention;

  const ChampBien({super.key, required this.libelle, required this.enfant, this.mention});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        LibelleChampBien(libelle),
        enfant,
        if (mention != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              mention!,
              style: const TextStyle(fontSize: 11.5, color: texteDouxAccueil),
            ),
          ),
      ],
    );
  }
}

/// Le fond blanc, la bordure fine, le rayon 12 : la même boîte pour tous
/// les champs de l'assistant, saisie libre comme liste déroulante.
InputDecoration decorationChampBien({
  String? indication,
  Widget? suffixe,
  Widget? prefixe,
  EdgeInsetsGeometry? marge,
}) {
  OutlineInputBorder bord(Color couleur, [double epaisseur = 1]) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(rayonChampBien),
        borderSide: BorderSide(color: couleur, width: epaisseur),
      );
  return InputDecoration(
    filled: true,
    fillColor: Colors.white,
    hintText: indication,
    hintStyle: const TextStyle(color: Color(0xFF9BA8AF), fontSize: 13.5),
    suffixIcon: suffixe,
    prefixIcon: prefixe,
    isDense: true,
    contentPadding: marge ?? const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
    border: bord(bordureAccueil),
    enabledBorder: bord(bordureAccueil),
    focusedBorder: bord(principaleBien, 1.4),
    errorBorder: bord(rougeAccueil),
    focusedErrorBorder: bord(rougeAccueil, 1.4),
    disabledBorder: bord(bordureAccueil),
    errorStyle: const TextStyle(fontSize: 11.5, color: rougeAccueil, height: 1.3),
    errorMaxLines: 3,
  );
}

/// Un champ de saisie habillé : libellé au-dessus, erreur en rouge dessous.
class ChampTexteBien extends StatelessWidget {
  final String libelle;
  final String? indication;
  final TextEditingController? controller;
  final String? Function(String?)? validateur;

  /// Pour retrouver le premier champ fautif et défiler jusqu'à lui.
  final GlobalKey<FormFieldState<String>>? cle;

  final TextInputType clavier;
  final int lignes;

  /// « MAD » en gris, à l'intérieur du champ, à droite.
  final String? unite;

  final Widget? icone;
  final bool lectureSeule;
  final VoidCallback? onTap;
  final ValueChanged<String>? onChange;
  final String? mention;
  final List<TextInputFormatter>? formats;
  final int? maxCaracteres;
  final TextCapitalization casse;

  const ChampTexteBien({
    super.key,
    required this.libelle,
    this.indication,
    this.controller,
    this.validateur,
    this.cle,
    this.clavier = TextInputType.text,
    this.lignes = 1,
    this.unite,
    this.icone,
    this.lectureSeule = false,
    this.onTap,
    this.onChange,
    this.mention,
    this.formats,
    this.maxCaracteres,
    this.casse = TextCapitalization.none,
  });

  @override
  Widget build(BuildContext context) {
    final suffixe = unite == null
        ? icone
        : Padding(
            padding: const EdgeInsets.only(right: 14, left: 8),
            child: Text(
              unite!,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: texteDouxAccueil,
              ),
            ),
          );

    return ChampBien(
      libelle: libelle,
      mention: mention,
      enfant: TextFormField(
        key: cle,
        controller: controller,
        validator: validateur,
        keyboardType: clavier,
        textCapitalization: casse,
        maxLines: lignes,
        minLines: lignes > 1 ? lignes : null,
        readOnly: lectureSeule,
        onTap: onTap,
        onChanged: onChange,
        inputFormatters: formats,
        maxLength: maxCaracteres,
        style: const TextStyle(fontSize: 14, color: texteAccueil),
        decoration: decorationChampBien(indication: indication, suffixe: suffixe).copyWith(
          // Le compteur du champ est remplacé par celui de la maquette,
          // posé sous le champ à gauche.
          counterText: '',
          suffixIconConstraints: unite == null
              ? null
              : const BoxConstraints(minWidth: 0, minHeight: 0),
        ),
      ),
    );
  }
}

/// Une liste déroulante habillée comme les champs de saisie.
class ChampListeBien<T> extends StatelessWidget {
  final String libelle;
  final String? indication;
  final T? valeur;
  final List<DropdownMenuItem<T>> choix;
  final ValueChanged<T?> onChange;
  final String? Function(T?)? validateur;
  final GlobalKey<FormFieldState<T>>? cle;
  final String? mention;

  const ChampListeBien({
    super.key,
    required this.libelle,
    required this.valeur,
    required this.choix,
    required this.onChange,
    this.indication,
    this.validateur,
    this.cle,
    this.mention,
  });

  @override
  Widget build(BuildContext context) {
    return ChampBien(
      libelle: libelle,
      mention: mention,
      enfant: DropdownButtonFormField<T>(
        key: cle,
        initialValue: valeur,
        items: choix,
        onChanged: onChange,
        validator: validateur,
        isExpanded: true,
        icon: const Icon(Icons.expand_more_rounded, color: texteDouxAccueil),
        style: const TextStyle(fontSize: 14, color: texteAccueil),
        dropdownColor: Colors.white,
        borderRadius: BorderRadius.circular(rayonChampBien),
        decoration: decorationChampBien(indication: indication),
      ),
    );
  }
}

/// La valeur, si la liste chargée la contient : une liste déroulante
/// refuse d'afficher un choix absent de ses propositions.
T? parmiListeBien<T>(List<T>? liste, T? valeur) {
  if (valeur == null) return null;
  return (liste ?? const []).contains(valeur) ? valeur : null;
}

/// Un choix parmi quelques-uns, tous visibles : le sélecteur segmenté.
class ChoixSegmenteBien<T> {
  final T valeur;
  final String libelle;

  const ChoixSegmenteBien(this.valeur, this.libelle);
}

/// Trois boutons collés : le choix retenu prend le fond vert clair.
class SegmenteBien<T> extends StatelessWidget {
  final List<ChoixSegmenteBien<T>> choix;
  final T? valeur;
  final ValueChanged<T> onChange;

  const SegmenteBien({
    super.key,
    required this.choix,
    required this.valeur,
    required this.onChange,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: bordureAccueil),
        borderRadius: BorderRadius.circular(rayonChampBien),
      ),
      child: Row(
        children: [
          for (final c in choix)
            Expanded(
              child: Material(
                color: valeur == c.valeur ? fondPrincipaleBien : Colors.transparent,
                borderRadius: BorderRadius.circular(9),
                child: InkWell(
                  onTap: () => onChange(c.valeur),
                  borderRadius: BorderRadius.circular(9),
                  child: Container(
                    height: 40,
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      c.libelle,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.15,
                        fontWeight: valeur == c.valeur ? FontWeight.w800 : FontWeight.w600,
                        color: valeur == c.valeur ? principaleBien : texteDouxAccueil,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Le sélecteur segmenté avec son libellé et, au besoin, son erreur.
///
/// Le validateur reçoit la valeur portée par le parent : le choix vit dans
/// le bloc, le champ ne fait que l'afficher et dire ce qui manque.
class ChampSegmenteBien<T> extends StatelessWidget {
  final String libelle;
  final List<ChoixSegmenteBien<T>> choix;
  final T? valeur;
  final ValueChanged<T> onChange;
  final String? Function(T?)? validateur;
  final GlobalKey<FormFieldState<T>>? cle;

  const ChampSegmenteBien({
    super.key,
    required this.libelle,
    required this.choix,
    required this.valeur,
    required this.onChange,
    this.validateur,
    this.cle,
  });

  @override
  Widget build(BuildContext context) {
    return FormField<T>(
      key: cle,
      initialValue: valeur,
      validator: validateur,
      builder: (champ) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          LibelleChampBien(libelle),
          SegmenteBien<T>(
            choix: choix,
            valeur: valeur,
            onChange: (v) {
              champ.didChange(v);
              onChange(v);
            },
          ),
          if (champ.hasError)
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 2),
              child: Text(
                champ.errorText!,
                style: const TextStyle(fontSize: 11.5, color: rougeAccueil),
              ),
            ),
        ],
      ),
    );
  }
}

/// Une puce à cocher : un équipement retenu prend le fond vert clair et
/// la bordure de la couleur principale.
class PuceEquipementBien extends StatelessWidget {
  final String texte;
  final bool choisi;
  final VoidCallback onTap;

  const PuceEquipementBien({
    super.key,
    required this.texte,
    required this.choisi,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: choisi ? fondPrincipaleBien : Colors.white,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 9, 14, 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: choisi ? principaleBien : bordureAccueil,
              width: choisi ? 1.4 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                choisi ? Icons.check_circle_rounded : Icons.circle_outlined,
                size: 17,
                color: choisi ? principaleBien : const Color(0xFFB4C0C6),
              ),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  texte,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: choisi ? FontWeight.w700 : FontWeight.w600,
                    color: choisi ? principaleBien : texteAccueil,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── La barre d'actions du bas ──────────────────────────────────────

/// Les boutons de l'étape, posés sur un fond blanc ombré, et le lien du
/// brouillon dessous. Elle reste en bas : le pouce la trouve sans chercher.
class BarreActionsBien extends StatelessWidget {
  /// Null à la première étape : le bouton « Suivant » prend toute la largeur.
  final VoidCallback? onPrecedent;

  final String libelleSuivant;
  final VoidCallback? onSuivant;

  /// L'enregistrement est parti : le bouton attend son retour.
  final bool occupe;

  /// Null en modification : un bien déjà créé n'a pas de brouillon.
  final VoidCallback? onBrouillon;

  const BarreActionsBien({
    super.key,
    required this.libelleSuivant,
    required this.onSuivant,
    this.onPrecedent,
    this.occupe = false,
    this.onBrouillon,
  });

  @override
  Widget build(BuildContext context) {
    final suivant = SizedBox(
      height: 50,
      child: ElevatedButton(
        onPressed: occupe ? null : onSuivant,
        style: ElevatedButton.styleFrom(
          backgroundColor: principaleBien,
          disabledBackgroundColor: principaleBien.withValues(alpha: .5),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(rayonChampBien)),
        ),
        child: occupe
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Text(
                libelleSuivant,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white),
              ),
      ),
    );

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Color(0x1417262E), blurRadius: 12, offset: Offset(0, -2))],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, 12, 16, onBrouillon == null ? 12 : 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (onPrecedent == null)
                SizedBox(width: double.infinity, child: suivant)
              else
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 50,
                        child: OutlinedButton(
                          onPressed: occupe ? null : onPrecedent,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: texteAccueil,
                            side: const BorderSide(color: bordureAccueil),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(rayonChampBien),
                            ),
                          ),
                          child: const Text(
                            'Précédent',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(flex: 2, child: suivant),
                  ],
                ),
              if (onBrouillon != null)
                TextButton(
                  onPressed: occupe ? null : onBrouillon,
                  style: TextButton.styleFrom(
                    foregroundColor: texteDouxAccueil,
                    minimumSize: const Size(0, 38),
                  ),
                  child: const Text(
                    'Enregistrer comme brouillon',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Petites pièces communes ────────────────────────────────────────

/// Le bandeau bleu très clair qui explique une règle de l'étape.
class BandeauInfoBien extends StatelessWidget {
  final String texte;

  const BandeauInfoBien(this.texte, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
      decoration: BoxDecoration(
        color: fondInfoBien,
        borderRadius: BorderRadius.circular(rayonChampBien),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded, size: 18, color: texteInfoBien),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              texte,
              style: const TextStyle(fontSize: 12.5, height: 1.35, color: texteInfoBien),
            ),
          ),
        ],
      ),
    );
  }
}

/// Une ligne du récapitulatif : le libellé en gris, la valeur en gras.
class LigneRecapBien extends StatelessWidget {
  final String libelle;
  final String valeur;

  const LigneRecapBien({super.key, required this.libelle, required this.valeur});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            libelle,
            style: const TextStyle(fontSize: 13, color: texteDouxAccueil),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              valeur,
              textAlign: TextAlign.right,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: texteAccueil,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Le titre d'un groupe de champs, dans une étape qui en compte plusieurs.
class TitreGroupeBien extends StatelessWidget {
  final String texte;

  const TitreGroupeBien(this.texte, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        texte.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: .6,
          color: texteDouxAccueil,
        ),
      ),
    );
  }
}

/// Le corps d'une étape : le fond clair et la marge, partout les mêmes.
class CorpsEtapeBien extends StatelessWidget {
  final List<Widget> enfants;
  final ScrollController? defilement;

  const CorpsEtapeBien({super.key, required this.enfants, this.defilement});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: fondAccueil,
      child: ListView(
        controller: defilement,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: enfants,
      ),
    );
  }
}

/// Défile jusqu'au premier champ en erreur, pour que l'agent voie ce qui
/// bloque au lieu de chercher.
void allerAuPremierFautifBien(List<GlobalKey<FormFieldState<dynamic>>> cles) {
  for (final cle in cles) {
    final etat = cle.currentState;
    final contexte = cle.currentContext;
    if (etat != null && etat.hasError && contexte != null) {
      Scrollable.ensureVisible(
        contexte,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
        alignment: 0.1,
      );
      return;
    }
  }
}
