import 'package:flutter/material.dart';
import 'package:immobilier/core/constants/app_colors.dart';
import 'package:immobilier/models/permissions_roles.dart';

/// Briques d'affichage communes aux écrans « Droits et permissions »
/// (par rôle et par utilisateur).

const Color couleurTexteDroits = Color(0xFF17262E);

/// L'icône d'un module : d'abord le nom donné par le serveur, puis le
/// code du module, sinon une icône neutre.
IconData iconeModule(ModulePermissions module) {
  const parNom = <String, IconData>{
    'building': Icons.apartment_rounded,
    'house': Icons.house_rounded,
    'home': Icons.home_rounded,
    'calendar-check': Icons.event_available_rounded,
    'calendar': Icons.calendar_month_rounded,
    'calendar-days': Icons.calendar_month_rounded,
    'airbnb': Icons.holiday_village_rounded,
    'users': Icons.people_alt_rounded,
    'user': Icons.person_rounded,
    'user-tie': Icons.real_estate_agent_rounded,
    'receipt': Icons.receipt_long_rounded,
    'triangle-exclamation': Icons.report_problem_rounded,
    'exclamation-triangle': Icons.report_problem_rounded,
    'cash-register': Icons.point_of_sale_rounded,
    'wallet': Icons.account_balance_wallet_rounded,
    'chart-line': Icons.show_chart_rounded,
    'chart-bar': Icons.bar_chart_rounded,
    'user-gear': Icons.manage_accounts_rounded,
    'users-gear': Icons.manage_accounts_rounded,
    'whatsapp': Icons.chat_rounded,
    'globe': Icons.public_rounded,
    'bullhorn': Icons.campaign_rounded,
    'message': Icons.message_rounded,
    'comment': Icons.chat_bubble_rounded,
    'envelope': Icons.mail_rounded,
    'building-user': Icons.location_city_rounded,
    'file-signature': Icons.assignment_rounded,
    'file-contract': Icons.assignment_rounded,
    'tag': Icons.sell_rounded,
    'file-export': Icons.file_download_rounded,
    'download': Icons.file_download_rounded,
    'shield': Icons.admin_panel_settings_rounded,
    'shield-halved': Icons.admin_panel_settings_rounded,
    'gear': Icons.settings_rounded,
    'ellipsis': Icons.more_horiz_rounded,
  };
  const parCode = <String, IconData>{
    'immobilier': Icons.apartment_rounded,
    'reservations': Icons.event_available_rounded,
    'calendrier': Icons.calendar_month_rounded,
    'airbnb': Icons.holiday_village_rounded,
    'clients': Icons.people_alt_rounded,
    'proprietaires': Icons.real_estate_agent_rounded,
    'charges': Icons.receipt_long_rounded,
    'reclamations': Icons.report_problem_rounded,
    'caisse': Icons.point_of_sale_rounded,
    'statistiques': Icons.show_chart_rounded,
    'utilisateurs': Icons.manage_accounts_rounded,
    'whatsapp': Icons.chat_rounded,
    'plateforme': Icons.public_rounded,
    'campagnes': Icons.campaign_rounded,
    'modeles': Icons.message_rounded,
    'syndics': Icons.location_city_rounded,
    'baux': Icons.assignment_rounded,
    'ventes': Icons.sell_rounded,
    'export': Icons.file_download_rounded,
    'administration': Icons.admin_panel_settings_rounded,
    'autres': Icons.more_horiz_rounded,
  };
  final nom = module.icone.toLowerCase().replaceFirst(RegExp(r'^fa-'), '');
  return parNom[nom] ??
      parCode[module.code.toLowerCase()] ??
      Icons.widgets_rounded;
}

/// Couleur d'une nature de droit.
Color couleurAction(ActionDroit action) {
  switch (action) {
    case ActionDroit.voir:
      return const Color(0xFF1E88E5);
    case ActionDroit.ajouter:
      return const Color(0xFF2E7D32);
    case ActionDroit.modifier:
      return const Color(0xFFEF6C00);
    case ActionDroit.supprimer:
      return const Color(0xFFC62828);
    case ActionDroit.action:
      return const Color(0xFF6A1B9A);
  }
}

/// Petite pastille « Voir », « Ajouter »… à côté d'un droit.
class PastilleAction extends StatelessWidget {
  final ActionDroit action;

  const PastilleAction(this.action, {super.key});

  @override
  Widget build(BuildContext context) {
    final couleur = couleurAction(action);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
      decoration: BoxDecoration(
        color: couleur.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: couleur.withValues(alpha: .35), width: .8),
      ),
      child: Text(
        action.libelle,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
          color: couleur,
          height: 1.2,
        ),
      ),
    );
  }
}

/// Pastille arrondie de compteur « n / N ».
class CompteurDroits extends StatelessWidget {
  final int n;
  final int total;
  final bool petit;

