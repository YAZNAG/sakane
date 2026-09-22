import 'package:immobilier/features/biens_desactives/outils_desactivation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:immobilier/components/error_widget.dart';
import 'package:immobilier/components/loading_indicator.dart';
import 'package:immobilier/core/constants/app_strings.dart';
import 'package:immobilier/core/constants/enums/app_status.dart';
import 'package:immobilier/core/constants/enums/permissions.dart';
import 'package:immobilier/core/dependencies/dependencies.dart';
import 'package:immobilier/core/extensions/extension_on_date.dart';
import 'package:immobilier/core/utils/show_dialogue_question.dart';
import 'package:immobilier/core/utils/show_toast.dart';
import 'package:immobilier/features/gestion_immobilier/home/cubit/gestion_immobilier_cubit.dart';
import 'package:immobilier/models/immobilier_overview.dart';
import 'package:immobilier/models/manager.dart';
import 'package:immobilier/models/realestate.dart';
import 'package:immobilier/routes.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:toastification/toastification.dart';
import 'package:immobilier/core/constants/app_colors.dart';
import '../../../../components/form_field.dart';
import '../../../../core/validator/validator.dart';
import 'package:immobilier/features/gestion_immobilier/groupes/cubit/groupes_cubit.dart';
import 'package:immobilier/features/gestion_immobilier/groupes/ui/components/carte_groupe.dart';
import 'package:immobilier/features/gestion_immobilier/groupes/ui/groupes_immobilier.dart';
import 'package:immobilier/core/utils/rafraichissement_auto.dart';

class GestionImmobilierHome extends StatefulWidget {
  GestionImmobilierHome({Key? key}) : super(key: key);

  static Widget page() {
    return BlocProvider<GestionImmobilierCubit>(
      create: (ctx) => GestionImmobilierCubit()..fetchData(),
      child: GestionImmobilierHome(),
    );
  }

  @override
  State<GestionImmobilierHome> createState() => _GestionImmobilierHomeState();
}

