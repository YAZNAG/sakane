<?php

namespace App\Services;

/**
 * Modeles fournis avec l'application.
 *
 * C'est la reference : chaque entree donne le texte d'origine, qui sert
 * a la fois de valeur initiale et de filet de securite si le modele
 * modifie devient inutilisable.
 */
class CatalogueModeles
{
    /** Variables communes a tous les modeles. */
    public const VARIABLES_COMMUNES = [
        "{client_name}"     => "Nom complet du client",
        "{client_phone}"    => "Téléphone du client",
        "{client_cin}"      => "CIN ou passeport du client",
        "{client_email}"    => "Email du client",
        "{apartment_name}"  => "Nom de l'appartement",
        "{address}"         => "Adresse de l'appartement",
        "{city}"            => "Ville de l'appartement",
        "{residence}"       => "Résidence (dossier) de l'appartement",
        "{rooms}"           => "Nombre de chambres",
        "{booking_id}"      => "Numéro de la réservation",
        "{guests}"          => "Nombre de personnes",
        "{guest_type}"      => "Type d'invité",
        "{check_in_date}"   => "Date d'arrivée",
        "{check_in_time}"   => "Heure d'arrivée",
        "{check_out_date}"  => "Date de départ",
        "{check_out_time}"  => "Heure de départ",
        "{nights}"          => "Nombre de nuits",
        "{amount}"          => "Montant total",
        "{advance}"         => "Paiement déjà versé",
        "{balance}"         => "Reste à payer",
        "{deposit}"         => "Caution",
        "{notes}"           => "Remarques sur la réservation",
        "{agent_name}"      => "Agent qui a fait la réservation",
        "{syndic_name}"     => "Nom du syndic",
        "{old_check_out_date}" => "Ancienne date de départ",
        "{nights_delta}"    => "Nuits ajoutées ou retirées (+3 / -2)",
        "{night_price}"     => "Prix par nuit",
        "{old_night_price}" => "Ancien prix par nuit",
        "{old_amount}"      => "Ancien total",
        "{new_amount}"      => "Nouveau total",
        "{difference}"      => "Écart entre l'ancien et le nouveau total",
        "{contact}"         => "Contact de l'agence",
        "{checkin_instructions}" => "Consignes d'arrivée",
    ];

    public static function tous(): array
    {
        // Les modeles des rappels de reservation completent cette liste.
        return array_merge(static::messages(), CatalogueRappels::modeles());
    }

