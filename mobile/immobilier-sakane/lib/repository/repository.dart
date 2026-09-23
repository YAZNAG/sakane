import 'package:immobilier/models/bien_desactive.dart';
import 'package:immobilier/models/reception_whatsapp.dart';
import 'package:immobilier/models/module_accueil.dart';
import 'package:immobilier/models/categories_immobilier.dart';
import 'package:immobilier/models/apercu_famille.dart';
import 'package:immobilier/models/apercu_bien.dart';
import 'package:immobilier/models/resume_accueil.dart';
import 'dart:typed_data';
import 'dart:io';
import 'package:immobilier/models/booking.dart';
import 'package:immobilier/models/financial_stats.dart';
import 'package:immobilier/models/category.dart';
import 'package:immobilier/models/charge.dart';
import 'package:immobilier/models/charge_annulee.dart';
import 'package:immobilier/models/city.dart';
import 'package:immobilier/models/client.dart';
import 'package:immobilier/models/contract.dart';
import 'package:immobilier/models/etat.dart';
import 'package:immobilier/models/feature.dart';
import 'package:immobilier/models/immobilier_overview.dart';
import 'package:immobilier/models/manager.dart';
import 'package:immobilier/models/owner.dart';
import 'package:immobilier/models/programed_charge.dart';
import 'package:immobilier/models/rapport.dart';
import 'package:immobilier/models/reclamation.dart';
import 'package:immobilier/models/realestate.dart';
import 'package:immobilier/models/realestate_stats.dart';
import 'package:immobilier/models/region.dart';
import 'package:immobilier/models/type_transaction.dart';
import 'package:immobilier/repository/data_providers/api/api_client.dart';

import '../models/application.dart';
import '../models/global_stats.dart';
import '../models/slider.dart';
import 'package:immobilier/models/secteur.dart';
import 'package:immobilier/models/campagne.dart';
import 'package:immobilier/models/numero_campagnes.dart';
import 'package:immobilier/models/modele_message.dart';
import 'package:immobilier/models/permissions_roles.dart';
import 'package:immobilier/models/dossier.dart';
import 'package:immobilier/models/caisse.dart';
import 'package:immobilier/models/reservation_supprimee.dart';
import 'package:immobilier/core/services/transcription_arabe.dart';
import 'package:immobilier/models/syndic.dart';
import 'package:immobilier/models/facture_reservation.dart';
import 'package:immobilier/models/detail_reservation.dart';
import 'package:immobilier/models/envoi_historique_syndic.dart';
import 'package:immobilier/models/contrat_proprietaire.dart';
import 'package:immobilier/models/apercu_suppression.dart';
import 'package:immobilier/models/calendrier_bien.dart';
import 'package:immobilier/models/airbnb.dart';
import 'package:immobilier/models/bail.dart';
import 'package:immobilier/models/vente.dart';

class Repository {
  ApiClient apiClient;

  Repository({required this.apiClient});

  Future<String> forgetPassword(String email) async {
    return await apiClient.forgetPassword(email);
  }

  Future<void> checkOtp(String email, String otp) async {
    await apiClient.checkOtp(email, otp);
  }

  Future<void> resetPassword(
      String email, String otp, String password, String confirmation) async {
    await apiClient.resetPassword(email, otp, password, confirmation);
  }

  Future<Manager> login(Manager manager) async {
    Manager res = await apiClient.login(manager);
    return res;
  }

  Future<Manager> me() async {
    Manager res = await apiClient.me();
    return res;
  }

  Future<List<Realestate>> getRealestates(
      {String? status, String? type, String? dossier}) async {
    return await apiClient.getRealestates(
        status: status, type: type, dossier: dossier);
  }

  Future<List<Category>> fetchCategories() async {
    return await apiClient.fetchCategories();
  }

  Future<List<TypeTransaction>> fetchTransactionTypes() async {
    return await apiClient.fetchTransactionTypes();
  }

  Future<List<Etat>> fetchEtats() async {
    return await apiClient.fetchEtats();
  }

  Future<List<City>> fetchCities({required int regionId}) async {
    return await apiClient.fetchCities(regionId: regionId);
  }

  // ================= Dossiers de biens =================

  Future<List<Dossier>> fetchDossiers({String? type}) =>
      apiClient.fetchDossiers(type: type);

  Future<Dossier> creerDossier(String nom,
          {String? description, String? type, List<int>? biens}) =>
      apiClient.creerDossier(nom,
          description: description, type: type, biens: biens);

  Future<Dossier> renommerDossier(int id, String nom, {String? description}) =>
      apiClient.renommerDossier(id, nom, description: description);

  Future<void> supprimerDossier(int id) => apiClient.supprimerDossier(id);

  Future<List<AgentDuDossier>> affecterAgentsDossier(
          int dossierId, List<int> agents) =>
      apiClient.affecterAgentsDossier(dossierId, agents);

