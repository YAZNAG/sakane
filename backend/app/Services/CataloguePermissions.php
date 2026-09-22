<?php

namespace App\Services;

use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Spatie\Permission\Models\Permission;
use Spatie\Permission\Models\Role;
use Spatie\Permission\PermissionRegistrar;

/**
 * Le catalogue des droits : module > sous-module > droit.
 *
 * Chaque droit porte son libelle, son type (voir, ajouter, modifier,
 * supprimer, action) et les roles qui le recoivent a sa creation, pour
 * que rien ne change pour les equipes le jour ou il apparait. Un droit
 * absent du catalogue n est jamais cache : il apparait dans « Autres ».
 *
 * Fichier genere depuis le catalogue source : le modifier la-bas.
 */
class CataloguePermissions
{
    public const GUARD = "managers";

    /** module => [libelle, icone, reserve a (null|alwed), [sous-module => [libelle, reserve a, [droit => [libelle, type, defaut]]]]] */
    public const ARBRE = [
        "immobilier" => ["Immobilier", "building", null, [
            "biens" => ["Biens", null, [
                "view_properties" => ["Voir la liste des biens", "voir", "tous"],
                "create_property" => ["Ajouter un bien", "ajouter", null],
                "update_property" => ["Modifier un bien", "modifier", null],
                "delete_property" => ["Supprimer un bien", "supprimer", null],
                "share_property" => ["Partager la fiche d'un bien", "action", "tous"],
            ]],
            "etats" => ["États des biens", null, [
                "view_available_properties" => ["Voir les biens disponibles", "voir", null],
                "view_reserved_properties" => ["Voir les biens réservés", "voir", null],
                "view_cleaning_properties" => ["Voir les biens à nettoyer", "voir", null],
                "view_today_checkouts" => ["Voir les départs du jour", "voir", null],
            ]],
            "arrivees" => ["Arrivées, départs et nettoyage", null, [
                "confirm_checkin" => ["Confirmer une arrivée", "action", null],
                "confirm_checkout" => ["Confirmer un départ", "action", null],
                "start_cleaning" => ["Commencer un nettoyage", "action", "comme:finish_cleaning"],
                "finish_cleaning" => ["Terminer un nettoyage", "action", null],
                "return_to_cleaning" => ["Remettre un bien en nettoyage", "action", "comme:finish_cleaning|confirm_checkout"],
            ]],
            "desactivation" => ["Biens désactivés", null, [
                "view_deactivated_properties" => ["Voir les biens désactivés", "voir", "comme:update_property"],
                "deactivate_property" => ["Désactiver un bien", "action", "comme:update_property"],
                "reactivate_property" => ["Réactiver un bien", "action", "comme:update_property"],
            ]],
            "dossiers" => ["Dossiers de biens", "alwed", [
                "create_folder" => ["Créer un dossier", "ajouter", "admin"],
                "update_folder" => ["Renommer un dossier / y ranger des biens", "modifier", "admin"],
                "delete_folder" => ["Supprimer un dossier", "supprimer", "admin"],
                "assign_folder_agents" => ["Choisir les agents d'un dossier", "action", "admin"],
            ]],
            "documents" => ["Contrats et rapports du bien", null, [
                "view_contract" => ["Voir les contrats", "voir", null],
                "create_contract" => ["Créer un contrat", "ajouter", null],
                "view_reports" => ["Voir les rapports", "voir", null],
                "create_report" => ["Créer un rapport", "ajouter", null],
            ]],
        ]],
        "reservations" => ["Réservations", "calendar-check", null, [
            "liste" => ["Liste et détail", null, [
                "view_reservations" => ["Voir les réservations", "voir", null],
                "export_reservations" => ["Exporter les réservations", "action", "admin"],
            ]],
            "creation" => ["Nouvelle réservation", null, [
                "create_reservation" => ["Créer une réservation", "ajouter", null],
            ]],
            "modification" => ["Modification", null, [
                "extend_reservation" => ["Prolonger une réservation", "modifier", null],
                "reduce_reservation" => ["Raccourcir une réservation", "modifier", null],
                "update_reservation_price" => ["Modifier le prix d'une réservation", "modifier", "comme:create_reservation"],
            ]],
            "suppression" => ["Suppression et corbeille", null, [
                "delete_reservation" => ["Supprimer une réservation", "supprimer", null],
                "view_reservation_trash" => ["Voir la corbeille", "voir", "comme:delete_reservation"],
                "restore_reservation" => ["Restaurer une réservation", "action", "comme:delete_reservation"],
            ]],
            "factures" => ["Factures", null, [
                "view_invoice" => ["Voir une facture", "voir", "comme:view_reservations"],
                "apply_invoice" => ["Appliquer une facture", "ajouter", "comme:create_reservation"],
                "send_invoice" => ["Envoyer une facture par WhatsApp", "action", "comme:create_reservation"],
            ]],
            "contrats" => ["Contrats de réservation", null, [
                "share_contract_syndic" => ["Envoyer le contrat au syndic", "action", "comme:view_reservations"],
            ]],
            "reglages" => ["Réglages", null, [
                "set_default_hours" => ["Modifier les heures par défaut", "modifier", "admin"],
            ]],
        ]],
        "calendrier" => ["Calendrier", "calendar", null, [
            "calendrier" => ["Calendrier des biens", null, [
                "view_calendar" => ["Voir le calendrier", "voir", "tous"],
                "update_night_prices" => ["Modifier le prix des nuits", "modifier", "comme:update_property"],
                "block_dates" => ["Bloquer des dates", "action", "comme:update_property"],
                "unblock_dates" => ["Débloquer des dates", "action", "comme:update_property"],
            ]],
        ]],
        "airbnb" => ["Airbnb", "airbnb", null, [
            "airbnb" => ["Biens et réservations Airbnb", null, [
                "view_airbnb" => ["Voir le module Airbnb", "voir", "tous"],
                "link_airbnb" => ["Relier / délier un bien à Airbnb", "modifier", "comme:update_property"],
                "sync_airbnb" => ["Synchroniser avec Airbnb", "action", "comme:update_property"],
            ]],
        ]],
        "clients" => ["Clients", "users", null, [
            "clients" => ["Clients", null, [
                "view_clients" => ["Voir les clients", "voir", null],
                "create_client" => ["Ajouter un client", "ajouter", null],
                "update_client" => ["Modifier un client", "modifier", null],
                "delete_client" => ["Supprimer un client", "supprimer", null],
                "blacklist_client" => ["Mettre / retirer de la liste noire", "action", "comme:update_client"],
            ]],
        ]],
        "proprietaires" => ["Propriétaires", "user-tie", null, [
            "proprietaires" => ["Propriétaires", null, [
                "view_owners" => ["Voir les propriétaires", "voir", null],
                "create_owner" => ["Ajouter un propriétaire", "ajouter", null],
                "update_owner" => ["Modifier un propriétaire", "modifier", null],
                "delete_owner" => ["Supprimer un propriétaire", "supprimer", null],
                "manage_owner_contracts" => ["Joindre / supprimer un contrat propriétaire", "action", "comme:update_owner"],
            ]],
        ]],
        "charges" => ["Charges", "receipt", null, [
            "charges" => ["Charges", null, [
                "view_charges" => ["Voir les charges", "voir", null],
                "create_charge" => ["Ajouter une charge", "ajouter", null],
                "validate_charge" => ["Valider une charge", "modifier", "comme:create_charge"],
                "cancel_charge" => ["Annuler une charge", "action", "comme:create_charge"],
                "delete_charge" => ["Supprimer une charge", "supprimer", null],
                "view_cancelled_charges" => ["Voir les charges annulées", "voir", "comme:view_charges"],
            ]],
            "programmees" => ["Charges programmées", null, [
                "view_programed_charges" => ["Voir les charges programmées", "voir", "admin"],
                "create_programed_charge" => ["Ajouter une charge programmée", "ajouter", "admin"],
                "update_programed_charge" => ["Modifier une charge programmée", "modifier", "admin"],
                "delete_programed_charge" => ["Supprimer une charge programmée", "supprimer", null],
            ]],
            "notifications" => ["Messages", null, [
                "receive_charge_notifications" => ["Recevoir les messages des charges", "action", null],
            ]],
        ]],
        "reclamations" => ["Réclamations", "triangle-exclamation", null, [
            "reclamations" => ["Réclamations", null, [
                "view_reclamations" => ["Voir les réclamations", "voir", null],
                "create_reclamation" => ["Signaler une réclamation", "ajouter", null],
                "close_reclamation" => ["Clôturer une réclamation", "action", null],
            ]],
        ]],
        "caisse" => ["Caisse", "cash-register", null, [
            "ma_caisse" => ["Ma caisse", null, [
                "view_own_cashbox" => ["Voir sa caisse", "voir", "tous"],
                "cash_in" => ["Encaisser", "ajouter", "tous"],
                "cash_contribution" => ["Faire un apport", "ajouter", "tous"],
                "cash_expense" => ["Saisir une dépense", "ajouter", "tous"],
                "cash_transfer" => ["Transférer des espèces", "action", "tous"],
                "confirm_cash_transfer" => ["Confirmer un transfert reçu", "action", "tous"],
                "close_cashbox" => ["Clôturer sa caisse", "action", "tous"],
                "view_cashbox_history" => ["Voir l'historique de sa caisse", "voir", "tous"],
            ]],
            "toutes" => ["Toutes les caisses", null, [
                "view_all_cashboxes" => ["Voir toutes les caisses", "voir", "admin"],
                "free_cash_movement" => ["Saisir tout type d'opération", "ajouter", "admin"],
                "empty_cashbox" => ["Vider la caisse d'un agent", "supprimer", "admin"],
            ]],
            "airbnb" => ["Caisse Airbnb", null, [
                "view_airbnb_cashbox" => ["Voir la caisse Airbnb", "voir", "admin"],
                "transfer_airbnb_cashbox" => ["Transférer depuis la caisse Airbnb", "action", "admin"],
            ]],
        ]],
        "statistiques" => ["Statistiques", "chart-line", null, [
            "statistiques" => ["Statistiques financières", null, [
                "view_stats" => ["Voir les statistiques", "voir", null],
                "download_stats_report" => ["Télécharger le rapport", "action", "comme:view_stats"],
            ]],
        ]],
        "utilisateurs" => ["Utilisateurs", "user-gear", null, [
            "utilisateurs" => ["Gestionnaires", null, [
                "view_users" => ["Voir les utilisateurs", "voir", null],
                "create_user" => ["Ajouter un utilisateur", "ajouter", null],
                "update_user" => ["Modifier un utilisateur", "modifier", "comme:create_user"],
                "delete_user" => ["Supprimer un utilisateur", "supprimer", null],
            ]],
            "dossiers" => ["Dossiers des agents", "alwed", [
                "manage_user_folders" => ["Choisir les dossiers d'un agent", "action", "admin"],
            ]],
        ]],
        "whatsapp" => ["Réception WhatsApp", "whatsapp", null, [
            "reception" => ["Messages reçus", null, [
                "manage_own_whatsapp" => ["Régler ses propres messages", "modifier", "tous"],
                "manage_team_whatsapp" => ["Régler les messages de l'équipe", "modifier", "admin"],
            ]],
        ]],
        "plateforme" => ["Plateforme", "globe", null, [
            "annonces" => ["Annonces", null, [
                "view_announces" => ["Voir les annonces", "voir", "comme:activate_announce|cancel_announce"],
                "activate_announce" => ["Accepter une annonce", "action", null],
                "cancel_announce" => ["Refuser une annonce", "action", null],
            ]],
            "carrousel" => ["Carrousel", null, [
                "view_slider" => ["Voir le carrousel", "voir", null],
                "create_slider" => ["Ajouter une image au carrousel", "ajouter", null],
                "activate_slider" => ["Activer une image du carrousel", "action", null],
            ]],
        ]],
        "campagnes" => ["Campagnes WhatsApp", "bullhorn", null, [
            "campagnes" => ["Campagnes", null, [
                "view_campaigns" => ["Voir les campagnes", "voir", "admin"],
                "create_campaign" => ["Créer une campagne", "ajouter", "admin"],
                "manage_campaign" => ["Lancer / mettre en pause / annuler", "modifier", "admin"],
                "delete_campaign" => ["Supprimer une campagne", "supprimer", "admin"],
                "manage_campaign_number" => ["Changer le numéro des campagnes", "action", "admin"],
            ]],
        ]],
        "modeles" => ["Modèles de messages", "message", null, [
            "modeles" => ["Modèles", null, [
                "view_message_templates" => ["Voir les modèles", "voir", "admin"],
                "update_message_templates" => ["Modifier les modèles", "modifier", "admin"],
            ]],
            "rappels" => ["Rappels automatiques", null, [
                "manage_reminders" => ["Gérer les rappels", "modifier", "admin"],
            ]],
        ]],
        "syndics" => ["Syndics", "building-user", null, [
            "syndics" => ["Syndics", null, [
                "view_syndics" => ["Voir les syndics", "voir", "admin"],
                "create_syndic" => ["Ajouter un syndic", "ajouter", "admin"],
                "update_syndic" => ["Modifier un syndic", "modifier", "admin"],
                "delete_syndic" => ["Supprimer un syndic", "supprimer", "admin"],
            ]],
            "envois" => ["Historique des envois", null, [
                "view_syndic_history" => ["Voir l'historique des envois", "voir", "admin"],
                "resend_syndic_contract" => ["Renvoyer un contrat", "action", "admin"],
            ]],
        ]],
        "baux" => ["Location longue durée", "file-signature", "alwed", [
            "baux" => ["Baux", null, [
                "view_leases" => ["Voir les baux", "voir", "comme:view_contract"],
                "create_lease" => ["Créer un bail", "ajouter", "comme:create_contract"],
                "update_lease" => ["Modifier / prolonger / envoyer un bail", "modifier", "comme:create_contract"],
                "end_lease" => ["Terminer un bail", "action", "comme:create_contract"],
                "delete_lease" => ["Supprimer un bail", "supprimer", "comme:create_contract"],
            ]],
            "loyers" => ["Loyers", null, [
                "collect_rent" => ["Encaisser / annuler un loyer, quittances", "action", "comme:create_contract"],
            ]],
        ]],
        "ventes" => ["Vente", "tag", "alwed", [
            "dossiers" => ["Dossiers de vente", null, [
                "view_sales" => ["Voir les ventes", "voir", "comme:view_contract"],
                "update_sale_status" => ["Changer le statut de vente", "modifier", "comme:create_contract"],
            ]],
            "mandats" => ["Mandats", null, [
                "create_mandate" => ["Créer un mandat", "ajouter", "comme:create_contract"],
                "update_mandate" => ["Modifier / envoyer un mandat", "modifier", "comme:create_contract"],
                "sign_mandate" => ["Faire signer un mandat", "action", "comme:create_contract"],
                "delete_mandate" => ["Supprimer un mandat", "supprimer", "comme:create_contract"],
            ]],
            "visites" => ["Reçus de visite", null, [
                "create_visit" => ["Créer / envoyer un reçu de visite", "ajouter", "comme:create_contract"],
                "sign_visit" => ["Faire signer une visite", "action", "comme:create_contract"],
                "delete_visit" => ["Supprimer une visite", "supprimer", "comme:create_contract"],
            ]],
        ]],
        "export" => ["Exports", "file-export", null, [
            "export" => ["Excel / PDF", null, [
                "export_data" => ["Exporter en Excel / PDF", "action", "tous"],
            ]],
        ]],
        "administration" => ["Administration", "shield", null, [
            "droits" => ["Droits et permissions", null, [
                "manage_permissions" => ["Gérer les droits et permissions", "modifier", "admin"],
            ]],
        ]],
    ];