  const CompteurDroits(
      {super.key, required this.n, required this.total, this.petit = false});

  @override
  Widget build(BuildContext context) {
    final vide = n == 0;
    final plein = total > 0 && n == total;
    final couleur = vide
        ? Colors.grey.shade600
        : (plein ? Colors.green.shade700 : AppColors.primaryColor);
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: petit ? 7 : 9, vertical: petit ? 2 : 3),
      decoration: BoxDecoration(
        color: vide ? Colors.grey.shade100 : couleur.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$n / $total',
        style: TextStyle(
          fontSize: petit ? 11 : 12,
          fontWeight: FontWeight.w600,
          color: couleur,
        ),
      ),
    );
  }
}

/// Badge orange « Non enregistré ».
class BadgeNonEnregistre extends StatelessWidget {
  const BadgeNonEnregistre({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.edit_note_rounded, size: 14, color: Colors.orange.shade800),
          const SizedBox(width: 3),
          Text(
            'Non enregistré',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: Colors.orange.shade800,
            ),
          ),
        ],
      ),
    );
  }
}

/// Champ de recherche compact avec bouton d'effacement.
class ChampRechercheDroits extends StatelessWidget {
  final TextEditingController controller;
  final String indication;
  final ValueChanged<String> onChanged;

  const ChampRechercheDroits({
    super.key,
    required this.controller,
    required this.onChanged,
    this.indication = 'Rechercher un droit…',
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        isDense: true,
        hintText: indication,
        hintStyle: TextStyle(fontSize: 13.5, color: Colors.grey.shade500),
        prefixIcon: Icon(Icons.search_rounded, color: Colors.grey.shade600),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                tooltip: 'Effacer',
                icon: Icon(Icons.close_rounded,
                    size: 19, color: Colors.grey.shade600),
                onPressed: () {
                  controller.clear();
                  onChanged('');
                },
              ),
        filled: true,
        fillColor: Colors.grey.shade100,
        contentPadding: const EdgeInsets.symmetric(vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.primaryColor),
        ),
      ),
    );
  }
}

/// « Tout déplier » / « Tout replier ».
class BoutonsDepliage extends StatelessWidget {
  final VoidCallback onDeplier;
  final VoidCallback onReplier;

  const BoutonsDepliage(
      {super.key, required this.onDeplier, required this.onReplier});

  @override
  Widget build(BuildContext context) {
    final style = TextButton.styleFrom(
      foregroundColor: AppColors.primaryColor,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      minimumSize: const Size(0, 34),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      textStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextButton.icon(
          onPressed: onDeplier,
          style: style,
          icon: const Icon(Icons.unfold_more_rounded, size: 18),
          label: const Text('Tout déplier'),
        ),
        TextButton.icon(
          onPressed: onReplier,
          style: style,
          icon: const Icon(Icons.unfold_less_rounded, size: 18),
          label: const Text('Tout replier'),
        ),
      ],
    );
  }
}

/// Case « tout » à trois états : cochée, décochée ou partielle.
/// Un appui coche tout, sauf si tout est déjà coché.
class CaseTout extends StatelessWidget {
  final int n;
  final int total;
  final ValueChanged<bool>? onChanged;

  const CaseTout(
      {super.key, required this.n, required this.total, this.onChanged});

  @override
  Widget build(BuildContext context) {
    final tout = total > 0 && n == total;
    final bool? valeur = n == 0 ? false : (tout ? true : null);
    return Checkbox(
      tristate: true,
      value: valeur,
      activeColor: AppColors.primaryColor,
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      onChanged: onChanged == null ? null : (_) => onChanged!(!tout),
    );
  }
}

/// Carte repliable d'un module : icône, libellé, compteur, actions.
class CarteModuleDroits extends StatelessWidget {
  final ModulePermissions module;
  final bool ouvert;
  final VoidCallback onOuvrir;
  final Widget compteur;

  /// Ligne sous le libellé (ex. « 2 personnalisés »).
  final Widget? sousTitre;

  /// Action à droite du compteur (ex. case « tout le module »).
  final Widget? action;
  final List<Widget> enfants;

  const CarteModuleDroits({
    super.key,
    required this.module,
    required this.ouvert,
    required this.onOuvrir,
    required this.compteur,
    required this.enfants,
    this.sousTitre,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: ouvert
              ? AppColors.primaryColor.withValues(alpha: .35)
              : Colors.grey.shade300,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onOuvrir,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(11, 10, 4, 10),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.primaryColor.withValues(alpha: .10),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Icon(iconeModule(module),
                        size: 20, color: AppColors.primaryColor),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          module.libelle,
                          style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w600,
                            color: couleurTexteDroits,
                          ),
                        ),
                        if (sousTitre != null) ...[
                          const SizedBox(height: 3),
                          sousTitre!,
                        ],
                      ],
                    ),
                  ),
                  compteur,
                  if (action != null) action!,
                  Icon(
                    ouvert
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: Colors.grey.shade600,
                  ),
                ],
              ),
            ),
          ),
          if (ouvert) ...[
            Divider(height: 1, color: Colors.grey.shade200),
            ...enfants,
            const SizedBox(height: 4),
          ],
        ],
      ),
    );
  }
}