  Future<List<Dossier>> dossiersDeLAgent(int managerId) =>
      apiClient.dossiersDeLAgent(managerId);

  Future<List<Dossier>> majDossiersDeLAgent(int managerId, List<int> dossiers) =>
      apiClient.majDossiersDeLAgent(managerId, dossiers);

  Future<int> affecterAuDossier(List<int> biens, int? dossier) =>
      apiClient.affecterAuDossier(biens, dossier);

  Future<List<Secteur>> fetchSecteurs({int? cityId}) async {
    return await apiClient.fetchSecteurs(cityId: cityId);
  }

  Future<Secteur> addSecteur(String nom, {int? cityId}) async {
    return await apiClient.addSecteur(nom, cityId: cityId);
  }

  /// La facture d'une reservation, dans un fichier temporaire.
  Future<FactureReservation> factureReservation(int id) => apiClient.factureReservation(id);

  /// Detail complet d'une reservation (historique, caisse, facture).
  Future<DetailReservation> detailReservation(int id) => apiClient.detailReservation(id);

  Future<DetailReservation> modifierPrixReservation(int id,
          {required double prixNuit, double? encaisse, bool? rembourser}) =>
      apiClient.modifierPrixReservation(id, prixNuit: prixNuit, encaisse: encaisse, rembourser: rembourser);

  Future<ResumeFacture> resumeFacture(int id) => apiClient.resumeFacture(id);

  /// Definitif : la TVA entre dans ma caisse (422 si deja appliquee).
  Future<ResumeFacture> appliquerFacture(
    int id, {
    double? tva,
    String? clientNom,
    String? clientIce,
    String? clientAdresse,
  }) =>
      apiClient.appliquerFacture(id,
          tva: tva, clientNom: clientNom, clientIce: clientIce, clientAdresse: clientAdresse);

  Future<HeuresParDefaut> heuresParDefaut() => apiClient.heuresParDefaut();

  Future<HeuresParDefaut> enregistrerHeuresParDefaut({String? arrivee, String? depart}) =>
      apiClient.enregistrerHeuresParDefaut(arrivee: arrivee, depart: depart);

  /// Envoie cette facture au client, par WhatsApp.
  Future<String> envoyerFacture(int id) => apiClient.envoyerFacture(id);

  Future<String> apercuContrat({
    required String checkin,
    required String checkout,
    required int guest,
    required int realestate,
    required int client,
    required num nightPrice,
    required String typeGuest,
    num? avance,
    num? caution,
    String? heureArrivee,
    String? heureDepart,
  }) =>
      apiClient.apercuContrat(
        checkin: checkin,
        checkout: checkout,
        guest: guest,
        realestate: realestate,
        client: client,
        nightPrice: nightPrice,
        typeGuest: typeGuest,
        heureArrivee: heureArrivee,
        heureDepart: heureDepart,
        avance: avance,
        caution: caution,
      );

  // ================= Modeles de messages =================

  Future<List<ModeleMessage>> fetchModelesMessages() =>
      apiClient.fetchModelesMessages();

  Future<ModeleMessage> fetchModeleMessage(int id) =>
      apiClient.fetchModeleMessage(id);

  Future<List<VariableModele>> fetchVariablesModeles() =>
      apiClient.fetchVariablesModeles();

  Future<ApercuModele> apercuModele(String contenu) =>
      apiClient.apercuModele(contenu);

  Future<ModeleMessage> majModeleMessage(int id, String contenu, {bool? actif}) =>
      apiClient.majModeleMessage(id, contenu, actif: actif);

  Future<ModeleMessage> deposerImageModele(int id, File image) =>
      apiClient.deposerImageModele(id, image);

  Future<ModeleMessage> retirerImageModele(int id) =>
      apiClient.retirerImageModele(id);

  Future<ModeleMessage> restaurerModeleMessage(int id) =>
      apiClient.restaurerModeleMessage(id);

  // ================= Campagnes / diffusion clients =================

  Future<List<Campagne>> fetchCampagnes() => apiClient.fetchCampagnes();

  Future<Campagne> fetchCampagne(int id) => apiClient.fetchCampagne(id);

  Future<List<Map<String, String>>> fetchSegmentsCampagne() =>
      apiClient.fetchSegmentsCampagne();

  Future<EstimationSegment> estimerSegment(SegmentClients segment) =>
      apiClient.estimerSegment(segment);

  Future<Campagne> addCampagne(Campagne campagne,
          {bool envoyerMaintenant = false}) =>
      apiClient.addCampagne(campagne, envoyerMaintenant: envoyerMaintenant);

  Future<void> envoyerTestCampagne({
    required String telephone,
    required String message,
    String? lien,
    int? campagneId,
  }) =>
      apiClient.envoyerTestCampagne(
        telephone: telephone,
        message: message,
        lien: lien,
        campagneId: campagneId,
      );

