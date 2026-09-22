import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:immobilier/components/bouton_export.dart';
import 'package:immobilier/components/error_widget.dart';
import 'package:immobilier/components/loading_indicator.dart';
import 'package:immobilier/core/constants/app_colors.dart';
import 'package:immobilier/core/constants/app_strings.dart';
import 'package:immobilier/core/constants/enums/app_status.dart';
import 'package:immobilier/core/utils/show_toast.dart';
import 'package:immobilier/features/syndics/cubit/historique_envois_cubit.dart';
import 'package:immobilier/features/syndics/ui/components/detail_envoi_syndic.dart';
import 'package:immobilier/features/syndics/ui/components/syndic_commun.dart';
import 'package:immobilier/models/envoi_historique_syndic.dart';
import 'package:immobilier/models/syndic.dart';
import 'package:open_file/open_file.dart';
import 'package:share_plus/share_plus.dart';
import 'package:toastification/toastification.dart';

const _encre = Color(0xFF17262E);
const _grisTexte = Color(0xFF6B7B84);
const _fondPage = Color(0xFFF2F5F7);

/// Historique des envois du contrat aux syndics : par mois, puis par
/// jour, avec le message envoyé, le contrat joint et la possibilité de
/// renvoyer.
class HistoriqueEnvoisPage extends StatefulWidget {
  /// Le syndic de la fiche d'où l'on vient : la liste lui est limitée.
  final Syndic? syndic;

  const HistoriqueEnvoisPage({super.key, this.syndic});

  static Future<void> ouvrir(BuildContext context, {Syndic? syndic}) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BlocProvider(
          create: (_) => HistoriqueEnvoisCubit(syndicId: syndic?.id)..demarrer(),
          child: HistoriqueEnvoisPage(syndic: syndic),
        ),
      ),
    );
  }

  @override
  State<HistoriqueEnvoisPage> createState() => _HistoriqueEnvoisPageState();
}

class _HistoriqueEnvoisPageState extends State<HistoriqueEnvoisPage> {
  /// Les mois repliés, par clé « AAAA-MM ».
  final Set<String> _replies = {};

  static const _periodes = {
    PeriodeEnvois.recent: 'Récents',
    PeriodeEnvois.ceMois: 'Ce mois',
    PeriodeEnvois.moisDernier: 'Mois dernier',
    PeriodeEnvois.troisMois: '3 derniers mois',
    PeriodeEnvois.personnalisee: 'Personnalisée',
  };

  static const _statuts = {'envoye': 'Envoyés', 'echec': 'Échecs', 'ignore': 'Non envoyés'};

  Future<void> _choisirPeriode(PeriodeEnvois periode) async {
    final cubit = context.read<HistoriqueEnvoisCubit>();
    if (periode != PeriodeEnvois.personnalisee) {
      cubit.choisirPeriode(periode);
      return;
    }
    final maintenant = DateTime.now();
    final aujourdHui = DateTime(maintenant.year, maintenant.month, maintenant.day);
    final actuelle = cubit.state.plage;
    // Une plage venue du serveur peut dépasser aujourd'hui : le
    // sélecteur refuserait de s'ouvrir avec une borne hors limites.
    final initiale = DateTimeRange(
      start: actuelle.start.isAfter(aujourdHui) ? aujourdHui : actuelle.start,
      end: actuelle.end.isAfter(aujourdHui) ? aujourdHui : actuelle.end,
    );
    final plage = await showDateRangePicker(
      context: context,
      firstDate: DateTime(maintenant.year - 5),
      lastDate: aujourdHui,
      initialDateRange: initiale.end.isBefore(initiale.start) ? null : initiale,
      helpText: 'Période des envois',
      saveText: 'Valider',
    );
    if (plage != null) cubit.choisirPeriode(PeriodeEnvois.personnalisee, plage: plage);
  }

  void _ouvrirEnvoi(EnvoiHistoriqueSyndic envoi) {
    final cubit = context.read<HistoriqueEnvoisCubit>();
    ouvrirDetailEnvoiSyndic(context, envoi, onModifie: () => cubit.charger(silencieux: true));
  }

