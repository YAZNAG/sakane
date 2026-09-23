import 'package:immobilier/features/biens_desactives/ui/biens_desactives.dart';
import 'package:immobilier/features/reception_whatsapp/ui/reception_whatsapp.dart';
import 'package:immobilier/features/reservations/ui/choix_bien.dart';
import 'package:immobilier/features/charges_new/annulees/ui/charges_annulees.dart';
import 'package:immobilier/features/immobilier/reservation_list/ui/corbeille.dart';
import 'package:go_router/go_router.dart';
import 'package:immobilier/features/immobilier/detail_reservation/ui/detail_reservation.dart';
import 'package:immobilier/features/reglages/heures/ui/heures_par_defaut.dart';
import 'package:immobilier/core/dependencies/dependencies.dart';
import 'package:immobilier/core/services/shared_pref_service.dart';
import 'package:immobilier/features/app_inactive/ui/app_inactive.dart';
import 'package:immobilier/features/charges_new/charges/add_charge/ui/add_charge.dart';
import 'package:immobilier/features/charges_new/charges/list/ui/charges.dart';
import 'package:immobilier/features/charges_new/home/ui/home.dart';
import 'package:immobilier/features/charges_new/programed_charges/add_programed_charge/ui/add_modify_programed_charge.dart';
import 'package:immobilier/features/charges_new/programed_charges/list/ui/programed_charges.dart';
import 'package:immobilier/features/clients/client_details/ui/client_details.dart';
import 'package:immobilier/features/gestion_immobilier/home/ui/home.dart';
import 'package:immobilier/features/gestion_immobilier/immobilier_by_status/ui/immobilier_by_status.dart';
import 'package:immobilier/features/immobilier/rapports/add_rapport/ui/add_raport.dart';
import 'package:immobilier/features/immobilier/rapports/rapports_list/ui/rapport_list.dart';
import 'package:immobilier/features/immobilier/signature/ui/signature.dart';
import 'package:immobilier/features/install_new_version/ui/app_new_version.dart';
import 'package:immobilier/features/owners/owner_details/ui/owners_details.dart';
import 'package:immobilier/models/owner.dart';
import 'package:immobilier/features/platform/add_slider/ui/add_slider.dart';
import 'package:immobilier/features/platform/announces/ui/announces.dart';
import 'package:immobilier/features/platform/platform_home/ui/platform_home.dart';
import 'package:immobilier/features/platform/sliders/ui/sliders.dart';
import 'package:immobilier/features/reservations/ui/reservation.dart';
import 'package:immobilier/features/users/add_user/ui/add_user.dart';


import 'features/clients/clients_list/ui/clients.dart';
import 'features/clients/edit_client/ui/edit_client.dart';
import 'features/immobilier/reclamations/add_reclamation/ui/add_reclamation.dart';
import 'features/reclamations/reclamations_list/ui/reclamations_list.dart';
import 'features/statistics/enhanced/ui/financial_stats_screen.dart';
import 'models/client.dart';
import 'features/owners/owners_list/ui/owners.dart';
import 'features/screens.dart';
import 'package:immobilier/features/auth/forgot_password/ui/forgot_password.dart';
import 'package:immobilier/features/campagnes/liste/ui/campagnes.dart';
import 'package:immobilier/features/campagnes/creation/ui/creation_campagne.dart';
import 'package:immobilier/features/campagnes/detail/ui/detail_campagne.dart';
import 'package:immobilier/features/modeles_messages/ui/modeles_messages.dart';
import 'package:immobilier/features/permissions/ui/permissions.dart';
import 'package:immobilier/features/exports/ui/export_reservations.dart';
import 'package:immobilier/features/gestion_immobilier/groupes/ui/groupes_immobilier.dart';
import 'package:immobilier/features/caisses/ui/caisses.dart';
import 'package:immobilier/features/syndics/ui/syndics.dart';
import 'package:immobilier/features/syndics/ui/syndic_detail.dart';
import 'package:immobilier/features/syndics/ui/syndic_form.dart';
import 'package:immobilier/models/syndic.dart';
import 'package:immobilier/features/calendrier_bien/ui/calendrier_bien.dart';
import 'package:immobilier/features/calendrier_bien/ui/calendrier_biens.dart';
import 'package:immobilier/features/airbnb/ui/airbnb_bien.dart';
import 'package:immobilier/features/airbnb/ui/airbnb_biens.dart';
import 'package:immobilier/features/immobilier/add_reservation/pre_remplissage_reservation.dart';
import 'package:immobilier/features/baux/ui/baux.dart';
import 'package:immobilier/features/baux/ui/bail_detail.dart';
import 'package:immobilier/features/baux/ui/bail_form.dart';
import 'package:immobilier/models/bail.dart';
import 'package:immobilier/features/ventes/ui/ventes.dart';
import 'package:immobilier/features/ventes/ui/dossier_vente.dart';
import 'package:immobilier/features/ventes/ui/visites_ventes.dart';