  Future<Campagne> lancerCampagne(int id) => apiClient.lancerCampagne(id);

  Future<Campagne> annulerCampagne(int id) => apiClient.annulerCampagne(id);

  Future<Campagne> relancerEchecsCampagne(int id) =>
      apiClient.relancerEchecsCampagne(id);

  Future<Campagne> pauseCampagne(int id) => apiClient.pauseCampagne(id);

  Future<Campagne> reprendreCampagne(int id) =>
      apiClient.reprendreCampagne(id);

  Future<void> supprimerCampagne(int id) => apiClient.supprimerCampagne(id);

  Future<NumeroCampagnes> fetchNumeroCampagnes() =>
      apiClient.fetchNumeroCampagnes();

  Future<NumeroCampagnes> enregistrerNumeroCampagnes(String cle) =>
      apiClient.enregistrerNumeroCampagnes(cle);

  Future<NumeroCampagnes> retirerNumeroCampagnes() =>
      apiClient.retirerNumeroCampagnes();

  Future<bool> majPromotionsClient(int clientId, bool accepte) =>
      apiClient.majPromotionsClient(clientId, accepte);

  Future<List<Region>> fetchRegions() async {
    return await apiClient.fetchRegions();
  }

  Future<List<Owner>> fetchOwners() async {
    return await apiClient.fetchOwners();
  }
  Future<List<Feature>> fetchFeatures()async{
    return await apiClient.fetchFeatures();
  }
  Future<Realestate> fetchRealesate(int id)async{
    return await apiClient.fetchRealestate(id);
  }
  Future<Realestate> addRealestate(Realestate realestate) async{
    return await apiClient.addRealestate(realestate);
  }

  Future<Realestate> updateRealestate(Realestate realestate) async{
    return await apiClient.updateRealestate(realestate);
  }

  Future<Owner> addOwner(Owner owner) async{
    return await apiClient.addOwner(owner);
  }

  Future<List<Client>> getClients({String? search})async{
    return await apiClient.getClients(search: search);
  }

  Future<Booking> addBooking(Booking booking, {int? airbnbSejour})async{
    return await apiClient.addBooking(booking, airbnbSejour: airbnbSejour);
  }
  Future<Client> addClient(Client client)async{
    return await apiClient.addClient(client);
  }
  
  Future<List<Booking>> fetchBookings(String from,String to,{String? type,int? id})async{
    return await apiClient.fetchBookings(from, to,type: type,id:id);
  }

  Future<Contract> addContract(Contract contract)async{
    return await apiClient.addContract(contract);
  }

  Future<List<Contract>> getContracts(int realestate)async{
    return await apiClient.getContracts(realestate);
  }




  Future<List<Charge>> getCharges(String from,String to, {int? realestate})async{
    return await apiClient.getCharges(from,to,realestate: realestate);
  }


  Future<RealestateStats> getRealestateStats(String from,String to,String groupBy,int realestate)async{
    return await apiClient.getRealestateStats(from, to, groupBy, realestate);
  }

  Future<List<Realestate>> getPendingAnnoces()async{
    return await apiClient.getPendingAnnoces();
  }

  Future<Realestate> acceptAnnounce(int id)async{
    return await apiClient.acceptAnnounce(id);

  }

  Future<Realestate> refuseAnnounce(int id)async{
    return await apiClient.refuseAnnounce(id);
  }

  Future<List<SliderModel>> getSliders()async{
    return await apiClient.getSliders();
  }

  Future<SliderModel> activateSlider(int id)async{
    return await apiClient.activateSlider(id);
  }

  Future<SliderModel> addSlider(SliderModel slider)async{
    return await apiClient.addSlider(slider);
  }

  Future<List<Manager>> getManagers()async{
    return await apiClient.fetchManagers();
  }

  Future<Manager> addUser(Manager manager)async{
    return await apiClient.addUser(manager);
  }

  Future<GlobalStats> getGlobalStats(String from,
      String to,
      String groupBy,)async{
    return await apiClient.getGlobalStats(from, to, groupBy);
  }

  Future<AppVersion> getApplicationVersion(String packageName)async{
    return await apiClient.getApplicationVersion(packageName);
  }

  Future<Client> fetchClientDetail(int id)async{
    return await apiClient.fetchClientDetails(id);
  }
  Future<Client> updateClient(Client client)async{
    return await apiClient.updateClient(client);
  }
  Future<void> deleteClient(int id)async{
    return await apiClient.deleteClient(id);
  }
  Future<Owner> fetchOwnerDetails(int id)async{
    return await apiClient.fetchOwnerDetails(id);
  }

  Future<Owner> updateOwner(Owner owner) async {
    return await apiClient.updateOwner(owner);
  }

  Future<List<Rapport>> fetchRapports(int id)async{
    return await apiClient.fetchRapports(id);
  }

  Future<Rapport> addRapport(Rapport rapport)async{
    return await apiClient.addRapport(rapport);
  }



