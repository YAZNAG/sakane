<?php

use App\Http\Controllers\app\CategoryController;
use App\Http\Controllers\app\CityController;
use App\Http\Controllers\app\EtatController;
use App\Http\Controllers\app\FeaturesController;
use App\Http\Controllers\app\PublicRealEstateController;
use App\Http\Controllers\app\RegionController;
use App\Http\Controllers\app\TransactionTypeController;
use App\Http\Controllers\dashboard\AnounceController;
use App\Http\Controllers\dashboard\ApercuContratController;
use App\Http\Controllers\dashboard\AuthController;
use App\Http\Controllers\dashboard\BookingController;
use App\Http\Controllers\dashboard\CampagneController;
use App\Http\Controllers\dashboard\ChargeController;
use App\Http\Controllers\dashboard\ClientController;
use App\Http\Controllers\dashboard\ContractsController;
use App\Http\Controllers\dashboard\FinancialStatsController;
use App\Http\Controllers\dashboard\DossierController;
use App\Http\Controllers\dashboard\ManagerController;
use App\Http\Controllers\dashboard\ModeleMessageController;
use App\Http\Controllers\dashboard\OwnerController;
use App\Http\Controllers\dashboard\ProgramedChargesController;
use App\Http\Controllers\dashboard\RapportController;
use App\Http\Controllers\dashboard\RappelController;
use App\Http\Controllers\dashboard\RealestateController;
use App\Http\Controllers\dashboard\ReclamationController;
use App\Http\Controllers\dashboard\SecteurController;
use App\Http\Controllers\dashboard\SlidesController;
use App\Http\Controllers\dashboard\StatistiquesController;
use App\Http\Controllers\dashboard\TransfersController;
use Illuminate\Support\Facades\Route;


Route::get("/dashboard-test", function () {
    return "dashboard-test";
});

Route::prefix("transactions")->group(function () {
    Route::post("/", [TransfersController::class, "addTransfert"]);
})->middleware("auth:sanctum");

Route::post("login", [AuthController::class, "login"]);


Route::prefix("realestates")->group(function () {
    Route::get("/categories", [CategoryController::class, "index"]);
    Route::get("/transaction-types", [TransactionTypeController::class, "index"]);
    Route::get("/etats", [EtatController::class, "index"]);
});
Route::get("/regions", [RegionController::class, "index"]);
Route::get("/cities", [CityController::class, "index"]);
Route::get("/secteurs", [SecteurController::class, "index"]);

// Dossiers de rangement des biens
// Dossiers accessibles a un agent, regles depuis son profil
Route::match(["get", "put"], "/managers/{id}/dossiers",
    [DossierController::class, "dossiersDeLAgent"])->middleware("auth:managers");

Route::prefix("dossiers")->middleware("auth:managers")->group(function () {
    Route::get("/", [DossierController::class, "index"]);
    Route::post("/", [DossierController::class, "store"]);
    Route::post("/affecter", [DossierController::class, "affecter"]);
    Route::post("/{id}/agents", [DossierController::class, "affecterAgents"]);
    Route::put("/{id}", [DossierController::class, "update"]);
    Route::delete("/{id}", [DossierController::class, "destroy"]);
});

// Apercu du bulletin avant signature du client
Route::post("/bookings/apercu-contrat", [ApercuContratController::class, "apercu"])
    ->middleware("auth:managers");

// Rappels de reservation et message post-sejour : reserve aux administrateurs
Route::prefix("rappels")->middleware("auth:managers")->group(function () {
    Route::get("/", [RappelController::class, "index"]);
    Route::put("/{id}", [RappelController::class, "update"]);
    Route::get("/{id}/suivi", [RappelController::class, "suivi"]);
    Route::patch("/{id}/relancer-echecs", [RappelController::class, "relancerEchecs"]);
});

