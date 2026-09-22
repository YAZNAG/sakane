import 'package:immobilier/repository/repository.dart';
import 'package:immobilier/models/booking.dart';
import 'package:immobilier/components/bouton_export.dart';
import 'package:immobilier/components/tableaux_export.dart';
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
import 'package:immobilier/features/gestion_immobilier/immobilier_by_status/cubit/immobilier_by_status_cubit.dart';
import 'package:immobilier/models/manager.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:toastification/toastification.dart';

import '../../../../components/form_field.dart';
import '../../../../core/validator/validator.dart';
import '../../../../models/realestate.dart';
import '../../../../routes.dart';
import '../../home/cubit/gestion_immobilier_cubit.dart';
import 'components/prolonger_dialogue.dart';
import 'components/shrink_dialogue.dart';
import 'package:immobilier/core/constants/app_colors.dart';
import 'package:immobilier/features/caisses/ui/garantir_caisse.dart';


class ImmobilierByStatusPage extends StatefulWidget {
  String status;

  /// Famille de biens : on traverse une famille avant d'atteindre un etat.
  final String? type;

  /// Dossier de rangement, lorsque la navigation passe par lui.
  final String? dossier;

  ImmobilierByStatusPage({required this.status, this.type, this.dossier});

  static Widget page(String status, {String? type, String? dossier}) {
    return BlocProvider<ImmobilierByStatusCubit>(
      create: (ctx) =>
          ImmobilierByStatusCubit(status, type, dossier)..fetchData(),
      child: ImmobilierByStatusPage(
        status: status,
        type: type,
        dossier: dossier,
      ),
    );
  }

  @override
  State<ImmobilierByStatusPage> createState() => _ImmobilierByStatusPageState();
}

class _ImmobilierByStatusPageState extends State<ImmobilierByStatusPage> {

  /// Sur la page des biens réservés : 'encours', 'aujourdhui' ou 'avenir'.
  String _vue = 'encours';
  List<Booking>? _arriveesAujourdhui;
  List<Booking>? _arriveesAVenir;
  bool _erreurArrivees = false;

  @override
  void initState() {
    super.initState();
    if (widget.status == 'reserved') _chargerArrivees();
  }

  Future<void> _chargerArrivees() async {
    final depot = Dependencies.get<Repository>();
    try {
      final listes = await Future.wait([
        depot.fetchArrivees('today', type: widget.type, dossier: widget.dossier),
        depot.fetchArrivees('upcoming', type: widget.type, dossier: widget.dossier),
      ]);
      if (!mounted) return;
      setState(() {
        _arriveesAujourdhui = listes[0];
        _arriveesAVenir = listes[1];
        _erreurArrivees = false;
      });
    } catch (_) {
      if (mounted) setState(() => _erreurArrivees = true);
    }
  }

