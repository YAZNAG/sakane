import 'dart:io';

import 'package:flutter/material.dart';
import 'package:immobilier/components/bouton_export.dart';
import 'package:immobilier/core/constants/app_colors.dart';
import 'package:immobilier/core/dependencies/dependencies.dart';
import 'package:immobilier/core/utils/show_toast.dart';
import 'package:immobilier/features/immobilier/contrat/ui/visionneuse_contrat.dart';
import 'package:immobilier/features/syndics/ui/components/syndic_commun.dart';
import 'package:immobilier/models/envoi_historique_syndic.dart';
import 'package:immobilier/repository/repository.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:toastification/toastification.dart';

// ── Statut et source ─────────────────────────────────────────────────

/// Libellé du statut : celui de l'application pour les trois statuts
/// qu'elle connaît, celui du serveur (statutLibelle) pour tout autre.
String libelleStatutEnvoiHistorique(EnvoiHistoriqueSyndic e) {
  switch (e.statut) {
    case 'envoye':
      return 'Envoyé';
    case 'echec':
      return 'Échec';
    case 'ignore':
      return 'Non envoyé';
  }
  final serveur = e.statutLibelle;
  if (serveur != null) return serveur;
  if (e.statut.isEmpty) return 'Statut inconnu';
  return e.statut[0].toUpperCase() + e.statut.substring(1);
}

/// Vert envoyé, rouge échec, gris non envoyé. Un statut inconnu reste
/// neutre plutôt que de s'annoncer en rouge.
Color couleurStatutEnvoiHistorique(String statut) {
  switch (statut) {
    case 'envoye':
      return const Color(0xFF1E7B45);
    case 'echec':
      return const Color(0xFFB3261E);
    default:
      return const Color(0xFF6B7B84);
  }
}

IconData iconeStatutEnvoiHistorique(String statut) {
  switch (statut) {
    case 'envoye':
      return Icons.check_circle_outline;
    case 'echec':
      return Icons.error_outline;
    case 'ignore':
      return Icons.remove_circle_outline;
    default:
      return Icons.help_outline;
  }
}

/// Libellé de la source : celui de l'application pour les sources
/// connues, celui du serveur (sourceLibelle) pour les autres, afin
/// qu'une source inattendue s'affiche quand même.
String libelleSourceEnvoi(EnvoiHistoriqueSyndic e) {
  switch (e.source) {
    case 'auto':
      return 'Automatique';
    case 'manuel':
      return 'Partage manuel';
    case 'renvoi':
      return 'Renvoi';
    case 'prolongation':
      return 'Prolongation';
    case 'raccourcissement':
      return 'Raccourcissement';
  }
  final serveur = e.sourceLibelle;
  if (serveur != null) return serveur;
  if (e.source.isEmpty) return '';
  return e.source[0].toUpperCase() + e.source.substring(1);
}

IconData iconeSourceEnvoi(String source) {
  switch (source) {
    case 'auto':
      return Icons.bolt_outlined;
    case 'manuel':
      return Icons.touch_app_outlined;
    case 'renvoi':
      return Icons.replay;
    case 'prolongation':
      return Icons.update;
    case 'raccourcissement':
      return Icons.content_cut;
    default:
      return Icons.edit_calendar_outlined;
  }
}

/// Couleur de la source : les modifications de séjour ressortent.
Color couleurSourceEnvoi(String source) {
  switch (source) {
    case 'prolongation':
      return Colors.teal.shade700;
    case 'raccourcissement':
      return Colors.deepOrange.shade700;
    case 'auto':
    case 'manuel':
    case 'renvoi':
      return const Color(0xFF6B7B84);
    default:
      return Colors.indigo.shade400;
  }
}

String heureEnvoi(DateTime? d) {
  if (d == null) return '';
  String deux(int n) => n.toString().padLeft(2, '0');
  return '${deux(d.hour)}:${deux(d.minute)}';
}

String sejourEnvoi(ReservationEnvoiSyndic? r) {
  if (r == null) return '';
  final debut = dateSejourSyndic(r.checkin);
  final fin = dateSejourSyndic(r.checkout);
  if (debut.isEmpty && fin.isEmpty) return '';
  if (fin.isEmpty) return 'Du $debut';
  if (debut.isEmpty) return "Jusqu'au $fin";
  return 'Du $debut au $fin';
}