  Future<ImmobilierOverview> fetchImmobilierOverview()async{
    return await apiClient.fetchImmobilierOverview();
  }

  Future<void> confirmDepart(int id)async{
    await apiClient.confirmDepart(id);
  }
  Future<void> confirmCheckin(int id)async{
    await apiClient.confirmCheckin(id);
  }
  Future<void> startCleaning(int id) async {
    return await apiClient.startCleaning(id);
  }

  Future<void> returnToCleaning(int id, {String? motif}) async {
    return await apiClient.returnToCleaning(id, motif: motif);
  }

  Future<String> telechargerExportStatistiques({
    required String format,
    String? from,
    String? to,
    int? realestate,
    void Function(int, int)? onProgress,
  }) async {
    return await apiClient.telechargerExportStatistiques(
      format: format,
      from: from,
      to: to,
      realestate: realestate,
      onProgress: onProgress,
    );
  }

  Future<void> finishCleaning(int id)async{
    await apiClient.finishCleaning(id);
  }
  Future<List<String>> getRoles()async{
    return await apiClient.getRoles();
  }
  Future<void> extendBooking(DateTime newCheckout, double price, int id) async {
    return await apiClient.extendBooking(newCheckout, price, id);
  }
  Future<void> shrinkBooking(DateTime newCheckout,double price,int id)async{
    return await apiClient.shrinkBooking(newCheckout, price, id);
  }

  Future<void> deleteBooking(int id, {bool? rembourse, double? montantRembourse}) async {
    return await apiClient.deleteBooking(id, rembourse: rembourse, montantRembourse: montantRembourse);
  }

  Future<void> annulerCharge(int id, {double? montant, String? motif}) =>
      apiClient.annulerCharge(id, montant: montant, motif: motif);

  Future<List<ChargeAnnulee>> chargesAnnulees() => apiClient.chargesAnnulees();

  Future<List<Booking>> fetchArrivees(String quand, {String? type, String? dossier}) =>
      apiClient.fetchArrivees(quand, type: type, dossier: dossier);

  /// Le résumé de l'accueil : utilisateur, agence, caisse, compteurs du jour.
  Future<ResumeAccueil> resumeAccueil() => apiClient.resumeAccueil();

  /// Les trois familles de biens et leurs compteurs (ecran Immobilier).
  Future<CategoriesImmobilier> categoriesImmobilier() =>
      apiClient.categoriesImmobilier();

  /// L'apercu d'une famille : compteurs, arrivees et departs du jour.
  Future<ApercuFamille> apercuFamille(String code) =>
      apiClient.apercuFamille(code);

  /// L'apercu d'un bien pour sa page de gestion.
  Future<ApercuBien> apercuBien(int bienId) => apiClient.apercuBien(bienId);

  Future<Map<String, dynamic>?> lireDispositionAccueil() =>
      apiClient.lireDispositionAccueil();

  Future<void> enregistrerDispositionAccueil(Map<String, dynamic> corps) =>
      apiClient.enregistrerDispositionAccueil(corps);

  Future<List<ModuleAccueil>> lireModulesAccueil() => apiClient.lireModulesAccueil();

  Future<List<ModuleAccueil>> enregistrerModulesAccueil(List<ModuleAccueil> modules) =>
      apiClient.enregistrerModulesAccueil(modules);

  Future<void> reinitialiserModulesAccueil() => apiClient.reinitialiserModulesAccueil();

  Future<List<Map<String, dynamic>>> fetchBlocages(int realestateId) =>
      apiClient.fetchBlocages(realestateId);

  Future<void> ajouterBlocage(int realestateId, {required String du, required String au, String? motif}) =>
      apiClient.ajouterBlocage(realestateId, du: du, au: au, motif: motif);

  Future<void> supprimerBlocage(int id) => apiClient.supprimerBlocage(id);

  Future<List<Map<String, dynamic>>> chercherDoublonsClient({String? tel, String? cin, String? prenom, String? nom}) =>
      apiClient.chercherDoublonsClient(tel: tel, cin: cin, prenom: prenom, nom: nom);

  Future<Map<String, dynamic>> reglagesSyndic({int? bookingId}) =>
      apiClient.reglagesSyndic(bookingId: bookingId);

  Future<String> partagerContratSyndic(int bookingId,
          {required String telephone, required String message, bool enregistrer = false}) =>
      apiClient.partagerContratSyndic(bookingId,
          telephone: telephone, message: message, enregistrer: enregistrer);

  Future<ApercuSuppression> apercuSuppression(int bookingId) => apiClient.apercuSuppression(bookingId);

  Future<Client> ajouterListeNoire(int clientId, String motif) => apiClient.ajouterListeNoire(clientId, motif);

  Future<Client> retirerListeNoire(int clientId) => apiClient.retirerListeNoire(clientId);