    /** « METHODE uri » => droits (un seul suffit). Les autres routes restent libres. */
    public const ROUTES = [
        "POST realestates" => ["create_property"],
        "POST realestates/{id}" => ["update_property"],
        "PUT realestates/{realestate}" => ["update_property"],
        "PATCH realestates/{realestate}" => ["update_property"],
        "DELETE realestates/{id}" => ["delete_property"],
        "DELETE realestates/{realestate}" => ["delete_property"],
        "PATCH realestates/{id}/confirm-checkin" => ["confirm_checkin"],
        "PATCH realestates/{id}/confirm-depart" => ["confirm_checkout"],
        "PATCH realestates/{id}/start-cleaning" => ["start_cleaning"],
        "PATCH realestates/{id}/finish-cleaning" => ["finish_cleaning"],
        "PATCH realestates/{id}/return-to-cleaning" => ["return_to_cleaning"],
        "GET biens-desactives" => ["view_deactivated_properties"],
        "POST realestates/{id}/desactiver" => ["deactivate_property"],
        "POST realestates/{id}/reactiver" => ["reactivate_property"],
        "POST dossiers" => ["create_folder"],
        "PUT dossiers/{id}" => ["update_folder"],
        "POST dossiers/affecter" => ["update_folder", "create_property", "update_property"],
        "DELETE dossiers/{id}" => ["delete_folder"],
        "POST dossiers/{id}/agents" => ["assign_folder_agents"],
        "PUT managers/{id}/dossiers" => ["manage_user_folders"],
        "GET contracts" => ["view_contract"],
        "POST contracts" => ["create_contract"],
        "GET rapports" => ["view_reports"],
        "POST rapports" => ["create_report"],
        "GET realestates/{id}/calendrier" => ["view_calendar"],
        "POST realestates/{id}/prix" => ["update_night_prices"],
        "DELETE realestates/{id}/prix" => ["update_night_prices"],
        "POST realestates/{id}/blocages" => ["block_dates"],
        "POST realestates/{id}/debloquer" => ["unblock_dates"],
        "DELETE blocages/{id}" => ["unblock_dates"],
        "GET airbnb/biens" => ["view_airbnb"],
        "GET airbnb/sejours" => ["view_airbnb"],
        "GET realestates/{id}/airbnb" => ["view_airbnb"],
        "PUT realestates/{id}/airbnb" => ["link_airbnb"],
        "POST realestates/{id}/airbnb/nouveau-lien" => ["link_airbnb"],
        "POST realestates/{id}/airbnb/synchroniser" => ["sync_airbnb"],
        "GET bookings" => ["view_reservations", "view_calendar"],
        "POST bookings" => ["create_reservation"],
        "GET bookings/corbeille" => ["view_reservation_trash"],
        "POST bookings/{id}/restaurer" => ["restore_reservation"],
        "DELETE bookings/{id}" => ["delete_reservation"],
        "GET bookings/{id}/apercu-suppression" => ["delete_reservation"],
        "GET bookings/{id}/detail" => ["view_reservations", "view_calendar"],
        "POST bookings/{id}/extend" => ["extend_reservation"],
        "POST bookings/{id}/shrink" => ["reduce_reservation"],
        "POST bookings/{id}/modifier" => ["extend_reservation", "reduce_reservation"],
        "POST bookings/{id}/modifier-prix" => ["update_reservation_price"],
        "GET bookings/{id}/facture" => ["view_invoice"],
        "GET bookings/{id}/facture/resume" => ["view_invoice"],
        "POST bookings/{id}/facture/appliquer" => ["apply_invoice"],
        "POST bookings/{id}/facture/envoyer" => ["send_invoice"],
        "POST bookings/{id}/partager-syndic" => ["share_contract_syndic"],
        "PUT reglages/syndic" => ["share_contract_syndic"],
        "GET reservations/export" => ["export_reservations"],
        "PUT reglages/heures" => ["set_default_hours"],
        "GET clients" => ["view_clients", "create_reservation", "create_campaign", "create_lease", "create_visit", "create_mandate"],
        "GET clients/{client}" => ["view_clients", "create_reservation", "view_leases", "view_sales"],
        "POST clients" => ["create_client", "create_reservation", "create_lease", "create_visit"],
        "PUT clients/{client}" => ["update_client"],
        "PATCH clients/{client}" => ["update_client"],
        "DELETE clients/{client}" => ["delete_client"],
        "POST clients/{id}/liste-noire" => ["blacklist_client"],
        "DELETE clients/{id}/liste-noire" => ["blacklist_client"],
        "PATCH clients/{id}/promotions" => ["update_client", "create_campaign"],
        "GET owners" => ["view_owners", "create_property", "update_property", "create_mandate", "update_mandate", "create_lease"],
        "GET owners/{owner}" => ["view_owners", "create_mandate", "update_mandate"],
        "POST owners" => ["create_owner", "create_property", "update_property", "create_mandate"],
        "PUT owners/{owner}" => ["update_owner"],
        "PATCH owners/{owner}" => ["update_owner"],
        "DELETE owners/{id}" => ["delete_owner"],
        "DELETE owners/{owner}" => ["delete_owner"],
        "POST owners/{id}/contrats" => ["manage_owner_contracts"],
        "DELETE contrats-proprietaires/{id}" => ["manage_owner_contracts"],
        "GET charges" => ["view_charges"],
        "POST charges" => ["create_charge"],
        "POST charges/{id}/validate" => ["validate_charge"],
        "POST charges/{id}/cancel" => ["cancel_charge"],
        "DELETE charges/{id}" => ["delete_charge"],
        "DELETE charges/{charge}" => ["delete_charge"],
        "GET charges/annulees" => ["view_cancelled_charges"],
        "GET programed-charges" => ["view_programed_charges"],
        "POST programed-charges" => ["create_programed_charge"],
        "PUT programed-charges/{programed_charge}" => ["update_programed_charge"],
        "PATCH programed-charges/{programed_charge}" => ["update_programed_charge"],
        "DELETE programed-charges/{id}" => ["delete_programed_charge"],
        "DELETE programed-charges/{programed_charge}" => ["delete_programed_charge"],
        "GET reclamations" => ["view_reclamations"],
        "POST reclamations" => ["create_reclamation"],
        "PATCH reclamations/{id}/resolve" => ["close_reclamation"],
        "GET caisses/ma-caisse" => ["view_own_cashbox"],
        "POST caisses/mouvements" => ["cash_in", "cash_contribution", "cash_expense", "free_cash_movement"],
        "POST caisses/remises" => ["cash_transfer"],
        "POST caisses/remises/{id}/confirmer" => ["confirm_cash_transfer"],
        "POST caisses/cloturer" => ["close_cashbox"],
        "GET caisses/cloturages" => ["view_cashbox_history"],
        "POST caisses/{id}/vider" => ["empty_cashbox"],
        "GET caisse-airbnb" => ["view_airbnb_cashbox"],
        "POST caisse-airbnb/transferer" => ["transfer_airbnb_cashbox"],
        "GET financial-stats" => ["view_stats"],
        "GET financial-stats/export" => ["download_stats_report"],
        "GET financial-stats/rapport" => ["download_stats_report"],
        "GET global-stats" => ["view_stats"],
        "GET stats" => ["view_stats"],
        "GET statistiques/export" => ["view_stats"],
        "GET managers" => ["view_users", "assign_folder_agents", "manage_team_whatsapp"],
        "POST managers" => ["create_user"],
        "PUT managers/{id}" => ["update_user"],
        "PUT managers/{manager}" => ["update_user"],
        "PATCH managers/{manager}" => ["update_user"],
        "DELETE managers/{id}" => ["delete_user"],
        "DELETE managers/{manager}" => ["delete_user"],
        "GET reception-whatsapp" => ["manage_own_whatsapp"],
        "PUT reception-whatsapp" => ["manage_own_whatsapp"],
        "GET reception-whatsapp/utilisateurs" => ["manage_team_whatsapp"],
        "GET anounces" => ["view_announces"],
        "PATCH anounces/{id}/accept" => ["activate_announce"],
        "PATCH anounces/{id}/refuse" => ["cancel_announce"],
        "GET sliders" => ["view_slider"],
        "POST sliders" => ["create_slider"],
        "PATCH sliders/{id}/activate" => ["activate_slider"],
        "GET campagnes" => ["view_campaigns"],
        "GET campagnes/{id}" => ["view_campaigns"],
        "GET campagnes/segments" => ["view_campaigns", "create_campaign"],
        "POST campagnes" => ["create_campaign"],
        "POST campagnes/estimer" => ["create_campaign"],
        "POST campagnes/test" => ["create_campaign"],
        "PATCH campagnes/{id}/envoyer" => ["manage_campaign"],
        "PATCH campagnes/{id}/pause" => ["manage_campaign"],
        "PATCH campagnes/{id}/reprendre" => ["manage_campaign"],
        "PATCH campagnes/{id}/annuler" => ["manage_campaign"],
        "PATCH campagnes/{id}/relancer-echecs" => ["manage_campaign"],
        "DELETE campagnes/{id}" => ["delete_campaign"],
        "GET campagnes-whatsapp" => ["view_campaigns", "manage_campaign_number"],
        "PUT campagnes-whatsapp" => ["manage_campaign_number"],
        "DELETE campagnes-whatsapp" => ["manage_campaign_number"],
        "GET modeles-messages" => ["view_message_templates"],
        "GET modeles-messages/{id}" => ["view_message_templates"],
        "GET modeles-messages/variables" => ["view_message_templates"],
        "POST modeles-messages/apercu" => ["view_message_templates"],
        "PUT modeles-messages/{id}" => ["update_message_templates"],
        "POST modeles-messages/{id}/image" => ["update_message_templates"],
        "DELETE modeles-messages/{id}/image" => ["update_message_templates"],
        "PATCH modeles-messages/{id}/restaurer" => ["update_message_templates"],
        "GET rappels" => ["manage_reminders"],
        "GET rappels/{id}/suivi" => ["manage_reminders"],
        "PUT rappels/{id}" => ["manage_reminders"],
        "PATCH rappels/{id}/relancer-echecs" => ["manage_reminders"],
        "GET syndics" => ["view_syndics"],
        "GET syndics/biens" => ["view_syndics", "create_syndic", "update_syndic"],
        "GET syndics/{id}" => ["view_syndics"],
        "POST syndics" => ["create_syndic"],
        "PUT syndics/{id}" => ["update_syndic"],
        "DELETE syndics/{id}" => ["delete_syndic"],
        "GET syndics/envois" => ["view_syndic_history"],
        "GET syndics/envois/export" => ["view_syndic_history"],
        "GET syndics/envois/{id}" => ["view_syndic_history"],
        "POST syndics/envois/{id}/renvoyer" => ["resend_syndic_contract"],
        "GET baux" => ["view_leases"],
        "GET baux/biens" => ["view_leases", "create_lease"],
        "GET baux/tableau" => ["view_leases"],
        "GET baux/{id}" => ["view_leases"],
        "GET baux/{id}/contrat" => ["view_leases"],
        "GET loyer-paiements/{id}/quittance" => ["view_leases"],
        "POST baux" => ["create_lease"],
        "PUT baux/{id}" => ["update_lease"],
        "POST baux/{id}/envoyer-contrat" => ["update_lease"],
        "POST baux/{id}/prolonger" => ["update_lease"],
        "POST baux/{id}/terminer" => ["end_lease"],
        "DELETE baux/{id}" => ["delete_lease"],
        "PUT loyers/{id}" => ["collect_rent"],
        "POST loyers/{id}/paiements" => ["collect_rent"],
        "DELETE loyer-paiements/{id}" => ["collect_rent"],
        "POST loyer-paiements/{id}/envoyer-quittance" => ["collect_rent"],
        "GET ventes/biens" => ["view_sales"],
        "GET ventes/biens/{id}" => ["view_sales"],
        "GET ventes/tableau" => ["view_sales"],
        "GET ventes/mandats" => ["view_sales"],
        "GET ventes/mandats/{id}" => ["view_sales"],
        "GET ventes/mandats/{id}/pdf" => ["view_sales"],
        "GET ventes/visites/{id}/pdf" => ["view_sales"],
        "GET ventes/biens/{id}/mandat-prerempli" => ["create_mandate"],
        "PUT ventes/biens/{id}/statut" => ["update_sale_status"],
        "POST ventes/biens/{id}/mandats" => ["create_mandate"],
        "POST ventes/mandats" => ["create_mandate"],
        "PUT ventes/mandats/{id}" => ["update_mandate"],
        "PUT ventes/mandats/{id}/bien" => ["update_mandate"],
        "POST ventes/mandats/{id}/envoyer" => ["update_mandate"],
        "POST ventes/mandats/{id}/signature" => ["sign_mandate"],
        "DELETE ventes/mandats/{id}" => ["delete_mandate"],
        "POST ventes/biens/{id}/visites" => ["create_visit"],
        "PUT ventes/visites/{id}" => ["create_visit"],
        "POST ventes/visites/{id}/envoyer" => ["create_visit"],
        "POST ventes/visites/{id}/signature" => ["sign_visit"],
        "DELETE ventes/visites/{id}" => ["delete_visit"],
        "POST export" => ["export_data"],
        "GET permissions" => ["manage_permissions"],
        "PUT permissions/roles/{role}" => ["manage_permissions"],
        "GET permissions/utilisateurs/{id}" => ["manage_permissions"],
        "PUT permissions/utilisateurs/{id}" => ["manage_permissions"],
    ];

