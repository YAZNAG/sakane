<?php

/**
 * Reglages de l'agence utilises par les rappels et le bulletin
 * d'hebergement. Modifiables dans le fichier .env.
 */
return [
    'nom'                => env('AGENCE_NOM', ''),
    'contact'            => env('AGENCE_CONTACT', ''),
    'adresse'            => env('AGENCE_ADRESSE', ''),
    // Les correspondants du pied de fiche, sous la forme
    // "Nom:numero, Nom:numero".
    'contacts'           => env('AGENCE_CONTACTS', ''),
    'heure_checkin'      => env('AGENCE_HEURE_CHECKIN', '14h00'),
    'heure_checkout'     => env('AGENCE_HEURE_CHECKOUT', '11h00'),
    // La caisse principale : son nom, et le gerant qui la tient.
    'caisse_principale_nom'     => env('CAISSE_PRINCIPALE_NOM', "Caisse de l'agence"),
    'caisse_principale_manager' => env('CAISSE_PRINCIPALE_MANAGER'),
    'consignes_checkin'  => env('AGENCE_CONSIGNES_CHECKIN',
        "Merci de nous prévenir de votre heure d'arrivée."),
];