// Modeles de messages : reserve aux administrateurs
Route::prefix("modeles-messages")->middleware("auth:managers")->group(function () {
    Route::get("/", [ModeleMessageController::class, "index"]);
    Route::get("/variables", [ModeleMessageController::class, "variables"]);
    Route::post("/apercu", [ModeleMessageController::class, "apercu"]);
    Route::get("/{id}", [ModeleMessageController::class, "show"]);
    Route::put("/{id}", [ModeleMessageController::class, "update"]);
    Route::patch("/{id}/restaurer", [ModeleMessageController::class, "restaurer"]);
    Route::post("/{id}/image", [ModeleMessageController::class, "deposerImage"]);
    Route::delete("/{id}/image", [ModeleMessageController::class, "retirerImage"]);
});

// Campagnes / diffusion clients
Route::prefix("campagnes")->middleware("auth:managers")->group(function () {
    Route::get("/", [CampagneController::class, "index"]);
    Route::get("/segments", [CampagneController::class, "segments"]);
    Route::post("/estimer", [CampagneController::class, "estimer"]);
    Route::post("/test", [CampagneController::class, "test"]);
    Route::post("/", [CampagneController::class, "store"]);
    Route::get("/{id}", [CampagneController::class, "show"]);
    Route::patch("/{id}/envoyer", [CampagneController::class, "envoyer"]);
    Route::patch("/{id}/annuler", [CampagneController::class, "annuler"]);
    Route::patch("/{id}/pause", [CampagneController::class, "pause"]);
    Route::patch("/{id}/reprendre", [CampagneController::class, "reprendre"]);
    Route::patch("/{id}/relancer-echecs", [CampagneController::class, "relancerEchecs"]);
    Route::delete("/{id}", [CampagneController::class, "destroy"]);
});
Route::patch("/clients/{id}/promotions", [CampagneController::class, "promotionsClient"])
    ->middleware("auth:managers");
Route::post("/secteurs", [SecteurController::class, "store"])->middleware("auth:managers");
Route::get("/features", [FeaturesController::class, "index"]);



