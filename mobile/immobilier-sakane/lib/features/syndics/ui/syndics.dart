import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:immobilier/components/bouton_export.dart';
import 'package:immobilier/components/entete_defilant.dart';
import 'package:immobilier/components/error_widget.dart';
import 'package:immobilier/components/loading_indicator.dart';
import 'package:immobilier/core/constants/app_colors.dart';
import 'package:immobilier/core/constants/app_strings.dart';
import 'package:immobilier/core/constants/enums/app_status.dart';
import 'package:immobilier/core/utils/show_toast.dart';
import 'package:immobilier/features/syndics/cubit/syndics_cubit.dart';
import 'package:immobilier/features/syndics/ui/components/syndic_commun.dart';
import 'package:immobilier/features/syndics/ui/historique_envois.dart';
import 'package:immobilier/models/syndic.dart';
import 'package:immobilier/routes.dart';
import 'package:toastification/toastification.dart';

/// Les syndics d'immeuble : chacun reçoit par WhatsApp le contrat public
/// de chaque nouvelle réservation, prolongation ou raccourcissement dans
/// l'un de ses biens.
class SyndicsPage extends StatefulWidget {
  const SyndicsPage({super.key});

  static Widget page() => BlocProvider(
        create: (_) => SyndicsCubit()..charger(),
        child: const SyndicsPage(),
      );

  @override
  State<SyndicsPage> createState() => _SyndicsPageState();
}

class _SyndicsPageState extends State<SyndicsPage> {
  final TextEditingController _recherche = TextEditingController();
  String _texte = '';

  @override
  void initState() {
    super.initState();
    _recherche.addListener(() {
      if (_recherche.text != _texte) setState(() => _texte = _recherche.text);
    });
  }

  @override
  void dispose() {
    _recherche.dispose();
    super.dispose();
  }

  List<Syndic> _filtrer(List<Syndic> tous) {
    final q = _texte.trim().toLowerCase();
    if (q.isEmpty) return tous;
    final chiffres = chiffresTelephone(q);
    return tous.where((s) {
      if (s.nom.toLowerCase().contains(q)) return true;
      if (chiffres.isNotEmpty && chiffresTelephone(s.telephone).contains(chiffres)) return true;
      return s.biens.any((b) => b.titre.toLowerCase().contains(q));
    }).toList();
  }

  TableauExportable? _tableauExport() {
    final tous = context.read<SyndicsCubit>().state.syndics;
    if (tous == null) return null;
    return TableauExportable(
      titre: 'Syndics',
      sousTitre: _texte.trim().isEmpty ? null : 'Recherche : ${_texte.trim()}',
      colonnes: const ['Nom', 'Téléphone', 'Biens', 'Actif', 'Dernier envoi'],
      lignes: _filtrer(tous)
          .map((s) => [
                s.nom,
                s.telephone,
                '${s.nombreBiens}',
                s.actif ? 'Oui' : 'Non',
                s.dernierEnvoi == null ? '' : resumeEnvoiSyndic(s.dernierEnvoi!),
              ])
          .toList(),
    );
  }

  Future<void> _nouveau() async {
    final cubit = context.read<SyndicsCubit>();
    final resultat = await GoRouter.of(context).push<Syndic>(Routes.syndicForm);
    if (resultat != null) cubit.charger(silencieux: true);
  }

  Future<void> _ouvrir(Syndic s) async {
    final cubit = context.read<SyndicsCubit>();
    await GoRouter.of(context).push(Routes.syndicDetail.replaceFirst(':id', '${s.id}'));
    // Modifié ou supprimé depuis la fiche : la liste suit.
    cubit.charger(silencieux: true);
  }

