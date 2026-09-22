import 'package:immobilier/components/bouton_export.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:immobilier/features/reception_whatsapp/ui/reception_whatsapp.dart';
import 'package:immobilier/components/loading_indicator.dart';
import 'package:immobilier/core/constants/app_strings.dart';
import 'package:immobilier/core/constants/enums/app_status.dart';
import 'package:immobilier/core/dependencies/dependencies.dart';
import 'package:immobilier/core/utils/droits.dart';
import 'package:immobilier/core/utils/show_dialogue_question.dart';
import 'package:immobilier/core/utils/show_toast.dart';
import 'package:immobilier/models/manager.dart';
import 'package:toastification/toastification.dart';
import 'package:immobilier/core/constants/app_colors.dart';
import '../../../../routes.dart';
import '../cubit/users_cubit.dart';
import 'package:immobilier/features/users/user_list/ui/components/dossiers_de_l_agent.dart';

class UsersListScreen extends StatefulWidget {
  const UsersListScreen({Key? key}) : super(key: key);

  static Widget page() {
    return BlocProvider<UsersCubit>(
      create: (ctx) => UsersCubit()..fetchData(),
      child: UsersListScreen(),
    );
  }

  @override
  State<UsersListScreen> createState() => _UsersListScreenState();
}

class _UsersListScreenState extends State<UsersListScreen> {