Route::group(["middleware" => ["auth:managers"]], function () {
    Route::get("/me", [AuthController::class, "me"]);
    Route::resource("realestates", RealestateController::class);
    Route::post("realestates/{id}", [RealestateController::class, 'update']);
    Route::resource("owners", OwnerController::class);
    Route::get("realestates/{id}", [RealestateController::class, "index"]);
    Route::get("/bookings", [BookingController::class, 'index']);
    Route::post("/bookings", [BookingController::class, 'store']);
    //Route::post("/clients", [ClientController::class, 'store']);
    // Avant la ressource : sinon « doublons » serait pris pour un identifiant.
    Route::get("/clients/doublons", [ClientController::class, "doublons"]);
    Route::resource('clients', ClientController::class);
    Route::resource("contracts", ContractsController::class);
    // L'historique des charges annulees, avant la route generique.
    Route::get("charges/annulees", [ChargeController::class, "annulees"]);
    Route::resource("charges", ChargeController::class);
    Route::get("/stats", [StatistiquesController::class, "stats"]);
    Route::get("/global-stats", [StatistiquesController::class, "globalStats"]);
    Route::get("/statistiques/export", [\App\Http\Controllers\dashboard\StatistiquesExportController::class, "export"]);
    Route::get("/sliders", [SlidesController::class, "index"]);
    Route::post("/sliders", [SlidesController::class, "store"]);
    Route::patch("/sliders/{id}/activate", [SlidesController::class, "activate"]);
    Route::resource("managers", ManagerController::class);
    Route::get("/anounces", [AnounceController::class, "index"]);
    Route::patch("/anounces/{id}/accept", [AnounceController::class, "acceptAnounce"]);
    Route::patch("/anounces/{id}/refuse", [AnounceController::class, "refuseAnounce"]);
    Route::resource("rapports", RapportController::class);

    Route::patch("/realestates/{id}/confirm-depart", [RealestateController::class, "confirmDepart"]);
    Route::patch("/realestates/{id}/confirm-checkin", [RealestateController::class, "confirmCheckin"]);
    Route::patch("/realestates/{id}/start-cleaning", [RealestateController::class, "startCleaning"]);
    Route::patch("/realestates/{id}/finish-cleaning", [RealestateController::class, "finishCleaning"]);
    Route::patch("/realestates/{id}/return-to-cleaning", [RealestateController::class, "returnToCleaning"]);
    Route::get("/realestates-overview", [RealestateController::class, "realestatesOverview"]);

    Route::get("/roles", [ManagerController::class, 'roles']);

    Route::post("/bookings/{id}/extend", [BookingController::class, "extendBooking"]);
    Route::post("/bookings/{id}/shrink", [BookingController::class, "shrink"]);
    // La facture d'une reservation : la lire, puis l'envoyer.
    Route::get("/bookings/{id}/facture", [\App\Http\Controllers\dashboard\FactureController::class, "voir"]);
    Route::post("/bookings/{id}/facture/envoyer", [\App\Http\Controllers\dashboard\FactureController::class, "envoyer"]);
    // La corbeille : ce qui a ete supprime dans la semaine, et de quoi
    // l'en sortir.
    Route::get("/bookings/corbeille", [BookingController::class, "corbeille"]);
    // Les arrivees du jour et les prochaines, par date d'arrivee.
    Route::get("/bookings/arrivees", [BookingController::class, "arrivees"]);
    Route::post("/bookings/{id}/restaurer", [BookingController::class, "restaurer"]);
    Route::delete("/bookings/{id}", [BookingController::class, "destroy"]);

    Route::put("/managers/{id}", [ManagerController::class, "update"]);
    Route::delete("/managers/{id}", [ManagerController::class, "destroy"]);
    Route::get("/managers/{id}", [ManagerController::class, "show"]);

    Route::delete("/realestates/{id}", [RealestateController::class, "delete"]);
    Route::delete("/owners/{id}",      [OwnerController::class,      "delete"]);
    Route::delete("/charges/{id}",     [ChargeController::class,     "delete"]);

    Route::resource("programed-charges", ProgramedChargesController::class);
    Route::delete("/programed-charges/{id}", [ProgramedChargesController::class, "delete"]);

    Route::post("charges/{id}/validate", [ChargeController::class, "validate"]);
    Route::post("charges/{id}/cancel", [ChargeController::class, "cancel"]);

    Route::get("/reclamations", [ReclamationController::class, "index"]);
    Route::post("/reclamations", [ReclamationController::class, "store"]);
    Route::patch("/reclamations/{id}/resolve", [ReclamationController::class, "resolve"]);

    Route::get("/financial-stats", [FinancialStatsController::class, "index"]);
    Route::get("/financial-stats/export", [FinancialStatsController::class, "export"]);
    Route::get("/financial-stats/rapport", [FinancialStatsController::class, "rapport"]);

    // Export des reservations, par bien ou par client, en xlsx ou pdf.
    Route::get("/reservations/export", [\App\Http\Controllers\dashboard\ExportReservationsController::class, "export"]);
    Route::get("/types-invites", [\App\Http\Controllers\dashboard\ExportReservationsController::class, "typesInvites"]);

    // Caisses : celle de chaque agent, celle de l'agence.
    Route::get("/caisses/ma-caisse", [\App\Http\Controllers\dashboard\CaisseController::class, "maCaisse"]);
    Route::post("/caisses/ouvrir", [\App\Http\Controllers\dashboard\CaisseController::class, "ouvrir"]);
    Route::post("/caisses/mouvements", [\App\Http\Controllers\dashboard\CaisseController::class, "ajouterMouvement"]);
    Route::post("/caisses/remises", [\App\Http\Controllers\dashboard\CaisseController::class, "declarerRemise"]);
    // Les caisses vers lesquelles on peut transferer.
    Route::get("/caisses/destinataires", [\App\Http\Controllers\dashboard\CaisseController::class, "destinataires"]);
    Route::post("/caisses/cloturer", [\App\Http\Controllers\dashboard\CaisseController::class, "cloturer"]);
    Route::get("/caisses/cloturages", [\App\Http\Controllers\dashboard\CaisseController::class, "cloturages"]);
    Route::get("/caisses/sessions", [\App\Http\Controllers\dashboard\CaisseController::class, "sessions"]);
    Route::get("/caisses", [\App\Http\Controllers\dashboard\CaisseController::class, "index"]);
    Route::get("/caisses/{id}/mouvements", [\App\Http\Controllers\dashboard\CaisseController::class, "mouvementsDe"]);
    Route::post("/caisses/{id}/vider", [\App\Http\Controllers\dashboard\CaisseController::class, "vider"]);
    Route::post("/caisses/remises/{id}/confirmer", [\App\Http\Controllers\dashboard\CaisseController::class, "confirmerRemise"]);
});

