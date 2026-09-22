import 'package:immobilier/components/entete_defilant.dart';
import 'package:immobilier/components/bouton_export.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:immobilier/components/error_widget.dart';
import 'package:immobilier/components/loading_indicator.dart';
import 'package:immobilier/core/constants/app_strings.dart';
import 'package:immobilier/core/constants/enums/app_status.dart';
import 'package:immobilier/core/constants/enums/permissions.dart';
import 'package:immobilier/core/dependencies/dependencies.dart';
import 'package:immobilier/core/utils/show_dialogue_question.dart';
import 'package:immobilier/core/utils/show_toast.dart';
import 'package:immobilier/models/manager.dart';
import 'package:immobilier/models/owner.dart';
import 'package:toastification/toastification.dart';
import 'package:immobilier/core/constants/app_colors.dart';
import '../../../../routes.dart';
import '../cubit/owners_cubit.dart';

class OwnersPage extends StatefulWidget {
  OwnersPage({Key? key}) : super(key: key);

  static Widget page() => BlocProvider(
    create: (ctx) => OwnersCubit()..fetchData(),
    child: OwnersPage(),
  );

  @override
  State<OwnersPage> createState() => _OwnersPageState();
}

class _OwnersPageState extends State<OwnersPage> {

  TableauExportable? _tableauExport() {
    final liste = context.read<OwnersCubit>().state.publicOwners;
    if (liste == null) return null;
    return TableauExportable(
      titre: 'Propriétaires',
      colonnes: const ['N°', 'Nom', 'Téléphone', 'E-mail', 'Adresse', 'Biens'],
      lignes: liste
          .map((o) => [
                '${o.id ?? ''}',
                o.name ?? '',
                o.tel ?? '',
                o.email ?? '',
                o.address ?? '',
                (o.realestates ?? []).map((r) => r.title ?? '').where((t) => t.isNotEmpty).join(', '),
              ])
          .toList(),
    );
  }

  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(
          'Liste des propriétaires',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        foregroundColor: Colors.white,
        backgroundColor: AppColors.primaryColor,
        elevation: 0,
        centerTitle: true,
        actions: [BoutonExport(tableau: _tableauExport)],
      ),
      body: BlocConsumer<OwnersCubit, OwnersState>(
        listener: (context, state) {
          if (state.deleteStatus == AppStatus.success) {
            showToast("Propriétaire supprimé avec succès", context, second: 2);
          } else if (state.deleteStatus == AppStatus.error) {
            showToast("", description: state.error ?? "Erreur de suppression",
                type: ToastificationType.error, context, second: 2);
          }
        },
        builder: (context, state) {
          return _buildContent(state);
        },
      ),
      floatingActionButton: !Dependencies.get<Manager>().can(AppPermission.createOwner) ? null : FloatingActionButton(
        onPressed: _navigateToAddOwner,
        backgroundColor: AppColors.primaryColor,
        child: Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildContent(OwnersState state) {
    if (state.fetchStatus == AppStatus.loading) {
      return Center(child: MyLoadingIndicator());
    } else if (state.fetchStatus == AppStatus.error) {
      return MyErrorWidget(
        error: state.error ?? "Error",
        action: AppStrings.tryAgain,
        actionCLick: _fetchData,
      );
    } else if (state.fetchStatus == AppStatus.success) {
      return PageAEnTeteDefilant(
        entete: [_buildSearchBar(state)],
        corps: _buildOwnersList(state),
      );
    }
    return SizedBox();
  }

  Widget _buildSearchBar(OwnersState state) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (value) {
          BlocProvider.of<OwnersCubit>(context).search(value);
        },
        decoration: InputDecoration(
          hintText: "Rechercher par nom, email ou téléphone...",
          hintStyle: TextStyle(
            color: Colors.grey.shade500,
            fontSize: 14,
          ),
          prefixIcon: Icon(
            Icons.search,
            color: Colors.grey.shade600,
          ),
          suffixIcon: state.query != null && state.query!.isNotEmpty
              ? IconButton(
            icon: Icon(Icons.clear, color: Colors.grey.shade600),
            onPressed: () {
              _searchController.clear();
              BlocProvider.of<OwnersCubit>(context).search('');
            },
          )
              : null,
          filled: true,
          fillColor: Colors.grey.shade50,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppColors.primaryColor, width: 2),
          ),
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  Widget _buildOwnersList(OwnersState state) {
    final owners = state.publicOwners ?? [];

    if (owners.isEmpty) {
      return _buildEmptyState(state.query?.isNotEmpty ?? false);
    }

    return RefreshIndicator(
      onRefresh: () async => _fetchData(),
      color: AppColors.primaryColor,
      child: ListView.separated(
        padding: EdgeInsets.all(16),
        itemCount: owners.length,
        separatorBuilder: (context, index) => SizedBox(height: 12),
        itemBuilder: (context, index) {
          return _buildOwnerCard(owners[index]);
        },
      ),
    );
  }

