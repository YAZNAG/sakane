import 'package:immobilier/core/constants/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:immobilier/components/error_widget.dart';
import 'package:immobilier/components/form_field.dart';
import 'package:immobilier/components/loading_indicator.dart';
import 'package:immobilier/components/statut_bien_chip.dart';
import 'package:immobilier/models/statut_jour.dart';
import 'package:immobilier/core/constants/app_strings.dart';
import 'package:immobilier/core/constants/enums/app_status.dart';
import 'package:immobilier/core/utils/show_toast.dart';
import 'package:immobilier/features/immobilier/add_reservation/cubit/add_reservation_cubit.dart';
import 'package:immobilier/models/booking.dart';
import 'package:immobilier/models/client.dart';
import 'package:immobilier/models/realestate.dart';
import 'package:signature/signature.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:toastification/toastification.dart';

import '../../../../core/utils/show_error_dialogue.dart';
import '../../../../core/validator/validator.dart';
import '../../../../routes.dart';
import 'package:open_file/open_file.dart';
import 'package:immobilier/core/dependencies/dependencies.dart';
import 'package:immobilier/repository/repository.dart';
import 'package:immobilier/core/extensions/extension_on_date.dart';
import 'package:immobilier/core/constants/types_invites.dart';
import 'package:immobilier/features/immobilier/contrat/ui/visionneuse_contrat.dart';
import 'package:immobilier/features/caisses/ui/garantir_caisse.dart';
import 'dart:typed_data';
import 'package:immobilier/features/immobilier/add_reservation/pre_remplissage_reservation.dart';
import 'package:immobilier/models/airbnb.dart';
import 'package:immobilier/features/airbnb/ui/components/outils_airbnb.dart'
    show CouleursAirbnb;

class AddReservationPage extends StatefulWidget {
  /// Dates choisies sur le calendrier, ou réservation Airbnb dont on
  /// crée le contrat. Sans lui, le formulaire est vierge.
  final PreRemplissageReservation? preRemplissage;

  AddReservationPage({Key? key, this.preRemplissage}) : super(key: key);

  static Widget page(int id, {PreRemplissageReservation? preRemplissage}) {
    return BlocProvider<AddReservationCubit>(
      create: (context) => AddReservationCubit(id)..fetchData(),
      child: AddReservationPage(preRemplissage: preRemplissage),
    );
  }

  @override
  State<AddReservationPage> createState() => _AddReservationPageState();
}

class _AddReservationPageState extends State<AddReservationPage> {
  // Step navigation
  final PageController _pageController = PageController();
  int _currentStep = 0;
  static const int _totalSteps = 3;

  // Step 2 form
  final _formKey = GlobalKey<FormState>();
  final _nbGuestsController = TextEditingController();
  final _nghitPriceController = TextEditingController();
  final _remarquesController = TextEditingController();

  /// Montant verse par Airbnb pour tout le sejour (mode Airbnb).
  final _montantAirbnbController = TextEditingController();
  bool _apercuEnCours = false;

  /// « Appliquer la facture » des la creation : le total de la
  /// reservation est alors T.T.C, la TVA y est comprise.
  bool _appliquerFacture = false;
  final _tvaFactureController = TextEditingController(text: "20");

  /// Reservation Airbnb dont on cree le contrat, sinon null.
  SejourAirbnb? get _airbnb =>
      widget.preRemplissage?.estAirbnb == true ? widget.preRemplissage!.sejourAirbnb : null;

  bool get _modeAirbnb => _airbnb != null;

  /// Paraphe recueilli depuis la visionneuse, s'il l'a ete la.
  Uint8List? _parapheRecueilli;
  bool _isPriceInitialised = false;
  DateTime? _checkInDate;
  DateTime? _checkOutDate;

  /// Heures convenues avec le client. Facultatives : sans elles, les
  /// heures d'usage de l'agence s'appliquent, comme auparavant.
  TimeOfDay? _heureArrivee;
  TimeOfDay? _heureDepart;

  /// Heures d'usage de l'agence, reglees par l'administrateur
  /// (« Heures par defaut ») : elles pre-remplissent le formulaire.
  TimeOfDay _arriveeUsage = const TimeOfDay(hour: 14, minute: 0);
  TimeOfDay _departUsage = const TimeOfDay(hour: 12, minute: 0);

  @override
  void initState() {
    super.initState();
    _preRemplir();
    _chargerHeuresParDefaut();
  }

  /// Dates du calendrier ou de la reservation Airbnb.
  void _preRemplir() {
    final pre = widget.preRemplissage;
    if (pre == null) return;
    final arrivee = pre.arrivee, depart = pre.depart;
    if (arrivee != null) {
      _checkInDate = _normalizeDate(arrivee);
      _focusedDay = _checkInDate!;
      if (depart != null && _normalizeDate(depart).isAfter(_checkInDate!)) {
        _checkOutDate = _normalizeDate(depart);
      }
    }
    final airbnb = _airbnb;
    if (airbnb != null) {
      _remarquesController.text =
          "Réservation Airbnb${(airbnb.code ?? '').isEmpty ? '' : ' ${airbnb.code}'}";
    }
  }

  // ─── Mode Airbnb ───────────────────────────────────────────────────────────

  int get _nuitsSelectionnees => (_checkInDate != null && _checkOutDate != null)
      ? _checkOutDate!.difference(_checkInDate!).inDays
      : 0;

  /// Les dates ne sont plus celles de la reservation Airbnb.
  bool get _datesAirbnbModifiees {
    final a = _airbnb;
    if (a == null) return false;
    return _checkInDate == null ||
        _checkOutDate == null ||
        !isSameDay(_checkInDate, a.du) ||
        !isSameDay(_checkOutDate, a.au);
  }

  static double? _lireMontant(String texte) =>
      double.tryParse(texte.trim().replaceAll(' ', '').replaceAll(',', '.'));

  /// « 450 » ou « 433.33 ».
  static String _formatPrix(double v) {
    if (v == v.roundToDouble()) return v.toInt().toString();
    return v.toStringAsFixed(2);
  }

  /// Montant Airbnb saisi : le prix par nuit en decoule.
  void _surMontantAirbnb(String _) {
    final montant = _lireMontant(_montantAirbnbController.text);
    final nuits = _nuitsSelectionnees;
    if (montant != null && montant > 0 && nuits > 0) {
      _nghitPriceController.text = _formatPrix(montant / nuits);
    }
    setState(() {});
  }

  /// Prix par nuit saisi : le montant Airbnb suit.
  void _surPrixNuit(String _) {
    if (!_modeAirbnb) return;
    final prix = _lireMontant(_nghitPriceController.text);
    final nuits = _nuitsSelectionnees;
    if (prix != null && nuits > 0) {
      _montantAirbnbController.text = _formatPrix(prix * nuits);
    }
    setState(() {});
  }

  /// Les nuits ont change : le montant Airbnb reste, le prix s'adapte.
  void _recalculerDepuisMontant() {
    if (!_modeAirbnb) return;
    final montant = _lireMontant(_montantAirbnbController.text);
    final nuits = _nuitsSelectionnees;
    if (montant != null && montant > 0 && nuits > 0) {
      _nghitPriceController.text = _formatPrix(montant / nuits);
    }
  }