/// Le detail d'un envoi, a partager tel quel (WhatsApp, e-mail…).
String texteDetailEnvoi(EnvoiHistoriqueSyndic e) {
  final r = e.reservation;
  final lignes = <String>[
    'Envoi du contrat au syndic',
    if (e.date != null) 'Date : ${dateHeureExport(e.date)}',
    if (e.syndicNom != null) 'Syndic : ${e.syndicNom}',
    if (e.telephone != null) 'Téléphone : ${e.telephone}',
    if (r?.bien != null) 'Bien : ${r!.bien}',
    if (r?.client != null) 'Client : ${r!.client}',
    if (sejourEnvoi(r).isNotEmpty) 'Séjour : ${sejourEnvoi(r)}',
    'Statut : ${libelleStatutEnvoiHistorique(e)}${e.erreur == null ? '' : ' (${e.erreur})'}',
    if (libelleSourceEnvoi(e).isNotEmpty) 'Source : ${libelleSourceEnvoi(e)}',
    if (e.envoyePar != null) 'Envoyé par : ${e.envoyePar}',
  ];
  if (e.message != null) {
    lignes
      ..add('')
      ..add('Message :')
      ..add(e.message!);
  }
  return lignes.join('\n');
}

// ── Le contrat envoyé ────────────────────────────────────────────────

/// Un nom de fichier lisible : « Contrat syndic - Nom - 19-09-2026.pdf ».
String nomFichierContratEnvoi(EnvoiHistoriqueSyndic e) {
  final morceaux = <String>[
    'Contrat syndic',
    if (e.syndicNom != null) e.syndicNom!,
    if (e.date != null) dateExport(e.date).replaceAll('/', '-'),
  ];
  final nom = morceaux.join(' - ').replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
  return '${nom.isEmpty ? 'contrat-syndic-${e.id}' : nom}.pdf';
}

Future<String> _fichierContratEnvoi(EnvoiHistoriqueSyndic e) =>
    Dependencies.get<Repository>().telechargerContratEnvoiSyndic(e.contratUrl!, e.id);

/// Ouvre le contrat dans la visionneuse de l'application.
Future<void> voirContratEnvoiSyndic(BuildContext context, EnvoiHistoriqueSyndic envoi) async {
  final chemin = await _fichierContratEnvoi(envoi);
  if (!context.mounted) return;
  await VisionneuseContrat.ouvrir(context, chemin: chemin, titre: 'Contrat envoyé');
}

/// Copie le PDF sous un nom lisible puis ouvre la feuille de partage
/// (« Enregistrer dans Fichiers », Drive, WhatsApp…), comme la facture.
Future<void> enregistrerContratEnvoiSyndic(EnvoiHistoriqueSyndic envoi) async {
  final chemin = await _fichierContratEnvoi(envoi);
  final dir = await getTemporaryDirectory();
  final dossier = Directory('${dir.path}${Platform.pathSeparator}contrats-syndics');
  await dossier.create(recursive: true);
  final cible = File('${dossier.path}${Platform.pathSeparator}${nomFichierContratEnvoi(envoi)}');
  await File(chemin).copy(cible.path);
  await SharePlus.instance.share(
    ShareParams(
      files: [XFile(cible.path, mimeType: 'application/pdf')],
      subject: 'Contrat envoyé au syndic',
    ),
  );
}

/// « Voir le contrat » et « Télécharger ». Sans contrat joint (une
/// réservation supprimée, par exemple), seule la mention l'explique.
class ActionsContratEnvoi extends StatefulWidget {
  final EnvoiHistoriqueSyndic envoi;

  /// Version discrète, pour une carte de la liste.
  final bool compact;

  const ActionsContratEnvoi({super.key, required this.envoi, this.compact = false});

  @override
  State<ActionsContratEnvoi> createState() => _ActionsContratEnvoiState();
}

class _ActionsContratEnvoiState extends State<ActionsContratEnvoi> {
  /// « voir », « telecharger » ou null.
  String? _occupe;

  Future<void> _lancer(String action, Future<void> Function() travail) async {
    if (_occupe != null) return;
    setState(() => _occupe = action);
    try {
      await travail();
    } catch (ex) {
      if (!mounted) return;
      showToast(
        '',
        context,
        description: messageErreurSyndic(ex),
        type: ToastificationType.error,
        second: 3,
      );
    } finally {
      if (mounted) setState(() => _occupe = null);
    }
  }

  Widget _indicateur(double taille) => SizedBox(
    width: taille,
    height: taille,
    child: const CircularProgressIndicator(strokeWidth: 2),
  );