  Future<List<Syndic>> fetchSyndics() => apiClient.fetchSyndics();

  Future<Syndic> fetchSyndic(int id) => apiClient.fetchSyndic(id);

  Future<List<BienDuSyndic>> fetchBiensPourSyndic() => apiClient.fetchBiensPourSyndic();

  Future<Syndic> enregistrerSyndic({
    int? id,
    required String nom,
    required String telephone,
    bool actif = true,
    String? notes,
    required List<int> biens,
  }) =>
      apiClient.enregistrerSyndic(id: id, nom: nom, telephone: telephone, actif: actif, notes: notes, biens: biens);

  Future<void> supprimerSyndic(int id) => apiClient.supprimerSyndic(id);

  Future<HistoriqueEnvoisSyndic> fetchEnvoisSyndics(
          {String? du, String? au, int? syndic, String? statut}) =>
      apiClient.fetchEnvoisSyndics(du: du, au: au, syndic: syndic, statut: statut);

  Future<EnvoiHistoriqueSyndic> fetchEnvoiSyndic(int id) => apiClient.fetchEnvoiSyndic(id);

  Future<EnvoiHistoriqueSyndic> renvoyerEnvoiSyndic(int id) => apiClient.renvoyerEnvoiSyndic(id);

  Future<String> exporterEnvoisSyndics(
          {String? du, String? au, int? syndic, String? statut, required String format}) =>
      apiClient.exporterEnvoisSyndics(
          du: du, au: au, syndic: syndic, statut: statut, format: format);

  Future<String> telechargerContratEnvoiSyndic(String url, int envoiId) =>
      apiClient.telechargerContratEnvoiSyndic(url, envoiId);

  Future<ContratProprietaire> ajouterContratProprietaire(int ownerId, File fichier,
          {int? bienId, String? titre, String? dateDebut, String? dateFin}) =>
      apiClient.ajouterContratProprietaire(ownerId, fichier,
          bienId: bienId, titre: titre, dateDebut: dateDebut, dateFin: dateFin);

  Future<void> supprimerContratProprietaire(int id) => apiClient.supprimerContratProprietaire(id);

  Future<CalendrierBien> fetchCalendrier(int bienId, {required DateTime du, required DateTime au}) =>
      apiClient.fetchCalendrier(bienId, du: du, au: au);

  Future<LienAirbnb> fetchAirbnb(int bienId) => apiClient.fetchAirbnb(bienId);

  Future<LienAirbnb> enregistrerLienAirbnb(int bienId, String urlImport) =>
      apiClient.enregistrerLienAirbnb(bienId, urlImport);

  Future<LienAirbnb> synchroniserAirbnb(int bienId) => apiClient.synchroniserAirbnb(bienId);

  Future<LienAirbnb> nouveauLienExportAirbnb(int bienId) => apiClient.nouveauLienExportAirbnb(bienId);

  Future<List<BienAirbnb>> fetchBiensAirbnb() => apiClient.fetchBiensAirbnb();

  Future<List<SejourAirbnb>> fetchSejoursAirbnb({int? bienId}) =>
      apiClient.fetchSejoursAirbnb(bienId: bienId);

  Future<void> definirPrixNuits(int bienId, {required DateTime du, required DateTime au, required double prix}) =>
      apiClient.definirPrixNuits(bienId, du: du, au: au, prix: prix);

  Future<void> effacerPrixNuits(int bienId, {required DateTime du, required DateTime au}) =>
      apiClient.effacerPrixNuits(bienId, du: du, au: au);

  Future<TarifSejour> tarifSejour(int bienId, {required DateTime arrivee, required DateTime depart}) =>
      apiClient.tarifSejour(bienId, arrivee: arrivee, depart: depart);

  Future<void> debloquerPeriode(int bienId, {required DateTime du, required DateTime au}) =>
      apiClient.debloquerPeriode(bienId, du: du, au: au);

  Future<double> modifierReservation(int reservationId,
          {required DateTime arrivee, required DateTime depart, required double prixNuit}) =>
      apiClient.modifierReservation(reservationId, arrivee: arrivee, depart: depart, prixNuit: prixNuit);

  Future<Uint8List> exporterTableau(Map<String, dynamic> corps) =>
      apiClient.exporterTableau(corps);

  Future<void> deleteCharge(int id) async {
    return await apiClient.deleteCharge(id);
  }

  Future<void> deleteOwner(int id) async {
    return await apiClient.deleteOwner(id);
  }

  Future<void> deleteRealestate(int id) async {
    return await apiClient.deleteRealestate(id);
  }

  Future<void> deleteProgramedCharge(int id) async {
    return await apiClient.deleteProgramedCharge(id);
  }

  Future<Manager> updateUser(Manager manager)async{
    return await apiClient.updateUser(manager);
  }
  Future<void> deleteUser(Manager manager)async{
    return await apiClient.deleteUser(manager);
  }
  Future<Manager> fetchManager(int id)async{
    return await apiClient.fetchManager(id);
  }