    /** Preferences de reception : jamais donnees d office a l administrateur. */
    public const PREFERENCES = ["receive_charge_notifications"];

    public const ROLES = [
        "admin" => "Administrateur",
        "agent" => "Agent",
        "nettoyeuse" => "Femme de ménage",
        "demo" => "Démonstration",
    ];

    /** Alwed a les baux, les ventes et les dossiers ; Godar non. */
    public static function disponible(?string $reserve): bool
    {
        return $reserve === null || ($reserve === "alwed" && class_exists(\App\Http\Controllers\dashboard\BailController::class));
    }

    /** Tous les droits du catalogue disponibles ici : nom => [libelle, type, defaut, module, sous-module]. */
    public static function droits(): array
    {
        $out = [];
        foreach (self::ARBRE as $mcode => [$mlib, $icone, $mres, $sous]) {
            if (!static::disponible($mres)) continue;
            foreach ($sous as $scode => [$slib, $sres, $droits]) {
                if (!static::disponible($sres)) continue;
                foreach ($droits as $nom => [$lib, $type, $defaut]) {
                    $out[$nom] = [$lib, $type, $defaut, $mcode, $scode];
                }
            }
        }
        return $out;
    }

    public static function libelle(string $droit): string
    {
        return static::droits()[$droit][0] ?? ucfirst(str_replace("_", " ", $droit));
    }