  @override
  Widget build(BuildContext context) {
    if (!widget.envoi.aUnContrat) {
      return Row(
        children: [
          Icon(Icons.description_outlined, size: 14, color: Colors.grey.shade500),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Contrat indisponible',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
            ),
          ),
        ],
      );
    }

    final voir = _occupe == 'voir';
    final telecharger = _occupe == 'telecharger';

    if (widget.compact) {
      // Un Wrap plutôt qu'une Row : sur un écran étroit, ou avec une
      // police agrandie, le second bouton passe à la ligne.
      return Wrap(
        spacing: 4,
        runSpacing: 2,
        children: [
          _BoutonPlat(
            icone: Icons.picture_as_pdf_outlined,
            texte: 'Voir le contrat',
            chargement: voir,
            onTap: _occupe != null
                ? null
                : () => _lancer('voir', () => voirContratEnvoiSyndic(context, widget.envoi)),
          ),
          _BoutonPlat(
            icone: Icons.download_outlined,
            texte: 'Télécharger',
            chargement: telecharger,
            onTap: _occupe != null
                ? null
                : () => _lancer('telecharger', () => enregistrerContratEnvoiSyndic(widget.envoi)),
          ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _occupe != null
                ? null
                : () => _lancer('voir', () => voirContratEnvoiSyndic(context, widget.envoi)),
            icon: voir ? _indicateur(16) : const Icon(Icons.picture_as_pdf_outlined, size: 18),
            label: const Text('Voir le contrat'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _occupe != null
                ? null
                : () => _lancer('telecharger', () => enregistrerContratEnvoiSyndic(widget.envoi)),
            icon: telecharger ? _indicateur(16) : const Icon(Icons.download_outlined, size: 18),
            label: const Text('Télécharger'),
          ),
        ),
      ],
    );
  }
}

class _BoutonPlat extends StatelessWidget {
  final IconData icone;
  final String texte;
  final bool chargement;
  final VoidCallback? onTap;

  const _BoutonPlat({
    required this.icone,
    required this.texte,
    required this.chargement,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final couleur = onTap == null ? Colors.grey.shade400 : AppColors.primaryColor;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (chargement)
              SizedBox(
                width: 13,
                height: 13,
                child: CircularProgressIndicator(strokeWidth: 2, color: couleur),
              )
            else
              Icon(icone, size: 15, color: couleur),
            const SizedBox(width: 5),
            Text(
              texte,
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: couleur),
            ),
          ],
        ),
      ),
    );
  }
}

/// Une pastille « icône + texte » : statut, source, information courte.
class PuceEnvoiSyndic extends StatelessWidget {
  final String texte;
  final Color couleur;
  final IconData? icone;

  /// Fond teinté (statut) ou simple contour (information secondaire).
  final bool plein;

  const PuceEnvoiSyndic({
    super.key,
    required this.texte,
    required this.couleur,
    this.icone,
    this.plein = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: plein ? couleur.withValues(alpha: .10) : Colors.transparent,
        border: plein ? null : Border.all(color: couleur.withValues(alpha: .35)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icone != null) ...[Icon(icone, size: 12, color: couleur), const SizedBox(width: 4)],
          // Flexible : un libellé inattendu du serveur se coupe au lieu
          // de déborder de la carte.
          Flexible(
            child: Text(
              texte,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: couleur),
            ),
          ),
        ],
      ),
    );
  }
}

// ── La feuille de détail ─────────────────────────────────────────────

/// Ouvre le detail d'un envoi. [onModifie] est appele apres un renvoi,
/// pour que la liste se mette a jour.
Future<void> ouvrirDetailEnvoiSyndic(
  BuildContext context,
  EnvoiHistoriqueSyndic envoi, {
  VoidCallback? onModifie,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _DetailEnvoi(envoi: envoi, onModifie: onModifie),
  );
}

class _DetailEnvoi extends StatefulWidget {
  final EnvoiHistoriqueSyndic envoi;
  final VoidCallback? onModifie;

  const _DetailEnvoi({required this.envoi, this.onModifie});

  @override
  State<_DetailEnvoi> createState() => _DetailEnvoiState();
}

class _DetailEnvoiState extends State<_DetailEnvoi> {
  late EnvoiHistoriqueSyndic _envoi = widget.envoi;
  bool _renvoi = false;

  Repository get _repository => Dependencies.get<Repository>();

  @override
  void initState() {
    super.initState();
    _actualiser();
  }

  /// La ligne de la liste suffit a l'affichage ; on la complete en silence.
  Future<void> _actualiser() async {
    try {
      final frais = await _repository.fetchEnvoiSyndic(widget.envoi.id);
      if (mounted) setState(() => _envoi = frais);
    } catch (_) {}
  }