  @override
  Widget build(BuildContext context) {
    final admin = peutCreerSyndic;
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'Syndics',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        foregroundColor: Colors.white,
        backgroundColor: AppColors.primaryColor,
        elevation: 0,
        centerTitle: true,
        actions: [
          if (peutVoirHistoriqueSyndics)
          IconButton(
            tooltip: 'Historique des envois',
            icon: const Icon(Icons.history, color: Colors.white),
            onPressed: () => HistoriqueEnvoisPage.ouvrir(context),
          ),
          BoutonExport(tableau: _tableauExport),
        ],
      ),
      floatingActionButton: admin
          ? FloatingActionButton.extended(
              onPressed: _nouveau,
              backgroundColor: AppColors.primaryColor,
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('Nouveau syndic', style: TextStyle(color: Colors.white)),
            )
          : null,
      body: BlocConsumer<SyndicsCubit, SyndicsState>(
        listener: (context, state) {
          // Une liste déjà affichée reste : on signale seulement l'échec.
          if (state.fetchStatus == AppStatus.error && state.syndics != null) {
            showToast('', context,
                description: state.error ?? "Actualisation impossible",
                type: ToastificationType.error,
                second: 3);
          }
        },
        builder: (context, state) {
          final cubit = context.read<SyndicsCubit>();
          if (state.syndics == null) {
            if (state.fetchStatus == AppStatus.error) {
              return MyErrorWidget(
                error: state.error ?? 'Erreur',
                action: AppStrings.tryAgain,
                actionCLick: () => cubit.charger(),
              );
            }
            return Center(child: MyLoadingIndicator());
          }

          final tous = state.syndics!;
          final liste = _filtrer(tous);

          return PageAEnTeteDefilant(
            entete: [
              if (tous.isNotEmpty) _barreRecherche(),
              if (tous.isNotEmpty) _explication(),
            ],
            corps: RefreshIndicator(
              onRefresh: () => cubit.charger(silencieux: true),
              child: tous.isEmpty
                  ? _vide(admin)
                  : liste.isEmpty
                      ? _aucunResultat()
                      : ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(14, 8, 14, 96),
                          itemCount: liste.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (context, i) => _carte(liste[i]),
                        ),
            ),
          );
        },
      ),
    );
  }

  Widget _barreRecherche() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      child: TextField(
        controller: _recherche,
        style: const TextStyle(color: Colors.black87),
        decoration: InputDecoration(
          hintText: 'Nom, téléphone ou bien…',
          hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade500),
          prefixIcon: Icon(Icons.search, color: Colors.grey.shade500),
          suffixIcon: _texte.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.clear, color: Colors.grey.shade500),
                  onPressed: () => _recherche.clear(),
                )
              : null,
          filled: true,
          fillColor: Colors.grey.shade100,
          contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _explication() {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 16, color: Colors.grey.shade600),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Le syndic reçoit le contrat à chaque nouvelle réservation, prolongation ou '
              'raccourcissement dans ses biens.',
              style: TextStyle(fontSize: 12, height: 1.35, color: Colors.grey.shade600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _vide(bool admin) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(28, 60, 28, 40),
      children: [
        Center(
          child: Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              color: AppColors.primaryColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.apartment, size: 42, color: AppColors.primaryColor),
          ),
        ),
        const SizedBox(height: 18),
        const Text(
          'Aucun syndic pour le moment',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF17262E)),
        ),
        const SizedBox(height: 10),
        Text(
          "Un syndic gère un immeuble où se trouvent certains de vos biens. "
          "Le syndic reçoit le contrat à chaque nouvelle réservation, prolongation ou "
          "raccourcissement dans ses biens.",
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13.5, height: 1.4, color: Colors.grey.shade700),
        ),
        if (admin) ...[
          const SizedBox(height: 10),
          Text(
            'Appuyez sur « Nouveau syndic » pour en ajouter un et choisir ses biens.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600),
          ),
        ],
      ],
    );
  }

  Widget _aucunResultat() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(28, 60, 28, 40),
      children: [
        Icon(Icons.search_off, size: 48, color: Colors.grey.shade400),
        const SizedBox(height: 12),
        Text(
          'Aucun syndic ne correspond à « ${_texte.trim()} ».',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
        ),
      ],
    );
  }

  Widget _carte(Syndic s) {
    final envoi = s.dernierEnvoi;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _ouvrir(s),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: AppColors.primaryColor.withValues(alpha: 0.1),
                child: Icon(Icons.apartment, color: AppColors.primaryColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            s.nom,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF17262E)),
                          ),
                        ),
                        const SizedBox(width: 6),
                        EtiquetteActifSyndic(actif: s.actif),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.phone_outlined, size: 14, color: Colors.grey.shade600),
                        const SizedBox(width: 4),
                        Text(s.telephone,
                            style: TextStyle(fontSize: 13, color: Colors.grey.shade800)),
                        const SizedBox(width: 14),
                        Icon(Icons.home_work_outlined, size: 14, color: Colors.grey.shade600),
                        const SizedBox(width: 4),
                        Text(
                          '${s.nombreBiens} bien${s.nombreBiens > 1 ? 's' : ''}',
                          style: TextStyle(fontSize: 13, color: Colors.grey.shade800),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    if (envoi == null)
                      Text('Aucun envoi pour le moment',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade500))
                    else
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(iconeStatutEnvoi(envoi.statut),
                              size: 14, color: couleurStatutEnvoi(envoi.statut)),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              resumeEnvoiSyndic(envoi),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 12, color: couleurStatutEnvoi(envoi.statut)),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }
}