  /// En cours, Aujourd'hui, À venir : chaque vue avec son nombre.
  Widget _selecteurVue(ImmobilierByStatusState state) {
    final couleur = colors['reserved'] ?? AppColors.primaryColor;

    Widget option(String cle, String libelle, IconData icone, int? nombre) {
      final actif = _vue == cle;
      return Expanded(
        child: GestureDetector(
          onTap: () => setState(() => _vue = cle),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
            decoration: BoxDecoration(
              color: actif ? Colors.white : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              boxShadow: actif
                  ? const [BoxShadow(color: Color(0x1417262E), blurRadius: 6, offset: Offset(0, 1))]
                  : null,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icone, size: 16, color: actif ? couleur : const Color(0xFF6B7B84)),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        libelle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: actif ? FontWeight.bold : FontWeight.w500,
                          color: actif ? couleur : const Color(0xFF4A5B64),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
                  decoration: BoxDecoration(
                    color: actif ? couleur : const Color(0xFFD5DDE2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    nombre == null ? '…' : '$nombre',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: actif ? Colors.white : const Color(0xFF28414F),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: const Color(0xFFF0F3F5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            option('encours', 'En cours', Icons.event_busy,
                state.fetchStatus == AppStatus.success ? (state.realestates?.length ?? 0) : null),
            option('aujourdhui', "Aujourd'hui", Icons.login, _arriveesAujourdhui?.length),
            option('avenir', 'À venir', Icons.update, _arriveesAVenir?.length),
          ],
        ),
      ),
    );
  }

  Widget _listeArrivees() {
    final liste = _vue == 'aujourdhui' ? _arriveesAujourdhui : _arriveesAVenir;

    if (_erreurArrivees) {
      return MyErrorWidget(
        error: "Les réservations n'ont pas pu être chargées.",
        action: AppStrings.tryAgain,
        actionCLick: _chargerArrivees,
      );
    }
    if (liste == null) return Center(child: MyLoadingIndicator());

    if (liste.isEmpty) {
      return RefreshIndicator(
        onRefresh: _chargerArrivees,
        child: ListView(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 60, 32, 32),
              child: Column(
                children: [
                  Icon(Icons.event_available, size: 56, color: Colors.grey.shade400),
                  const SizedBox(height: 12),
                  Text(
                    _vue == 'aujourdhui'
                        ? "Aucune arrivée prévue aujourd'hui"
                        : 'Aucune réservation à venir',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _chargerArrivees,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: liste.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, i) => _carteArrivee(liste[i]),
      ),
    );
  }

  Widget _carteArrivee(Booking b) {
    final bien = b.realestate;
    final client = [b.client?.firstName, b.client?.lastName].whereType<String>().join(' ').trim();
    final nuits = (b.checkin != null && b.checkout != null)
        ? b.checkout!.difference(b.checkin!).inDays
        : 0;
    final image = (bien?.media?.isNotEmpty ?? false) ? bien!.media!.first.url : null;
    final aujourdhui = _vue == 'aujourdhui';
    final accent = aujourdhui ? const Color(0xFF157F76) : const Color(0xFF3D5AA8);
    final maintenant = DateTime.now();
    final dans = b.checkin == null
        ? null
        : DateTime(b.checkin!.year, b.checkin!.month, b.checkin!.day)
            .difference(DateTime(maintenant.year, maintenant.month, maintenant.day))
            .inDays;
    final etiquette = aujourdhui
        ? "Arrive aujourd'hui"
        : (dans == 1 ? 'Demain' : (dans == null ? 'À venir' : 'Dans $dans jours'));

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: bien?.id == null
            ? null
            : () async {
                final modifie = await GoRouter.of(context)
                    .push(Routes.homeImmobilier.replaceFirst(':id', '${bien!.id}'));
                if (modifie == true && mounted) _chargerArrivees();
              },
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade200),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: image != null
                    ? Image.network(image,
                        width: 64,
                        height: 64,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _vignetteArrivee())
                    : _vignetteArrivee(),
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
                            bien?.title ?? 'Bien',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: .12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(etiquette,
                              style: TextStyle(
                                  fontSize: 11, fontWeight: FontWeight.bold, color: accent)),
                        ),
                      ],
                    ),
                    if (client.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.person_outline, size: 14, color: Colors.grey.shade600),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(client,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 13, color: Colors.grey.shade800)),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.event, size: 14, color: Colors.grey.shade600),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            '${b.checkin?.formattedDateFr ?? '-'} → ${b.checkout?.formattedDateFr ?? '-'}'
                            '${nuits > 0 ? '  •  $nuits nuit${nuits > 1 ? 's' : ''}' : ''}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12.5, color: Colors.grey.shade800),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (b.heureArrivee != null) ...[
                          Icon(Icons.schedule, size: 14, color: Colors.grey.shade600),
                          const SizedBox(width: 4),
                          Text('Arrivée ${b.heureArrivee}',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                        ],
                        const Spacer(),
                        Text('${(b.amount ?? 0).toStringAsFixed(0)} MAD',
                            style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primaryColor)),
                      ],
                    ),
                    if ((b.creePar ?? '').isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Text('Créée par ${b.creePar}',
                            style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600)),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _vignetteArrivee() => Container(
        width: 64,
        height: 64,
        color: const Color(0xFFEEF2F5),
        child: const Icon(Icons.home_outlined, color: Color(0xFF98A6AE)),
      );


  TableauExportable? _tableauExport(String titre) {
    if (widget.status == 'reserved' && _vue != 'encours') {
      final arrivees = _vue == 'aujourdhui' ? _arriveesAujourdhui : _arriveesAVenir;
      if (arrivees == null) return null;
      return tableauReservations(
          _vue == 'aujourdhui' ? "Arrivées d'aujourd'hui" : 'Réservations à venir', arrivees);
    }
    final liste = context.read<ImmobilierByStatusCubit>().state.realestates;
    if (liste == null) return null;
    return tableauBiens(titre, liste);
  }

  Manager manager=Dependencies.get<Manager>();

  final titles = {
    "available": "Appartements disponibles",
    "reserved": "Appartements réservés",
    "cleaning": "Appartements en nettoyage"
  };

  final colors = {
    "available": Colors.green.shade600,
    "reserved": Colors.red.shade600,
    "cleaning": Colors.orange.shade600
  };

  final icons = {
    "available": Icons.check_circle_outline,
    "reserved": Icons.event_busy,
    "cleaning": Icons.cleaning_services
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(
          titles[widget.status] ?? "",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: colors[widget.status] ?? AppColors.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        actions: [
          BoutonExport(tableau: () => _tableauExport(titles[widget.status] ?? 'Biens')),
        ],
      ),
      body: BlocConsumer<ImmobilierByStatusCubit, ImmobilierByStatusState>(
        listener: _listener,
        builder: (context, state) {
          if (widget.status != 'reserved') return _buildContent(state);
          return Column(
            children: [
              _selecteurVue(state),
              Expanded(
                child: _vue == 'encours' ? _buildContent(state) : _listeArrivees(),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildContent(ImmobilierByStatusState state) {
    if (state.fetchStatus == AppStatus.loading) {
      return Center(child: MyLoadingIndicator());
    } else if (state.fetchStatus == AppStatus.error) {
      return Center(
        child: MyErrorWidget(
          error: state.error ?? "Erreur",
          action: AppStrings.tryAgain,
          actionCLick: () {
            context.read<ImmobilierByStatusCubit>().fetchData();
          },
        ),
      );
    } else if (state.fetchStatus == AppStatus.success) {
      final realestates = state.realestates ?? [];

      if (realestates.isEmpty) {
        return _buildEmptyState();
      }

      return RefreshIndicator(
        onRefresh: () async {
          context.read<ImmobilierByStatusCubit>().fetchData();
        },
        child: ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: realestates.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            return _buildRealestateCard(realestates[index]);
          },
        ),
      );
    }
    return const SizedBox();
  }

  Widget _buildEmptyState() {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(32),
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: (colors[widget.status] ?? Colors.blue).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icons[widget.status] ?? Icons.apartment,
                size: 64,
                color: colors[widget.status] ?? Colors.blue.shade600,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              "Aucun appartement",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _getEmptyMessage(),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getEmptyMessage() {
    switch (widget.status) {
      case "available":
        return "Tous les appartements sont actuellement réservés ou en nettoyage";
      case "reserved":
        return "Aucune réservation en cours pour le moment";
      case "cleaning":
        return "Aucun appartement en cours de nettoyage";
      default:
        return "Aucun résultat trouvé";
    }
  }

  Widget _buildRealestateCard(Realestate realestate) {
    final booking = realestate.booking;
    final client = booking?.client;
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
                  final modifie = await GoRouter.of(context).push(Routes.homeImmobilier
                      .replaceFirst(":id", realestate.id.toString()));
                  if (modifie == true && mounted) {
                    context.read<ImmobilierByStatusCubit>().fetchData();
                  }
                },
                borderRadius: BorderRadius.circular(8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: realestate.media?.isNotEmpty == true
                      ? Image.network(
                    realestate.media!.first.url ?? "",
                    width: 70,
                    height: 70,
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
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    if (client != null)
                      Row(
                        children: [
                          Icon(
                            Icons.person_outline,
                            size: 16,
                            color: Colors.grey.shade600,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              clientName,
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
                    if (booking?.checkin != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.calendar_today,
                            size: 14,
                            color: Colors.grey.shade600,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            "Arrivée: ${booking?.checkin?.formattedDateFr ?? '-'}",
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              // Checkout Badge
              if (widget.status == "reserved" && booking?.checkout != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Column(
                    children: [
                      Text(
                        "Départ",
                        style: TextStyle(
                          fontSize: 10,
                          color: AppColors.primaryColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        booking?.checkout?.formattedDateFr ?? '-',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),

          const SizedBox(height: 14),

          // Action Buttons based on status
          _buildActionButtons(realestate),
        ],
      ),
    );
  }

  Widget _buildActionButtons(Realestate realestate) {
    if (widget.status == "available" && (realestate.hasTodayBooking??false) && manager.can(AppPermission.confirmCheckin)) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () => _confirmCheckin(realestate),
          icon: const Icon(Icons.login, size: 18),
          label: const Text("Confirmer le check-in"),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.teal.shade600,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            elevation: 2,
          ),
        ),
      );
    } else if (widget.status == "available" && manager.can(AppPermission.returnToCleaning)) {
      // un appartement propre peut etre remis en nettoyage si le menage
      // s'avere insuffisant
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: () => _returnToCleaning(realestate),
          icon: const Icon(Icons.cleaning_services_outlined, size: 18),
          label: const Text("Remettre en nettoyage"),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.orange.shade700,
            side: BorderSide(color: Colors.orange.shade400),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      );
    } else if (widget.status == "cleaning" &&
        realestate.aNettoyer &&
        manager.can(AppPermission.startCleaning)) {
      // L'appartement attend : la femme de menage declare qu'elle commence.
      final attente = realestate.attenteDepuisDepart;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (attente != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.blueGrey.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.hourglass_empty,
                      size: 15, color: Colors.blueGrey.shade700),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      "En attente depuis $attente",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.blueGrey.shade800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _startCleaning(realestate),
              icon: const Icon(Icons.play_arrow_rounded, size: 20),
              label: const Text("Commencer le nettoyage"),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 2,
              ),
            ),
          ),
        ],
      );
    } else if (widget.status == "cleaning" && manager.can(AppPermission.finishCleaning)) {
      final depuis = realestate.dureeEnCours;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (depuis != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.timer_outlined,
                      size: 15, color: Colors.orange.shade800),
                  const SizedBox(width: 6),
                  Text(
                    "Nettoyage en cours depuis $depuis",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.orange.shade900,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
          SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () => _finishCleaning(realestate),
          icon: const Icon(Icons.done_all, size: 18),
          label: const Text("Terminer le nettoyage"),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.teal.shade600,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            elevation: 2,
          ),
        ),
          ),
        ],
      );
    } else if (widget.status == "reserved" ) {
      return Row(
        children: [
          if(manager.can(AppPermission.extendReservation))
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => _prolonger(realestate),
              icon: const Icon(Icons.update, size: 18),
              label: const Text("Prolonger"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade600,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 2,
              ),
            ),
          ),
          const SizedBox(width: 8),
          if(manager.can(AppPermission.reduceReservation))
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => _shrinkReservation(realestate),
              icon: const Icon(FontAwesomeIcons.minus, size: 16),
              label: const Text("Diminuer"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange.shade600,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 2,
              ),
            ),
          ),
        ],
      );
    }
    return const SizedBox();
  }

  Widget _buildImagePlaceholder() {
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

  void _confirmCheckin(Realestate realestate) async {
    var result = await showDialogueQuestion(
      context,
      "Voulez-vous vraiment confirmer le check-in pour cet appartement ?",
    );
    if (result != null && result) {
      context.read<ImmobilierByStatusCubit>().confirmCheckin(realestate);
    }
  }

  /// La femme de menage declare qu'elle commence le nettoyage de ce bien.
  void _startCleaning(Realestate realestate) async {
    final confirme = await showDialogueQuestion(
      context,
      "Commencer le nettoyage de ${realestate.title ?? 'ce bien'} ?",
    );
    if (confirme == true && mounted) {
      context.read<ImmobilierByStatusCubit>().startCleaning(realestate);
    }
  }

  /// Remet un appartement en nettoyage, avec un motif facultatif.
  void _returnToCleaning(Realestate realestate) async {
    final motif = TextEditingController();
    final confirme = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text("Remettre en nettoyage"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              realestate.title ?? "Ce bien",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              "Les femmes de ménage seront prévenues par WhatsApp.",
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: motif,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: "Motif (facultatif)",
                hintText: "Ex : salle de bain à revoir",
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Annuler"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade700),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Confirmer", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirme == true && mounted) {
      context
          .read<ImmobilierByStatusCubit>()
          .returnToCleaning(realestate, motif: motif.text.trim());
    }
    motif.dispose();
  }

  void _finishCleaning(Realestate realestate) async {
    var result = await showDialogueQuestion(
      context,
      "Voulez-vous vraiment marquer cet appartement comme nettoyé ?",
    );
    if (result != null && result) {
      context.read<ImmobilierByStatusCubit>().finishCleaning(realestate);
    }
  }


  void _prolonger(Realestate realestate) async {
    final from = realestate.booking!.checkout!;
    final maxDate = realestate.nextCheckin ?? DateTime.now().add(const Duration(days: 365));

    DateTime? checkoutChoisi;
    double? prixChoisi;

    await showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return ProlongerReservationDialog(
          from: from,
          maxDate: maxDate,
          initialPrice: (realestate.booking?.nightPrice??realestate.price!).toDouble(),
          // Les valeurs sont recueillies ici, mais l'envoi attend la
          // fermeture de la fenetre : la caisse se verifie ensuite, et
          // deux fenetres ne peuvent se chevaucher.
          onConfirm: (checkout, price) {
            checkoutChoisi = checkout;
            prixChoisi = price;
          },
        );
      },
    );

    if (checkoutChoisi == null || prixChoisi == null) return;

    // Le total de la prolongation entre dans la caisse de l'agent : une
    // entree n'a rien a verifier, la caisse s'ouvre d'elle-meme.

    if (!mounted) return;
    context.read<ImmobilierByStatusCubit>().prolonger(
      checkoutChoisi!,
      prixChoisi!,
      realestate.booking!.id!,
    );
  }


  void _shrinkReservation(Realestate realestate) async {
    final originalCheckout = realestate.booking!.checkout!;

    DateTime? checkoutChoisi;
    double remboursement = 0;

    await showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return ShrinkReservationDialog(
          originalCheckout: originalCheckout,
          originalPrice: (realestate.price??0).toDouble(),
          onConfirm: (newCheckout, refundPrice) {
            checkoutChoisi = newCheckout;
            remboursement = refundPrice;
          },
        );
      },
    );

    if (checkoutChoisi == null) return;

    // Un remboursement sort des especes : la caisse doit etre ouverte et
    // les contenir, sans quoi le serveur refuse le mouvement en silence.
    if (remboursement > 0) {
      if (!mounted) return;
      final prete = await garantirCaisseOuverte(
        context,
        motif: "le remboursement de cette réservation",
        sortie: remboursement,
      );
      if (!prete || !mounted) return;
    }

    if (!mounted) return;
    context.read<ImmobilierByStatusCubit>().shrink(
      checkoutChoisi!,
      remboursement,
      realestate.booking!.id!,
    );
  }

  void _listener(BuildContext context, ImmobilierByStatusState state) {
    if (state.actionStatus == AppStatus.success) {
      showToast(AppStrings.success, context);
      context.read<ImmobilierByStatusCubit>().fetchData();
    } else if (state.actionStatus == AppStatus.error) {
      showToast("", description: state.error ?? AppStrings.error, context,type: ToastificationType.error);
    }
  }
}