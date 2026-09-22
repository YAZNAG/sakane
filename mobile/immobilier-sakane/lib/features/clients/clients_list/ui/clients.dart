import 'package:immobilier/components/entete_defilant.dart';
import 'package:immobilier/components/bouton_export.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:immobilier/components/error_widget.dart';
import 'package:immobilier/components/loading_indicator.dart';
import 'package:immobilier/core/constants/app_colors.dart';
import 'package:immobilier/core/constants/app_strings.dart';
import 'package:immobilier/core/constants/enums/app_status.dart';
import 'package:immobilier/core/constants/enums/permissions.dart';
import 'package:immobilier/core/dependencies/dependencies.dart';
import 'package:immobilier/core/utils/show_dialogue_question.dart';
import 'package:immobilier/core/utils/show_toast.dart';
import 'package:immobilier/models/client.dart';
import 'package:immobilier/models/manager.dart';
import 'package:toastification/toastification.dart';
import '../../../../routes.dart';
import '../cubit/clients_cubit.dart';

class ClientsPage extends StatefulWidget {
  ClientsPage({Key? key}) : super(key: key);

  static Widget page() => BlocProvider(
    create: (ctx) => ClientsCubit()..fetchData(),
    child: ClientsPage(),
  );

  @override
  State<ClientsPage> createState() => _ClientsPageState();
}

class _ClientsPageState extends State<ClientsPage> {

  TableauExportable? _tableauExport() {
    final tous = context.read<ClientsCubit>().state.clients;
    if (tous == null) return null;
    final liste = _filter(tous);
    return TableauExportable(
      titre: _seulementListeNoire ? 'Clients – liste noire' : 'Clients',
      colonnes: const ['N°', 'Nom', 'Nom en arabe', 'Téléphone', 'E-mail', "Pièce d'identité", 'Type', 'Liste noire'],
      lignes: liste
          .map((c) => [
                '${c.id ?? ''}',
                [c.firstName, c.lastName].whereType<String>().join(' ').trim(),
                [c.firstNameAr, c.lastNameAr].whereType<String>().join(' ').trim(),
                c.tel ?? '',
                c.email ?? '',
                c.identityNumber ?? '',
                c.type ?? '',
                c.listeNoire != null
                    ? ((c.listeNoire!.motif ?? '').isEmpty ? 'Oui' : 'Oui – ${c.listeNoire!.motif}')
                    : '—',
              ])
          .toList(),
    );
  }

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  /// Filtre « Liste noire » actif.
  bool _seulementListeNoire = false;

  static const _rouge = Color(0xFFC62828);

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Client> _filter(List<Client> tous) {
    final clients = _seulementListeNoire
        ? tous.where((c) => c.listeNoire != null).toList()
        : tous;
    if (_searchQuery.isEmpty) return clients;
    return clients.where((c) {
      final nomComplet =
          "${c.firstName ?? ''} ${c.lastName ?? ''}".toLowerCase();
      return (c.firstName?.toLowerCase().contains(_searchQuery) ?? false) ||
          (c.lastName?.toLowerCase().contains(_searchQuery) ?? false) ||
          nomComplet.contains(_searchQuery) ||
          (c.tel?.toLowerCase().contains(_searchQuery) ?? false) ||
          (c.identityNumber?.toLowerCase().contains(_searchQuery) ?? false);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final Manager manager = Dependencies.get<Manager>();
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(
          'Liste des clients',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        foregroundColor: Colors.white,
        backgroundColor: AppColors.primaryColor,
        elevation: 0,
        centerTitle: true,
        actions: [BoutonExport(tableau: _tableauExport)],
      ),
      body: BlocConsumer<ClientsCubit, ClientsState>(
        listener: _listener,
        builder: (context, state) => _buildContent(state, manager),
      ),
      floatingActionButton: manager.can(AppPermission.createClient)
          ? FloatingActionButton(
              onPressed: _navigateToAddClient,
              backgroundColor: AppColors.primaryColor,
              child: Icon(Icons.add, color: Colors.white),
            )
          : null,
    );
  }

  void _listener(BuildContext context, ClientsState state) {
    if (state.deleteStatus == AppStatus.success) {
      showToast(
        AppStrings.success,
        context,
        second: 2,
        type: ToastificationType.success,
      );
    } else if (state.deleteStatus == AppStatus.error) {
      showToast(
        "",
        description: state.error ?? AppStrings.error,
        context,
        second: 3,
        type: ToastificationType.error,
      );
    }
  }

  Widget _buildContent(ClientsState state, Manager manager) {
    if (state.fetchStatus == AppStatus.loading) {
      return Center(child: MyLoadingIndicator());
    } else if (state.fetchStatus == AppStatus.error) {
      return MyErrorWidget(
        error: state.error ?? "Error",
        action: AppStrings.tryAgain,
        actionCLick: _fetchData,
      );
    } else if (state.fetchStatus == AppStatus.success) {
      if (state.clients == null || state.clients!.isEmpty) {
        return _buildEmptyState();
      }
      final filtered = _filter(state.clients!);
      return PageAEnTeteDefilant(
        entete: [
          _buildSearchBar(),
          _buildFiltres(state.clients!),
        ],
        corps: filtered.isEmpty
                ? _buildNoResultsState()
                : ListView.separated(
                    padding: EdgeInsets.all(16),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final client = filtered[index];
                      final isDeleting = state.deleteStatus == AppStatus.loading &&
                          state.deletingId == client.id;
                      return _buildClientCard(
                        client,
                        manager,
                        isDeleting,
                        index == filtered.length - 1,
                      );
                    },
                  ),
      );
    }
    return SizedBox();
  }