// Export Excel / PDF du tableau affiche par une page de l'application.
Route::post("/export", [\App\Http\Controllers\dashboard\ExportController::class, "generer"])->middleware("auth:managers");

// Organisation de l'accueil propre a chaque utilisateur : ordre, dossiers, barre du bas.
Route::get("/accueil/disposition", [\App\Http\Controllers\dashboard\AccueilController::class, "lire"])->middleware("auth:managers");
Route::put("/accueil/disposition", [\App\Http\Controllers\dashboard\AccueilController::class, "enregistrer"])->middleware("auth:managers");

// Dates bloquees d'un bien : le bien ne peut pas etre reserve pendant la periode.
Route::get("/realestates/{id}/blocages", [\App\Http\Controllers\dashboard\BlocageController::class, "index"])->middleware("auth:managers");
Route::post("/realestates/{id}/blocages", [\App\Http\Controllers\dashboard\BlocageController::class, "store"])->middleware("auth:managers");
Route::delete("/blocages/{id}", [\App\Http\Controllers\dashboard\BlocageController::class, "destroy"])->middleware("auth:managers");

// Partage du contrat de location avec le syndic : reglages et envoi.
Route::get("/reglages/syndic", [\App\Http\Controllers\dashboard\PartageSyndicController::class, "reglages"])->middleware("auth:managers");
Route::put("/reglages/syndic", [\App\Http\Controllers\dashboard\PartageSyndicController::class, "enregistrer"])->middleware("auth:managers");
Route::post("/bookings/{id}/partager-syndic", [\App\Http\Controllers\dashboard\PartageSyndicController::class, "partager"])->middleware("auth:managers");

// Syndics : un compte par immeuble, qui recoit le contrat public de chaque reservation.
Route::get("/syndics/biens", [\App\Http\Controllers\dashboard\SyndicController::class, "biens"])->middleware("auth:managers");
Route::get("/syndics", [\App\Http\Controllers\dashboard\SyndicController::class, "index"])->middleware("auth:managers");
Route::post("/syndics", [\App\Http\Controllers\dashboard\SyndicController::class, "store"])->middleware("auth:managers");
Route::get("/syndics/{id}", [\App\Http\Controllers\dashboard\SyndicController::class, "show"])->middleware("auth:managers");
Route::put("/syndics/{id}", [\App\Http\Controllers\dashboard\SyndicController::class, "update"])->middleware("auth:managers");
Route::delete("/syndics/{id}", [\App\Http\Controllers\dashboard\SyndicController::class, "destroy"])->middleware("auth:managers");

// Contrats signes avec les proprietaires, joints par appartement.
Route::post("/owners/{id}/contrats", [\App\Http\Controllers\dashboard\ContratProprietaireController::class, "store"])->middleware("auth:managers");
Route::delete("/contrats-proprietaires/{id}", [\App\Http\Controllers\dashboard\ContratProprietaireController::class, "destroy"])->middleware("auth:managers");

// Liste noire des clients : plus de nouvelle reservation.
Route::post("/clients/{id}/liste-noire", [\App\Http\Controllers\dashboard\ClientController::class, "ajouterListeNoire"])->middleware("auth:managers");
Route::delete("/clients/{id}/liste-noire", [\App\Http\Controllers\dashboard\ClientController::class, "retirerListeNoire"])->middleware("auth:managers");

// Ce qu'implique la suppression d'une reservation, avant de la confirmer.
Route::get("/bookings/{id}/apercu-suppression", [\App\Http\Controllers\dashboard\BookingController::class, "apercuSuppression"])->middleware("auth:managers");

