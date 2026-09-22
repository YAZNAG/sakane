import 'package:immobilier/components/bouton_export.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:immobilier/components/error_widget.dart';
import 'package:immobilier/components/loading_indicator.dart';
import 'package:immobilier/core/constants/app_colors.dart';
import 'package:immobilier/core/constants/app_strings.dart';
import 'package:immobilier/core/constants/enums/app_status.dart';
import 'package:immobilier/core/constants/enums/permissions.dart';
import 'package:immobilier/core/dependencies/dependencies.dart';
import 'package:immobilier/core/utils/show_dialogue_question.dart';
import 'package:immobilier/core/utils/show_toast.dart';
import 'package:immobilier/features/reclamations/reclamations_list/cubit/reclamations_cubit.dart';
import 'package:immobilier/models/manager.dart';
import 'package:immobilier/models/media.dart';
import 'package:immobilier/models/reclamation.dart';
import 'package:toastification/toastification.dart';
import 'package:immobilier/components/images_galery.dart';

class ReclamationsListPage extends StatefulWidget {
  const ReclamationsListPage({Key? key}) : super(key: key);

  static Widget page({int? realestateId}) {
    return BlocProvider<ReclamationsCubit>(
      create: (_) => ReclamationsCubit()..fetchReclamations(realestateId: realestateId),
      child: const ReclamationsListPage(),
    );
  }

  @override
  State<ReclamationsListPage> createState() => _ReclamationsListPageState();
}