  Future<void> _telecharger() async {
    final cubit = context.read<HistoriqueEnvoisCubit>();
    final messager = ScaffoldMessenger.of(context);
    final navigateur = Navigator.of(context, rootNavigator: true);

    final format = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (feuille) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Télécharger l\'historique',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: _encre),
              ),
              const SizedBox(height: 4),
              Text(
                _resumeFiltres(cubit.state),
                style: const TextStyle(fontSize: 12.5, color: _grisTexte),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _ChoixFormat(
                      icone: Icons.table_chart_outlined,
                      titre: 'Excel',
                      detail: 'Tableur .xlsx',
                      couleur: const Color(0xFF1E7B45),
                      onTap: () => Navigator.of(feuille).pop('xlsx'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ChoixFormat(
                      icone: Icons.picture_as_pdf_outlined,
                      titre: 'PDF',
                      detail: 'Document à imprimer',
                      couleur: const Color(0xFFB3261E),
                      onTap: () => Navigator.of(feuille).pop('pdf'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (format == null || !mounted) return;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(
          children: [
            SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5)),
            SizedBox(width: 16),
            Expanded(child: Text('Préparation du fichier…')),
          ],
        ),
      ),
    );

    try {
      final chemin = await cubit.exporter(format);
      navigateur.pop();

      final ouverture = await OpenFile.open(chemin);
      final message = messager.showSnackBar(
        SnackBar(
          content: Text(
            ouverture.type == ResultType.done
                ? 'Fichier ${format == 'pdf' ? 'PDF' : 'Excel'} prêt.'
                : 'Aucune application pour ouvrir ce fichier : partagez-le.',
          ),
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'Partager',
            onPressed: () => SharePlus.instance.share(ShareParams(files: [XFile(chemin)])),
          ),
        ),
      );
      // Un message qui porte un bouton reste affiche : on le retire nous-memes
      Future.delayed(const Duration(seconds: 5), () {
        try {
          message.close();
        } catch (_) {}
      });
    } catch (ex) {
      navigateur.pop();
      messager.showSnackBar(SnackBar(content: Text(messageErreurSyndic(ex))));
    }
  }

  String _resumeFiltres(HistoriqueEnvoisState s) {
    final morceaux = <String>[
      _periodeTexte(s),
      if (s.syndicId != null) _nomSyndic(s) ?? 'Syndic',
      if (s.statut != null) _statuts[s.statut] ?? s.statut!,
    ];
    return morceaux.join(' • ');
  }

  /// La période effectivement affichée : celle que le serveur renvoie
  /// quand c'est lui qui la choisit.
  String _periodeTexte(HistoriqueEnvoisState s) =>
      'Du ${dateExport(s.plage.start)} au ${dateExport(s.plage.end)}';

  String? _nomSyndic(HistoriqueEnvoisState s) {
    for (final syndic in s.syndics) {
      if (syndic.id == s.syndicId) return syndic.nom;
    }
    return widget.syndic?.id == s.syndicId ? widget.syndic?.nom : null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _fondPage,
      appBar: AppBar(
        title: Column(
          children: [
            const Text(
              'Historique des envois',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
            ),
            if (widget.syndic != null)
              Text(
                widget.syndic!.nom,
                style: const TextStyle(fontSize: 12.5, color: Colors.white70),
              ),
          ],
        ),
        foregroundColor: Colors.white,
        backgroundColor: AppColors.primaryColor,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Télécharger (PDF / Excel)',
            icon: const Icon(Icons.file_download_outlined, color: Colors.white),
            onPressed: _telecharger,
          ),
        ],
      ),
      body: BlocConsumer<HistoriqueEnvoisCubit, HistoriqueEnvoisState>(
        listener: (context, state) {
          // Une liste deja affichee reste : on signale seulement l'echec
          if (state.fetchStatus == AppStatus.error && state.historique != null) {
            showToast(
              '',
              context,
              description: state.error ?? 'Actualisation impossible',
              type: ToastificationType.error,
              second: 3,
            );
          }
        },
        builder: (context, state) {
          final cubit = context.read<HistoriqueEnvoisCubit>();
          final historique = state.historique;

          if (historique == null) {
            if (state.fetchStatus == AppStatus.error) {
              return Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: MyErrorWidget(
                    error: state.error ?? "L'historique n'a pas pu être chargé.",
                    action: AppStrings.tryAgain,
                    actionCLick: () => cubit.charger(),
                  ),
                ),
              );
            }
            return Center(child: MyLoadingIndicator());
          }

          return RefreshIndicator(
            color: AppColors.primaryColor,
            onRefresh: () => cubit.charger(silencieux: true),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 34),
              children: [
                _enTete(state, historique),
                if (state.fetchStatus == AppStatus.loading)
                  const LinearProgressIndicator(minHeight: 2)
                else
                  const SizedBox(height: 2),
                if (state.fetchStatus == AppStatus.error) _bandeauErreur(state, cubit),
                if (state.vide)
                  _vide(state, cubit)
                else
                  for (final mois in historique.mois) ..._mois(mois),
              ],
            ),
          );
        },
      ),
    );
  }

  // ── En-tête : période, filtres, compteurs ──────────────────────────

  Widget _enTete(HistoriqueEnvoisState s, HistoriqueEnvoisSyndic h) {
    final cubit = context.read<HistoriqueEnvoisCubit>();
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.event_note_outlined, size: 16, color: AppColors.primaryColor),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _periodeTexte(s),
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _encre),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final p in _periodes.entries) ...[
                  ChoiceChip(
                    label: Text(p.value),
                    selected: s.periode == p.key,
                    showCheckmark: false,
                    backgroundColor: const Color(0xFFF2F5F7),
                    selectedColor: AppColors.primaryColor.withValues(alpha: .14),
                    side: BorderSide(
                      color: s.periode == p.key
                          ? AppColors.primaryColor.withValues(alpha: .45)
                          : Colors.grey.shade300,
                    ),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    labelStyle: TextStyle(
                      fontSize: 12.5,
                      color: s.periode == p.key ? AppColors.primaryColor : Colors.black87,
                      fontWeight: s.periode == p.key ? FontWeight.bold : FontWeight.normal,
                    ),
                    avatar: p.key == PeriodeEnvois.personnalisee
                        ? Icon(
                            Icons.date_range,
                            size: 15,
                            color: s.periode == p.key
                                ? AppColors.primaryColor
                                : Colors.grey.shade700,
                          )
                        : null,
                    onSelected: (_) => _choisirPeriode(p.key),
                  ),
                  const SizedBox(width: 6),
                ],
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _listeSyndics(s)),
              const SizedBox(width: 10),
              Expanded(
                child: _liste<String?>(
                  valeur: s.statut,
                  icone: Icons.filter_list,
                  elements: [
                    const DropdownMenuItem(value: null, child: Text('Tous les statuts')),
                    for (final st in _statuts.entries)
                      DropdownMenuItem(value: st.key, child: Text(st.value)),
                  ],
                  onChanged: cubit.choisirStatut,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _PuceStat(
                  libelle: 'Total',
                  valeur: h.totalAffiche,
                  couleur: AppColors.primaryColor,
                  active: s.statut == null,
                  onTap: () => cubit.choisirStatut(null),
                ),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: _PuceStat(
                  libelle: 'Envoyés',
                  valeur: h.envoyes,
                  couleur: couleurStatutEnvoiHistorique('envoye'),
                  active: s.statut == 'envoye',
                  onTap: () => cubit.choisirStatut(s.statut == 'envoye' ? null : 'envoye'),
                ),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: _PuceStat(
                  libelle: 'Échecs',
                  valeur: h.echecs,
                  couleur: couleurStatutEnvoiHistorique('echec'),
                  active: s.statut == 'echec',
                  onTap: () => cubit.choisirStatut(s.statut == 'echec' ? null : 'echec'),
                ),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: _PuceStat(
                  libelle: 'Non envoyés',
                  valeur: h.ignores,
                  couleur: couleurStatutEnvoiHistorique('ignore'),
                  active: s.statut == 'ignore',
                  onTap: () => cubit.choisirStatut(s.statut == 'ignore' ? null : 'ignore'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _bandeauErreur(HistoriqueEnvoisState s, HistoriqueEnvoisCubit cubit) {
    const rouge = Color(0xFFB3261E);
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 12, 14, 0),
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        color: rouge.withValues(alpha: .07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: rouge.withValues(alpha: .25)),
      ),
      child: Row(
        children: [
          const Icon(Icons.wifi_off_outlined, size: 18, color: rouge),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              s.error ?? "L'historique n'a pas pu être actualisé.",
              style: const TextStyle(fontSize: 12.5, color: rouge),
            ),
          ),
          TextButton(
            onPressed: () => cubit.charger(),
            style: TextButton.styleFrom(
              foregroundColor: rouge,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              minimumSize: const Size(0, 34),
            ),
            child: const Text(AppStrings.tryAgain, style: TextStyle(fontSize: 12.5)),
          ),
        ],
      ),
    );
  }

  Widget _listeSyndics(HistoriqueEnvoisState s) {
    final cubit = context.read<HistoriqueEnvoisCubit>();
    final syndics = [...s.syndics];
    // Tant que la liste n'est pas chargee, le syndic de la fiche reste choisi
    if (widget.syndic != null && !syndics.any((x) => x.id == widget.syndic!.id)) {
      syndics.insert(0, widget.syndic!);
    }
    final valeur = syndics.any((x) => x.id == s.syndicId) ? s.syndicId : null;
    return _liste<int?>(
      valeur: valeur,
      icone: Icons.apartment,
      elements: [
        const DropdownMenuItem(value: null, child: Text('Tous les syndics')),
        for (final x in syndics)
          DropdownMenuItem(
            value: x.id,
            child: Text(x.nom, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: cubit.choisirSyndic,
    );
  }

  Widget _liste<T>({
    required T valeur,
    required IconData icone,
    required List<DropdownMenuItem<T>> elements,
    required ValueChanged<T?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F5F7),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Icon(icone, size: 17, color: Colors.grey.shade600),
          const SizedBox(width: 6),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<T>(
                value: valeur,
                isExpanded: true,
                isDense: false,
                dropdownColor: Colors.white,
                style: const TextStyle(fontSize: 13, color: Colors.black87),
                items: elements,
                onChanged: onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Liste ──────────────────────────────────────────────────────────

  Widget _vide(HistoriqueEnvoisState s, HistoriqueEnvoisCubit cubit) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 46, 28, 40),
      child: Column(
        children: [
          Icon(Icons.history, size: 48, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text(
            s.filtre
                ? 'Aucun envoi ne correspond aux filtres choisis.'
                : 'Aucun envoi sur cette période.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
          ),
          if (s.filtre) ...[
            const SizedBox(height: 10),
            TextButton.icon(
              onPressed: () => cubit.reinitialiserFiltres(garderSyndic: widget.syndic != null),
              icon: const Icon(Icons.filter_alt_off_outlined, size: 18),
              label: const Text('Retirer les filtres'),
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _mois(MoisEnvoisSyndic mois) {
    final replie = _replies.contains(mois.mois);
    final details = <String>[
      '${mois.total} envoi${mois.total > 1 ? 's' : ''}',
      if (mois.envoyes > 0) '${mois.envoyes} envoyé${mois.envoyes > 1 ? 's' : ''}',
      if (mois.echecs > 0) '${mois.echecs} échec${mois.echecs > 1 ? 's' : ''}',
    ];
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 16, 14, 2),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () =>
                setState(() => replie ? _replies.remove(mois.mois) : _replies.add(mois.mois)),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          mois.libelle,
                          style: const TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.bold,
                            color: _encre,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          details.join(' • '),
                          style: const TextStyle(fontSize: 12, color: _grisTexte),
                        ),
                      ],
                    ),
                  ),
                  if (mois.echecs > 0)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: PuceEnvoiSyndic(
                        texte: '${mois.echecs}',
                        couleur: couleurStatutEnvoiHistorique('echec'),
                        icone: Icons.error_outline,
                      ),
                    ),
                  Icon(replie ? Icons.expand_more : Icons.expand_less, color: Colors.grey.shade600),
                ],
              ),
            ),
          ),
        ),
      ),
      if (!replie)
        for (final jour in mois.jours) ..._jour(jour),
    ];
  }

  List<Widget> _jour(JourEnvoisSyndic jour) {
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
        child: Row(
          children: [
            Icon(Icons.today_outlined, size: 14, color: AppColors.primaryColor),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                jour.libelle,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade800,
                ),
              ),
            ),
            Text(
              '${jour.total} envoi${jour.total > 1 ? 's' : ''}',
              style: const TextStyle(fontSize: 11.5, color: _grisTexte),
            ),
          ],
        ),
      ),
      for (final envoi in jour.envois)
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
          child: _CarteEnvoi(envoi: envoi, onOuvrir: () => _ouvrirEnvoi(envoi)),
        ),
    ];
  }
}

