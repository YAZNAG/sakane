import 'package:immobilier/components/entete_defilant.dart';
import 'package:immobilier/components/bouton_export.dart';
import 'package:immobilier/features/reservations/ui/choix_bien.dart';
import 'package:immobilier/components/tableaux_export.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:immobilier/core/dependencies/dependencies.dart';
import 'package:immobilier/core/utils/droits.dart';
import 'package:immobilier/core/extensions/extension_on_date.dart';
import 'package:immobilier/core/extensions/extension_on_string.dart';
import 'package:immobilier/core/utils/show_toast.dart';
import 'package:immobilier/components/dialogue_suppression_reservation.dart';
import 'package:toastification/toastification.dart';
import 'package:immobilier/features/reservations/cubit/reservation_cubit.dart';
import 'package:immobilier/models/client.dart';
import 'package:immobilier/models/manager.dart';
import 'package:immobilier/models/realestate.dart';
import 'package:immobilier/routes.dart';
import 'package:immobilier/core/constants/app_colors.dart';
import '../../../components/error_widget.dart';
import '../../../components/form_field.dart';
import '../../../components/loading_indicator.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/enums/app_status.dart';
import '../../../models/booking.dart';
import 'package:immobilier/components/bandeau_synchro.dart';
import 'package:immobilier/features/reservations/ui/components/reservations_en_attente.dart';
import 'package:immobilier/core/utils/rafraichissement_auto.dart';
import 'package:immobilier/features/immobilier/facture/ui/facture.dart';
import 'package:immobilier/features/immobilier/facture/ui/appliquer_facture.dart';
import 'package:immobilier/features/immobilier/detail_reservation/ui/detail_reservation.dart';
import 'package:immobilier/components/partage_syndic.dart';

class ReservationPage extends StatefulWidget {
  ReservationPage({Key? key}) : super(key: key);

  static Widget page() => BlocProvider(
    create: (ctx) => ReservationCubit()..fetchData(),
    child: ReservationPage(),
  );

  @override
  State<ReservationPage> createState() => _ReservationPageState();
}