  TableauExportable? _tableauExport() {
    final liste = context.read<UsersCubit>().state.managers;
    if (liste == null) return null;
    return TableauExportable(
      titre: 'Gestionnaires',
      colonnes: const ['N°', 'Prénom', 'Nom', 'E-mail', 'Téléphone', 'Rôle'],
      lignes: liste
          .map((m) => [
                '${m.id ?? ''}',
                m.firstName ?? '',
                m.lastName ?? '',
                m.email ?? '',
                m.phone ?? '',
                (m.roles ?? []).join(', '),
              ])
          .toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(
          "Gestionnaires",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        centerTitle: true,
        elevation: 0,
        foregroundColor: Colors.white,
        backgroundColor: AppColors.primaryColor,
        actions: [
          if (estAdminReceptionWhatsapp)
            IconButton(
              tooltip: 'Réception WhatsApp',
              icon: const FaIcon(FontAwesomeIcons.whatsapp, size: 20),
              onPressed: () => GoRouter.of(context).push(Routes.receptionsWhatsapp),
            ),
          BoutonExport(tableau: _tableauExport),
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () {
              context.read<UsersCubit>().fetchData();
            },
          ),
        ],
      ),
      body: BlocConsumer<UsersCubit, UsersState>(
        listener: listener,
        builder: (context, state) {
          if (state.fetchDataStatus == AppStatus.loading) {
            return _buildLoadingState();
          } else if (state.fetchDataStatus == AppStatus.error) {
            return _buildErrorState(state.error);
          } else if (state.fetchDataStatus == AppStatus.success) {
            if (state.managers == null || state.managers!.isEmpty) {
              return _buildEmptyState();
            }
            return _buildManagersList(state.managers!);
          }
          return _buildInitialState();
        },
      ),
      floatingActionButton: !peut(AppPermission.createUser) ? null : FloatingActionButton.extended(
        onPressed: _navigateToAddManager,
        backgroundColor: AppColors.primaryColor,
        icon: Icon(Icons.add, color: Colors.white),
        label: Text(
          "Ajouter",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(child: MyLoadingIndicator());
  }

  Widget _buildErrorState(String? error) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red.shade700,
              ),
            ),
            SizedBox(height: 24),
            Text(
              "Erreur de chargement",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            SizedBox(height: 8),
            Text(
              error ?? "Une erreur s'est produite",
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                context.read<UsersCubit>().fetchData();
              },
              icon: Icon(Icons.refresh),
              label: Text("Réessayer"),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryColor,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.people_outline,
                size: 64,
                color: AppColors.primaryColor,
              ),
            ),
            SizedBox(height: 24),
            Text(
              "Aucun gestionnaire",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            SizedBox(height: 8),
            Text(
              "Commencez par ajouter votre premier gestionnaire",
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 24),
            if (peut(AppPermission.createUser))
            ElevatedButton.icon(
              onPressed: _navigateToAddManager,
              icon: Icon(Icons.add),
              label: Text("Ajouter un gestionnaire"),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryColor,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInitialState() {
    return Center(
      child: Text(
        "Initialisation...",
        style: TextStyle(color: Colors.grey.shade600),
      ),
    );
  }

  Widget _buildManagersList(List<Manager> managers) {
    return RefreshIndicator(
      onRefresh: () async {
        context.read<UsersCubit>().fetchData();
      },
      color: AppColors.primaryColor,
      child: Column(
        children: [
          // Stats header
          Container(
            margin: EdgeInsets.all(16),
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primaryColor, Colors.blue.shade900],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryColor.withOpacity(0.3),
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.people,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Total des gestionnaires",
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        "${managers.length}",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // List
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.only(left: 16, right: 16, bottom: 80),
              itemCount: managers.length,
              itemBuilder: (context, index) {
                return _buildManagerCard(managers[index], index);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildManagerCard(Manager manager, int index) {
    String initials = _getInitials(manager);
    Color avatarColor = _getAvatarColor(index);
    final state=context.read<UsersCubit>().state;

    return Container(
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Main content
          Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                // Avatar
                Hero(
                  tag: 'manager_${manager.id}',
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: avatarColor,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: avatarColor.withOpacity(0.3),
                          blurRadius: 8,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        initials,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),

                SizedBox(width: 16),

                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              "${manager.firstName ?? ''} ${manager.lastName ?? ''}",
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 6),
                      Container(
                        padding: EdgeInsets.symmetric(
                          vertical: 4,
                          horizontal: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: Colors.blue.shade200,
                            width: 1,
                          ),
                        ),
                        child: Text(
                          "${manager.roles?.first ?? 'N/A'}",
                          style: TextStyle(
                            color: AppColors.primaryColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.email_outlined,
                            size: 14,
                            color: Colors.grey.shade600,
                          ),
                          SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              manager.email ?? 'N/A',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.phone_outlined,
                            size: 14,
                            color: Colors.grey.shade600,
                          ),
                          SizedBox(width: 6),
                          Text(
                            manager.phone ?? 'N/A',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Divider
          Divider(height: 1, thickness: 1, color: Colors.grey.shade200),

          // Action buttons
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                // Edit button
                if (peut(AppPermission.updateUser))
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _editManager(manager),
                    icon: Icon(Icons.edit_outlined, size: 18),
                    label: Text(
                      "Modifier",
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryColor,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 12),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),

                // Reserve aux administrateurs : c'est eux qui decident
                // du perimetre de chacun.
                if (peut(AppPermission.manageUserFolders)) ...[
                  SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _dossiersDeLAgent(manager),
                      icon: Icon(Icons.folder_outlined, size: 18),
                      label: Text(
                        "Dossiers",
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primaryColor,
                        side: BorderSide(color: AppColors.primaryColor),
                        padding: EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],

                if (Dependencies.get<Manager>().can(AppPermission.deleteUser)) ...[
                  SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: state.actionStatus == AppStatus.loading && state.managerInOperationId == manager.id
                          ? null
                          : () => _deleteManager(manager),
                      icon: Icon(Icons.delete_outline, size: 18),
                      label: Text(
                        "Supprimer",
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade600,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 12),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
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

  String _getInitials(Manager manager) {
    String first = manager.firstName?.isNotEmpty == true
        ? manager.firstName![0].toUpperCase()
        : '';
    String last = manager.lastName?.isNotEmpty == true
        ? manager.lastName![0].toUpperCase()
        : '';
    return first + last;
  }

  Color _getAvatarColor(int index) {
    List<Color> colors = [
      AppColors.primaryColor,
      Colors.green.shade700,
      Colors.orange.shade700,
      Colors.purple.shade700,
      Colors.teal.shade700,
      Colors.red.shade700,
      Colors.indigo.shade700,
      Colors.pink.shade700,
    ];
    return colors[index % colors.length];
  }

  void _navigateToAddManager() async {
    await GoRouter.of(context).push(Routes.addUser);
    BlocProvider.of<UsersCubit>(context).fetchData();
  }

  /// Perimetre de l'agent : les dossiers dont il voit les biens.
  void _dossiersDeLAgent(Manager manager) async {
    if (manager.id == null) return;
    final modifie = await DossiersDeLAgent.ouvrir(context, manager);
    if (modifie == true && mounted) {
      showToast("Accès mis à jour", context, second: 2);
    }
  }

  void _editManager(Manager manager) async {
    await GoRouter.of(context).push(
      Routes.updateUser.replaceAll(':id', manager.id.toString()),
    );
    BlocProvider.of<UsersCubit>(context).fetchData();
  }

  void _deleteManager(Manager manager) async{
    var result=await showDialogueQuestion(context, "Voulez-vous vraiment supprimer ce manager ?");
    if(result !=null && result){
      context.read<UsersCubit>().deleteUser(manager);
    }

  }

  void listener(BuildContext context, UsersState state) {
    if(state.actionStatus==AppStatus.success){
      showToast(AppStrings.success, context);
    }else if(state.actionStatus==AppStatus.error){
      showToast("Error", context,type: ToastificationType.error);
    }
  }
}