class Routes {
  static const String login = "/login";
  static const String forgotPassword = "/forgot-password";
  static const String home = "/";
  static const String immobilier = "/immobilier-list";
  static const String immobilierDetails = "/immobilier-detail/:id";
  static const String addImmobilier = "/add-immobilier";
  static const String updateImmobilier = "/update-immobilier/:id";
  static const String homeImmobilier = "/home-immobilier/:id";
  // Titre du bien en parametre facultatif : ?titre=...
  static const String calendrierBien = "/calendrier-bien/:id";
  // Choix du bien avant son calendrier, depuis l'accueil.
  static const String calendrierBiens = "/calendrier-biens";
  // Liaison Airbnb d'un bien (?titre=...) et vue d'ensemble.
  static const String airbnbBien = "/airbnb-bien/:id";
  static const String airbnbBiens = "/airbnb-biens";
  static const String addOwner = "/add-owner";
  static const String editOwner = "/edit-owner/:id";
  static const String initialiser = "/initialiser";
  static const String addReservation = "/add-reservation/:id";
  static const String addClient = "/add-client";
  static const String reservationList = "/reservations/:id";
  static const String contracts = "/contracts/:id";
  static const String addContract = "/add-contract/:id";
  static const String realestateCharges = "/charges/:id";
  static const String stats = "/stats/:id";
  static const String platform = "/platform";
  static const String users = "/users";
  static const String statistics = "/statistics";
  static const String announces = "/announces";
  static const String sliders = "/sliders";
  static const String addSlider = "/add-slider";
  static const String addUser = "/add-user";
  static const String appInactive = "/app-inacvtive";
  static const String newVersion = "/new-version";


  static const String owners = "/owners";
  static const String clients = "/clients";
  static const String reservation = "/reservation";
  static const String charges = "/charges";

 static const String clientDetail = "/client-detail/:id";
 static const String ownerDetail = "/owner-detail/:id";

 static const String reports = "/rapports/:id";
 static const String addRapport = "/add-rapport/:id";

 static const String gestionImmobilier = "/gestion-immobilier";
  static const String groupesImmobilier = "/groupes-immobilier";


 // Biens par etat ; ?type=...&dossier=...&vue=encours|aujourdhui|avenir
 // (la vue ne vaut que pour les biens reserves).
 static const String immobilierByStatus = "/immobilier-stats/:status";

 static const String signature = "/signature";

 static const String updateUser = "/update-user/:id";
 static const String editClient = "/edit-client/:id";


 static const String programedCharges = "/programed-charges";
 static const String createProgramedCharges = "/programed-charges/create";
 static const String updateProgramedCharges = "/programed-charges/:id/update";


 static const String chargesList = "/charges-list";
 static const String addCharge = "/add-charge";

 static const String reclamationsList = "/reclamations-list";
  static const String campagnes = "/campagnes";
  static const String exportReservations = "/export-reservations";
  static const String corbeilleReservations = "/corbeille-reservations";
  static const String chargesAnnulees = "/charges-annulees";
  static const String nouvelleReservation = "/nouvelle-reservation";
  // Caisse ; ?action=encaisser|ouvrir ouvre directement la saisie.
  static const String caisses = "/caisses";
  static const String modelesMessages = "/modeles-messages";
  static const String addCampagne = "/add-campagne";
  static const String campagneDetail = "/campagne/:id";
 static const String addReclamation = "/add-reclamation/:id";

 static const String financialStats = "/financial-stats";
 static const String financialStatsProperty = "/financial-stats-property/:id";