// Calendrier de gestion d'un bien : prix par nuit, blocages et reservations.
Route::get("/realestates/{id}/calendrier", [\App\Http\Controllers\dashboard\CalendrierController::class, "index"])->middleware("auth:managers");
Route::post("/realestates/{id}/prix", [\App\Http\Controllers\dashboard\CalendrierController::class, "definirPrix"])->middleware("auth:managers");
Route::delete("/realestates/{id}/prix", [\App\Http\Controllers\dashboard\CalendrierController::class, "effacerPrix"])->middleware("auth:managers");
Route::get("/realestates/{id}/tarif", [\App\Http\Controllers\dashboard\CalendrierController::class, "tarif"])->middleware("auth:managers");
Route::post("/realestates/{id}/debloquer", [\App\Http\Controllers\dashboard\CalendrierController::class, "debloquer"])->middleware("auth:managers");

Route::post("/bookings/{id}/modifier", [\App\Http\Controllers\dashboard\ModifierReservationController::class, "modifier"])->middleware("auth:managers");


// Location longue duree : baux, loyers, paiements et quittances.
Route::prefix("baux")->middleware("auth:managers")->group(function () {
    Route::get("/", [\App\Http\Controllers\dashboard\BailController::class, "index"]);
    Route::get("/tableau", [\App\Http\Controllers\dashboard\BailController::class, "tableau"]);
    Route::get("/biens", [\App\Http\Controllers\dashboard\BailController::class, "biens"]);
    Route::post("/", [\App\Http\Controllers\dashboard\BailController::class, "store"]);
    Route::get("/{id}", [\App\Http\Controllers\dashboard\BailController::class, "show"])->whereNumber("id");
    Route::put("/{id}", [\App\Http\Controllers\dashboard\BailController::class, "update"])->whereNumber("id");
    Route::delete("/{id}", [\App\Http\Controllers\dashboard\BailController::class, "destroy"])->whereNumber("id");
    Route::post("/{id}/prolonger", [\App\Http\Controllers\dashboard\BailController::class, "prolonger"])->whereNumber("id");
    Route::post("/{id}/terminer", [\App\Http\Controllers\dashboard\BailController::class, "terminer"])->whereNumber("id");
    Route::get("/{id}/contrat", [\App\Http\Controllers\dashboard\BailController::class, "contrat"])->whereNumber("id");
    Route::post("/{id}/envoyer-contrat", [\App\Http\Controllers\dashboard\BailController::class, "envoyerContrat"])->whereNumber("id");
});
Route::put("/loyers/{id}", [\App\Http\Controllers\dashboard\BailController::class, "modifierLoyer"])->middleware("auth:managers");
Route::post("/loyers/{id}/paiements", [\App\Http\Controllers\dashboard\BailController::class, "payer"])->middleware("auth:managers");
Route::delete("/loyer-paiements/{id}", [\App\Http\Controllers\dashboard\BailController::class, "annulerPaiement"])->middleware("auth:managers");
Route::get("/loyer-paiements/{id}/quittance", [\App\Http\Controllers\dashboard\BailController::class, "quittance"])->middleware("auth:managers");
Route::post("/loyer-paiements/{id}/envoyer-quittance", [\App\Http\Controllers\dashboard\BailController::class, "envoyerQuittance"])->middleware("auth:managers");


// Reception des messages WhatsApp : la sienne, ou celle d'un utilisateur (administrateur).
Route::middleware("auth:managers")->group(function () {
    Route::get("/reception-whatsapp", [\App\Http\Controllers\dashboard\ReceptionWhatsappController::class, "afficher"]);
    Route::put("/reception-whatsapp", [\App\Http\Controllers\dashboard\ReceptionWhatsappController::class, "modifier"]);
    Route::get("/reception-whatsapp/utilisateurs", [\App\Http\Controllers\dashboard\ReceptionWhatsappController::class, "liste"]);
    Route::get("/reception-whatsapp/{id}", [\App\Http\Controllers\dashboard\ReceptionWhatsappController::class, "afficher"])->whereNumber("id");
    Route::put("/reception-whatsapp/{id}", [\App\Http\Controllers\dashboard\ReceptionWhatsappController::class, "modifier"])->whereNumber("id");
});