    private static function messages(): array
    {
        return [
            // ---------------- Modifications de contrat ----------------
            [
                "code"        => "booking-extended-admin",
                "message_name" => "Prolongation (gestionnaires)",
                "categorie"   => "modifications",
                "description" => "Envoyé aux gestionnaires avec le nouveau contrat quand un séjour est prolongé.",
                "variables"   => ["{client_name}", "{apartment_name}", "{address}", "{old_check_out_date}", "{check_out_date}", "{nights_delta}", "{old_amount}", "{new_amount}", "{difference}", "{agent_name}"],
                "defaut"      => "🔁 Réservation prolongée ({nights_delta} j)\n\n"
                    . "🏠 {apartment_name}\n"
                    . "👤 Client : {client_name}\n"
                    . "📅 Départ : {old_check_out_date} → {check_out_date}\n"
                    . "💰 Total : {old_amount} → {new_amount} MAD (+{difference} MAD)",
            ],
            [
                "code"        => "booking-shortened-admin",
                "message_name" => "Raccourcissement (gestionnaires)",
                "categorie"   => "modifications",
                "description" => "Envoyé aux gestionnaires avec le nouveau contrat quand un séjour est raccourci.",
                "variables"   => ["{client_name}", "{apartment_name}", "{address}", "{old_check_out_date}", "{check_out_date}", "{nights_delta}", "{old_amount}", "{new_amount}", "{difference}", "{agent_name}"],
                "defaut"      => "✂️ Réservation raccourcie ({nights_delta} j)\n\n"
                    . "🏠 {apartment_name}\n"
                    . "👤 Client : {client_name}\n"
                    . "📅 Départ : {old_check_out_date} → {check_out_date}\n"
                    . "💰 Total : {old_amount} → {new_amount} MAD (-{difference} MAD)",
            ],
            [
                "code"        => "booking-price-client",
                "message_name" => "Modification du prix (client)",
                "categorie"   => "modifications",
                "description" => "Envoyé au client avec le nouveau contrat quand le prix de sa réservation change.",
                "variables"   => ["{client_name}", "{apartment_name}", "{check_in_date}", "{check_out_date}", "{nights}", "{old_night_price}", "{night_price}", "{old_amount}", "{new_amount}", "{contact}"],
                "defaut"      => "Bonjour {client_name},\n\n"
                    . "Le prix de votre séjour à {apartment_name} a été mis à jour.\n\n"
                    . "🌙 Prix par nuit : {old_night_price} → {night_price} MAD\n"
                    . "💰 Total : {old_amount} → {new_amount} MAD\n\n"
                    . "Vous trouverez ci-joint votre nouveau bulletin d'hébergement.",
            ],
            [
                "code"        => "booking-price-admin",
                "message_name" => "Modification du prix (gestionnaires)",
                "categorie"   => "modifications",
                "description" => "Envoyé aux gestionnaires avec le nouveau contrat quand le prix d'une réservation change.",
                "variables"   => ["{client_name}", "{apartment_name}", "{old_night_price}", "{night_price}", "{old_amount}", "{new_amount}", "{difference}", "{agent_name}"],
                "defaut"      => "💱 Prix modifié\n\n"
                    . "🏠 {apartment_name}\n"
                    . "👤 Client : {client_name}\n"
                    . "🌙 Prix par nuit : {old_night_price} → {night_price} MAD\n"
                    . "💰 Total : {old_amount} → {new_amount} MAD",
            ],
            [
                "code"        => "syndic-prolongation",
                "message_name" => "Prolongation envoyée au syndic",
                "categorie"   => "modifications",
                "description" => "Accompagne le nouveau contrat envoyé aux syndics de l'immeuble quand un séjour est prolongé.",
                "variables"   => ["{syndic_name}", "{client_name}", "{client_cin}", "{apartment_name}", "{address}", "{residence}", "{check_in_date}", "{old_check_out_date}", "{check_out_date}", "{nights_delta}", "{guests}", "{contact}"],
                "defaut"      => "Bonjour {syndic_name},\n\n"
                    . "Le séjour de {client_name} à {apartment_name} est prolongé ({nights_delta} j) : "
                    . "départ le {check_out_date} au lieu du {old_check_out_date}.\n"
                    . "Veuillez trouver ci-joint le contrat mis à jour.\n\n"
                    . "Cordialement.",
            ],
            [
                "code"        => "syndic-raccourcissement",
                "message_name" => "Raccourcissement envoyé au syndic",
                "categorie"   => "modifications",
                "description" => "Accompagne le nouveau contrat envoyé aux syndics de l'immeuble quand un séjour est raccourci.",
                "variables"   => ["{syndic_name}", "{client_name}", "{client_cin}", "{apartment_name}", "{address}", "{residence}", "{check_in_date}", "{old_check_out_date}", "{check_out_date}", "{nights_delta}", "{guests}", "{contact}"],
                "defaut"      => "Bonjour {syndic_name},\n\n"
                    . "Le séjour de {client_name} à {apartment_name} est raccourci ({nights_delta} j) : "
                    . "départ le {check_out_date} au lieu du {old_check_out_date}.\n"
                    . "Veuillez trouver ci-joint le contrat mis à jour.\n\n"
                    . "Cordialement.",
            ],

            // ---------------- Reservations ----------------
            [
                "code"        => "new-booking-client",
                "message_name" => "Confirmation de réservation (client)",
                "categorie"   => "reservations",
                "description" => "Envoyé au client dès que sa réservation est enregistrée.",
                "variables"   => ["{client_name}", "{apartment_name}", "{check_in_date}", "{check_out_date}", "{amount}"],
                "defaut"      => "Bonjour {client_name},\n\n"
                    . "Votre réservation est confirmée.\n\n"
                    . "🏠 Appartement : {apartment_name}\n"
                    . "📅 Arrivée : {check_in_date}\n"
                    . "📅 Départ : {check_out_date}\n"
                    . "💰 Montant : {amount} MAD\n\n"
                    . "Merci de votre confiance.",
            ],
            [
                "code"        => "new-booking-admin",
                "message_name" => "Nouvelle réservation (administration)",
                "categorie"   => "reservations",
                "description" => "Prévient l'administration d'une nouvelle réservation.",
                "variables"   => ["{client_name}", "{apartment_name}", "{check_in_date}", "{check_out_date}", "{amount}"],
                "defaut"      => "📌 Nouvelle réservation\n\n"
                    . "🏠 Appartement : {apartment_name}\n"
                    . "👤 Client : {client_name}\n"
                    . "📅 Du {check_in_date} au {check_out_date}\n"
                    . "💰 Montant : {amount} MAD",
            ],
            [
                "code"        => "booking-extended-client",
                "message_name" => "Message de prolongement (client)",
                "categorie"   => "reservations",
                "description" => "Envoyé au client quand son séjour est prolongé.",
                "variables"   => ["{client_name}", "{apartment_name}", "{check_out_date}", "{nights}", "{amount}"],
                "defaut"      => "Bonjour {client_name},\n\n"
                    . "Votre séjour à {apartment_name} est prolongé.\n\n"
                    . "📅 Nouveau départ : {check_out_date}\n"
                    . "🌙 Nuits ajoutées : {nights}\n"
                    . "💰 Supplément : {amount} MAD\n\n"
                    . "Bon séjour parmi nous.",
            ],
            [
                "code"        => "booking-shortened-client",
                "message_name" => "Message de raccourcissement (client)",
                "categorie"   => "reservations",
                "description" => "Envoyé au client quand son séjour est raccourci.",
                "variables"   => ["{client_name}", "{apartment_name}", "{check_out_date}", "{nights}", "{amount}"],
                "defaut"      => "Bonjour {client_name},\n\n"
                    . "Votre séjour à {apartment_name} a été raccourci.\n\n"
                    . "📅 Nouveau départ : {check_out_date}\n"
                    . "🌙 Nuits retirées : {nights}\n"
                    . "💰 Remboursement : {amount} MAD\n\n"
                    . "Merci de votre confiance.",
            ],
            [
                "code"        => "client-leaving-reminder",
                "message_name" => "Rappel de départ (client)",
                "categorie"   => "reservations",
                "description" => "Rappelle au client que son séjour se termine.",
                "variables"   => ["{client_name}", "{apartment_name}", "{check_out_date}"],
                "defaut"      => "Bonjour {client_name},\n\n"
                    . "Nous vous rappelons que votre séjour à {apartment_name} "
                    . "se termine le {check_out_date}.\n\n"
                    . "Nous vous souhaitons une bonne continuation.",
            ],

            [
                "code"        => "syndic-contrat",
                "message_name" => "Contrat envoyé au syndic",
                "categorie"   => "reservations",
                "description" => "Accompagne le contrat public envoyé au syndic de l'immeuble, automatiquement à chaque réservation ou depuis le partage.",
                "variables"   => ["{syndic_name}", "{client_name}", "{client_phone}", "{client_cin}", "{apartment_name}", "{address}", "{residence}", "{booking_id}", "{check_in_date}", "{check_in_time}", "{check_out_date}", "{check_out_time}", "{nights}", "{guests}", "{amount}", "{advance}", "{balance}", "{deposit}", "{notes}", "{agent_name}", "{contact}"],
                "defaut"      => "Bonjour {syndic_name},\n\n"
                    . "Veuillez trouver ci-joint le contrat de location de {apartment_name}"
                    . " pour le séjour de {client_name}, du {check_in_date} au {check_out_date}.\n\n"
                    . "Cordialement.",
            ],

            // ---------------- Location longue duree ----------------
            [
                "code"        => "bail-contrat-locataire",
                "message_name" => "Contrat de bail (locataire)",
                "categorie"   => "loyers",
                "description" => "Accompagne le contrat de bail envoyé au locataire.",
                "variables"   => ["{client_name}", "{apartment_name}", "{address}", "{start_date}", "{end_date}", "{rent}", "{deposit}", "{contact}"],
                "defaut"      => "Bonjour {client_name},\n\n"
                    . "Veuillez trouver ci-joint votre contrat de bail.\n\n"
                    . "🏠 {apartment_name}\n"
                    . "📍 {address}\n"
                    . "📅 Du {start_date} au {end_date}\n"
                    . "💰 Loyer mensuel : {rent} MAD\n\n"
                    . "Pour toute question : {contact}",
            ],
            [
                "code"        => "loyer-quittance",
                "message_name" => "Quittance de loyer",
                "categorie"   => "loyers",
                "description" => "Accompagne la quittance envoyée après un paiement de loyer.",
                "variables"   => ["{client_name}", "{apartment_name}", "{period}", "{amount}", "{balance}", "{contact}"],
                "defaut"      => "Bonjour {client_name},\n\n"
                    . "Nous avons bien reçu votre paiement de {amount} MAD pour le loyer de {period}.\n"
                    . "Vous trouverez votre quittance ci-jointe.\n\n"
                    . "Merci.",
            ],
            [
                "code"        => "loyer-rappel-avant",
                "message_name" => "Rappel de loyer (3 jours avant)",
                "categorie"   => "loyers",
                "description" => "Envoyé au locataire trois jours avant l'échéance.",
                "variables"   => ["{client_name}", "{apartment_name}", "{period}", "{due_date}", "{amount}", "{balance}", "{contact}"],
                "defaut"      => "Bonjour {client_name},\n\n"
                    . "Petit rappel : le loyer de {period} ({balance} MAD) est à régler le {due_date}.\n\n"
                    . "🏠 {apartment_name}\n\n"
                    . "Merci. Pour toute question : {contact}",
            ],
            [
                "code"        => "loyer-rappel-jour",
                "message_name" => "Rappel de loyer (jour de l'échéance)",
                "categorie"   => "loyers",
                "description" => "Envoyé au locataire le jour de l'échéance.",
                "variables"   => ["{client_name}", "{apartment_name}", "{period}", "{due_date}", "{amount}", "{balance}", "{contact}"],
                "defaut"      => "Bonjour {client_name},\n\n"
                    . "Le loyer de {period} ({balance} MAD) est à régler aujourd'hui.\n\n"
                    . "🏠 {apartment_name}\n\n"
                    . "Merci. Pour toute question : {contact}",
            ],
            [
                "code"        => "loyer-retard",
                "message_name" => "Loyer en retard",
                "categorie"   => "loyers",
                "description" => "Envoyé au locataire cinq jours après l'échéance si le loyer n'est pas réglé.",
                "variables"   => ["{client_name}", "{apartment_name}", "{period}", "{due_date}", "{amount}", "{balance}", "{contact}"],
                "defaut"      => "Bonjour {client_name},\n\n"
                    . "Sauf erreur de notre part, le loyer de {period} (échéance du {due_date}) n'est pas encore réglé.\n"
                    . "Reste à payer : {balance} MAD.\n\n"
                    . "Merci de régulariser rapidement. Pour toute question : {contact}",
            ],

            // ---------------- Nettoyage ----------------
            [
                "code"        => "cleaning-to-do",
                "message_name" => "Appartement à nettoyer",
                "categorie"   => "nettoyage",
                "description" => "Prévient les femmes de ménage qu'un appartement est libre.",
                "variables"   => ["{apartment_name}", "{check_out_date}"],
                "defaut"      => "🧹 Appartement à nettoyer\n\n"
                    . "🏠 {apartment_name}\n"
                    . "🕐 Départ du client : {check_out_date}\n\n"
                    . "Merci de déclarer le début du nettoyage dans l'application.",
            ],
            [
                "code"        => "cleaning-started",
                "message_name" => "Nettoyage commencé",
                "categorie"   => "nettoyage",
                "description" => "Informe les gestionnaires du début d'un nettoyage.",
                "variables"   => ["{apartment_name}", "{agent_name}", "{time}", "{waiting_time}"],
                "defaut"      => "🧹 Nettoyage commencé\n\n"
                    . "🏠 Appartement : {apartment_name}\n"
                    . "👤 Par : {agent_name}\n"
                    . "🕐 Début : {time}",
            ],
            [
                "code"        => "cleaning-finished",
                "message_name" => "Nettoyage terminé",
                "categorie"   => "nettoyage",
                "description" => "Informe les gestionnaires de la fin d'un nettoyage.",
                "variables"   => ["{apartment_name}", "{agent_name}", "{time}", "{duration}"],
                "defaut"      => "✅ Nettoyage terminé\n\n"
                    . "🏠 Appartement : {apartment_name}\n"
                    . "👤 Par : {agent_name}\n"
                    . "⏱️ Durée : {duration}\n"
                    . "🕐 Fin : {time}\n\n"
                    . "L'appartement est de nouveau disponible.",
            ],

            // ---------------- Charges ----------------
            [
                "code"        => "charge-created",
                "message_name" => "Nouvelle charge",
                "categorie"   => "charges",
                "description" => "Prévient les gestionnaires qu'une charge a été saisie.",
                "variables"   => ["{apartment_name}", "{agent_name}", "{amount}", "{label}", "{status}"],
                "defaut"      => "💸 Nouvelle charge\n\n"
                    . "🏠 Appartement : {apartment_name}\n"
                    . "📄 Objet : {label}\n"
                    . "💰 Montant : {amount} MAD\n"
                    . "📌 Statut : {status}\n"
                    . "👤 Saisie par : {agent_name}",
            ],
            [
                "code"        => "charge-validated",
                "message_name" => "Charge traitée",
                "categorie"   => "charges",
                "description" => "Prévient les gestionnaires qu'une charge a été validée.",
                "variables"   => ["{apartment_name}", "{agent_name}", "{amount}", "{label}"],
                "defaut"      => "✅ Charge traitée\n\n"
                    . "🏠 Appartement : {apartment_name}\n"
                    . "📄 Objet : {label}\n"
                    . "💰 Montant : {amount} MAD\n"
                    . "👤 Traitée par : {agent_name}",
            ],
            [
                "code"        => "programed-charge",
                "message_name" => "Charge programmée",
                "categorie"   => "charges",
                "description" => "Rappel automatique d'une charge récurrente.",
                "variables"   => ["{apartment_name}", "{amount}", "{label}"],
                "defaut"      => "🔔 Charge programmée\n\n"
                    . "🏠 Appartement : {apartment_name}\n"
                    . "📄 Objet : {label}\n"
                    . "💰 Montant : {amount} MAD",
            ],

            // ---------------- Reclamations ----------------
            [
                "code"        => "reclamation-created",
                "message_name" => "Nouvelle réclamation",
                "categorie"   => "reclamations",
                "description" => "Prévient les personnes concernées d'une réclamation.",
                "variables"   => ["{apartment_name}", "{agent_name}", "{note}"],
                "defaut"      => "⚠️ Nouvelle réclamation\n\n"
                    . "🏠 Appartement : {apartment_name}\n"
                    . "👤 Signalée par : {agent_name}\n"
                    . "📝 Détail : {note}",
            ],
            [
                "code"        => "reclamation-resolved",
                "message_name" => "Réclamation résolue",
                "categorie"   => "reclamations",
                "description" => "Informe que la réclamation a été traitée.",
                "variables"   => ["{apartment_name}", "{agent_name}", "{note}"],
                "defaut"      => "✅ Réclamation résolue\n\n"
                    . "🏠 Appartement : {apartment_name}\n"
                    . "👤 Traitée par : {agent_name}\n"
                    . "📝 Détail : {note}",
            ],
        ];
    }