class _ReclamationsListPageState extends State<ReclamationsListPage>
    with SingleTickerProviderStateMixin {

  TableauExportable? _tableauExport() {
    final liste = context.read<ReclamationsCubit>().state.reclamations;
    if (liste == null) return null;
    return TableauExportable(
      titre: 'Réclamations',
      colonnes: const ['N°', 'Date', 'Bien', 'Réclamation', 'Statut', 'Signalée par', 'Photos'],
      lignes: liste
          .map((r) => [
                '${r.id ?? ''}',
                r.createdAt ?? '',
                r.realestateName ?? '',
                r.note ?? '',
                r.status == 'resolved' ? 'Résolue' : 'En attente',
                r.signaledBy ?? '',
                '${r.images?.length ?? 0}',
              ])
          .toList(),
    );
  }

  late TabController _tabController;
  final Manager _manager = Dependencies.get<Manager>();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          "Réclamations",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        centerTitle: true,
        elevation: 0,
        foregroundColor: Colors.white,
        backgroundColor: AppColors.primaryColor,
        actions: [BoutonExport(tableau: _tableauExport)],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(text: "En attente"),
            Tab(text: "Résolues"),
          ],
        ),
      ),
      body: BlocConsumer<ReclamationsCubit, ReclamationsState>(
        listener: _listener,
        builder: (context, state) {
          if (state.fetchStatus == AppStatus.loading) {
            return Center(child: MyLoadingIndicator());
          }
          if (state.fetchStatus == AppStatus.error) {
            return MyErrorWidget(
              error: state.error ?? "Erreur",
              action: AppStrings.tryAgain,
              actionCLick: () => context.read<ReclamationsCubit>().fetchReclamations(realestateId: state.realestateId),
            );
          }
          if (state.fetchStatus == AppStatus.success) {
            final all = state.reclamations ?? [];
            final pending = all.where((r) => r.isPending).toList();
            final resolved = all.where((r) => r.isResolved).toList();

            return TabBarView(
              controller: _tabController,
              children: [
                _buildList(pending, state, isPending: true),
                _buildList(resolved, state, isPending: false),
              ],
            );
          }
          return const SizedBox();
        },
      ),
    );
  }

  Widget _buildList(List<Reclamation> items, ReclamationsState state, {required bool isPending}) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isPending ? Icons.check_circle_outline : Icons.history,
              size: 64,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 12),
            Text(
              isPending ? "Aucune réclamation en attente" : "Aucune réclamation résolue",
              style: TextStyle(fontSize: 15, color: Colors.grey.shade500),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async => context.read<ReclamationsCubit>().fetchReclamations(
            realestateId: context.read<ReclamationsCubit>().state.realestateId),
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, i) => _buildCard(items[i], state),
      ),
    );
  }

  Widget _buildCard(Reclamation reclamation, ReclamationsState state) {
    final isResolving = state.resolvingId == reclamation.id &&
        state.resolveStatus == AppStatus.loading;
    final isPending = reclamation.isPending;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isPending ? Colors.orange.shade200 : Colors.green.shade200,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(color: Color.fromRGBO(0, 0, 0, 0.05), blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isPending ? Colors.orange.shade50 : Colors.green.shade50,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Icon(
                  isPending ? Icons.pending_outlined : Icons.check_circle_outline,
                  size: 18,
                  color: isPending ? Colors.orange.shade700 : Colors.green.shade700,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    reclamation.realestateName ?? "Propriété #${reclamation.realestateId}",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isPending ? Colors.orange.shade100 : Colors.green.shade100,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isPending ? "En attente" : "Résolue",
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isPending ? Colors.orange.shade800 : Colors.green.shade800,
                    ),
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Date
                if (reclamation.createdAt != null)
                  Row(
                    children: [
                      Icon(Icons.access_time, size: 14, color: Colors.grey.shade500),
                      const SizedBox(width: 4),
                      Text(
                        _formatDate(reclamation.createdAt!),
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                      ),
                    ],
                  ),

                // Note
                if (reclamation.note != null && reclamation.note!.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    reclamation.note!,
                    style: const TextStyle(fontSize: 14, color: Colors.black87),
                  ),
                ] else ...[
                  const SizedBox(height: 10),
                  Text(
                    "Aucune description",
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade400, fontStyle: FontStyle.italic),
                  ),
                ],

                // Qui a signale la reclamation
                if (reclamation.signaledBy?.isNotEmpty == true) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(Icons.person_outline,
                          size: 15, color: Colors.grey.shade600),
                      const SizedBox(width: 5),
                      Text(
                        "Signalée par ",
                        style: TextStyle(
                            fontSize: 12.5, color: Colors.grey.shade600),
                      ),
                      Expanded(
                        child: Text(
                          reclamation.signaledBy!,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],

                // Images
                if (reclamation.images?.isNotEmpty == true) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 80,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: reclamation.images!.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (_, i) => _buildImageThumb(
                          reclamation.images![i], reclamation.images!, i),
                    ),
                  ),
                ],

                // Resolve button
                if (isPending && _manager.can(AppPermission.closeReclamation)) ...[
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: isResolving ? null : () => _onResolve(reclamation),
                      icon: isResolving
                          ? const SizedBox(
                              height: 16, width: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white)),
                            )
                          : const Icon(Icons.check, size: 18, color: Colors.white),
                      label: Text(
                        isResolving ? "En cours..." : "Marquer comme résolue",
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade600,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageThumb(Media media, List<Media> toutes, int index) {
    return GestureDetector(
      // ouvre la galerie plein ecran, navigation entre toutes les photos
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ImagesGalery(medias: toutes, index: index),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          media.url ?? '',
          width: 80,
          height: 80,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            width: 80,
            height: 80,
            color: Colors.grey.shade200,
            child: Icon(Icons.broken_image, color: Colors.grey.shade400),
          ),
        ),
      ),
    );
  }

  void _showFullImage(String url) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: InteractiveViewer(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(url, fit: BoxFit.contain),
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(String isoDate) {
    try {
      final dt = DateTime.parse(isoDate).toLocal();
      return "${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} "
          "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
    } catch (_) {
      return isoDate;
    }
  }

  void _onResolve(Reclamation reclamation)async {
    var result=await showDialogueQuestion(context, "Voulez-vous marquer cette réclamation comme résolue ?");
    if(result!=null && result){
      context.read<ReclamationsCubit>().resolveReclamation(reclamation.id!);
    }
  }

  void _listener(BuildContext context, ReclamationsState state) {
    if (state.resolveStatus == AppStatus.success) {
      // Switch to "Résolues" tab after resolving
      _tabController.animateTo(1);
    } else if (state.resolveStatus == AppStatus.error) {
      showToast("", description: state.error ?? "Erreur", context,
          type: ToastificationType.error, second: 2);
    }
  }
}