  Widget _buildOwnerCard(Owner owner) {
    return InkWell(
      onTap: () => _navigateToOwnerDetails(owner),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Owner header
              Row(
                children: [
                  // Avatar
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: Colors.blue.shade100,
                    child: Icon(
                      Icons.person,
                      size: 24,
                      color: AppColors.primaryColor,
                    ),
                  ),
                  SizedBox(width: 12),
                  // Name and ID
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          owner.name ?? 'Nom non défini',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 2),
                        Text(
                          "Propriétaire #${owner.id}",
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (Dependencies.get<Manager>().can(AppPermission.deleteOwner))
                    IconButton(
                      icon: Icon(Icons.delete_outline,
                          color: Colors.red.shade400, size: 22),
                      tooltip: 'Supprimer',
                      onPressed: () => _deleteOwner(owner),
                      padding: EdgeInsets.zero,
                      constraints: BoxConstraints(),
                    ),
                  // Property count badge
                  if (owner.realestates != null && owner.realestates!.isNotEmpty)
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.home,
                            size: 14,
                            color: Colors.green.shade700,
                          ),
                          SizedBox(width: 4),
                          Text(
                            "${owner.realestates!.length}",
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.green.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),

              SizedBox(height: 12),

              // Contact information
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  children: [
                    if (owner.email != null && owner.email!.isNotEmpty) ...[
                      _buildContactRow(
                        Icons.email,
                        owner.email!,
                      ),
                      if (owner.tel != null && owner.tel!.isNotEmpty)
                        Divider(height: 16, color: Colors.blue.shade200),
                    ],
                    if (owner.tel != null && owner.tel!.isNotEmpty)
                      _buildContactRow(
                        Icons.phone,
                        owner.tel!,
                      ),
                    if ((owner.email == null || owner.email!.isEmpty) &&
                        (owner.tel == null || owner.tel!.isEmpty))
                      Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 16,
                            color: Colors.grey.shade600,
                          ),
                          SizedBox(width: 8),
                          Text(
                            "Aucune information de contact",
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),

              // Address (if available)
              if (owner.address != null && owner.address!.isNotEmpty) ...[
                SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      Icons.location_on,
                      size: 16,
                      color: Colors.grey.shade600,
                    ),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        owner.address!,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContactRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.primaryColor),
        SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              color: Colors.black87,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(bool isSearching) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isSearching ? Icons.search_off : Icons.people_outline,
            size: 80,
            color: Colors.grey.shade400,
          ),
          SizedBox(height: 16),
          Text(
            isSearching
                ? "Aucun résultat trouvé"
                : "Aucun propriétaire trouvé",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          SizedBox(height: 8),
          Text(
            isSearching
                ? "Essayez une autre recherche"
                : "Commencez par ajouter un nouveau propriétaire",
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  void _fetchData() {
    BlocProvider.of<OwnersCubit>(context).fetchData();
  }

  void _navigateToAddOwner() async {
    await GoRouter.of(context).push(Routes.addOwner);
    _fetchData();
  }

  void _navigateToOwnerDetails(Owner owner) {
    GoRouter.of(context).push(Routes.ownerDetail.replaceFirst(":id", owner.id.toString()));
  }

  void _deleteOwner(Owner owner) async {
    final confirmed = await showDialogueQuestion(
        context, "Voulez-vous vraiment supprimer ce propriétaire ?");
    if (confirmed == true && mounted) {
      BlocProvider.of<OwnersCubit>(context).deleteOwner(owner);
    }
  }
}