// Airbnb : liaison du calendrier de chaque bien (iCal), dans les deux sens.
Route::get("/calendrier-airbnb/{jeton}.ics", [\App\Http\Controllers\dashboard\AirbnbController::class, "export"])->where("jeton", "[A-Za-z0-9]{20,64}");
Route::middleware("auth:managers")->group(function () {
    Route::get("/airbnb/biens", [\App\Http\Controllers\dashboard\AirbnbController::class, "liste"]);
    Route::get("/airbnb/sejours", [\App\Http\Controllers\dashboard\AirbnbController::class, "sejours"]);
    Route::get("/realestates/{id}/airbnb", [\App\Http\Controllers\dashboard\AirbnbController::class, "afficher"])->whereNumber("id");
    Route::put("/realestates/{id}/airbnb", [\App\Http\Controllers\dashboard\AirbnbController::class, "modifier"])->whereNumber("id");
    Route::post("/realestates/{id}/airbnb/synchroniser", [\App\Http\Controllers\dashboard\AirbnbController::class, "synchroniser"])->whereNumber("id");
    Route::post("/realestates/{id}/airbnb/nouveau-lien", [\App\Http\Controllers\dashboard\AirbnbController::class, "nouveauLien"])->whereNumber("id");
});


// Historique des contrats envoyes aux syndics.
Route::middleware("auth:managers")->group(function () {
    Route::get("/syndics/envois", [\App\Http\Controllers\dashboard\HistoriqueSyndicController::class, "index"]);
    Route::get("/syndics/envois/export", [\App\Http\Controllers\dashboard\HistoriqueSyndicController::class, "export"]);
    Route::get("/syndics/envois/{id}", [\App\Http\Controllers\dashboard\HistoriqueSyndicController::class, "show"])->whereNumber("id");
    Route::post("/syndics/envois/{id}/renvoyer", [\App\Http\Controllers\dashboard\HistoriqueSyndicController::class, "renvoyer"])->whereNumber("id");
});


// Vente : biens a vendre, mandats du proprietaire et visites des acheteurs.
Route::prefix("ventes")->middleware("auth:managers")->group(function () {
    $c = \App\Http\Controllers\dashboard\VenteController::class;
    Route::get("/tableau", [$c, "tableau"]);
    Route::get("/biens", [$c, "biens"]);
    Route::get("/biens/{id}", [$c, "dossier"])->whereNumber("id");
    Route::put("/biens/{id}/statut", [$c, "statut"])->whereNumber("id");
    Route::post("/biens/{id}/mandats", [$c, "ajouterMandat"])->whereNumber("id");
    Route::get("/biens/{id}/mandat-prerempli", [$c, "preremplirMandat"])->whereNumber("id");
    Route::post("/biens/{id}/visites", [$c, "ajouterVisite"])->whereNumber("id");
    Route::get("/mandats", [$c, "mandats"]);
    Route::post("/mandats", [$c, "creerMandat"]);
    Route::get("/mandats/{id}", [$c, "mandat"])->whereNumber("id");
    Route::put("/mandats/{id}", [$c, "modifierMandat"])->whereNumber("id");
    Route::post("/mandats/{id}/signature", [$c, "signerMandat"])->whereNumber("id");
    Route::put("/mandats/{id}/bien", [$c, "lierMandat"])->whereNumber("id");
    Route::delete("/mandats/{id}", [$c, "supprimerMandat"])->whereNumber("id");
    Route::get("/mandats/{id}/pdf", [$c, "pdfMandat"])->whereNumber("id");
    Route::post("/mandats/{id}/envoyer", [$c, "envoyerMandat"])->whereNumber("id");
    Route::put("/visites/{id}", [$c, "modifierVisite"])->whereNumber("id");
    Route::post("/visites/{id}/signature", [$c, "signerVisite"])->whereNumber("id");
    Route::delete("/visites/{id}", [$c, "supprimerVisite"])->whereNumber("id");
    Route::get("/visites/{id}/pdf", [$c, "pdfVisite"])->whereNumber("id");
    Route::post("/visites/{id}/envoyer", [$c, "envoyerVisite"])->whereNumber("id");
});