  Widget _buildSearchBar() {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: "Nom, prénom, téléphone ou CIN...",
          hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade500),
          prefixIcon: Icon(Icons.search, color: Colors.grey.shade500),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.clear, color: Colors.grey.shade500),
                  onPressed: () => _searchController.clear(),
                )
              : null,
          filled: true,
          fillColor: Colors.grey.shade100,
          contentPadding: EdgeInsets.symmetric(vertical: 0, horizontal: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _buildFiltres(List<Client> clients) {
    final nbListeNoire = clients.where((c) => c.listeNoire != null).length;
    return Container(
      color: Colors.white,
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Wrap(
        spacing: 8,
        children: [
          ChoiceChip(
            label: Text('Tous (${clients.length})'),
            selected: !_seulementListeNoire,
            onSelected: (_) => setState(() => _seulementListeNoire = false),
            selectedColor: AppColors.primaryColor.withValues(alpha: 0.15),
            labelStyle: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: !_seulementListeNoire ? AppColors.primaryColor : Colors.grey.shade700,
            ),
            showCheckmark: false,
          ),
          ChoiceChip(
            avatar: Icon(Icons.block, size: 16,
                color: _seulementListeNoire ? Colors.white : _rouge),
            label: Text('Liste noire ($nbListeNoire)'),
            selected: _seulementListeNoire,
            onSelected: (_) => setState(() => _seulementListeNoire = true),
            selectedColor: _rouge,
            backgroundColor: Colors.red.shade50,
            labelStyle: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: _seulementListeNoire ? Colors.white : _rouge,
            ),
            showCheckmark: false,
          ),
        ],
      ),
    );
  }

  Widget _buildNoResultsState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(_seulementListeNoire && _searchQuery.isEmpty ? Icons.verified_user_outlined : Icons.search_off,
              size: 64, color: Colors.grey.shade400),
          SizedBox(height: 16),
          Text(
            _searchQuery.isEmpty
                ? "Aucun client sur liste noire"
                : "Aucun résultat pour \"$_searchQuery\"",
            style: TextStyle(fontSize: 15, color: Colors.grey.shade600),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildClientCard(
    Client client,
    Manager manager,
    bool isDeleting,
    bool isLast,
  ) {
    return InkWell(
      onTap: () => _navigateToClientDetails(client),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: isLast ? EdgeInsets.only(bottom: 47) : EdgeInsets.zero,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: client.listeNoire != null
              ? Border.all(color: Colors.red.shade200)
              : null,
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
              // Header row: avatar + name + rating
              Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: Colors.blue.shade100,
                    backgroundImage:
                        (client.profile != null && client.profile!.isNotEmpty)
                        ? NetworkImage(client.profile!)
                        : null,
                    child: (client.profile == null || client.profile!.isEmpty)
                        ? Icon(
                            Icons.person,
                            size: 28,
                            color: AppColors.primaryColor,
                          )
                        : null,
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "${client.firstName ?? ''} ${client.lastName ?? ''}",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 2),
                        Text(
                          "Client #${client.id}",
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        if (client.listeNoire != null) ...[
                          SizedBox(height: 4),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: _rouge,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.block, size: 12, color: Colors.white),
                                SizedBox(width: 4),
                                Text(
                                  "Liste noire",
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if ((client.listeNoire!.motif ?? '').isNotEmpty)
                            Padding(
                              padding: EdgeInsets.only(top: 3),
                              child: Text(
                                client.listeNoire!.motif!,
                                style: TextStyle(fontSize: 12, color: _rouge),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                      ],
                    ),
                  ),
                  if (client.rate != null && client.rate! > 0)
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.amber.shade200),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.star,
                            size: 14,
                            color: Colors.amber.shade700,
                          ),
                          SizedBox(width: 4),
                          Text(
                            client.rate!.toStringAsFixed(1),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.amber.shade900,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),

              SizedBox(height: 12),

              // Contact info
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  children: [
                    if (client.email != null)
                      _buildInfoRow(Icons.email, client.email!),
                    if (client.email != null && client.tel != null)
                      Divider(height: 16, color: Colors.blue.shade200),
                    if (client.tel != null)
                      _buildInfoRow(Icons.phone, client.tel!),
                  ],
                ),
              ),

              SizedBox(height: 12),

              // Bottom row: evaluations + action buttons
              Row(
                children: [
                  Icon(Icons.reviews, size: 16, color: Colors.grey.shade600),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      "${client.nbRates ?? 0} évaluation${(client.nbRates ?? 0) > 1 ? 's' : ''}",
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ),
                  if (manager.can(AppPermission.updateClient)) ...[
                    _buildActionButton(
                      icon: Icons.edit_outlined,
                      color: AppColors.primaryColor,
                      onTap: () => _navigateToEditClient(client),
                    ),
                    SizedBox(width: 8),
                  ],
                  if(manager.can(AppPermission.deleteClient))
                  _buildDeleteButton(client, isDeleting),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 18, color: color),
      ),
    );
  }

  Widget _buildDeleteButton(Client client, bool isDeleting) {
    return InkWell(
      onTap: isDeleting ? null : () => _confirmDelete(client),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(8),
        ),
        child: isDeleting
            ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.red.shade600,
                ),
              )
            : Icon(Icons.delete_outline, size: 18, color: Colors.red.shade600),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.primaryColor),
        SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 13, color: Colors.black87),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 80, color: Colors.grey.shade400),
          SizedBox(height: 16),
          Text(
            "Aucun client trouvé",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          SizedBox(height: 8),
          Text(
            "Commencez par ajouter un nouveau client",
            style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(Client client) async{
    var result=await showDialogueQuestion(context, "Voulez-vous vraiment supprimer ce client ?",);
    if(result!=null&& result){
      BlocProvider.of<ClientsCubit>(context).deleteClient(client.id!);
    }
  }

  void _fetchData() => BlocProvider.of<ClientsCubit>(context).fetchData();

  void _navigateToAddClient() async {
    await GoRouter.of(context).push(Routes.addClient);
    _fetchData();
  }

  void _navigateToEditClient(Client client) async {
    await GoRouter.of(context).push(
      Routes.editClient.replaceFirst(':id', client.id.toString()),
      extra: client,
    );
    _fetchData();
  }

  // Au retour, la liste est rechargee sans ecran de chargement (liste noire...)
  void _navigateToClientDetails(Client client) async {
    await GoRouter.of(
      context,
    ).push(Routes.clientDetail.replaceFirst(":id", client.id.toString()));
    if (!mounted) return;
    BlocProvider.of<ClientsCubit>(context).rafraichir();
  }
}