  static const String syndics = "/syndics";
  static const String syndicDetail = "/syndics/:id";
  // Chemin distinct de "/syndics/:id" : aucun conflit avec un identifiant.
  static const String syndicForm = "/syndic-form";

  // Reglages de reception WhatsApp ; ?manager=ID&nom=... pour un autre utilisateur (admin).
  static const String receptionWhatsapp = "/reception-whatsapp";
  // Vue d'ensemble de tous les utilisateurs (admin).
  static const String receptionsWhatsapp = "/receptions-whatsapp";
  // Detail d'une reservation (historique, caisse, facture) ; rend vrai si elle a change.
  static const String detailReservation = "/reservation-detail/:id";
  // Heures d'arrivee et de depart par defaut (admin).
  static const String heuresParDefaut = "/heures-par-defaut";
  static const String biensDesactives = "/biens-desactives";
  // Droits de chaque role, module par module (administrateur).
  static const String permissions = "/permissions";

  // Location longue duree ; ?onglet=tableau|baux|logements&filtre=... ouvre
  // directement un onglet filtre (baux : actif, termine, tous, impayes,
  // finissants ; logements : tous, loues, libres).
  static const String baux = "/baux";
  static const String bailDetail = "/bail/:id";
  // Bien a proposer d'office en extra (BienLongueDuree) ; rend le Bail cree.
  static const String bailForm = "/bail-form";

  // Vente de biens ; ?filtre=tous|a_vendre|compromis|vendu|sans_mandat&dossier=ID.
  static const String ventes = "/ventes";
  // Dossier de vente d'un bien ; ?onglet=mandats|visites, ?mandat=1 ouvre le formulaire.
  static const String dossierVente = "/vente/:id";
  static const String visitesVentes = "/ventes-visites";
  // Entree du module Vente : les dossiers de vente, avec les compteurs par statut.
  static const String dossiersVente = "/ventes-dossiers";