    /** Texte d'origine d'un modele, ou null si le code est inconnu. */
    public static function defaut(string $code): ?string
    {
        foreach (static::tous() as $modele) {
            if ($modele["code"] === $code) {
                return $modele["defaut"];
            }
        }
        return null;
    }

    /** Valeurs d'exemple pour l'apercu. */
    public static function exemples(): array
    {
        return [
            "{client_name}"    => "Mohamed Alami",
            "{apartment_name}" => "Appartement Founty 12",
            "{check_in_date}"  => "05/09/2026",
            "{check_out_date}" => "12/09/2026",
            "{amount}"         => "3 500",
            "{agent_name}"     => "Fatima",
            "{time}"           => "14h30",
            "{duration}"       => "1 h 15",
            "{waiting_time}"   => "45 min",
            "{label}"          => "Facture d'eau",
            "{status}"         => "Payée",
            "{note}"           => "Fuite d'eau dans la salle de bain",
            "{client_phone}"   => "212661234567",
            "{address}"        => "Hay Founty, Agadir",
            "{check_in_time}"  => "14h00",
            "{nights}"         => "7",
            "{advance}"        => "1 000",
            "{balance}"        => "2 500",
            "{deposit}"        => "1 500",
            "{notes}"          => "Arrivée tardive prévue",
            "{old_check_out_date}" => "10/09/2026",
            "{nights_delta}"   => "+2",
            "{night_price}"    => "500",
            "{old_night_price}" => "450",
            "{old_amount}"     => "3 150",
            "{new_amount}"     => "3 500",
            "{difference}"     => "350",
            "{contact}"        => "0661 23 45 67",
            "{syndic_name}"    => "Hicham",
            "{client_cin}"     => "AB123456",
            "{client_email}"   => "client@exemple.ma",
            "{city}"           => "Agadir",
            "{residence}"      => "Résidence Nasser 3",
            "{rooms}"          => "2",
            "{booking_id}"     => "1248",
            "{guests}"         => "3",
            "{guest_type}"     => "Famille",
            "{start_date}"     => "01/10/2026",
            "{end_date}"       => "30/09/2027",
            "{rent}"           => "4 500",
            "{period}"         => "Octobre 2026",
            "{due_date}"       => "01/10/2026",
            "{checkin_instructions}" => "Les clés vous seront remises sur place.",
        ];
    }
}