    /**
     * L arbre pour l ecran des droits. Chaque module garde aussi la liste
     * plate de ses droits (« permissions »), lue par les anciennes versions.
     */
    public static function modules(string $guard = self::GUARD): array
    {
        $existants = Permission::where("guard_name", $guard)->pluck("name")->all();
        $vus = [];
        $modules = [];
        foreach (self::ARBRE as $mcode => [$mlib, $icone, $mres, $sous]) {
            if (!static::disponible($mres)) continue;
            $sousModules = [];
            $plat = [];
            foreach ($sous as $scode => [$slib, $sres, $droits]) {
                if (!static::disponible($sres)) continue;
                $lignes = [];
                foreach ($droits as $nom => [$lib, $type, $defaut]) {
                    if (!in_array($nom, $existants, true)) continue;
                    $ligne = ["code" => $nom, "libelle" => $lib, "action" => $type];
                    $lignes[] = $ligne;
                    $plat[] = $ligne;
                    $vus[] = $nom;
                }
                if ($lignes) $sousModules[] = ["code" => $scode, "libelle" => $slib, "permissions" => $lignes];
            }
            if ($plat) {
                $modules[] = ["code" => $mcode, "libelle" => $mlib, "icone" => $icone,
                    "sousModules" => $sousModules, "permissions" => $plat];
            }
        }
        $autres = array_values(array_diff($existants, $vus));
        sort($autres);
        if ($autres) {
            $lignes = array_map(fn($n) => ["code" => $n, "libelle" => static::libelle($n), "action" => "action"], $autres);
            $modules[] = ["code" => "autres", "libelle" => "Autres", "icone" => "ellipsis",
                "sousModules" => [["code" => "autres", "libelle" => "Autres", "permissions" => $lignes]], "permissions" => $lignes];
        }
        return $modules;
    }