class _ReservationPageState extends State<ReservationPage>
    with RafraichissementAuto<ReservationPage> {
  /// Filtres de la liste : un appartement, et un client (nom, téléphone
  /// ou e-mail). L'export reprend la liste filtrée.
  int? _bienFiltre;
  final _rechercheClient = TextEditingController();

  /// Filtre rapide actif : hier, aujourdhui, mois, ou periode lorsque les
  /// deux dates sont choisies a la main.
  String _periodeRapide = 'periode';

  /// Raccourcis de periode : ils remplissent les deux dates et relancent
  /// la recherche avec les memes parametres que le bouton loupe.
  Widget _filtresRapides() {
    final cubit = context.read<ReservationCubit>();
    final maintenant = DateTime.now();
    final aujourdhui =
        DateTime(maintenant.year, maintenant.month, maintenant.day);
    final hier = aujourdhui.subtract(const Duration(days: 1));
    final debutMois = DateTime(aujourdhui.year, aujourdhui.month, 1);

    void appliquer(String cle, DateTime du, DateTime au) {
      setState(() => _periodeRapide = cle);
      cubit.selectPeriode(du, au);
    }

    Widget puce(String cle, String libelle, VoidCallback onTap) {
      final actif = _periodeRapide == cle;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          label: Text(libelle),
          selected: actif,
          onSelected: (_) => onTap(),
          showCheckmark: false,
          backgroundColor: Colors.white,
          selectedColor: AppColors.primaryColor,
          side: BorderSide(
              color: actif ? AppColors.primaryColor : Colors.grey.shade300),
          labelStyle: TextStyle(
            fontSize: 13,
            fontWeight: actif ? FontWeight.bold : FontWeight.w500,
            color: actif ? Colors.white : Colors.black87,
          ),
        ),
      );
    }

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            puce('hier', 'Hier', () => appliquer('hier', hier, hier)),
            puce('aujourdhui', "Aujourd'hui",
                () => appliquer('aujourdhui', aujourdhui, aujourdhui)),
            puce('mois', 'Ce mois',
                () => appliquer('mois', debutMois, aujourdhui)),
            puce('periode', 'Période',
                () => appliquer('periode', aujourdhui, aujourdhui)),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _rechercheClient.dispose();
    super.dispose();
  }

  List<Booking> _filtrer(List<Booking> liste) {
    final q = _rechercheClient.text.trim().toLowerCase();
    return liste.where((b) {
      if (_bienFiltre != null && b.realestate?.id != _bienFiltre) return false;
      if (q.isEmpty) return true;
      final c = b.client;
      final texte = [c?.firstName, c?.lastName, c?.firstNameAr, c?.lastNameAr, c?.tel, c?.email]
          .whereType<String>()
          .join(' ')
          .toLowerCase();
      return texte.contains(q);
    }).toList();
  }

  String _nomBien(ReservationState state, int id) {
    for (final b in state.bookings ?? const <Booking>[]) {
      if (b.realestate?.id == id) return b.realestate?.title ?? 'Bien #$id';
    }
    return 'Bien #$id';
  }

  Widget _buildFiltres(ReservationState state) {
    final biens = <int, String>{};
    for (final b in state.bookings ?? const <Booking>[]) {
      final r = b.realestate;
      if (r?.id != null) biens[r!.id!] = r.title ?? 'Bien #${r.id}';
    }
    final tries = biens.entries.toList()
      ..sort((a, b) => a.value.toLowerCase().compareTo(b.value.toLowerCase()));
    final choisi = biens.containsKey(_bienFiltre) ? _bienFiltre : null;
    final total = (state.bookings ?? const <Booking>[]).length;
    final affichees = _filtrer(state.bookings ?? const []).length;
    final filtre = choisi != null || _rechercheClient.text.trim().isNotEmpty;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonFormField<int?>(
            value: choisi,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: 'Appartement',
              prefixIcon: const Icon(Icons.home_work_outlined),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            items: [
              const DropdownMenuItem<int?>(value: null, child: Text('Tous les appartements')),
              for (final e in tries)
                DropdownMenuItem<int?>(
                  value: e.key,
                  child: Text(e.value, maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (v) => setState(() => _bienFiltre = v),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _rechercheClient,
            onChanged: (_) => setState(() {}),
            style: const TextStyle(color: Colors.black87),
            decoration: InputDecoration(
              labelText: 'Client',
              hintText: 'Nom, téléphone ou e-mail',
              prefixIcon: const Icon(Icons.person_search_outlined),
              suffixIcon: _rechercheClient.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => setState(_rechercheClient.clear),
                    ),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                filtre ? '$affichees réservation${affichees > 1 ? 's' : ''} sur $total'
                    : '$total réservation${total > 1 ? 's' : ''}',
                style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700),
              ),
              const Spacer(),
              if (filtre)
                TextButton(
                  onPressed: () => setState(() {
                    _bienFiltre = null;
                    _rechercheClient.clear();
                  }),
                  child: const Text('Effacer les filtres'),
                ),
            ],
          ),
        ],
      ),
    );
  }


  /// Les réservations affichées, ligne par ligne, pour l'export.
  TableauExportable? _tableauExport() {
    final state = context.read<ReservationCubit>().state;
    if (state.bookings == null) return null;
    final filtres = [
      if (_bienFiltre != null) _nomBien(state, _bienFiltre!),
      if (_rechercheClient.text.trim().isNotEmpty) 'client « ${_rechercheClient.text.trim()} »',
    ].join(', ');
    return tableauReservations(
        filtres.isEmpty ? 'Réservations' : 'Réservations — $filtres', _filtrer(state.bookings!),
        depuis: state.from, jusqua: state.to);
  }

  /// Nouvelle réservation : on choisit d'abord le bien.
  Future<void> _nouvelleReservation() async {
    await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const ChoixBienReservationPage()));
    if (mounted) fetchData();
  }

  @override
  void rafraichir() => fetchData();

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
          // Droit « Modifier les heures par défaut » (retiré de l'accueil).
          if (peut(AppPermission.setDefaultHours))
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.white),
              onSelected: (_) => GoRouter.of(context).push(Routes.heuresParDefaut),
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'heures',
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.schedule),
                    title: Text('Heures par défaut'),
                  ),
                ),
              ],
            ),
        ],
      ),
      floatingActionButton: Dependencies.get<Manager>().can(AppPermission.createReservation)
          ? FloatingActionButton.extended(
              onPressed: _nouvelleReservation,
              backgroundColor: AppColors.primaryColor,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: const Text('Ajouter',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            )
          : null,
      body: BlocConsumer<ReservationCubit, ReservationState>(
        listener: listener,
        builder: (context, state) {
          return _buildContent(state);
        },
      ),
    );
  }

  Widget _buildContent(ReservationState state) {
    final cubit = BlocProvider.of<ReservationCubit>(context);
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
          const BandeauSynchro(),
          // Reservations enregistrees sans reseau, pas encore confirmees.
          const ReservationsEnAttente(),
          // Raccourcis de periode au-dessus des deux dates.
          _filtresRapides(),
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
                      onPicked: (dt) {
                        // Une date choisie a la main, c'est le mode
                        // « Période ».
                        setState(() => _periodeRapide = 'periode');
                        cubit.selectDate(dt, "from");
                      },
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
                      onPicked: (dt) {
                        setState(() => _periodeRapide = 'periode');
                        cubit.selectDate(dt, "to");
                      },
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
          _buildFiltres(state),

        ],
        // Bookings list
        corps: _filtrer(state.bookings ?? const []).isEmpty
                ? _buildEmptyState()
                : ListView.separated(
              padding: EdgeInsets.all(16),
              itemCount: _filtrer(state.bookings!).length,
              separatorBuilder: (context, index) => SizedBox(height: 12),
              itemBuilder: (context, index) {
                final booking = _filtrer(state.bookings!)[index];
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
          // Header with ID and Status
          Container(
            padding: EdgeInsets.all(16),
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
                // Delete Button
                if(Dependencies.get<Manager>().can(AppPermission.deleteReservation))
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
                // Property Section (Clickable)
                if (realestate != null)
                  GestureDetector(
                    onTap: ()=>_navigateToRealestate(realestate),
                    child: Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        children: [
                          // Property Image
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: propertyImage != null
                                ? Image.network(
                              propertyImage,
                              width: 70,
                              height: 70,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  _buildPropertyPlaceholder(),
                            )
                                : _buildPropertyPlaceholder(),
                          ),
                          SizedBox(width: 12),
                          // Property Info
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.home,
                                        size: 16, color: Colors.orange.shade700),
                                    SizedBox(width: 6),
                                    Text(
                                      "Propriété",
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
                                  realestate.title ?? "Sans titre",
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(Icons.location_on,
                                        size: 12, color: Colors.grey.shade600),
                                    SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        realestate.address?.city?.name ?? "-",
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade600,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
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

                // Client Section (Clickable)
                if (client != null)
                  GestureDetector(
                    onTap:()=>_navigateToClientDetails(client),
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

                _contractActions(context, booking)
              ],
            ),
          ),

        ],
      ),
    );
  }

  // Add this method to handle deletion
  void _deleteBooking(Booking booking) async{
    // On demande d'abord si le client est rembourse, et de combien.
    final choix = await demanderSuppressionReservation(context, booking);
    if (choix != null && mounted) {
      context.read<ReservationCubit>().deleteBooking(
            booking,
            rembourse: choix.rembourse,
            montant: choix.montant,
          );
    }
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
        Icons.home_outlined,
        color: Colors.grey.shade400,
        size: 32,
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
    BlocProvider.of<ReservationCubit>(context).fetchData();
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

  void _navigateToClientDetails(Client client) {
    GoRouter.of(context).push(Routes.clientDetail.replaceFirst(":id", client.id.toString()));
  }

  void _navigateToRealestate(Realestate realestate) {
    GoRouter.of(context).push(
      Routes.homeImmobilier.replaceAll(
        ":id",
        realestate.id.toString(),
      ),
    );
  }

  void viewContract(String contract) {
    context.read<ReservationCubit>().viewDocument(contract);
  }

  void listener(BuildContext context, ReservationState state) {
    if(state.actionStatus==AppStatus.success){
      showToast("Réservation supprimée.", context);
    }else if(state.actionStatus==AppStatus.error){
      showToast(state.error ?? "La suppression a échoué.", context,
          type: ToastificationType.error, second: 4);
    }
  }
}