  Future<List<ProgramedCharge>> fetchProgramedCharges({int? realestate})async{
    return await apiClient.fetchProgramedCharges(realestate:realestate);
  }
  Future<ProgramedCharge> addProgramedCharge(ProgramedCharge charge)async{
    return await apiClient.addProgramedCharge(charge);
  }

  Future<ProgramedCharge> updateProgramedCharge(ProgramedCharge charge)async{
    return await apiClient.updateProgramedCharge(charge);
  }

  Future<ProgramedCharge> fetchProgramedCharge(int id)async{
    return await apiClient.fetchProgramedCharge(id);
  }

  Future<Charge> validateCharge(Charge charge)async{
    return await apiClient.validate(charge);
  }

  Future<List<Charge>> fetchCharges({String? status,String? type,String? from,String? to,Object? realestate})async{
    return await apiClient.fetchCharges(type: type,status: status,from: from,to: to,realestate: realestate);
  }

  Future<Charge> addCharge(Charge charge)async{
    return await apiClient.addCharge(charge);
  }

  Future<List<Reclamation>> getReclamations({int? realestateId}) async {
    return await apiClient.getReclamations(realestateId: realestateId);
  }

  Future<Reclamation> createReclamation(Reclamation reclamation) async {
    return await apiClient.createReclamation(reclamation);
  }

  Future<Reclamation> resolveReclamation(int id) async {
    return await apiClient.resolveReclamation(id);
  }

  Future<FinancialStats> getFinancialStats({
    required String from,
    required String to,
    String groupBy = 'month',
    List<int> realestateIds = const [],
    String repartition = 'encaissement',
  }) async {
    return await apiClient.getFinancialStats(
      from: from,
      to: to,
      groupBy: groupBy,
      realestateIds: realestateIds,
      repartition: repartition,
    );
  }

  Future<String> exportFinancialStats({
    required String from,
    required String to,
    List<int> realestateIds = const [],
  }) async {
    return await apiClient.exportFinancialStats(
      from: from,
      to: to,
      realestateIds: realestateIds,
    );
  }

  Future<String> telechargerRapportStatistiques({
    required DateTime du,
    required DateTime au,
    List<int> biens = const [],
    required String repartition,
    required bool detail,
    required String format,
  }) {
    return apiClient.telechargerRapportStatistiques(
      du: du,
      au: au,
      biens: biens,
      repartition: repartition,
      detail: detail,
      format: format,
    );
  }

  Future<String> exportReservations({
    required String format,
    List<int> realestateIds = const [],
    List<int> clientIds = const [],
    DateTime? du,
    DateTime? au,
  }) async {
    return await apiClient.exportReservations(
      format: format,
      realestateIds: realestateIds,
      clientIds: clientIds,
      du: du,
      au: au,
    );
  }

  // ─── Caisses ────────────────────────────────────────────────────

  Future<MaCaisse> maCaisse() => apiClient.maCaisse();

  Future<VueCaisses> toutesLesCaisses() => apiClient.toutesLesCaisses();

  Future<(MemoireNom?, MemoireNom?)> nomsArabes(String? prenom, String? nom) =>
      apiClient.nomsArabes(prenom, nom);

Future<void> ouvrirCaisse({double? montant, bool reporter = false}) =>
      apiClient.ouvrirCaisse(montant: montant, reporter: reporter);

  Future<List<ReservationSupprimee>> corbeilleReservations() =>
      apiClient.corbeilleReservations();

  Future<void> restaurerReservation(int id) =>
      apiClient.restaurerReservation(id);

  Future<List<CaisseDestinataire>> destinatairesCaisse() =>
      apiClient.destinatairesCaisse();

  Future<void> declarerRemise(double montant, String? commentaire,
          {int? caisse, File? piece}) =>
      apiClient.declarerRemise(montant, commentaire,
          caisse: caisse, piece: piece);

  Future<void> confirmerRemise(int id, double montantRecu, String? commentaire) =>
      apiClient.confirmerRemise(id, montantRecu, commentaire);

  Future<MaCaisse> mouvementsDeLaCaisse(int id) =>
      apiClient.mouvementsDeLaCaisse(id);

  Future<Cloturage> cloturerCaisse(double montantCompte, String? commentaire) =>
      apiClient.cloturerCaisse(montantCompte, commentaire);

  /// Les caisses successives, chacune avec son journal.
  Future<List<SessionCaisse>> sessionsCaisse({int? caisse}) =>
      apiClient.sessionsCaisse(caisse: caisse);

  Future<List<Cloturage>> cloturages({int? caisse}) =>
      apiClient.cloturages(caisse: caisse);

  Future<void> viderCaisse(int id, String motif) =>
      apiClient.viderCaisse(id, motif);