  Widget _encadreAirbnb() {
    final a = _airbnb!;
    final code = (a.code ?? '').trim();
    final tel = (a.telephone4 ?? '').trim();
    final reperes = [
      if (code.isNotEmpty) "Code $code",
      if (tel.isNotEmpty) "téléphone se terminant par $tel",
    ];
    var reperesTexte = reperes.join(', ');
    if (reperesTexte.isNotEmpty) {
      reperesTexte = "${reperesTexte[0].toUpperCase()}${reperesTexte.substring(1)}. ";
    }
    const rose = Color(0xFFFF5A5F);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: rose.withValues(alpha: .07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: rose.withValues(alpha: .35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FaIcon(FontAwesomeIcons.airbnb, color: rose, size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Contrat d'une réservation Airbnb",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  ("Le client a déjà payé sur Airbnb : le montant entre automatiquement "
                          "dans la caisse Airbnb. Renseignez seulement le client, le montant payé "
                          "et, si possible, sa signature. "
                          "$reperesTexte")
                      .trim(),
                  style: TextStyle(fontSize: 12.5, color: Colors.grey.shade800, height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Avertit quand les dates s'ecartent de celles d'Airbnb.
  Widget _avertissementDatesAirbnb() {
    if (!_datesAirbnbModifiees) return SizedBox();
    final a = _airbnb!;
    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(bottom: 16),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade300),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.orange.shade800, size: 20),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              "Les dates ne correspondent plus à la réservation Airbnb "
              "(du ${_formatDate(a.du)} au ${_formatDate(a.au)}). "
              "Vérifiez-les avant de créer le contrat.",
              style: TextStyle(fontSize: 12.5, color: Colors.orange.shade900),
            ),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _checkInDate = _normalizeDate(a.du);
                _checkOutDate = _normalizeDate(a.au);
                _focusedDay = _checkInDate!;
                _recalculerDepuisMontant();
              });
            },
            child: Text("Rétablir"),
          ),
        ],
      ),
    );
  }

  Future<void> _chargerHeuresParDefaut() async {
    TimeOfDay? lire(String h) {
      final p = h.split(':');
      if (p.length < 2) return null;
      final heure = int.tryParse(p[0]), minute = int.tryParse(p[1]);
      if (heure == null || minute == null) return null;
      return TimeOfDay(hour: heure, minute: minute);
    }

    try {
      final h = await Dependencies.get<Repository>().heuresParDefaut();
      if (!mounted) return;
      setState(() {
        _arriveeUsage = lire(h.arrivee) ?? _arriveeUsage;
        _departUsage = lire(h.depart) ?? _departUsage;
        // Seulement si l'agent n'a encore rien choisi.
        _heureArrivee ??= _arriveeUsage;
        _heureDepart ??= _departUsage;
      });
    } catch (_) {
      // Hors ligne : les champs restent vides, le contrat prendra les
      // heures d'usage.
    }
  }
  DateTime _focusedDay = DateTime.now();
  String? _selectedTypeGuest;

  /// La valeur enregistree reste le code anglais attendu par la base ;
  /// seul l'affichage change.
  final List<String> _guestTypes = TypeInvite.codes;

  List<DateTime> _reservedDates = [];
  Map<DateTime, Color> _dateColors = {};
  Map<DateTime, List<Color>> _sharedDateColors = {};
  List<DateTimeRange> _reservedRanges = [];
  final List<Color> _reservationColors = [
    Colors.amber.shade300,
    Colors.indigo.shade300,
  ];

  /// Pour chaque plage de [_reservedRanges] : réservée sur Airbnb ?
  List<bool> _reservedAirbnb = [];

  /// Jours réservés sur Airbnb : rose Airbnb.
  static const Color _couleurAirbnb = CouleursAirbnb.rose;

  bool get _aDesJoursAirbnb => _reservedAirbnb.contains(true);

  /// Nuits reservees sur Airbnb (depart exclu) : personne, agent ou
  /// administrateur, ne peut y ajouter une reservation. Le sejour dont on
  /// cree le contrat (mode Airbnb) en est deja ecarte.
  Set<DateTime> _nuitsAirbnb = {};

  /// Premiere nuit reservee sur Airbnb entre [debut] et [fin] (depart
  /// exclu) ; sans [fin], seule la nuit de [debut] est examinee.
  DateTime? _premiereNuitAirbnb(DateTime debut, DateTime? fin) {
    if (_nuitsAirbnb.isEmpty) return null;
    var nuit = _normalizeDate(debut);
    final limite = fin == null ? nuit.add(const Duration(days: 1)) : _normalizeDate(fin);
    while (nuit.isBefore(limite)) {
      if (_nuitsAirbnb.contains(nuit)) return nuit;
      nuit = DateTime(nuit.year, nuit.month, nuit.day + 1);
    }
    return null;
  }

  void _signalerNuitAirbnb(DateTime nuit) {
    showToast(
      "Dates réservées sur Airbnb",
      description:
          "Le ${_formatDate(nuit)} est réservé sur Airbnb : choisissez d'autres dates.",
      context,
      type: ToastificationType.warning,
      second: 3,
    );
  }

  /// Statut du jour du bien : celui fourni par le serveur, ou a defaut
  /// « Désactivé » quand le bien l'est.
  StatutJour? _statutDuBien(Realestate? bien) {
    if (bien == null) return null;
    if (bien.statutJour != null) return bien.statutJour;
    if (bien.estDesactive) {
      return const StatutJour(code: StatutJour.desactive, libelle: 'Désactivé');
    }
    return null;
  }

  bool _bienDesactive(Realestate? bien) =>
      bien != null && (bien.estDesactive || bien.statutJour?.estDesactive == true);

  /// Un bien desactive ne prend plus de reservation : le serveur les
  /// refuse. On le dit avant que l'agent ne remplisse le formulaire.
  Widget _avertissementDesactive() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.block, color: Colors.red.shade700, size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              "Ce bien est désactivé : les réservations sont refusées tant "
              "qu'il n'est pas réactivé.",
              style: TextStyle(
                fontSize: 13,
                height: 1.35,
                fontWeight: FontWeight.w600,
                color: Colors.red.shade800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Step 3 signature
  final SignatureController _signatureController = SignatureController(
    penStrokeWidth: 5,
    penColor: Colors.black,
    exportBackgroundColor: Colors.white,
  );

  @override
  void dispose() {
    _pageController.dispose();
    _nbGuestsController.dispose();
    _nghitPriceController.dispose();
    _remarquesController.dispose();
    _montantAirbnbController.dispose();
    _tvaFactureController.dispose();
    _signatureController.dispose();
    super.dispose();
  }

  /// Dernier prix place d'office dans le champ : tant que le champ le
  /// contient, l'utilisateur n'y a pas touche et on peut le remplacer.
  String? _prixPropose;

  /// Propose le prix moyen du sejour quand il comprend des prix
  /// personnalises, sans ecraser une saisie de l'utilisateur.
  Future<void> _proposerPrixSejour() async {
    // Contrat Airbnb : le prix vient du montant verse par Airbnb.
    if (_modeAirbnb) return;
    final arrivee = _checkInDate, depart = _checkOutDate;
    final cubit = context.read<AddReservationCubit>();
    final bienId = cubit.state.realestateId;
    if (arrivee == null || depart == null || bienId == null) return;
    if (!depart.isAfter(arrivee)) return;
    final attendu = _prixPropose ?? cubit.state.realestate?.price?.toString();
    if (_nghitPriceController.text != attendu) return;
    try {
      final tarif = await Dependencies.get<Repository>()
          .tarifSejour(bienId, arrivee: arrivee, depart: depart);
      if (!mounted || _checkInDate != arrivee || _checkOutDate != depart) return;
      if (_nghitPriceController.text != attendu) return;
      final base = cubit.state.realestate?.price?.toString() ?? attendu ?? '';
      final propose = tarif.contientPrixSpecial && tarif.prixMoyen > 0
          ? tarif.prixMoyen.round().toString()
          : base;
      setState(() {
        _nghitPriceController.text = propose;
        _prixPropose = propose;
      });
    } catch (_) {
      // Sans tarif, le prix habituel reste en place.
    }
  }

  // ─── Step navigation ───────────────────────────────────────────────────────

  void _goToStep(int step) {
    setState(() => _currentStep = step);
    _pageController.animateToPage(
      step,
      duration: Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _nextStep() => _goToStep(_currentStep + 1);
  void _prevStep() => _goToStep(_currentStep - 1);

  bool _validateStep1() {
    final booking = context.read<AddReservationCubit>().state.booking;
    if (booking?.client == null) {
      showToast(
        "",
        description: "Veuillez sélectionner un client",
        context,
        type: ToastificationType.warning,
        second: 2,
      );
      return false;
    }
    if (booking!.client!.listeNoire != null) {
      _signalerListeNoire(booking.client!);
      return false;
    }
    return true;
  }

  /// Un client sur liste noire ne peut pas réserver.
  void _signalerListeNoire(Client client) {
    showToast(
      "Liste noire",
      description: messageListeNoire(client),
      context,
      type: ToastificationType.error,
      second: 4,
    );
  }

  bool _validateStep2() {
    if (!_formKey.currentState!.validate()) return false;
    if (_checkInDate == null || _checkOutDate == null) {
      showToast(
        "",
        description: "Veuillez sélectionner les dates",
        context,
        type: ToastificationType.warning,
        second: 2,
      );
      return false;
    }
    // Dates venues d'ailleurs (calendrier) : jamais sur une reservation
    // Airbnb, quel que soit le role.
    final nuitAirbnb = _premiereNuitAirbnb(_checkInDate!, _checkOutDate);
    if (nuitAirbnb != null) {
      _signalerNuitAirbnb(nuitAirbnb);
      return false;
    }
    return true;
  }

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(
          "Nouvelle réservation",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        centerTitle: true,
        elevation: 0,
        foregroundColor: Colors.white,
        backgroundColor: AppColors.primaryColor,
      ),
      body: BlocConsumer<AddReservationCubit, AddReservationState>(
        listener: _listener,
        builder: (context, state) {
          if (state.fetchStatus == AppStatus.loading) {
            return Center(child: MyLoadingIndicator());
          }
          if (state.fetchStatus == AppStatus.error) {
            return MyErrorWidget(
              error: state.error ?? "Error",
              action: AppStrings.tryAgain,
              actionCLick: _fetchData,
            );
          }
          if (state.fetchStatus == AppStatus.success) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _updateReservedDates(state.realestate!);
            });
            return Column(
              children: [
                _buildStepIndicator(),
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    physics: NeverScrollableScrollPhysics(),
                    children: [
                      _buildStep1(state),
                      _buildStep2(state),
                      _buildStep3(state),
                    ],
                  ),
                ),
              ],
            );
          }
          return SizedBox();
        },
      ),
    );
  }

  // ─── Step indicator ────────────────────────────────────────────────────────

  Widget _buildStepIndicator() {
    final labels = ["Client", "Réservation", "Signature"];
    return Container(
      color: Colors.white,
      padding: EdgeInsets.symmetric(vertical: 16, horizontal: 24),
      child: Row(
        children: List.generate(_totalSteps * 2 - 1, (i) {
          if (i.isOdd) {
            // connector line
            final stepIndex = i ~/ 2;
            final passed = _currentStep > stepIndex;
            return Expanded(
              child: Container(
                height: 2,
                color: passed ? AppColors.primaryColor : Colors.grey.shade300,
              ),
            );
          }
          final step = i ~/ 2;
          final isActive = _currentStep == step;
          final isDone = _currentStep > step;
          return Column(
            children: [
              AnimatedContainer(
                duration: Duration(milliseconds: 250),
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDone
                      ? AppColors.primaryColor
                      : isActive
                      ? AppColors.primaryColor
                      : Colors.grey.shade200,
                ),
                child: Center(
                  child: isDone
                      ? Icon(Icons.check, size: 16, color: Colors.white)
                      : Text(
                          '${step + 1}',
                          style: TextStyle(
                            color: isActive
                                ? Colors.white
                                : Colors.grey.shade500,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                ),
              ),
              SizedBox(height: 4),
              Text(
                labels[step],
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                  color: isActive
                      ? AppColors.primaryColor
                      : Colors.grey.shade500,
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  // ─── Step 1 — Client selection ─────────────────────────────────────────────

  Widget _buildStep1(AddReservationState state) {
    final clients = state.clients ?? [];
    final selectedClient = state.booking?.client;
    final searchQuery = state.searchQuery ?? '';

    return Column(
      children: [
        // Property mini-header
        // _buildPropertyMiniHeader(state.realestate!),
        if (_bienDesactive(state.realestate))
          Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: _avertissementDesactive(),
          ),
        if (_modeAirbnb)
          Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: _encadreAirbnb(),
          ),

        // Search + Add
        Padding(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: MyFormField(
                  label: "",
                  hint: "Nom ou téléphone…",
                  labelColor: Colors.black,
                  borderColor: Colors.black,
                  hintColor: Colors.black54,
                  activeBorderColor: Colors.black,
                  onChange: _onSearchClient,
                ),
              ),
              SizedBox(width: 10),
              ElevatedButton.icon(
                onPressed: _onAddClient,
                icon: Icon(Icons.add, color: Colors.white, size: 18),
                label: Text(
                  "Nouveau",
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryColor,
                  padding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ),

        SizedBox(height: 8),

        // Recherche en cours sur le serveur.
        if (state.rechercheClients)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: LinearProgressIndicator(
              minHeight: 2,
              color: AppColors.primaryColor,
              backgroundColor: Colors.transparent,
            ),
          ),

        // Client list
        Expanded(
          child: clients.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        searchQuery.isNotEmpty
                            ? Icons.search_off
                            : Icons.people_outline,
                        size: 64,
                        color: Colors.grey.shade400,
                      ),
                      SizedBox(height: 12),
                      Text(
                        searchQuery.isNotEmpty
                            ? "Aucun client trouvé"
                            : "Aucun client disponible",
                        style: TextStyle(
                          fontSize: 15,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      SizedBox(height: 14),
                      ElevatedButton.icon(
                        onPressed: _onAddClient,
                        icon: Icon(Icons.person_add_alt_1,
                            color: Colors.white, size: 18),
                        label: Text("Ajouter un client",
                            style: TextStyle(color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryColor,
                          padding: EdgeInsets.symmetric(
                              horizontal: 18, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: clients.length,
                  separatorBuilder: (_, __) =>
                      Divider(height: 1, color: Colors.grey.shade200),
                  itemBuilder: (_, index) =>
                      _buildClientTile(clients[index], selectedClient),
                ),
        ),

        // Next button
        _buildBottomNav(
          onNext: () {
            if (_validateStep1()) _nextStep();
          },
          showBack: false,
        ),
      ],
    );
  }

  Widget _buildClientTile(Client client, Client? selected) {
    final isSelected = selected?.id == client.id;
    final listeNoire = client.listeNoire != null;
    return InkWell(
      onTap: () => _onClientSelected(client),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Opacity(
              opacity: listeNoire ? 0.5 : 1,
              child: _buildClientAvatar(client),
            ),
            SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 6,
                    runSpacing: 2,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        "${client.firstName ?? ''} ${client.lastName ?? ''}",
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: listeNoire ? Colors.black45 : Colors.black87,
                        ),
                      ),
                      if (listeNoire)
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: Color(0xFFC62828),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            "Liste noire",
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (listeNoire && (client.listeNoire!.motif ?? '').isNotEmpty) ...[
                    SizedBox(height: 2),
                    Text(
                      client.listeNoire!.motif!,
                      style: TextStyle(fontSize: 12, color: Color(0xFFC62828)),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (client.tel != null) ...[
                    SizedBox(height: 2),
                    Text(
                      client.tel!,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                  if (client.identityNumber != null) ...[
                    SizedBox(height: 2),
                    Text(
                      client.identityNumber!,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                  SizedBox(height: 4),
                  _buildRatingStars(client.rate ?? 0),
                ],
              ),
            ),
            // Edit button
            IconButton(
              onPressed: () => _onEditClient(client),
              icon: Icon(
                Icons.edit_outlined,
                size: 20,
                color: AppColors.primaryColor,
              ),
              padding: EdgeInsets.zero,
              constraints: BoxConstraints(),
            ),
            SizedBox(width: 8),
            // Selection indicator
            Icon(
              listeNoire
                  ? Icons.block
                  : isSelected
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
              color: listeNoire
                  ? Color(0xFFC62828)
                  : isSelected
                      ? AppColors.primaryColor
                      : Colors.grey.shade400,
              size: 24,
            ),
          ],
        ),
      ),
    );
  }

  // ─── Step 2 — Reservation info ─────────────────────────────────────────────

  Widget _buildStep2(AddReservationState state) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // _buildPropertyHeader(state.realestate!),
                  // SizedBox(height: 16),
                  // _buildSelectedClientBanner(state.booking?.client),
                  SizedBox(height: 16),
                  if (_modeAirbnb) ...[
                    _encadreAirbnb(),
                    SizedBox(height: 16),
                    _avertissementDatesAirbnb(),
                  ],
                  _buildReservationForm(),
                  SizedBox(height: 16),
                  _buildCalendarSection(state.realestate),
                  SizedBox(height: 16),
                  _buildDatesSummary(),
                  // Contrat Airbnb : le client a deja paye, l'agent
                  // n'encaisse rien. Ni facture ni TVA a appliquer ici.
                  if (!_modeAirbnb) ...[
                    SizedBox(height: 16),
                    _carteFacture(),
                  ],
                  SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ),
        _buildBottomNav(
          onNext: () {
            if (_validateStep2()) _nextStep();
          },
          onBack: _prevStep,
          showBack: true,
        ),
      ],
    );
  }

  Widget _buildSelectedClientBanner(Client? client) {
    if (client == null) return SizedBox();
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Row(
        children: [
          _buildClientAvatar(client),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Client sélectionné",
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
                SizedBox(height: 2),
                Text(
                  "${client.firstName ?? ''} ${client.lastName ?? ''}",
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                if (client.tel != null)
                  Text(
                    client.tel!,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
              ],
            ),
          ),
          Icon(Icons.check_circle, color: Colors.green.shade600, size: 22),
        ],
      ),
    );
  }

  Widget _buildReservationForm() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.05),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Informations de réservation",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: 20),
          if (_modeAirbnb) ...[
            MyFormField(
              label: "Montant payé sur Airbnb (MAD)",
              hint: "Montant total payé par le client sur Airbnb",
              labelColor: Colors.black,
              borderColor: Colors.black,
              hintColor: Colors.black54,
              activeBorderColor: Colors.black,
              controller: _montantAirbnbController,
              inputType: TextInputType.numberWithOptions(decimal: true),
              validator: Validator().number().make(),
              formatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
              onChange: _surMontantAirbnb,
            ),
            SizedBox(height: 4),
            Text(
              _nuitsSelectionnees > 0
                  ? "Prix par nuit = montant ÷ $_nuitsSelectionnees nuit${_nuitsSelectionnees > 1 ? 's' : ''}."
                  : "Prix par nuit = montant ÷ nombre de nuits.",
              style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
            ),
            SizedBox(height: 16),
          ],
          MyFormField(
            label: "Prix par nuit *",
            hint: "Entrez le prix par nuit",
            labelColor: Colors.black,
            borderColor: Colors.black,
            hintColor: Colors.black54,
            activeBorderColor: Colors.black,
            controller: _nghitPriceController,
            inputType: _modeAirbnb
                ? TextInputType.numberWithOptions(decimal: true)
                : TextInputType.number,
            validator: _modeAirbnb
                ? Validator().required().number().make()
                : Validator().required().integer().make(),
            formatters: _modeAirbnb
                ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))]
                : [FilteringTextInputFormatter.digitsOnly],
            onChange: _modeAirbnb
                ? _surPrixNuit
                : (_) {
                    // Le detail de la facture suit le prix saisi.
                    if (_appliquerFacture) setState(() {});
                  },
          ),
          SizedBox(height: 16),
          MyFormField(
            label: "Nombre d'invités *",
            hint: "Entrez le nombre d'invités",
            labelColor: Colors.black,
            borderColor: Colors.black,
            hintColor: Colors.black54,
            activeBorderColor: Colors.black,
            controller: _nbGuestsController,
            inputType: TextInputType.number,
            validator: Validator().required().integer().make(),
          ),
          SizedBox(height: 16),
          // Ni le montant encaisse ni le reste a payer ne figurent
          // dans l'application : ils ne sont plus demandes.
          MyFormField(
            label: "Remarques",
            hint: "Arrivée tardive, demande particulière...",
            labelColor: Colors.black,
            borderColor: Colors.black,
            hintColor: Colors.black54,
            activeBorderColor: Colors.black,
            controller: _remarquesController,
            isLarge: true,
          ),
          SizedBox(height: 16),
          _buildTypeGuestDropdown(),
        ],
      ),
    );
  }

  // ─── Facture appliquee a la creation ───────────────────────────────────────

  /// Total de la reservation : nuits × prix par nuit.
  double get _totalReservation {
    final prix = _lireMontant(_nghitPriceController.text) ?? 0;
    return prix * _nuitsSelectionnees;
  }

  /// Taux saisi, s'il est valide (0 a 30 %).
  double? get _tauxFacture {
    final t = _lireMontant(_tvaFactureController.text);
    if (t == null || t < 0 || t > 30) return null;
    return t;
  }

  static double _arrondi2(double v) => (v * 100).roundToDouble() / 100;

  Widget _carteFacture() {
    final ttc = _arrondi2(_totalReservation);
    final taux = _tauxFacture;
    final ht = taux == null ? null : _arrondi2(ttc / (1 + taux / 100));
    final tva = ht == null ? null : _arrondi2(ttc - ht);
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.05),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _appliquerFacture,
            activeThumbColor: AppColors.primaryColor,
            onChanged: (v) => setState(() => _appliquerFacture = v),
            secondary: Icon(Icons.request_quote_outlined,
                color: AppColors.primaryColor),
            title: Text(
              "Appliquer la facture",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            subtitle: Text(
              "La TVA est comprise dans le total de la réservation.",
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ),
          if (_appliquerFacture) ...[
            SizedBox(height: 12),
            MyFormField(
              label: "Taux de TVA (%)",
              hint: "20",
              labelColor: Colors.black,
              borderColor: Colors.black,
              hintColor: Colors.black54,
              activeBorderColor: Colors.black,
              controller: _tvaFactureController,
              inputType: TextInputType.numberWithOptions(decimal: true),
              formatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
              validator: (v) {
                if (!_appliquerFacture) return null;
                final t = _lireMontant(v ?? '');
                if (t == null) return "Saisissez le taux de TVA";
                if (t < 0 || t > 30) return "Le taux doit être compris entre 0 et 30 %";
                return null;
              },
              onChange: (_) => setState(() {}),
            ),
            SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primaryColor.withValues(alpha: .06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: AppColors.primaryColor.withValues(alpha: .25)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ttc <= 0
                        ? "Choisissez les dates et le prix par nuit pour voir le détail de la facture."
                        : (taux == null
                            ? "Saisissez un taux de TVA entre 0 et 30 %."
                            : "Le total est T.T.C : ${_formatPrix(ttc)} MAD = "
                                "${_formatPrix(ht!)} MAD H.T + ${_formatPrix(tva!)} MAD TVA "
                                "(${_formatPrix(taux)} %)"),
                    style: TextStyle(
                      fontSize: 13.5,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  if (ttc > 0) ...[
                    SizedBox(height: 6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline,
                            size: 16, color: Colors.grey.shade700),
                        SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            "Le contrat indiquera ${_formatPrix(ttc)} MAD. "
                            "La facture sera appliquée automatiquement.",
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey.shade700),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Invite a lire le bulletin avant de signer : le client doit savoir
  /// ce qu'il signe.
  Widget _boutonApercuContrat(AddReservationState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _apercuEnCours ? null : () => _voirContrat(state),
            icon: _apercuEnCours
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.description_outlined, size: 19),
            label: Text(_apercuEnCours
                ? "Préparation du contrat…"
                : "Voir le contrat avant de signer"),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              side: BorderSide(color: AppColors.primaryColor),
              foregroundColor: AppColors.primaryColor,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          "Présentez le document au client : l'emplacement de sa signature y est indiqué.",
          style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
        ),
      ],
    );
  }

  void _voirContrat(AddReservationState state) async {
    final client = state.booking?.client;
    final bien = state.realestate;

    if (_checkInDate == null || _checkOutDate == null ||
        client?.id == null || bien?.id == null) {
      showToast("Complétez d'abord le client et les dates", context,
          type: ToastificationType.warning, second: 3);
      return;
    }

    setState(() => _apercuEnCours = true);
    try {
      final chemin = await Dependencies.get<Repository>().apercuContrat(
        checkin: _checkInDate!.formattedDateEn,
        checkout: _checkOutDate!.formattedDateEn,
        guest: int.tryParse(_nbGuestsController.text) ?? 1,
        realestate: bien!.id!,
        client: client!.id!,
        nightPrice: double.tryParse(_nghitPriceController.text) ?? 0,
        typeGuest: _selectedTypeGuest ?? '',
        heureArrivee:
            _heureArrivee == null ? null : _formatHeure(_heureArrivee!),
        heureDepart:
            _heureDepart == null ? null : _formatHeure(_heureDepart!),
      );
      if (!mounted) return;

      // Le contrat se lit sur place, et la signature se recueille dans
      // la foulee : l'agent n'a plus a quitter l'application au moment
      // ou le client est devant lui.
      final paraphe = await VisionneuseContrat.ouvrir(
        context,
        chemin: chemin,
        titre: "Bulletin d'hébergement",
        avecSignature: true,
      );

      if (paraphe != null && mounted) {
        setState(() => _parapheRecueilli = paraphe);
        showToast("Signature enregistrée", context, second: 2);
      }
    } catch (_) {
      if (mounted) {
        showToast("Aperçu indisponible", context,
            description: "Vérifiez la connexion, puis réessayez.",
            type: ToastificationType.error, second: 3);
      }
    } finally {
      if (mounted) setState(() => _apercuEnCours = false);
    }
  }

  // ─── Step 3 — Signature ────────────────────────────────────────────────────

  Widget _buildStep3(AddReservationState state) {
    final isLoading = state.addStatus == AppStatus.loading;
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildReservationSummaryCard(state),
                SizedBox(height: 14),
                _boutonApercuContrat(state),
                SizedBox(height: 20),
                // Le pave de signature a ete retire : le client signe
                // depuis la visionneuse du contrat, document sous les
                // yeux. Cette carte rend compte de ce qui y a ete
                // recueilli.
                _carteSignatureRecueillie(),
                SizedBox(height: 8),
              ],
            ),
          ),
        ),

        // Fixed bottom nav
        Padding(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: isLoading ? null : _prevStep,
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    side: BorderSide(color: Colors.grey.shade400),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    "Précédent",
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: isLoading ? null : _onSubmit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryColor,
                    padding: EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: isLoading
                      ? SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(Colors.white),
                          ),
                        )
                      : Text(
                          "Créer la réservation",
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildReservationSummaryCard(AddReservationState state) {
    final client = state.booking?.client;
    final nights = (_checkInDate != null && _checkOutDate != null)
        ? _checkOutDate!.difference(_checkInDate!).inDays
        : 0;
    final price = double.tryParse(_nghitPriceController.text) ?? 0;

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Résumé de la réservation",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.primaryColor,
            ),
          ),
          SizedBox(height: 12),
          if (client != null)
            _buildSummaryRow(
              Icons.person,
              "${client.firstName} ${client.lastName}",
            ),
          if (_checkInDate != null)
            _buildSummaryRow(
              Icons.login,
              "Arrivée : ${_formatDate(_checkInDate!)}"
              "${_heureArrivee != null ? ' à ${_formatHeure(_heureArrivee!)}' : ''}",
            ),
          if (_checkOutDate != null)
            _buildSummaryRow(
              Icons.logout,
              "Départ : ${_formatDate(_checkOutDate!)}"
              "${_heureDepart != null ? ' à ${_formatHeure(_heureDepart!)}' : ''}",
            ),
          if (nights > 0)
            _buildSummaryRow(
              Icons.nights_stay,
              "$nights nuit${nights > 1 ? 's' : ''}",
            ),
          if (_nbGuestsController.text.isNotEmpty)
            _buildSummaryRow(
              Icons.people,
              "${_nbGuestsController.text} invité(s)",
            ),
          if (price > 0 && nights > 0)
            _buildSummaryRow(
              Icons.monetization_on_outlined,
              "${(price * nights).toStringAsFixed(2)} MAD",
              bold: true,
            ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(IconData icon, String text, {bool bold = false}) {
    return Padding(
      padding: EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.primaryColor),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                color: Colors.black87,
                fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Shared helpers ────────────────────────────────────────────────────────

  Widget _buildBottomNav({
    required VoidCallback onNext,
    VoidCallback? onBack,
    required bool showBack,
  }) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Row(
        children: [
          if (showBack) ...[
            Expanded(
              child: OutlinedButton(
                onPressed: onBack,
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  side: BorderSide(color: Colors.grey.shade400),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  "Précédent",
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
            ),
            SizedBox(width: 12),
          ],
          Expanded(
            flex: showBack ? 2 : 1,
            child: ElevatedButton(
              onPressed: onNext,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryColor,
                padding: EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Suivant",
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(width: 6),
                  Icon(Icons.arrow_forward, size: 18, color: Colors.white),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPropertyMiniHeader(Realestate realestate) {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.all(12),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: realestate.media?.isNotEmpty == true
                ? Image.network(
                    realestate.media!.first.url!,
                    width: 56,
                    height: 56,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        _buildImagePlaceholder(size: 56),
                  )
                : _buildImagePlaceholder(size: 56),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  realestate.title ?? "Propriété",
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  "${realestate.price} MAD / nuit",
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.green.shade700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPropertyHeader(Realestate realestate) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.05),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: realestate.media?.isNotEmpty == true
                ? Image.network(
                    realestate.media!.first.url!,
                    width: 80,
                    height: 80,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _buildImagePlaceholder(),
                  )
                : _buildImagePlaceholder(),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  realestate.title ?? "Propriété",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  "${realestate.price} MAD / nuit",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.green.shade700,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  realestate.address?.city?.name ??
                      "Localisation non spécifiée",
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImagePlaceholder({double size = 80}) {
    return Container(
      width: size,
      height: size,
      color: Colors.grey.shade200,
      child: Icon(Icons.home, size: size * 0.4, color: Colors.grey.shade400),
    );
  }

  Widget _buildTypeGuestDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              "Type d'invité",
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.black,
              ),
            ),
            SizedBox(width: 4),
            Text("*", style: TextStyle(fontSize: 14, color: Colors.red)),
          ],
        ),
        SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _selectedTypeGuest,
          decoration: InputDecoration(
            hintText: "Sélectionnez le type d'invité",
            hintStyle: TextStyle(color: Colors.black54),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.black),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.black),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.black, width: 2),
            ),
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          icon: Icon(Icons.arrow_drop_down, color: Colors.black),
          items: _guestTypes
              .map(
                (t) => DropdownMenuItem(
                  value: t,
                  child: Text(TypeInvite.libelleDe(t),
                      style: TextStyle(color: Colors.black87)),
                ),
              )
              .toList(),
          onChanged: (v) => setState(() => _selectedTypeGuest = v),
          validator: (v) => (v == null || v.isEmpty)
              ? "Veuillez sélectionner un type d'invité"
              : null,
        ),
      ],
    );
  }

  /// Une reservation Airbnb peut avoir commence : ses dates doivent
  /// rester visibles.
  DateTime _premierJourCalendrier() {
    var premier = DateTime.now().subtract(const Duration(days: 1));
    final arrivee = _checkInDate;
    if (arrivee != null && arrivee.isBefore(premier)) premier = arrivee;
    return premier;
  }

  DateTime _dernierJourCalendrier() {
    var dernier = DateTime.now().add(Duration(days: 365));
    final depart = _checkOutDate;
    if (depart != null && depart.isAfter(dernier)) {
      dernier = depart.add(Duration(days: 31));
    }
    if (_focusedDay.isAfter(dernier)) dernier = _focusedDay;
    return dernier;
  }

  Widget _buildCalendarSection(Realestate? bien) {
    final statut = _statutDuBien(bien);
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.05),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                "Sélectionner les dates",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              SizedBox(width: 8),
              Text("*", style: TextStyle(fontSize: 18, color: Colors.red)),
            ],
          ),
          // Statut du bien aujourd'hui : disponible, occupe, a nettoyer…
          if (statut != null) ...[
            SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.only(top: 5),
                  child: Text(
                    "Statut du bien : ",
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                  ),
                ),
                Flexible(child: StatutBienChip(statut: statut, detailDessous: true)),
              ],
            ),
          ],
          if (_bienDesactive(bien)) ...[
            SizedBox(height: 10),
            _avertissementDesactive(),
          ],
          SizedBox(height: 16),
          _buildCalendarLegend(),
          SizedBox(height: 16),
          TableCalendar<DateTime>(
            firstDay: _premierJourCalendrier(),
            lastDay: _dernierJourCalendrier(),
            focusedDay: _focusedDay,
            calendarFormat: CalendarFormat.month,
            rangeSelectionMode: RangeSelectionMode.enforced,
            rangeStartDay: _checkInDate,
            rangeEndDay: _checkOutDate,
            startingDayOfWeek: StartingDayOfWeek.monday,
            calendarBuilders: CalendarBuilders(
              defaultBuilder: (context, day, _) => _buildCalendarDay(day),
              outsideBuilder: (context, day, _) => _buildCalendarDay(day),
              disabledBuilder: (context, day, _) =>
                  _buildCalendarDay(day, isDisabled: true),
            ),
            calendarStyle: CalendarStyle(
              outsideDaysVisible: false,
              weekendTextStyle: TextStyle(color: Colors.red.shade600),
              selectedDecoration: BoxDecoration(
                color: AppColors.primaryColor,
                shape: BoxShape.circle,
              ),
              rangeStartDecoration: BoxDecoration(
                color: AppColors.primaryColor,
                shape: BoxShape.circle,
              ),
              rangeEndDecoration: BoxDecoration(
                color: AppColors.primaryColor,
                shape: BoxShape.circle,
              ),
              rangeHighlightColor: Colors.blue.shade100,
              todayDecoration: BoxDecoration(
                color: Colors.blue.shade300,
                shape: BoxShape.circle,
              ),
            ),
            headerStyle: HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
              titleTextStyle: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            enabledDayPredicate: (day) {
              bool isReserved = _reservedDates.any((d) => isSameDay(day, d));
              if (!isReserved) return true;
              // Le jour d'arrivee d'une plage reste touchable pour servir
              // de depart ; une arrivee sur une nuit Airbnb est refusee
              // ci-dessous.
              return _reservedRanges.any((r) => isSameDay(day, r.start));
            },
            onRangeSelected: (start, end, focused) {
              // Aucune nuit reservee sur Airbnb, pour l'agent comme pour
              // l'administrateur.
              if (start != null) {
                final nuitAirbnb = _premiereNuitAirbnb(start, end);
                if (nuitAirbnb != null) {
                  _signalerNuitAirbnb(nuitAirbnb);
                  final arriveeAirbnb = isSameDay(nuitAirbnb, start);
                  setState(() {
                    _checkInDate = arriveeAirbnb ? null : start;
                    _checkOutDate = null;
                    _focusedDay = focused;
                  });
                  return;
                }
              }
              setState(() {
                _checkInDate = start;
                _checkOutDate = end;
                _focusedDay = focused;
                _recalculerDepuisMontant();
              });
              _proposerPrixSejour();
            },
            onPageChanged: (focused) => _focusedDay = focused,
          ),
          SizedBox(height: 14),
          _selecteursHeures(),
        ],
      ),
    );
  }

  /// Heures d'arrivée et de départ, en regard des dates.
  ///
  /// Elles restent facultatives : laissées vides, ce sont les heures
  /// d'usage de l'agence qui figurent au contrat.
  Widget _selecteursHeures() {
    Widget champ(String libelle, TimeOfDay? valeur, IconData icone,
        void Function(TimeOfDay?) poser, TimeOfDay usage) {
      return Expanded(
        child: InkWell(
          onTap: () async {
            final choisie = await showTimePicker(
              context: context,
              initialTime: valeur ?? usage,
              helpText: libelle,
            );
            if (choisie != null) setState(() => poser(choisie));
          },
          borderRadius: BorderRadius.circular(9),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 11, vertical: 9),
            decoration: BoxDecoration(
              border: Border.all(
                color: valeur == null ? Colors.grey.shade400 : Colors.black,
              ),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Row(
              children: [
                Icon(icone,
                    size: 18,
                    color: valeur == null
                        ? Colors.grey.shade500
                        : AppColors.primaryColor),
                SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(libelle,
                          style: TextStyle(
                              fontSize: 10.5, color: Colors.grey.shade600)),
                      Text(
                        valeur == null
                            ? "${_formatHeure(usage)} par défaut"
                            : _formatHeure(valeur),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: valeur == null
                              ? Colors.grey.shade600
                              : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
                if (valeur != null)
                  InkWell(
                    onTap: () => setState(() => poser(null)),
                    child: Icon(Icons.close,
                        size: 17, color: Colors.grey.shade600),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    // Un titre, pour que les heures ne passent pas inapercues sous le
    // calendrier : les agents ne les saisissaient jamais.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Heures d'arrivée et de départ",
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        SizedBox(height: 8),
        Row(
          children: [
            // Les heures d'usage de l'agence, celles que le contrat retient
            // quand aucune n'est saisie (AGENCE_HEURE_CHECKIN et _CHECKOUT).
            champ("Heure d'arrivée", _heureArrivee, Icons.login,
                (v) => _heureArrivee = v, _arriveeUsage),
            SizedBox(width: 10),
            champ("Heure de départ", _heureDepart, Icons.logout,
                (v) => _heureDepart = v, _departUsage),
          ],
        ),
      ],
    );
  }

  /// Rend compte de la signature recueillie depuis le contrat.
  ///
  /// Le client signe le document sous les yeux, pas un cadre vide :
  /// c'est la seule façon d'attester qu'il a lu ce qu'il signe.
  Widget _carteSignatureRecueillie() {
    final signee = _parapheRecueilli != null;
    if (!signee && _modeAirbnb) return _carteSignatureFacultative();

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: signee ? Colors.green.shade300 : Colors.orange.shade300,
        ),
        boxShadow: [
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.05),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                signee ? Icons.check_circle : Icons.info_outline,
                size: 20,
                color: signee ? Colors.green.shade600 : Colors.orange.shade700,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  signee ? "Signature recueillie" : "Signature du client *",
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 6),
          Text(
            signee
                ? "Le client a signé depuis le contrat. Vous pouvez créer la réservation."
                : "Ouvrez « Voir le contrat avant de signer », présentez le "
                    "document au client, puis recueillez sa signature.",
            style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700),
          ),
          if (signee) ...[
            SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Image.memory(
                _parapheRecueilli!,
                height: 110,
                fit: BoxFit.contain,
              ),
            ),
            SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => setState(() => _parapheRecueilli = null),
                icon: Icon(Icons.refresh, size: 18),
                label: Text("Recommencer la signature"),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red.shade700,
                  side: BorderSide(color: Colors.red.shade300),
                  padding: EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Contrat Airbnb : le client peut signer, mais rien ne l'impose.
  Widget _carteSignatureFacultative() {
    final state = context.read<AddReservationCubit>().state;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.05),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.draw_outlined, size: 20, color: Colors.grey.shade700),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  "Signature du client (facultative)",
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 6),
          Text(
            "Réservation Airbnb : vous pouvez créer le contrat sans signature, "
            "ou faire signer le client s'il est présent.",
            style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700),
          ),
          SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _apercuEnCours ? null : () => _voirContrat(state),
              icon: Icon(Icons.edit_outlined, size: 18),
              label: Text("Ajouter la signature du client"),
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
      ),
    );
  }

  /// « 16:30 » — la forme que le serveur attend.
  static String _formatHeure(TimeOfDay h) =>
      "${h.hour.toString().padLeft(2, '0')}:"
      "${h.minute.toString().padLeft(2, '0')}";

  Widget? _buildCalendarDay(DateTime day, {bool isDisabled = false}) {
    final normalized = _normalizeDate(day);
    if (_sharedDateColors.containsKey(normalized) &&
        _sharedDateColors[normalized]!.length >= 2) {
      final colors = _sharedDateColors[normalized]!;
      return Container(
        margin: EdgeInsets.all(4),
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(shape: BoxShape.circle),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Row(
              children: [
                Expanded(child: Container(color: colors[0])),
                Expanded(child: Container(color: colors[1])),
              ],
            ),
            Text(
              '${day.day}',
              style: TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }
    final color = _dateColors[normalized];
    if (color != null) {
      return Container(
        margin: EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: color.withValues(alpha: 0.5), width: 2),
        ),
        child: Center(
          child: Text(
            '${day.day}',
            style: TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
    }
    return null;
  }

  Widget _buildCalendarLegend() {
    Set<Color> usedColors = _dateColors.values.toSet()..remove(_couleurAirbnb);
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: [
        _buildLegendItem(AppColors.primaryColor, "Sélectionné"),
        ...usedColors.take(3).map((c) => _buildLegendItem(c, "Réservé")),
        if (_aDesJoursAirbnb)
          _buildLegendItem(_couleurAirbnb, "Réservé sur Airbnb"),
        _buildLegendItem(Colors.grey.shade300, "Disponible"),
      ],
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.grey.shade300),
          ),
        ),
        SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
      ],
    );
  }

  Widget _buildDatesSummary() {
    if (_checkInDate == null || _checkOutDate == null) return SizedBox();
    final nights = _checkOutDate!.difference(_checkInDate!).inDays;
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Résumé",
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppColors.primaryColor,
            ),
          ),
          SizedBox(height: 10),
          _buildSummaryRow(
            Icons.login,
            "Arrivée : ${_formatDate(_checkInDate!)}",
          ),
          _buildSummaryRow(
            Icons.logout,
            "Départ : ${_formatDate(_checkOutDate!)}",
          ),
          _buildSummaryRow(
            Icons.nights_stay,
            "$nights nuit${nights > 1 ? 's' : ''}",
          ),
          if (double.tryParse(_nghitPriceController.text) != null)
            _buildSummaryRow(
              Icons.monetization_on_outlined,
              "${(double.parse(_nghitPriceController.text) * nights).toStringAsFixed(2)} MAD",
              bold: true,
            ),
        ],
      ),
    );
  }

  Widget _buildClientAvatar(Client client) {
    if (client.profile != null && client.profile!.isNotEmpty) {
      return CircleAvatar(
        radius: 24,
        backgroundColor: Colors.grey.shade200,
        backgroundImage: NetworkImage(client.profile!),
      );
    }
    return CircleAvatar(
      radius: 24,
      backgroundColor: _getAvatarColor(client.fullName),
      child: Text(
        _getClientInitials(client),
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildRatingStars(double rating) {
    int full = rating.floor();
    bool half = (rating - full) >= 0.5;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ...List.generate(
          full,
          (_) => Icon(Icons.star, size: 13, color: Colors.amber),
        ),
        if (half) Icon(Icons.star_half, size: 13, color: Colors.amber),
        ...List.generate(
          5 - full - (half ? 1 : 0),
          (_) => Icon(Icons.star_border, size: 13, color: Colors.grey.shade400),
        ),
        SizedBox(width: 4),
        Text(
          "${rating.toStringAsFixed(1)}",
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
        ),
      ],
    );
  }

  // ─── Utilities ─────────────────────────────────────────────────────────────

  void _updateReservedDates(Realestate realestate) {
    if (realestate.reservedDates == null) return;
    // En mode Airbnb, le séjour qu'on transforme en contrat ne doit pas
    // se bloquer lui-même : on écarte sa propre plage.
    final sejourCourant = _airbnb?.id;
    final plages = realestate.reservedDates!
        .where((d) =>
            d.checkin != null &&
            d.checkout != null &&
            !d.checkout!.isBefore(d.checkin!) &&
            !(sejourCourant != null && d.airbnbSejour == sejourCourant))
        .toList();
    setState(() {
      _reservedRanges = plages
          .map((d) => DateTimeRange(start: d.checkin!, end: d.checkout!))
          .toList();
      _reservedAirbnb = plages.map((d) => d.airbnb).toList();
      _nuitsAirbnb = {};
      for (int i = 0; i < _reservedRanges.length; i++) {
        if (!_reservedAirbnb[i]) continue;
        final r = _reservedRanges[i];
        var nuit = _normalizeDate(r.start);
        final fin = _normalizeDate(r.end);
        while (nuit.isBefore(fin)) {
          _nuitsAirbnb.add(nuit);
          nuit = DateTime(nuit.year, nuit.month, nuit.day + 1);
        }
      }
      _reservedDates = [];
      _dateColors = {};
      _sharedDateColors = {};
      Color couleurPlage(int i) => _reservedAirbnb[i]
          ? _couleurAirbnb
          : _reservationColors[i % _reservationColors.length];
      for (int i = 0; i < _reservedRanges.length; i++) {
        final range = _reservedRanges[i];
        final color = couleurPlage(i);
        for (int j = 0; j < range.end.difference(range.start).inDays; j++) {
          final date = range.start.add(Duration(days: j));
          _reservedDates.add(date);
          _dateColors[_normalizeDate(date)] = color;
        }
        final checkout = _normalizeDate(range.end);
        bool shared = false;
        for (int k = 0; k < _reservedRanges.length; k++) {
          if (k != i && isSameDay(_reservedRanges[k].start, range.end)) {
            shared = true;
            final c2 = couleurPlage(k);
            _sharedDateColors.putIfAbsent(checkout, () => []);
            if (!_sharedDateColors[checkout]!.contains(color))
              _sharedDateColors[checkout]!.add(color);
            if (!_sharedDateColors[checkout]!.contains(c2))
              _sharedDateColors[checkout]!.add(c2);
            break;
          }
        }
        if (!shared) _dateColors[checkout] = color;
      }
    });
  }

  DateTime _normalizeDate(DateTime d) => DateTime(d.year, d.month, d.day);

  String _formatDate(DateTime d) =>
      "${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}";

  String _getClientInitials(Client c) {
    String i = '';
    if (c.firstName?.isNotEmpty == true) i += c.firstName![0].toUpperCase();
    if (c.lastName?.isNotEmpty == true) i += c.lastName![0].toUpperCase();
    return i.isEmpty ? '?' : i;
  }

  Color _getAvatarColor(String name) {
    final colors = [
      Colors.blue.shade600,
      Colors.green.shade600,
      Colors.orange.shade600,
      Colors.purple.shade600,
      Colors.red.shade600,
      Colors.teal.shade600,
    ];
    return colors[name.hashCode.abs() % colors.length];
  }

  // ─── Actions ───────────────────────────────────────────────────────────────

  void _onSearchClient(String val) =>
      BlocProvider.of<AddReservationCubit>(context).searchClient(val);

  void _onClientSelected(Client client) {
    if (client.listeNoire != null) {
      _signalerListeNoire(client);
      return;
    }
    final cubit = BlocProvider.of<AddReservationCubit>(context);
    cubit.updateReservation(
      (cubit.state.booking ?? Booking()).copyWith(client: client),
    );
    setState(() {});
  }

  void _onAddClient() async {
    final cubit = BlocProvider.of<AddReservationCubit>(context);
    final result = await GoRouter.of(context).push(Routes.addClient);
    if (!mounted) return;
    if (result is Client) cubit.addClient(result);
  }

  void _onEditClient(Client client) async {
    final cubit = BlocProvider.of<AddReservationCubit>(context);
    final result = await GoRouter.of(context).push(
      Routes.editClient.replaceFirst(':id', client.id.toString()),
      extra: client,
    );
    if (!mounted) return;
    if (result is Client) cubit.editClient(result);
  }

  void _fetchData() =>
      BlocProvider.of<AddReservationCubit>(context).fetchData();

  void _onSubmit() async {
    // Le pave de l'etape 3 est masque : la signature vient de la
    // visionneuse du contrat, document sous les yeux du client.
    // Contrat Airbnb : la signature est facultative.
    if (_parapheRecueilli == null && !_modeAirbnb) {
      showToast(
        "",
        description: "Ouvrez le contrat et faites signer le client",
        context,
        type: ToastificationType.warning,
        second: 2,
      );
      return;
    }
    final cubit = BlocProvider.of<AddReservationCubit>(context);
    final signatureBytes = _parapheRecueilli;
    if (!mounted) return;
    if (signatureBytes != null) cubit.clientSignature(signatureBytes);
    Booking booking = (cubit.state.booking ?? Booking()).copyWith(
      checkin: _checkInDate,
      checkout: _checkOutDate,
      nbGuest: int.tryParse(_nbGuestsController.text),
      nightPrice: double.tryParse(_nghitPriceController.text),
      typeGuest: _selectedTypeGuest,
      heureArrivee:
          _heureArrivee == null ? null : _formatHeure(_heureArrivee!),
      heureDepart: _heureDepart == null ? null : _formatHeure(_heureDepart!),
      remarques: _remarquesController.text.trim().isEmpty
          ? null
          : _remarquesController.text.trim(),
      // Contrat Airbnb : rien n'est encaisse par l'agent, donc ni
      // facture ni TVA (avance et caution ne sont pas envoyees).
      appliquerFacture: !_modeAirbnb && _appliquerFacture,
      tvaFacture:
          !_modeAirbnb && _appliquerFacture ? (_tauxFacture ?? 20) : null,
    );

    cubit.addBooking(booking, airbnbSejour: _airbnb?.id);
  }

  void _listener(BuildContext context, AddReservationState state) {
    if (state.fetchStatus == AppStatus.success && !_isPriceInitialised) {
      _nghitPriceController.text = state.realestate?.price?.toString() ?? "0";
      final prixAirbnb = _airbnb?.prixNuit;
      if (prixAirbnb != null && prixAirbnb > 0) {
        _nghitPriceController.text = _formatPrix(prixAirbnb);
      }
      _isPriceInitialised = true;
      // Dates venues du calendrier : le prix du sejour est propose.
      if (!_modeAirbnb && _checkInDate != null && _checkOutDate != null) {
        _proposerPrixSejour();
      }
    }
    if (state.addStatus == AppStatus.success) {
      showToast(
        AppStrings.success,
        context,
        second: 2,
        // true : l'ecran appelant se rafraichit (calendrier, Airbnb).
        whenComplete: () => GoRouter.of(context).pop(true),
      );
    } else if (state.addStatus == AppStatus.error) {
      if (state.errors != null) {
        showDialogueError(context, state.errors!);
      } else {
        showToast(
          "",
          description: state.error,
          context,
          type: ToastificationType.error,
        );
      }
    }
  }
}