/// En-tête repliable d'un sous-module, à l'intérieur d'une carte.
class EnTeteSousModule extends StatelessWidget {
  final SousModulePermissions sousModule;
  final bool ouvert;
  final VoidCallback onOuvrir;
  final Widget compteur;
  final Widget? action;

  const EnTeteSousModule({
    super.key,
    required this.sousModule,
    required this.ouvert,
    required this.onOuvrir,
    required this.compteur,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onOuvrir,
      child: Container(
        color: Colors.grey.shade50,
        padding: const EdgeInsets.fromLTRB(14, 7, 4, 7),
        child: Row(
          children: [
            Icon(
              ouvert
                  ? Icons.arrow_drop_down_rounded
                  : Icons.arrow_right_rounded,
              color: Colors.grey.shade700,
            ),
            const SizedBox(width: 2),
            Expanded(
              child: Text(
                sousModule.libelle,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade800,
                ),
              ),
            ),
            compteur,
            if (action != null) action! else const SizedBox(width: 10),
          ],
        ),
      ),
    );
  }
}

/// Barre collante « Annuler » / « Enregistrer ».
class BarreEnregistrementDroits extends StatelessWidget {
  final bool enCours;
  final String? precision;
  final VoidCallback onAnnuler;
  final VoidCallback onEnregistrer;

  const BarreEnregistrementDroits({
    super.key,
    required this.enCours,
    required this.onAnnuler,
    required this.onEnregistrer,
    this.precision,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Colors.grey.shade300)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .06),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const BadgeNonEnregistre(),
                if (precision != null) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      precision!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey.shade700),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: enCours ? null : onAnnuler,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(44),
                      foregroundColor: Colors.grey.shade800,
                      side: BorderSide(color: Colors.grey.shade400),
                    ),
                    child: const Text('Annuler'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: enCours ? null : onEnregistrer,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(44),
                      backgroundColor: AppColors.primaryColor,
                      foregroundColor: Colors.white,
                    ),
                    icon: enCours
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.save_rounded, size: 19),
                    label: const Text('Enregistrer',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Bandeau d'information (bleu) ou d'avertissement.
class BandeauDroits extends StatelessWidget {
  final IconData icone;
  final String texte;

  const BandeauDroits({super.key, required this.icone, required this.texte});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icone, size: 18, color: Colors.blue.shade800),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              texte,
              style: TextStyle(
                  fontSize: 12.5, color: Colors.blue.shade900, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}

/// Message en bas d'écran, vert ou rouge.
void messageDroits(BuildContext context, String texte, {bool erreur = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(texte),
      behavior: SnackBarBehavior.floating,
      backgroundColor: erreur ? Colors.red.shade700 : Colors.green.shade700,
    ));
}

/// Boîte de confirmation ; rend vrai si l'utilisateur confirme.
Future<bool> confirmerDroits(
  BuildContext context, {
  required String titre,
  required String message,
  String confirmer = 'Confirmer',
  bool danger = false,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(titre),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Annuler'),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          style: TextButton.styleFrom(
            foregroundColor:
                danger ? Colors.red.shade700 : AppColors.primaryColor,
          ),
          child: Text(confirmer),
        ),
      ],
    ),
  );
  return ok == true;
}

/// Demande avant de perdre des changements non enregistrés.
Future<bool> confirmerAbandon(BuildContext context) => confirmerDroits(
      context,
      titre: 'Modifications non enregistrées',
      message: 'Les changements en cours seront perdus. Continuer ?',
      confirmer: 'Abandonner',
      danger: true,
    );

/// Les sous-modules et droits d'un module qui répondent à une recherche.
/// Si le libellé du module ou du sous-module correspond, tous ses droits
/// restent visibles.
List<SousModulePermissions> filtrerSousModules(
  ModulePermissions module,
  String requete, {
  bool Function(PermissionDroit)? garder,
}) {
  final moduleCorrespond = requete.isNotEmpty &&
      normaliserRecherche(module.libelle).contains(requete);
  final resultat = <SousModulePermissions>[];
  for (final s in module.sousModules) {
    final sousCorrespond = moduleCorrespond ||
        (requete.isNotEmpty &&
            normaliserRecherche(s.libelle).contains(requete));
    final droits = s.permissions
        .where((p) => sousCorrespond || p.correspond(requete))
        .where((p) => garder == null || garder(p))
        .toList();
    if (droits.isNotEmpty) {
      resultat.add(SousModulePermissions(
          code: s.code, libelle: s.libelle, permissions: droits));
    }
  }
  return resultat;
}