// ── Une carte d'envoi ────────────────────────────────────────────────

class _CarteEnvoi extends StatefulWidget {
  final EnvoiHistoriqueSyndic envoi;
  final VoidCallback onOuvrir;

  const _CarteEnvoi({required this.envoi, required this.onOuvrir});

  @override
  State<_CarteEnvoi> createState() => _CarteEnvoiState();
}

class _CarteEnvoiState extends State<_CarteEnvoi> {
  bool _message = false;

  @override
  Widget build(BuildContext context) {
    final e = widget.envoi;
    final r = e.reservation;
    final couleur = couleurStatutEnvoiHistorique(e.statut);
    final source = libelleSourceEnvoi(e);
    final sejour = sejourEnvoi(r);
    final heure = heureEnvoi(e.date);
    final message = e.message;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
              onTap: widget.onOuvrir,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 11, 12, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                e.syndicNom ?? 'Syndic',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.bold,
                                  color: _encre,
                                ),
                              ),
                              if (e.telephone != null) ...[
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.phone_outlined,
                                      size: 13,
                                      color: Colors.grey.shade600,
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        e.telephone!,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 12.5, color: _grisTexte),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 132),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              PuceEnvoiSyndic(
                                texte: libelleStatutEnvoiHistorique(e),
                                couleur: couleur,
                                icone: iconeStatutEnvoiHistorique(e.statut),
                              ),
                              if (heure.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  heure,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: _grisTexte,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (r?.bien != null || r?.client != null || sejour.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      if (r?.bien != null)
                        _LigneInfo(icone: Icons.home_work_outlined, texte: r!.bien!),
                      if (r?.client != null)
                        _LigneInfo(icone: Icons.person_outline, texte: r!.client!),
                      if (sejour.isNotEmpty)
                        _LigneInfo(icone: Icons.date_range_outlined, texte: sejour),
                    ],
                    if (source.isNotEmpty || e.envoyePar != null || (r?.supprimee ?? false)) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (source.isNotEmpty)
                            PuceEnvoiSyndic(
                              texte: source,
                              couleur: couleurSourceEnvoi(e.source),
                              icone: iconeSourceEnvoi(e.source),
                              plein: false,
                            ),
                          if (e.envoyePar != null)
                            PuceEnvoiSyndic(
                              texte: e.envoyePar!,
                              couleur: Colors.grey.shade600,
                              icone: Icons.badge_outlined,
                              plein: false,
                            ),
                          if (r?.supprimee ?? false)
                            PuceEnvoiSyndic(
                              texte: 'Réservation supprimée',
                              couleur: Colors.grey.shade600,
                              icone: Icons.delete_outline,
                              plein: false,
                            ),
                        ],
                      ),
                    ],
                    if (e.erreur != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: couleur.withValues(alpha: .07),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.warning_amber_rounded, size: 15, color: couleur),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                e.erreur!,
                                style: TextStyle(fontSize: 12, color: couleur),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          if (message != null) ...[
            InkWell(
              onTap: () => setState(() => _message = !_message),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 2, 12, 6),
                child: Row(
                  children: [
                    Icon(
                      _message ? Icons.expand_less : Icons.chat_bubble_outline,
                      size: 15,
                      color: AppColors.primaryColor,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _message ? 'Masquer le message' : 'Voir le message',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primaryColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_message)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE7F7EE),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: SelectableText(
                    message,
                    style: const TextStyle(fontSize: 12.5, height: 1.4, color: Colors.black87),
                  ),
                ),
              ),
          ],
          Divider(height: 1, color: Colors.grey.shade200),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
            child: ActionsContratEnvoi(envoi: e, compact: true),
          ),
        ],
      ),
    );
  }
}

