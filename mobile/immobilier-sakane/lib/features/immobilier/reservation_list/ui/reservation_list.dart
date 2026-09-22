import 'package:immobilier/components/entete_defilant.dart';
import 'package:immobilier/components/bouton_export.dart';
import 'package:immobilier/components/tableaux_export.dart';
import 'package:immobilier/features/immobilier/reservation_list/ui/corbeille.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:immobilier/components/error_widget.dart';
import 'package:immobilier/core/constants/app_colors.dart';
import 'package:immobilier/core/constants/enums/app_status.dart';
import 'package:immobilier/core/dependencies/dependencies.dart';
import 'package:immobilier/core/utils/droits.dart';
import 'package:immobilier/core/extensions/extension_on_date.dart';
import 'package:immobilier/core/extensions/extension_on_string.dart';
import 'package:immobilier/features/immobilier/reservation_list/cubit/reservations_cubit.dart';
import 'package:immobilier/models/booking.dart';
import 'package:immobilier/models/manager.dart';

import '../../../../components/custom_button.dart';
import '../../../../components/form_field.dart';
import '../../../../components/loading_indicator.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../routes.dart';
import 'package:immobilier/routes.dart';
import 'package:immobilier/features/immobilier/contrat/ui/visionneuse_contrat.dart';
import 'package:immobilier/features/immobilier/facture/ui/facture.dart';
import 'package:immobilier/features/immobilier/facture/ui/appliquer_facture.dart';
import 'package:immobilier/features/immobilier/detail_reservation/ui/detail_reservation.dart';
import 'package:immobilier/components/partage_syndic.dart';
import 'package:immobilier/components/dialogue_suppression_reservation.dart';
import 'package:immobilier/core/utils/show_toast.dart';
import 'package:toastification/toastification.dart';

class ReservationList extends StatefulWidget {
  ReservationList({Key? key}) : super(key: key);

  static Widget page(int id) {
    return BlocProvider<ReservationsCubit>(
      create: (ctx) => ReservationsCubit(id)..fetchData(),
      child: ReservationList(),
    );
  }

  @override
  State<ReservationList> createState() => _ReservationListState();
}

class _ReservationListState extends State<ReservationList> {