class _GestionImmobilierHomeState extends State<GestionImmobilierHome>
    with RafraichissementAuto<GestionImmobilierHome> {
  @override
  void rafraichir() {
    if (!mounted) return;
    context.read<GestionImmobilierCubit>().fetchData();
  }


  Manager manager=Dependencies.get<Manager>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'Gestion Immobilier',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: AppColors.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        actions: [
          if (manager.can(AppPermission.viewAirbnb))
          IconButton(
            tooltip: 'Airbnb',
            icon: const FaIcon(FontAwesomeIcons.airbnb, color: Colors.white, size: 20),
            onPressed: () => GoRouter.of(context).push(Routes.airbnbBiens),
          ),
          if (peutVoirBiensDesactives())
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.white),
              onSelected: (_) => GoRouter.of(context).push(Routes.biensDesactives).then((_) => rafraichir()),
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'biens-desactives',
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.visibility_off_outlined),
                    title: Text('Biens désactivés'),
                  ),
                ),
              ],
            ),
        ],
      ),
      body: BlocProvider(
        // Le regroupement par type se nourrit de la liste des biens :
        // un cubit distinct, charge en parallele du tableau de bord.
        create: (_) => GroupesCubit()..charger(),
        child: BlocConsumer<GestionImmobilierCubit, GestionImmobilierState>(
          listener: _listener,
          builder: (context, state) {
            return _buildContent(state);
          },
        ),
      ),
    );
  }

  Widget _buildContent(GestionImmobilierState state) {
    Manager manager=Dependencies.get<Manager>();
    if (state.fetchDataStatus == AppStatus.loading) {
      return  Center(child: MyLoadingIndicator());
    } else if (state.fetchDataStatus == AppStatus.error) {
      return Center(
        child: MyErrorWidget(
          error: state.error ?? "Erreur",
          action: AppStrings.tryAgain,
          actionCLick: () {
            context.read<GestionImmobilierCubit>().fetchData();
          },
        ),
      );
    } else if (state.fetchDataStatus == AppStatus.success) {
      return RefreshIndicator(
        onRefresh: () async {
          context.read<GestionImmobilierCubit>().fetchData();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Seules les trois familles de biens : les etats et les
              // dossiers se decouvrent en entrant dans chacune.
              _buildGroupesSection(),

              // Les departs du jour ont rejoint la location courte duree :
              // c'est la qu'ils se produisent, et la qu'on les surveille.
            ],
          ),
        ),
      );
    }
    return const SizedBox();
  }

  /// Les trois familles de biens, avec leur nombre.
  Widget _buildGroupesSection() {
    return BlocBuilder<GroupesCubit, GroupesState>(
      builder: (context, groupes) {
        if (groupes.fetchStatus == AppStatus.loading) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 30),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: typesDeBiens
              .map((t) => CarteGroupe(
                    nombre: groupes.compterType(t.code),
                    titre: t.titre,
                    sousTitre: t.sousTitre,
                    libelleAction: t.action,
                    icone: t.icone,
                    degrade: t.degrade,
                    onTap: () {
                      final cubit = context.read<GroupesCubit>();
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => BlocProvider.value(
                          value: cubit,
                          child: pageDuType(t),
                        ),
                      ));
                    },
                  ))
              .toList(),
        );
      },
    );
  }

  Widget _buildStatisticsSection(GestionImmobilierState state) {
    final overview=state.immobilierOverview;
    Manager manager=Dependencies.get<Manager>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Available Apartments Card

        if (manager.can(AppPermission.viewProperties))
        _buildStatCard(
          count: overview?.allImmobilier??0,
          title: "Tous les biens",
          buttonText: "Voir tous les biens",
          color: Colors.purple.shade600,
          icon: Icons.list,
          onTap: () {
            _navigateToModule(Routes.immobilier);
          },
        ),

        const SizedBox(height: 16),

        if(manager.can(AppPermission.viewAvailableProperties))
        _buildStatCard(
          count: overview?.available??0,
          title: "Appartements disponibles",
          buttonText: "Voir les appartements",
          color: Colors.green.shade600,
          icon: Icons.check_circle_outline,
          onTap: () {
            navigate(Routes.immobilierByStatus.replaceFirst(":status", "available"));
          },
        ),

        const SizedBox(height: 16),

        // Reserved Apartments Card
        if(manager.can(AppPermission.viewReservedProperties))
        _buildStatCard(
          count: overview?.reserved??0,
          title: "Appartements réservés",
          buttonText: "Voir les réservations",
          color: Colors.red.shade600,
          icon: Icons.event_busy,
          onTap: () {
           navigate(Routes.immobilierByStatus.replaceFirst(":status", "reserved"));
          },
        ),

        const SizedBox(height: 16),

        // Cleaning Apartments Card
        if(manager.can(AppPermission.viewCleaningProperties))
        _buildStatCard(
          count: overview?.cleaning??0,
          title: "Appartements en nettoyage",
          buttonText: "",
          color: Colors.orange.shade600,
          icon: Icons.cleaning_services,
          onTap: (){
            navigate(Routes.immobilierByStatus.replaceFirst(":status", "cleaning"));
          },
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required int count,
    required String title,
    required String buttonText,
    required Color color,
    required IconData icon,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            // Count
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                count.toString(),
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),

            const SizedBox(width: 16),

            // Title and Button
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        icon,
                        color: Colors.white,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (buttonText.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        buttonText,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCheckoutSection(GestionImmobilierState state) {
    final checkoutToday = state.immobilierOverview?.realestates ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.event_note,
              color: Colors.grey.shade700,
              size: 24,
            ),
            const SizedBox(width: 8),
            Text(
              "Check-out du jour",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        if (checkoutToday.isEmpty)
          _buildEmptyCheckout()
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: checkoutToday.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              return _buildCheckoutCard(checkoutToday[index]);
            },
          ),
      ],
    );
  }

  Widget _buildCheckoutCard(Realestate realestate) {
    final booking=realestate.booking;
    final client=booking?.client;
    String clientName = client?.fullName ?? "unknown";
    String apartmentName = realestate.title ?? "Appartement";

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Property Image
              InkWell(
                onTap: () async {
                  final modifie = await GoRouter.of(context).push(Routes.homeImmobilier.replaceFirst(":id", realestate.id.toString()));
                  if (modifie == true && mounted) rafraichir();
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: realestate.media?.isNotEmpty == true
                      ? Image.network(
                    realestate.media!.first.url ?? "",
                    width: 60,
                    height: 60,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        _buildImagePlaceholder(),
                  )
                      : _buildImagePlaceholder(),
                ),
              ),

              const SizedBox(width: 12),

              // Property Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      apartmentName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.person_outline,
                          size: 14,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            "Client : $clientName",
                            overflow: TextOverflow.fade,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Today Badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Text(
                  booking?.checkout?.formattedDateFr??'-',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryColor,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Confirm Button
          SizedBox(
            width: double.infinity,
            child: Row(
              children: [
                if(manager.can(AppPermission.confirmCheckout))
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed:()=>_confirmDepart(realestate),
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text("Confirmer le départ"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),


              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImagePlaceholder() {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        Icons.home_outlined,
        color: Colors.grey.shade400,
        size: 28,
      ),
    );
  }

  Widget _buildEmptyCheckout() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Icon(
            Icons.event_available,
            size: 60,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            "Aucun check-out aujourd'hui",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Tous les appartements sont à jour",
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }



  /*void _showConfirmDialog(Realestate realestate, String clientName) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text("Confirmer le départ"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Êtes-vous sûr de vouloir confirmer le départ de ce client ?",
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      realestate.title ?? "Appartement",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Client : $clientName",
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text("Annuler"),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                // TODO: Implement confirm checkout logic
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Départ confirmé avec succès"),
                    backgroundColor: Colors.green,
                  ),
                );
                // Refresh data
                context.read<GestionImmobilierCubit>().fetchData();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal.shade600,
                foregroundColor: Colors.white,
              ),
              child: const Text("Confirmer"),
            ),
          ],
        );
      },
    );
  }
*/
  void _navigateToModule( String route) {
    GoRouter.of(context).push(route);
  }

  void _confirmDepart(Realestate realestate) async{
    var result=await showDialogueQuestion(context, "Voulez-vous vraiment confirmer le départ du client ?");
    if(result!=null && result){
      BlocProvider.of<GestionImmobilierCubit>(context).confirmDepart(realestate);
    }
  }

  void _listener(BuildContext context, GestionImmobilierState state) {
    if(state.actionStatus==AppStatus.success){
      showToast(AppStrings.success, context);
    }else if(state.actionStatus==AppStatus.error){
      showToast("",description: state.error ??AppStrings.error, context,type: ToastificationType.error);
    }
  }

  void navigate(String route)async{
    await GoRouter.of(context).push(route);
    context.read<GestionImmobilierCubit>().fetchData();
  }





}