class _LigneInfo extends StatelessWidget {
  final IconData icone;
  final String texte;

  const _LigneInfo({required this.icone, required this.texte});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icone, size: 14, color: Colors.grey.shade600),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              texte,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12.5, color: Colors.grey.shade800),
            ),
          ),
        ],
      ),
    );
  }
}

/// Un compteur de l'en-tête, qui filtre la liste quand on l'effleure.
class _PuceStat extends StatelessWidget {
  final String libelle;
  final int valeur;
  final Color couleur;
  final bool active;
  final VoidCallback onTap;

  const _PuceStat({
    required this.libelle,
    required this.valeur,
    required this.couleur,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? couleur.withValues(alpha: .10) : const Color(0xFFF2F5F7),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: active ? couleur.withValues(alpha: .45) : Colors.grey.shade200,
            ),
          ),
          child: Column(
            children: [
              Text(
                '$valeur',
                maxLines: 1,
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: couleur),
              ),
              const SizedBox(height: 1),
              Text(
                libelle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 10.5, color: _grisTexte),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChoixFormat extends StatelessWidget {
  final IconData icone;
  final String titre;
  final String detail;
  final Color couleur;
  final VoidCallback onTap;

  const _ChoixFormat({
    required this.icone,
    required this.titre,
    required this.detail,
    required this.couleur,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: couleur.withValues(alpha: .07),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
          decoration: BoxDecoration(
            border: Border.all(color: couleur.withValues(alpha: .25)),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Icon(icone, size: 32, color: couleur),
              const SizedBox(height: 8),
              Text(
                titre,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: couleur),
              ),
              const SizedBox(height: 2),
              Text(
                detail,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 11.5, color: Color(0xFF4A5B64)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