  Future<void> _renvoyer() async {
    final destinataire = [
      if (_envoi.syndicNom != null) _envoi.syndicNom!,
      if (_envoi.telephone != null) _envoi.telephone!,
    ].join(' – ');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text(
          'Renvoyer le contrat ?',
          style: TextStyle(fontSize: 17, color: Color(0xFF17262E)),
        ),
        content: Text(
          'Le même contrat et le même message seront renvoyés par WhatsApp'
          '${destinataire.isEmpty ? '' : ' à $destinataire'}.',
          style: const TextStyle(fontSize: 14, color: Colors.black87),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Renvoyer'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _renvoi = true);
    try {
      final nouveau = await _repository.renvoyerEnvoiSyndic(_envoi.id);
      widget.onModifie?.call();
      if (!mounted) return;
      if (nouveau.statut == 'envoye') {
        showToast('Contrat renvoyé au syndic', context, second: 2);
        Navigator.of(context).pop();
      } else {
        setState(() {
          _renvoi = false;
          _envoi = nouveau;
        });
        showToast(
          '',
          context,
          description: nouveau.erreur ?? "Le renvoi n'a pas abouti.",
          type: ToastificationType.error,
          second: 3,
        );
      }
    } catch (ex) {
      // Un echec cote serveur laisse une trace dans l'historique
      widget.onModifie?.call();
      if (!mounted) return;
      setState(() => _renvoi = false);
      showToast(
        '',
        context,
        description: messageErreurSyndic(ex),
        type: ToastificationType.error,
        second: 3,
      );
    }
  }

  void _partager() {
    SharePlus.instance.share(
      ShareParams(text: texteDetailEnvoi(_envoi), subject: 'Envoi du contrat au syndic'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final e = _envoi;
    final r = e.reservation;
    final couleur = couleurStatutEnvoiHistorique(e.statut);
    final sejour = sejourEnvoi(r);
    final source = libelleSourceEnvoi(e);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: .85,
      minChildSize: .4,
      maxChildSize: .95,
      builder: (context, defilement) => Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFD5DDE2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Expanded(
            child: ListView(
              controller: defilement,
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(iconeStatutEnvoiHistorique(e.statut), color: couleur, size: 26),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            e.syndicNom ?? 'Syndic',
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF17262E),
                            ),
                          ),
                          if (e.date != null)
                            Text(
                              'Le ${dateHeureExport(e.date)}',
                              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    PuceEnvoiSyndic(
                      texte: libelleStatutEnvoiHistorique(e),
                      couleur: couleur,
                      icone: iconeStatutEnvoiHistorique(e.statut),
                    ),
                    if (source.isNotEmpty)
                      PuceEnvoiSyndic(
                        texte: source,
                        couleur: couleurSourceEnvoi(e.source),
                        icone: iconeSourceEnvoi(e.source),
                        plein: false,
                      ),
                    if (r != null && r.supprimee)
                      PuceEnvoiSyndic(
                        texte: 'Réservation supprimée',
                        couleur: Colors.grey.shade600,
                        icone: Icons.delete_outline,
                        plein: false,
                      ),
                  ],
                ),
                if (e.erreur != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: couleur.withValues(alpha: .08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.warning_amber_rounded, size: 17, color: couleur),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(e.erreur!, style: TextStyle(fontSize: 13, color: couleur)),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                _Info(icone: Icons.phone_outlined, libelle: 'Téléphone', valeur: e.telephone),
                _Info(icone: Icons.home_work_outlined, libelle: 'Bien', valeur: r?.bien),
                _Info(icone: Icons.person_outline, libelle: 'Client', valeur: r?.client),
                _Info(
                  icone: Icons.date_range_outlined,
                  libelle: 'Séjour',
                  valeur: sejour.isEmpty ? null : sejour,
                ),
                _Info(icone: Icons.badge_outlined, libelle: 'Envoyé par', valeur: e.envoyePar),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F8FA),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Contrat envoyé',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF17262E),
                        ),
                      ),
                      const SizedBox(height: 8),
                      ActionsContratEnvoi(envoi: e),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Message envoyé',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF17262E),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE7F7EE),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: SelectableText(
                    e.message ?? 'Aucun message enregistré pour cet envoi.',
                    style: TextStyle(
                      fontSize: 13.5,
                      height: 1.4,
                      color: e.message == null ? Colors.grey.shade600 : Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _partager,
                      icon: const Icon(Icons.share_outlined, size: 18),
                      label: const Text('Partager le détail'),
                    ),
                  ),
                  if (peutRenvoyerContratSyndic) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _renvoi ? null : _renvoyer,
                      icon: _renvoi
                          ? const SizedBox(
                              width: 17,
                              height: 17,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.replay, size: 18),
                      label: const Text('Renvoyer'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryColor,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.grey.shade400,
                        disabledForegroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                      ),
                    ),
                  ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Info extends StatelessWidget {
  final IconData icone;
  final String libelle;
  final String? valeur;

  const _Info({required this.icone, required this.libelle, this.valeur});

  @override
  Widget build(BuildContext context) {
    if ((valeur ?? '').isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icone, size: 18, color: Colors.grey.shade600),
          const SizedBox(width: 10),
          SizedBox(
            width: 92,
            child: Text(libelle, style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
          ),
          Expanded(
            child: Text(
              valeur!,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
