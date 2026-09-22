<?php

namespace App\Services;

/**
 * Rappels proposes a l'installation. Le gerant peut ensuite modifier
 * les delais, les textes, les destinataires et l'activation.
 */
class CatalogueRappels
{
    public static function tous(): array
    {
        return [
            [
                "code" => "rappel-j3", "libelle" => "Rappel 3 jours avant l'arrivée",
                "moment" => "checkin", "decalage_heures" => -72,
                "vers_client" => true, "vers_agent" => false,
                "modele_client" => "rappel-j3-client", "modele_agent" => "rappel-j3-agent",
                "actif" => true, "ordre" => 1,
            ],
            [
                "code" => "rappel-j1", "libelle" => "Rappel la veille de l'arrivée",
                "moment" => "checkin", "decalage_heures" => -24,
                "vers_client" => true, "vers_agent" => true,
                "modele_client" => "rappel-j1-client", "modele_agent" => "rappel-j1-agent",
                "actif" => true, "ordre" => 2,
            ],
            [
                "code" => "rappel-jour-j", "libelle" => "Rappel le jour de l'arrivée",
                "moment" => "checkin", "decalage_heures" => -3,
                "vers_client" => true, "vers_agent" => true,
                "modele_client" => "rappel-jour-j-client", "modele_agent" => "rappel-jour-j-agent",
                "actif" => true, "ordre" => 3,
            ],
            [
                "code" => "post-sejour", "libelle" => "Message après le séjour",
                "moment" => "depart", "decalage_heures" => 0,
                "vers_client" => true, "vers_agent" => false,
                "modele_client" => "post-sejour-client", "modele_agent" => null,
                "actif" => true, "ordre" => 4,
            ],
        ];
    }

    /** Modeles de messages associes, ajoutes au catalogue general. */
    public static function modeles(): array
    {
        $variablesClient = [
            "{client_name}", "{apartment_name}", "{address}",
            "{check_in_date}", "{check_in_time}", "{check_out_date}",
            "{amount}", "{advance}", "{balance}", "{deposit}",
            "{contact}", "{checkin_instructions}",
        ];
        $variablesAgent = [
            "{client_name}", "{client_phone}", "{apartment_name}",
            "{check_in_date}", "{check_in_time}", "{balance}",
            "{deposit}", "{notes}",
        ];

        return [
            [
                "code" => "rappel-j3-client", "message_name" => "Rappel J-3 (client)",
                "categorie" => "rappels", "variables" => $variablesClient,
                "description" => "Envoyé au client trois jours avant son arrivée.",
                "defaut" => "Bonjour {client_name},\n\n"
                    . "Votre séjour approche.\n\n"
                    . "🏠 {apartment_name}\n"
                    . "📍 {address}\n"
                    . "📅 Arrivée le {check_in_date} à {check_in_time}\n"
                    . "💰 Reste à régler : {balance} MAD\n\n"
                    . "{checkin_instructions}\n\n"
                    . "Pour toute question : {contact}",
            ],
            [
                "code" => "rappel-j3-agent", "message_name" => "Rappel J-3 (agent)",
                "categorie" => "rappels", "variables" => $variablesAgent,
                "description" => "Prévient l'agent responsable trois jours avant l'arrivée.",
                "defaut" => "📋 Arrivée dans 3 jours\n\n"
                    . "👤 {client_name} — {client_phone}\n"
                    . "🏠 {apartment_name}\n"
                    . "📅 {check_in_date} à {check_in_time}\n"
                    . "💰 À encaisser : {balance} MAD\n"
                    . "🔐 Caution : {deposit} MAD\n"
                    . "📝 {notes}",
            ],
            [
                "code" => "rappel-j1-client", "message_name" => "Rappel J-1 (client)",
                "categorie" => "rappels", "variables" => $variablesClient,
                "description" => "Envoyé au client la veille de son arrivée.",
                "defaut" => "Bonjour {client_name},\n\n"
                    . "Nous vous attendons demain.\n\n"
                    . "🏠 {apartment_name}\n"
                    . "📍 {address}\n"
                    . "📅 Arrivée le {check_in_date} à {check_in_time}\n"
                    . "💰 Reste à régler : {balance} MAD\n\n"
                    . "{checkin_instructions}\n\n"
                    . "Pour toute question : {contact}",
            ],
            [
                "code" => "rappel-j1-agent", "message_name" => "Rappel J-1 (agent)",
                "categorie" => "rappels", "variables" => $variablesAgent,
                "description" => "Prévient l'agent responsable la veille de l'arrivée.",
                "defaut" => "📋 Arrivée demain\n\n"
                    . "👤 {client_name} — {client_phone}\n"
                    . "🏠 {apartment_name}\n"
                    . "📅 {check_in_date} à {check_in_time}\n"
                    . "💰 À encaisser : {balance} MAD\n"
                    . "🔐 Caution : {deposit} MAD\n"
                    . "📝 {notes}",
            ],
            [
                "code" => "rappel-jour-j-client", "message_name" => "Rappel jour d'arrivée (client)",
                "categorie" => "rappels", "variables" => $variablesClient,
                "description" => "Envoyé au client le jour même de son arrivée.",
                "defaut" => "Bonjour {client_name},\n\n"
                    . "Votre appartement vous attend aujourd'hui.\n\n"
                    . "🏠 {apartment_name}\n"
                    . "📍 {address}\n"
                    . "🕐 À partir de {check_in_time}\n"
                    . "💰 Reste à régler : {balance} MAD\n\n"
                    . "{checkin_instructions}\n\n"
                    . "Bon séjour ! {contact}",
            ],
            [
                "code" => "rappel-jour-j-agent", "message_name" => "Rappel jour d'arrivée (agent)",
                "categorie" => "rappels", "variables" => $variablesAgent,
                "description" => "Prévient l'agent responsable le jour de l'arrivée.",
                "defaut" => "📋 Arrivée aujourd'hui\n\n"
                    . "👤 {client_name} — {client_phone}\n"
                    . "🏠 {apartment_name}\n"
                    . "🕐 {check_in_time}\n"
                    . "💰 À encaisser : {balance} MAD\n"
                    . "🔐 Caution : {deposit} MAD\n"
                    . "📝 {notes}",
            ],
            [
                "code" => "post-sejour-client", "message_name" => "Message après le séjour",
                "categorie" => "rappels", "variables" => $variablesClient,
                "description" => "Envoyé au client après son départ, une fois le séjour clôturé.",
                "defaut" => "Bonjour {client_name},\n\n"
                    . "Merci d'avoir séjourné à {apartment_name}.\n\n"
                    . "Nous espérons que tout s'est bien passé. "
                    . "Votre avis nous aide à progresser : n'hésitez pas à nous "
                    . "écrire.\n\n"
                    . "Au plaisir de vous accueillir à nouveau.\n{contact}",
            ],
        ];
    }
}