  TableauExportable? _tableauExport() {
    final state = context.read<ReservationsCubit>().state;
    if (state.bookings == null) return null;
    final bien = state.bookings!.isNotEmpty ? state.bookings!.first.realestate?.title : null;
    return tableauReservations(
        bien == null ? 'Réservations du bien' : 'Réservations - $bien', state.bookings!,
        depuis: state.from, jusqua: state.to);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(
          'Liste des réservations',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        foregroundColor: Colors.white,
        backgroundColor: AppColors.primaryColor,
        elevation: 0,
        centerTitle: true,
        actions: [
          BoutonExport(tableau: _tableauExport),
          // La corbeille : ce qui a ete supprime dans la semaine.
          IconButton(
            tooltip: "Corbeille",
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => CorbeillePage.page()),
            ),
            icon: const Icon(Icons.delete_outline, color: Colors.white),
          ),
          IconButton(
            tooltip: "Exporter les réservations",
            onPressed: () =>
                GoRouter.of(context).push(Routes.exportReservations),
            icon: const Icon(Icons.file_download_outlined,
                color: Colors.white),
          ),
        ],
      ),
      body: BlocConsumer<ReservationsCubit, ReservationsState>(
        listenWhen: (avant, apres) => avant.actionStatus != apres.actionStatus,
        listener: (context, state) {
          if (state.actionStatus == AppStatus.success) {
            showToast("Réservation supprimée.", context);
          } else if (state.actionStatus == AppStatus.error) {
            showToast(state.error ?? "La suppression a échoué.", context,
                type: ToastificationType.error, second: 4);
          }
        },
        builder: (context, state) {
          return _buildContent(state);
        },
      ),
    );
  }

  Widget _buildContent(ReservationsState state) {
    final cubit = BlocProvider.of<ReservationsCubit>(context);
    if (state.fetchDataStatus == AppStatus.loading) {
      return Center(child: MyLoadingIndicator());
    } else if (state.fetchDataStatus == AppStatus.error) {
      return MyErrorWidget(
        error: state.error ?? "Error",
        action: AppStrings.tryAgain,
        actionCLick: fetchData,
      );
    } else if (state.fetchDataStatus == AppStatus.success) {
      return PageAEnTeteDefilant(
        entete: [
          // Date filter section
          Container(
            width: double.infinity,
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
            child: Row(
              children: [
                Expanded(
                  child: MyFormField(
                    label: "",
                    hint: "Date début",
                    readOnly: true,
                    borderColor: Colors.black,
                    activeBorderColor: Colors.black,
                    labelColor: Colors.black,
                    onTap: () => _pickDate(
                      initialDate: state.from!,
                      onPicked: (dt) => cubit.selectDate(dt, "from"),
                    ),
                    controller: TextEditingController()
                      ..text = state.from!.formattedDateFr,
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(Icons.arrow_forward, color: Colors.grey.shade600),
                ),
                Expanded(
                  child: MyFormField(
                    label: "",
                    hint: "Date fin",
                    readOnly: true,
                    borderColor: Colors.black,
                    activeBorderColor: Colors.black,
                    labelColor: Colors.black,
                    onTap: () => _pickDate(
                      initialDate: state.to!,
                      onPicked: (dt) => cubit.selectDate(dt, "to"),
                    ),
                    controller: TextEditingController()
                      ..text = state.to!.formattedDateFr,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.primaryColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: IconButton(
                    onPressed: fetchData,
                    icon: Icon(Icons.search, color: Colors.white),
                    tooltip: "Rechercher",
                  ),
                ),
              ],
            ),
          ),

        ],
        // Bookings list
        corps: state.bookings == null || state.bookings!.isEmpty
                ? _buildEmptyState()
                : ListView.separated(
              padding: EdgeInsets.all(16),
              itemCount: state.bookings!.length,
              separatorBuilder: (context, index) => SizedBox(height: 12),
              itemBuilder: (context, index) {
                final booking = state.bookings![index];
                // Toucher la carte ouvre le detail de la reservation.
                return GestureDetector(
                  onTap: () => _ouvrirDetail(booking),
                  child: _buildBookingCard(booking),
                );
              },
            ),
      );
    }
    return SizedBox();
  }

  Widget _buildBookingCard(Booking booking) {
    final nights = booking.checkout!.difference(booking.checkin!).inDays;
    final realestate = booking.realestate;
    final client = booking.client;
    String? propertyImage = realestate?.media?.isNotEmpty == true
        ? realestate!.media!.first.url
        : null;

    return Container(
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with ID, Status, and Delete button
          Container(
            padding: EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.receipt_long, size: 20, color: AppColors.primaryColor),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Réservation #${booking.id}",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),

                SizedBox(width: 8),
                if (Dependencies.get<Manager>().can(AppPermission.deleteReservation))
                  IconButton(
                    icon: Icon(Icons.delete_outline, color: Colors.red.shade600),
                    onPressed: () => _deleteBooking(booking),
                    tooltip: 'Supprimer',
                    padding: EdgeInsets.zero,
                    constraints: BoxConstraints(),
                  ),
              ],
            ),
          ),

          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [


                SizedBox(height: 12),

                // Client Section (Clickable)
                if (client != null)
                  GestureDetector(
                    onTap: () => _navigateToClientDetails(client),
                    child: Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: Colors.blue.shade100,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.person,
                              color: AppColors.primaryColor,
                              size: 28,
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.person_outline,
                                        size: 16, color: AppColors.primaryColor),
                                    SizedBox(width: 6),
                                    Text(
                                      "Client",
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey.shade600,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 4),
                                Text(
                                  client.fullName ?? "Client",
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.arrow_forward_ios,
                              size: 16, color: Colors.grey.shade400),
                        ],
                      ),
                    ),
                  ),

                SizedBox(height: 12),

                // Dates and nights
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.purple.shade200),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.login,
                                    size: 16, color: Colors.purple.shade700),
                                SizedBox(width: 6),
                                Text(
                                  "Arrivée",
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 4),
                            Text(
                              booking.checkin!.formattedDateFr,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 40,
                        color: Colors.purple.shade200,
                      ),
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(left: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.logout,
                                      size: 16, color: Colors.purple.shade700),
                                  SizedBox(width: 6),
                                  Text(
                                    "Départ",
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 4),
                              Text(
                                booking.checkout!.formattedDateFr,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 12),

                // Booking info
                Row(
                  children: [
                    Expanded(
                      child: _buildInfoItem(
                        Icons.people,
                        "${booking.nbGuest ?? 0} invité${(booking.nbGuest ?? 0) > 1 ? 's' : ''}",
                      ),
                    ),
                    Expanded(
                      child: _buildInfoItem(
                        Icons.nights_stay,
                        "$nights nuit${nights > 1 ? 's' : ''}",
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 8),

                _buildInfoItem(
                  Icons.attach_money,
                  "${booking.nightPrice ?? 0} MAD/nuit",
                ),

                // L'agent qui a enregistre la reservation.
                if ((booking.creePar ?? "").isNotEmpty) ...[
                  SizedBox(height: 8),
                  _buildInfoItem(
                    Icons.person_outline,
                    "Créée par ${booking.creePar}",
                  ),
                ],

                SizedBox(height: 16),

                // Total amount
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Montant total",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      Text(
                        "${booking.amount?.toStringAsFixed(2) ?? '0.00'} MAD",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 8),
                _contractActions(context, booking)
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _contractActions(BuildContext context, Booking booking) {
    // Trois boutons ne tiennent pas sur une ligne d'ecran etroit : une
    // rangee les rognait, et le dernier devenait intouchable.
    return Wrap(
      spacing: 4,
      runSpacing: 2,
      children: [
        if (booking.publicContract != null)
          TextButton.icon(
            onPressed: () => viewContract(booking.publicContract!),
            icon: const Icon(Icons.public, size: 18),
            label: const Text("Contrat public"),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),


        if (booking.privateContract != null)
          TextButton.icon(
            onPressed: () => viewContract(booking.privateContract!),
            icon: const Icon(Icons.lock, size: 18),
            label: const Text("Contrat privé"),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),


        // Le contrat public part au syndic, avec un numero et un message
        // modifiables.
        if (booking.publicContract != null && booking.id != null && peut(AppPermission.shareContractSyndic))
          TextButton.icon(
            onPressed: () => partagerAvecSyndic(context, booking),
            icon: const Icon(Icons.apartment, size: 18),
            label: const Text("Syndic"),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),

        // Une seule entree pour la facture : tant qu'elle n'est pas
        // appliquee, on l'applique (le total est H.T, la TVA s'ajoute).
        if (!booking.factureAppliquee && peut(AppPermission.applyInvoice))
        TextButton.icon(
          onPressed: booking.id == null
              ? null
              : () => _appliquerFacture(booking),
          icon: const Icon(Icons.request_quote_outlined, size: 18),
          label: const Text("Appliquer la facture"),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),

        // Tout sur la reservation : historique, caisse, facture.
        TextButton.icon(
          onPressed: booking.id == null ? null : () => _ouvrirDetail(booking),
          icon: const Icon(Icons.info_outline, size: 18),
          label: const Text("Détail"),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),

        // Facture appliquee : elle se consulte, se telecharge et
        // s'envoie au client depuis la visionneuse.
        if (booking.factureAppliquee && peut(AppPermission.viewInvoice))
        TextButton.icon(
          onPressed: booking.id == null
              ? null
              : () => ouvrirFacture(context, booking.id!),
          icon: const Icon(Icons.receipt_long, size: 18),
          label: const Text("Facture"),
          // Pleine, la ou les contrats sont plats : c'est l'action que
          // l'on vient chercher, et elle se distingue au premier coup d'oeil.
          style: TextButton.styleFrom(
            foregroundColor: Colors.white,
            backgroundColor: AppColors.primaryColor,
            disabledForegroundColor: Colors.white70,
            disabledBackgroundColor: Colors.grey.shade400,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPropertyPlaceholder() {
    return Container(
      width: 70,
      height: 70,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        Icons.home,
        color: Colors.grey.shade400,
        size: 30,
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade600),
        SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade700,
            ),
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
          Icon(
            Icons.event_busy,
            size: 80,
            color: Colors.grey.shade400,
          ),
          SizedBox(height: 16),
          Text(
            "Aucune réservation trouvée",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          SizedBox(height: 8),
          Text(
            "Essayez de modifier les dates de recherche",
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  void _deleteBooking(Booking booking) async {
    // On demande d'abord si le client est rembourse, et de combien.
    final choix = await demanderSuppressionReservation(context, booking);
    if (choix != null && mounted) {
      context.read<ReservationsCubit>().deleteBooking(
            booking,
            rembourse: choix.rembourse,
            montant: choix.montant,
          );
    }
  }



  void _navigateToClientDetails(client) {
    GoRouter.of(context).push(Routes.clientDetail.replaceFirst(":id", client.id.toString()));
  }

  /// Applique la facture ; la liste se recharge pour proposer
  /// ensuite « Facture ».
  Future<void> _appliquerFacture(Booking booking) async {
    if (booking.id == null) return;
    final resume = await ouvrirAppliquerFacture(context, booking.id!);
    if (resume != null && mounted) fetchData();
  }

  /// Le detail de la reservation ; la liste se recharge s'il a change.
  Future<void> _ouvrirDetail(Booking booking) async {
    if (booking.id == null) return;
    final modifie = await DetailReservationPage.ouvrir(context, booking.id!);
    if (modifie && mounted) fetchData();
  }

  void fetchData() {
    BlocProvider.of<ReservationsCubit>(context).fetchData();
  }

  Future<void> _pickDate({
    required DateTime initialDate,
    required ValueChanged<DateTime> onPicked,
  }) async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(Duration(days: 365)),
    );
    if (picked != null) onPicked(picked);
  }


  void viewContract(String contract) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final chemin =
          await context.read<ReservationsCubit>().telechargerContrat(contract);
      if (!mounted) return;
      await VisionneuseContrat.ouvrir(context, chemin: chemin);
    } catch (_) {
      messenger.showSnackBar(const SnackBar(
        content: Text("Le contrat n'a pas pu être ouvert."),
      ));
    }
  }
}