    /** Les droits exiges par une route, ou null si elle reste libre. */
    public static function droitsDeRoute(string $methode, string $uri): ?array
    {
        $methode = strtoupper($methode) === "HEAD" ? "GET" : strtoupper($methode);
        $uri = preg_replace("#^api/dashboard/#", "", trim($uri, "/"));
        return self::ROUTES[$methode . " " . $uri] ?? null;
    }

    /** L administrateur peut tout ; les autres selon leurs droits effectifs. */
    public static function peut($manager, string $droit): bool
    {
        if (!$manager) return false;
        if ($manager->hasRole("admin")) return true;
        try {
            return $manager->hasPermissionTo($droit, self::GUARD);
        } catch (\Throwable $e) {
            return false;
        }
    }

    public static function peutUnDe($manager, array $droits): bool
    {
        foreach ($droits as $d) {
            if (static::peut($manager, $d)) return true;
        }
        return false;
    }

    /** Identifiants des utilisateurs a qui ce droit est retire. */
    public static function retires(string $droit): array
    {
        return Schema::hasTable("permissions_retirees")
            ? DB::table("permissions_retirees")->where("permission", $droit)->pluck("manager_id")->all()
            : [];
    }

    /**
     * Cree les droits manquants et les donne aux roles prevus par leur
     * defaut. Un droit deja present n est jamais modifie : les reglages
     * faits depuis l ecran des droits sont respectes.
     */
    public static function installer(): array
    {
        $roles = Role::where("guard_name", self::GUARD)->get()->keyBy("name");
        $crees = [];
        foreach (static::droits() as $nom => [$lib, $type, $defaut]) {
            if (Permission::where("guard_name", self::GUARD)->where("name", $nom)->exists()) continue;
            // Les roles qui ont deja le droit de reference, avant creation du nouveau.
            $cibles = [];
            if ($defaut === "tous") {
                $cibles = $roles->keys()->all();
            } elseif ($defaut === "admin") {
                $cibles = ["admin"];
            } elseif (is_string($defaut) && str_starts_with($defaut, "comme:")) {
                $refs = explode("|", substr($defaut, 6));
                foreach ($roles as $rnom => $role) {
                    if ($role->permissions->pluck("name")->intersect($refs)->isNotEmpty()) $cibles[] = $rnom;
                }
            }
            $p = Permission::create(["name" => $nom, "guard_name" => self::GUARD]);
            foreach (array_unique(array_merge($cibles, ["admin"])) as $rnom) {
                if (isset($roles[$rnom]) && !in_array($nom, self::PREFERENCES, true)) $roles[$rnom]->givePermissionTo($p);
            }
            $crees[$nom] = array_values(array_unique(array_merge($cibles, ["admin"])));
        }
        // L administrateur garde tous les droits du catalogue (hors preferences).
        if (isset($roles["admin"])) {
            $manque = array_diff(array_keys(static::droits()), $roles["admin"]->permissions()->pluck("name")->all(), self::PREFERENCES);
            if ($manque) $roles["admin"]->givePermissionTo(array_values($manque));
        }
        app(PermissionRegistrar::class)->forgetCachedPermissions();
        return $crees;
    }
}