  Future<void> mouvementCaisse({
    required String sens,
    required double montant,
    required String motif,
    String? commentaire,
  }) =>
      apiClient.mouvementCaisse(
        sens: sens,
        montant: montant,
        motif: motif,
        commentaire: commentaire,
      );

  // ─── Location longue duree ──────────────────────────────────────

  Future<List<Bail>> fetchBaux({
    String statut = 'actif',
    String? recherche,
    int? bien,
    int? client,
    bool impayes = false,
  }) =>
      apiClient.fetchBaux(statut: statut, recherche: recherche, bien: bien, client: client, impayes: impayes);

  Future<TableauBaux> fetchTableauBaux() => apiClient.fetchTableauBaux();

  Future<List<BienLongueDuree>> fetchBiensLongueDuree() => apiClient.fetchBiensLongueDuree();

  Future<Bail> fetchBail(int id) => apiClient.fetchBail(id);

  Future<AvecAvertissement<Bail>> creerBail({
    required int bien,
    required int client,
    required DateTime dateDebut,
    DateTime? dateFin,
    int? dureeMois,
    required double loyer,
    double? charges,
    double? depot,
    bool depotRecu = false,
    String? compteurEauEntree,
    String? compteurElecEntree,
    String? remarques,
    bool relancesActives = true,
    bool envoyerContrat = false,
    List<File> photos = const [],
    List<Colocataire> colocataires = const [],
    List<File> cinPhotos = const [],
  }) =>
      apiClient.creerBail(
        bien: bien,
        client: client,
        dateDebut: dateDebut,
        dateFin: dateFin,
        dureeMois: dureeMois,
        loyer: loyer,
        charges: charges,
        depot: depot,
        depotRecu: depotRecu,
        compteurEauEntree: compteurEauEntree,
        compteurElecEntree: compteurElecEntree,
        remarques: remarques,
        relancesActives: relancesActives,
        envoyerContrat: envoyerContrat,
        photos: photos,
        colocataires: colocataires,
        cinPhotos: cinPhotos,
      );

  Future<Bail> modifierBail(
    int id, {
    String? remarques,
    bool? relancesActives,
    String? compteurEauEntree,
    String? compteurElecEntree,
    double? loyer,
    double? charges,
    bool depotRecu = false,
    List<Colocataire>? colocataires,
    List<File> cinPhotos = const [],
  }) =>
      apiClient.modifierBail(
        id,
        remarques: remarques,
        relancesActives: relancesActives,
        compteurEauEntree: compteurEauEntree,
        compteurElecEntree: compteurElecEntree,
        loyer: loyer,
        charges: charges,
        depotRecu: depotRecu,
        colocataires: colocataires,
        cinPhotos: cinPhotos,
      );

  Future<AvecAvertissement<Bail>> prolongerBail(int id,
          {required int mois, double? loyer, bool envoyerContrat = false}) =>
      apiClient.prolongerBail(id, mois: mois, loyer: loyer, envoyerContrat: envoyerContrat);

  Future<Bail> terminerBail(
    int id, {
    required DateTime dateSortie,
    String? motif,
    double? depotRendu,
    String? compteurEauSortie,
    String? compteurElecSortie,
  }) =>
      apiClient.terminerBail(
        id,
        dateSortie: dateSortie,
        motif: motif,
        depotRendu: depotRendu,
        compteurEauSortie: compteurEauSortie,
        compteurElecSortie: compteurElecSortie,
      );

  Future<void> supprimerBail(int id) => apiClient.supprimerBail(id);

  /// Chemin du PDF telecharge.
  Future<String> telechargerContratBail(int id) => apiClient.telechargerContratBail(id);

  Future<String?> envoyerContratBail(int id) => apiClient.envoyerContratBail(id);

  Future<Loyer> modifierMontantLoyer(int id, double montant) => apiClient.modifierMontantLoyer(id, montant);

  Future<PaiementEnregistre> encaisserLoyer(
    int loyerId, {
    required double montant,
    DateTime? payeLe,
    String mode = 'especes',
    String? reference,
    String? remarque,
    bool envoyerQuittance = true,
  }) =>
      apiClient.encaisserLoyer(
        loyerId,
        montant: montant,
        payeLe: payeLe,
        mode: mode,
        reference: reference,
        remarque: remarque,
        envoyerQuittance: envoyerQuittance,
      );

  Future<Loyer> annulerPaiementLoyer(int paiementId, {String? motif}) =>
      apiClient.annulerPaiementLoyer(paiementId, motif: motif);

  Future<String> telechargerQuittance(int paiementId) => apiClient.telechargerQuittance(paiementId);

  Future<String?> envoyerQuittance(int paiementId) => apiClient.envoyerQuittance(paiementId);

  // ─── Vente de biens ─────────────────────────────────────────────

  Future<TableauVentes> fetchTableauVentes() => apiClient.fetchTableauVentes();