// Reservation : detail, modification du prix, facture payee ou non, heures par defaut.
Route::middleware("auth:managers")->group(function () {
    Route::get("/bookings/{id}/detail", [\App\Http\Controllers\dashboard\DetailReservationController::class, "detail"])->whereNumber("id");
    Route::post("/bookings/{id}/modifier-prix", [\App\Http\Controllers\dashboard\DetailReservationController::class, "modifierPrix"])->whereNumber("id");
    Route::get("/bookings/{id}/facture/resume", [\App\Http\Controllers\dashboard\DetailReservationController::class, "facture"])->whereNumber("id");
    Route::post("/bookings/{id}/facture/appliquer", [\App\Http\Controllers\dashboard\DetailReservationController::class, "appliquerFacture"])->whereNumber("id");
    Route::match(["get", "put"], "/reglages/heures", [\App\Http\Controllers\dashboard\DetailReservationController::class, "heures"]);
});


// Numero WhatsApp reserve aux campagnes.
Route::middleware("auth:managers")->group(function () {
    Route::get("/campagnes-whatsapp", [\App\Http\Controllers\dashboard\WhatsappCampagnesController::class, "afficher"]);
    Route::put("/campagnes-whatsapp", [\App\Http\Controllers\dashboard\WhatsappCampagnesController::class, "modifier"]);
    Route::delete("/campagnes-whatsapp", [\App\Http\Controllers\dashboard\WhatsappCampagnesController::class, "supprimer"]);
});


// Modules de l'accueil de chaque utilisateur : masques, ajoutes, renommes.
Route::middleware("auth:managers")->group(function () {
    Route::get("/accueil/modules", [\App\Http\Controllers\dashboard\ModulesAccueilController::class, "afficher"]);
    Route::put("/accueil/modules", [\App\Http\Controllers\dashboard\ModulesAccueilController::class, "modifier"]);
    Route::delete("/accueil/modules", [\App\Http\Controllers\dashboard\ModulesAccueilController::class, "reinitialiser"]);
});


// Desactiver / reactiver un bien.
Route::middleware("auth:managers")->group(function () {
    Route::get("/biens-desactives", [\App\Http\Controllers\dashboard\ActivationBienController::class, "liste"]);
    Route::post("/realestates/{id}/desactiver", [\App\Http\Controllers\dashboard\ActivationBienController::class, "desactiver"])->whereNumber("id");
    Route::post("/realestates/{id}/reactiver", [\App\Http\Controllers\dashboard\ActivationBienController::class, "reactiver"])->whereNumber("id");
});


// Caisse Airbnb (administrateur).
Route::middleware("auth:managers")->group(function () {
    Route::get("/caisse-airbnb", [\App\Http\Controllers\dashboard\CaisseAirbnbController::class, "afficher"]);
    Route::post("/caisse-airbnb/transferer", [\App\Http\Controllers\dashboard\CaisseAirbnbController::class, "transferer"]);
});


// Droits de chaque role, module par module (administrateur).
Route::middleware("auth:managers")->group(function () {
    Route::get("/permissions", [\App\Http\Controllers\dashboard\PermissionsController::class, "afficher"]);
    Route::put("/permissions/roles/{role}", [\App\Http\Controllers\dashboard\PermissionsController::class, "modifier"]);
    Route::get("/permissions/utilisateurs/{id}", [\App\Http\Controllers\dashboard\PermissionsController::class, "utilisateur"])->whereNumber("id");
    Route::put("/permissions/utilisateurs/{id}", [\App\Http\Controllers\dashboard\PermissionsController::class, "modifierUtilisateur"])->whereNumber("id");
});

// Service de version des applications mobiles (remplace jway-apps.msjsa.com)
// Route publique : appelee au demarrage de l'app, avant toute authentification.
Route::get("/app-version/{package}", [\App\Http\Controllers\dashboard\AppVersionController::class, "show"]);

// Mot de passe oublie (managers) - OTP envoye par WhatsApp.
// Routes publiques : appelees avant authentification.
Route::post("/forget-password", [\App\Http\Controllers\dashboard\PasswordResetController::class, "forgetPassword"]);
Route::post("/check-otp",       [\App\Http\Controllers\dashboard\PasswordResetController::class, "checkOtp"]);
Route::post("/reset-password",  [\App\Http\Controllers\dashboard\PasswordResetController::class, "resetPassword"]);

// Memoire de l'agence : ecriture arabe deja enregistree pour un nom.
Route::get("/noms-arabes", [\App\Http\Controllers\dashboard\NomsArabesController::class, "show"])->middleware("auth:managers");