  static GoRouter router = GoRouter(
    initialLocation: login,
    routes: [
      GoRoute(
        path: forgotPassword,
        builder: (context, state) => ForgotPasswordPage.page(),
      ),
      GoRoute(

        path: login,
        redirect: (cxt, state) {
          SharedPrefService sharedPrefService =
              Dependencies.get<SharedPrefService>();
          if (sharedPrefService.contains(SharedPrefService.token)) {
            return initialiser;
          }
        },
        pageBuilder: (context, state) =>
            NoTransitionPage(child: LoginPage.page()),
      ),
      GoRoute(
        path: initialiser,
        pageBuilder: (context, state) =>
            NoTransitionPage(child: InitiliserPage.page()),
      ),
      GoRoute(
        path: home,
        pageBuilder: (context, state) => NoTransitionPage(child: HomePage()),
      ),
      GoRoute(
        path: groupesImmobilier,
        pageBuilder: (context, state) =>
            NoTransitionPage(child: GroupesImmobilierPage.page()),
      ),
      GoRoute(
        path: immobilier,
        // « Tous les biens » de la vente ouvre les dossiers de vente.
        redirect: (context, state) {
          final q = state.uri.queryParameters;
          return q.length == 1 && q['type'] == 'selle' ? dossiersVente : null;
        },
        pageBuilder: (context, state) {
          final q = state.uri.queryParameters;
          return NoTransitionPage(
            child: ImmobilierPage.page(
              typeInitial: q['type'],
              secteurInitial:
                  q['secteur'] != null ? int.tryParse(q['secteur']!) : null,
              sansSecteur: q['sansSecteur'] == '1',
              rechercheOuverte: q['recherche'] == '1',
            ),
          );
        },
      ),
      GoRoute(
        // ?type=selle&dossier=ID : ajout depuis un dossier ; ?brouillon=ID : reprise d'un brouillon.
        path: addImmobilier,
        pageBuilder: (context, state) {
          final q = state.uri.queryParameters;
          return NoTransitionPage(
            child: AddModifyImmobilierPage.page(
              type: q['type'],
              dossier: int.tryParse(q['dossier'] ?? ''),
              brouillon: q['brouillon'],
            ),
          );
        },
      ),
      GoRoute(
          path: addOwner,
        pageBuilder: (ctx,state)=>NoTransitionPage(child: AddModifyOwnerPage.page())
      ),
      GoRoute(
          path: editOwner,
          pageBuilder: (ctx, state) {
            final owner = state.extra as Owner;
            return NoTransitionPage(child: AddModifyOwnerPage.page(owner: owner));
          }
      ),
      GoRoute(
          path: updateImmobilier,
        pageBuilder: (cxt,state){
            int id=int.parse(state.pathParameters["id"].toString());
            return NoTransitionPage(child: AddModifyImmobilierPage.page(id: id,));
        }
      ),
      GoRoute(
          path: homeImmobilier,
          pageBuilder: (cxt,state){
            int id=int.parse(state.pathParameters["id"].toString());
            return NoTransitionPage(child: ImmobilierHomePage.page(id,));
          }
      ),
      GoRoute(
          path: calendrierBiens,
          pageBuilder: (cxt, state) => const NoTransitionPage(child: CalendrierBiensPage()),
      ),
      GoRoute(
          path: calendrierBien,
          pageBuilder: (cxt,state){
            int id=int.parse(state.pathParameters["id"].toString());
            return NoTransitionPage(child: CalendrierBienPage.page(id, titre: state.uri.queryParameters['titre']));
          }
      ),
      GoRoute(
          path: airbnbBiens,
          pageBuilder: (cxt, state) => NoTransitionPage(child: AirbnbBiensPage.page()),
      ),
      GoRoute(
          path: airbnbBien,
          pageBuilder: (cxt, state) {
            int id = int.parse(state.pathParameters["id"].toString());
            return NoTransitionPage(child: AirbnbBienPage.page(id, titre: state.uri.queryParameters['titre']));
          }
      ),
      GoRoute(
          path: immobilierDetails,
          pageBuilder: (cxt,state){
            int id=int.parse(state.pathParameters["id"].toString());
            return NoTransitionPage(child: ImmobilierDetailPage.page(id));
          }
      ),
      GoRoute(
          path: addReservation,
          pageBuilder: (cxt,state){
            int id=int.parse(state.pathParameters["id"].toString());
            // Dates du calendrier ou réservation Airbnb, s'il y en a.
            final pre = state.extra is PreRemplissageReservation
                ? state.extra as PreRemplissageReservation
                : null;
            return NoTransitionPage(child: AddReservationPage.page(id, preRemplissage: pre));
          }
      ),
      GoRoute(
          path: addClient,
          pageBuilder: (cxt,state){
            return NoTransitionPage(child: AddClientPage.page());
          }
      ),
      GoRoute(
          path: reservationList,
          pageBuilder: (cxt,state){
            int id=int.parse(state.pathParameters["id"].toString());
            return NoTransitionPage(child: ReservationList.page(id));
          }
      ),
      GoRoute(
          path: contracts,
          pageBuilder: (cxt,state){
            int id=int.parse(state.pathParameters["id"].toString());
            return NoTransitionPage(child: ContractsList.page(id));
          }
      ),
      GoRoute(
          path: addContract,
          pageBuilder: (cxt,state){
            int id=int.parse(state.pathParameters["id"].toString());
            return NoTransitionPage(child: AddContractScreen.page(id));
          }
      ),
      GoRoute(
          path: realestateCharges,
          pageBuilder: (cxt,state){
            int id=int.parse(state.pathParameters["id"].toString());
            return NoTransitionPage(child: ChargesScreen.page(id: id));
          }
      ),
      GoRoute(
          path: stats,
          pageBuilder: (cxt,state){
            int id=int.parse(state.pathParameters["id"].toString());
            return NoTransitionPage(child: StatsScreen.page(id));
          }
      ),
      GoRoute(
          path: platform,
          pageBuilder: (cxt,state){
            //int id=int.parse(state.pathParameters["id"].toString());
            return NoTransitionPage(child: PlatformHome());
          }
      ),
      GoRoute(
          path: statistics,
          pageBuilder: (cxt,state){
            //int id=int.parse(state.pathParameters["id"].toString());
            return NoTransitionPage(child: StatisticsScreen.page());
          }
      ),
      GoRoute(
          path: users,
          pageBuilder: (cxt,state){
            //int id=int.parse(state.pathParameters["id"].toString());
            return NoTransitionPage(child: UsersListScreen.page());
          }
      ),
      GoRoute(
          path: announces,
          pageBuilder: (cxt,state){
            //int id=int.parse(state.pathParameters["id"].toString());
            return NoTransitionPage(child: AnnouncesScreen.page());
          }
      ),
      GoRoute(
          path: sliders,
          pageBuilder: (cxt,state){
            //int id=int.parse(state.pathParameters["id"].toString());
            return NoTransitionPage(child: SlidersScreen.page());
          }
      ),
      GoRoute(
          path: addSlider,
          pageBuilder: (cxt,state){
            //int id=int.parse(state.pathParameters["id"].toString());
            return NoTransitionPage(child: AddSliderScreen.page());
          }
      ),
      GoRoute(
          path: addUser,
          pageBuilder: (cxt,state){
            //int id=int.parse(state.pathParameters["id"].toString());
            return NoTransitionPage(child: AddUserScreen.page());
          }
      ),
      GoRoute(
          path: appInactive,
          pageBuilder: (cxt,state){
            //int id=int.parse(state.pathParameters["id"].toString());
            return NoTransitionPage(child: AppInactivePage());
          }
      ),
      GoRoute(
          path: newVersion,
          pageBuilder: (cxt,state){
            return NoTransitionPage(child: AppNewVersionPage.page());
          }
      ),
      GoRoute(
          path: reservation,
          pageBuilder: (cxt,state){
            return NoTransitionPage(child: ReservationPage.page());
          }
      ),
      GoRoute(
          path: clients,
          pageBuilder: (cxt,state){
            return NoTransitionPage(child: ClientsPage.page());
          }
      ),
      GoRoute(
          path: owners,
          pageBuilder: (cxt,state){
            return NoTransitionPage(child: OwnersPage.page());
          }
      ),
      GoRoute(
          path: charges,
          pageBuilder: (cxt,state){
            int? realestate=state.uri.queryParameters['realestate']!=null?int.parse(state.uri.queryParameters['realestate']!):null;
            return NoTransitionPage(child: ChargesHome(propertyId: realestate,));
          }
      ),
      GoRoute(
          path: clientDetail,
          pageBuilder: (cxt,state){
            int id=int.parse(state.pathParameters["id"].toString());
            return NoTransitionPage(child: ClientDetailsPage.page(id));
          }
      ),
      GoRoute(
          path: editClient,
          pageBuilder: (cxt,state){
            final client=state.extra as Client;
            return NoTransitionPage(child: EditClientPage.page(client));
          }
      ),
      GoRoute(
          path: ownerDetail,
          pageBuilder: (cxt,state){
            int id=int.parse(state.pathParameters["id"].toString());
            return NoTransitionPage(child: OwnerDetailsPage.page(id));
          }
      ),
      GoRoute(
          path: reports,
          pageBuilder: (cxt,state){
            int id=int.parse(state.pathParameters["id"].toString());
            return NoTransitionPage(child: RapportListPage.page(id));
          }
      ),
      GoRoute(
          path: addRapport,
          pageBuilder: (cxt,state){
            int id=int.parse(state.pathParameters["id"].toString());
            return NoTransitionPage(child: AddRapportPage.page(id));
          }
      ),
      GoRoute(
          path: gestionImmobilier,
          pageBuilder: (cxt,state){
            return NoTransitionPage(child:GestionImmobilierHome.page());
          }
      ),
      GoRoute(
          path: immobilierByStatus,
          // Reserve / disponible / nettoyage ne valent que pour la courte duree :
          // les deux autres familles ouvrent leur propre module.
          redirect: (cxt, state) {
            final status = state.pathParameters["status"];
            final type = state.uri.queryParameters['type'];
            if (type == 'rent-long') {
              final filtre = status == 'reserved' ? 'loues' : (status == 'available' ? 'libres' : 'tous');
              return '$baux?onglet=logements&filtre=$filtre';
            }
            if (type == 'selle') {
              final filtre = status == 'reserved' ? 'compromis' : (status == 'available' ? 'a_vendre' : 'tous');
              final dossier = state.uri.queryParameters['dossier'];
              return Uri(path: ventes, queryParameters: {
                'filtre': filtre,
                if (dossier != null) 'dossier': dossier,
              }).toString();
            }
            return null;
          },
          pageBuilder: (cxt,state){
            final status=state.pathParameters["status"];
            return NoTransitionPage(child:ImmobilierByStatusPage.page(status!, type: state.uri.queryParameters['type'],
                dossier: state.uri.queryParameters['dossier'],
                vue: state.uri.queryParameters['vue']));
          }
      ),
      GoRoute(
          path: signature,
          pageBuilder: (cxt,state){
            return NoTransitionPage(child:SignaturePage());
          }
      ),
      GoRoute(
          path: updateUser,
          pageBuilder: (cxt,state){
            int id=int.parse(state.pathParameters["id"].toString());
            return NoTransitionPage(child:AddUserScreen.page(id: id));
          }
      ),
      GoRoute(
          path: programedCharges,
          pageBuilder: (cxt,state){
            int? realestate=state.uri.queryParameters['realestate']!=null?int.parse(state.uri.queryParameters['realestate']!):null;
            return NoTransitionPage(child:ProgramedChargesPage.page(realestate: realestate));
          }
      ),
      GoRoute(
          path: createProgramedCharges,
          pageBuilder: (cxt,state){
            int? realestate=state.uri.queryParameters['realestate']!=null?int.parse(state.uri.queryParameters['realestate']!):null;
            return NoTransitionPage(child:AddModifyProgramedCharge.page(realestate: realestate));
          }
      ),
      GoRoute(
          path: updateProgramedCharges,
          pageBuilder: (cxt,state){
            int id=int.parse(state.pathParameters['id'].toString());
            return NoTransitionPage(child:AddModifyProgramedCharge.page(id: id));
          }
      ),
      GoRoute(
          path: chargesList,
          pageBuilder: (cxt,state){
            int? realestate=state.uri.queryParameters['realestate']!=null?int.parse(state.uri.queryParameters['realestate']!):null;
            return NoTransitionPage(child:ChargesPage.page(realestate: realestate));
          }
      ),
      GoRoute(
          path: addCharge,
          pageBuilder: (cxt,state){
            int? realestate=state.uri.queryParameters['realestate']!=null?int.parse(state.uri.queryParameters['realestate']!):null;
            return NoTransitionPage(child:AddChargePage.page(realestate: realestate));
          }
      ),
      GoRoute(
          path: modelesMessages,
          pageBuilder: (cxt, state) =>
              NoTransitionPage(child: ModelesMessagesPage.page())
      ),
      GoRoute(
          path: campagnes,
          pageBuilder: (cxt, state) =>
              NoTransitionPage(child: CampagnesPage.page())
      ),
      GoRoute(
          path: chargesAnnulees,
          pageBuilder: (cxt, state) =>
              NoTransitionPage(child: ChargesAnnuleesPage.page())
      ),
      GoRoute(
          path: nouvelleReservation,
          pageBuilder: (cxt, state) =>
              const NoTransitionPage(child: ChoixBienReservationPage())
      ),
      GoRoute(
          path: corbeilleReservations,
          pageBuilder: (cxt, state) =>
              NoTransitionPage(child: CorbeillePage.page())
      ),
      GoRoute(
          path: exportReservations,
          pageBuilder: (cxt, state) =>
              NoTransitionPage(child: ExportReservationsPage.page())
      ),
      GoRoute(
          path: caisses,
          pageBuilder: (cxt, state) => NoTransitionPage(
              child: CaissesPage.page(
                  action: state.uri.queryParameters['action']))
      ),
      GoRoute(
          path: addCampagne,
          pageBuilder: (cxt, state) =>
              NoTransitionPage(child: CreationCampagnePage.page())
      ),
      GoRoute(
          path: campagneDetail,
          pageBuilder: (cxt, state) {
            int id = int.parse(state.pathParameters["id"].toString());
            return NoTransitionPage(child: DetailCampagnePage.page(id: id));
          }
      ),
      GoRoute(
          path: reclamationsList,
          pageBuilder: (cxt,state){
            int? realestate = state.uri.queryParameters['realestate'] != null
                ? int.parse(state.uri.queryParameters['realestate']!)
                : null;
            return NoTransitionPage(child: ReclamationsListPage.page(realestateId: realestate));
          }
      ),
      GoRoute(
          path: addReclamation,
          pageBuilder: (cxt,state){
            int id=int.parse(state.pathParameters["id"].toString());
            return NoTransitionPage(child: AddReclamationPage.page(id));
          }
      ),
      GoRoute(
          path: financialStats,
          pageBuilder: (cxt,state){
            return NoTransitionPage(child: FinancialStatsScreen.page());
          }
      ),
      GoRoute(
          path: financialStatsProperty,
          pageBuilder: (cxt,state){
            int id=int.parse(state.pathParameters["id"].toString());
            return NoTransitionPage(child: FinancialStatsScreen.page(realestateId: id));
          }
      ),
      GoRoute(
          path: syndics,
          pageBuilder: (cxt, state) =>
              NoTransitionPage(child: SyndicsPage.page())
      ),
      GoRoute(
          path: syndicForm,
          pageBuilder: (cxt, state) {
            final syndic = state.extra is Syndic ? state.extra as Syndic : null;
            return NoTransitionPage(child: SyndicFormPage.page(syndic: syndic));
          }
      ),
      GoRoute(
          path: syndicDetail,
          pageBuilder: (cxt, state) {
            int id = int.parse(state.pathParameters["id"].toString());
            return NoTransitionPage(child: SyndicDetailPage.page(id));
          }
      ),
      GoRoute(
          path: baux,
          pageBuilder: (cxt, state) => NoTransitionPage(
              child: BauxPage.page(
                  onglet: state.uri.queryParameters['onglet'],
                  filtre: state.uri.queryParameters['filtre']))
      ),
      GoRoute(
          path: ventes,
          pageBuilder: (cxt, state) => NoTransitionPage(
              child: VentesPage.page(
                  filtre: state.uri.queryParameters['filtre'],
                  dossier: state.uri.queryParameters['dossier']))
      ),
      GoRoute(
          path: dossierVente,
          pageBuilder: (cxt, state) {
            int id = int.parse(state.pathParameters["id"].toString());
            final q = state.uri.queryParameters;
            return NoTransitionPage(
                child: DossierVentePage.page(id, onglet: q['onglet'], nouveauMandat: q['mandat'] == '1'));
          }
      ),
      GoRoute(
          path: dossiersVente,
          pageBuilder: (cxt, state) => NoTransitionPage(child: pageDossiersVente())
      ),
      GoRoute(
          path: visitesVentes,
          pageBuilder: (cxt, state) => const NoTransitionPage(child: VisitesVentesPage())
      ),
      GoRoute(
          path: bailDetail,
          pageBuilder: (cxt, state) {
            int id = int.parse(state.pathParameters["id"].toString());
            final bail = state.extra is Bail ? state.extra as Bail : null;
            final nouveau = state.uri.queryParameters['nouveau'] == '1';
            return NoTransitionPage(child: BailDetailPage.page(id, initial: bail, nouveau: nouveau));
          }
      ),
      GoRoute(
          path: bailForm,
          pageBuilder: (cxt, state) {
            final bien = state.extra is BienLongueDuree ? state.extra as BienLongueDuree : null;
            return NoTransitionPage(child: BailFormPage.page(bien: bien));
          }
      ),
      GoRoute(
          path: receptionWhatsapp,
          pageBuilder: (cxt, state) {
            final params = state.uri.queryParameters;
            return NoTransitionPage(
                child: ReceptionWhatsappPage.page(
                    managerId: int.tryParse(params['manager'] ?? ''),
                    nom: params['nom']));
          }
      ),
      GoRoute(
          path: receptionsWhatsapp,
          pageBuilder: (cxt, state) =>
              NoTransitionPage(child: ReceptionsWhatsappPage.page())
      ),
      GoRoute(
          path: detailReservation,
          pageBuilder: (cxt, state) {
            int id = int.parse(state.pathParameters["id"].toString());
            return NoTransitionPage(child: DetailReservationPage.page(id));
          }
      ),
      GoRoute(
          path: heuresParDefaut,
          pageBuilder: (cxt, state) =>
              const NoTransitionPage(child: HeuresParDefautPage())
      ),
      GoRoute(
          path: biensDesactives,
          pageBuilder: (cxt, state) =>
              const NoTransitionPage(child: BiensDesactivesPage())
      ),
      GoRoute(
          path: permissions,
          pageBuilder: (cxt, state) =>
              NoTransitionPage(child: PermissionsPage.page())
      ),
    ],
  );
}