  Future<List<BienVente>> fetchBiensVente({String filtre = 'tous', String? recherche, String? dossier}) =>
      apiClient.fetchBiensVente(filtre: filtre, recherche: recherche, dossier: dossier);

  Future<DossierVente> fetchDossierVente(int bien) => apiClient.fetchDossierVente(bien);

  Future<void> changerStatutVente(int bien, String statut) => apiClient.changerStatutVente(bien, statut);

  Future<MandatVente> creerMandatVente(int bien, Map<String, dynamic> champs) =>
      apiClient.creerMandatVente(bien, champs);

  Future<MandatPrerempli> fetchMandatPrerempli(int bien) => apiClient.fetchMandatPrerempli(bien);

  Future<MandatVente> creerMandatAvecSignature(int bien, Map<String, dynamic> champs, {Uint8List? signature}) =>
      apiClient.creerMandatAvecSignature(bien, champs, signature: signature);

  Future<void> supprimerMandatVente(int id) => apiClient.supprimerMandatVente(id);

  /// Chemin du PDF telecharge.
  Future<String> telechargerMandatVente(int id) => apiClient.telechargerMandatVente(id);

  Future<String?> envoyerMandatVente(int id) => apiClient.envoyerMandatVente(id);

  Future<List<MandatVente>> fetchMandatsVente({bool libres = false, String? recherche}) =>
      apiClient.fetchMandatsVente(libres: libres, recherche: recherche);

  Future<FicheMandat> fetchMandatVente(int id) => apiClient.fetchMandatVente(id);

  Future<MandatVente> creerMandatLibre(Map<String, dynamic> champs) => apiClient.creerMandatLibre(champs);

  Future<MandatVente> modifierMandatVente(int id, Map<String, dynamic> champs) =>
      apiClient.modifierMandatVente(id, champs);

  Future<MandatVente> signerMandatVente(int id, Uint8List png) => apiClient.signerMandatVente(id, png);

  Future<DossierVente> lierMandatVente(int id, int bien) => apiClient.lierMandatVente(id, bien);

  Future<VisiteVente> creerVisiteVente(int bien, Map<String, dynamic> champs) =>
      apiClient.creerVisiteVente(bien, champs);

  Future<void> modifierVisiteVente(int id, {String? suite, String? remarques}) =>
      apiClient.modifierVisiteVente(id, suite: suite, remarques: remarques);

  Future<VisiteVente> signerVisiteVente(int id, Uint8List png) => apiClient.signerVisiteVente(id, png);

  Future<void> supprimerVisiteVente(int id) => apiClient.supprimerVisiteVente(id);

  Future<String> telechargerRecuVisite(int id) => apiClient.telechargerRecuVisite(id);

  Future<String?> envoyerRecuVisite(int id) => apiClient.envoyerRecuVisite(id);

  // ─── Caisse Airbnb (administrateur) ─────────────────────────────

  Future<CaisseAirbnb> caisseAirbnb({String? depuis}) =>
      apiClient.caisseAirbnb(depuis: depuis);

  Future<CaisseAirbnb> transfererCaisseAirbnb({
    required int caisse,
    required double montant,
    String? commentaire,
  }) =>
      apiClient.transfererCaisseAirbnb(
          caisse: caisse, montant: montant, commentaire: commentaire);

  Future<ReceptionWhatsapp> lireReceptionWhatsapp({int? managerId}) =>
      apiClient.lireReceptionWhatsapp(managerId: managerId);

  Future<ReceptionWhatsapp> enregistrerReceptionWhatsapp({
    int? managerId,
    bool? actif,
    List<String>? typesCoupes,
  }) =>
      apiClient.enregistrerReceptionWhatsapp(
        managerId: managerId,
        actif: actif,
        typesCoupes: typesCoupes,
      );

  Future<List<ReceptionWhatsapp>> receptionWhatsappUtilisateurs() =>
      apiClient.receptionWhatsappUtilisateurs();

  Future<BienDesactive> desactiverBien(int id, {String? motif}) =>
      apiClient.desactiverBien(id, motif: motif);

  Future<BienDesactive> reactiverBien(int id) => apiClient.reactiverBien(id);

  Future<List<BienDesactive>> biensDesactives() => apiClient.biensDesactives();

  // ================= Droits et permissions (administrateur) =================

  Future<DroitsEtPermissions> fetchDroitsPermissions() =>
      apiClient.fetchDroitsPermissions();

  Future<RolePermissions> majPermissionsRole(
          String nom, List<String> permissions) =>
      apiClient.majPermissionsRole(nom, permissions);

  Future<DetailUtilisateurPermissions> fetchPermissionsUtilisateur(int id) =>
      apiClient.fetchPermissionsUtilisateur(id);

  Future<DetailUtilisateurPermissions> majPermissionsUtilisateur(
          int id, List<String> accordes, List<String> retires) =>
      apiClient.majPermissionsUtilisateur(id, accordes, retires);
}
