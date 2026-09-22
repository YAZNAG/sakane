<?php

namespace App\Services;

/**
 * Met les numeros de telephone au format attendu par WhatsApp.
 *
 * Les numeros sont saisis comme on les ecrit au Maroc : "0612345678",
 * "07 12 34 56 78", "+212 612-345-678", parfois "00212612345678".
 * WhatsApp, lui, exige la forme internationale sans signe ni espace :
 * "212612345678".
 *
 * Le plan de numerotation marocain sert de reference : le numero
 * national compte neuf chiffres et commence par 5 (fixe), 6 ou 7
 * (mobile). Tout ce qui ne s'y conforme pas est refuse plutot que
 * corrige au juge : mieux vaut un envoi manquant qu'un message adresse
 * a un inconnu.
 */
class Telephone
{
    /** Indicatif du Maroc. */
    private const INDICATIF = '212';

    /** Longueur du numero national, indicatif exclu. */
    private const LONGUEUR_NATIONALE = 9;

    /** Premiers chiffres admis : fixe, mobile, mobile. */
    private const PREFIXES = ['5', '6', '7'];

    /**
     * Renvoie le numero au format international, ou une chaine vide si
     * la saisie ne correspond a aucun numero marocain exploitable.
     */
    public static function international(?string $numero): string
    {
        $national = static::national($numero);

        if ($national !== '') {
            return self::INDICATIF . $national;
        }

        // Une clientele de location saisonniere est largement etrangere.
        // Un numero qui n'entre pas dans le plan marocain n'est pas pour
        // autant invalide : s'il a la longueur d'un numero international,
        // il part tel quel plutot que d'etre jete sans mot dire.
        return static::etranger($numero);
    }

    /** Forme lisible pour l'affichage : 0612345678. */
    public static function local(?string $numero): string
    {
        $national = static::national($numero);

        if ($national !== '') {
            return '0' . $national;
        }

        // Un numero etranger n'a pas de forme locale marocaine : on
        // l'affiche a l'international, avec son signe plus.
        $etranger = static::etranger($numero);
        if ($etranger !== '') {
            return '+' . $etranger;
        }

        // Une saisie non reconnue est rendue telle quelle : la corriger
        // silencieusement masquerait une donnee a verifier.
        return (string) $numero;
    }

    public static function estValide(?string $numero): bool
    {
        return static::international($numero) !== '';
    }

    /** Vrai lorsque le numero n'appartient pas au plan marocain. */
    public static function estEtranger(?string $numero): bool
    {
        return static::national($numero) === ''
            && static::etranger($numero) !== '';
    }

    /**
     * Extrait les neuf chiffres du numero national.
     *
     * Accepte indifferemment "0612345678", "612345678", "212612345678",
     * "+212612345678" et "00212612345678", espaces, points et tirets
     * compris.
     */
    private static function national(?string $numero): string
    {
        $chiffres = preg_replace('/[^0-9]/', '', (string) $numero);

        if ($chiffres === '') {
            return '';
        }

        // Code d'acces international compose ("00212...").
        if (str_starts_with($chiffres, '00')) {
            $chiffres = substr($chiffres, 2);
        }

        // L'indicatif peut apparaitre plusieurs fois lorsqu'un numero a
        // deja ete prefixe par erreur ("212212612345678").
        while (strlen($chiffres) > self::LONGUEUR_NATIONALE
            && str_starts_with($chiffres, self::INDICATIF)) {
            $chiffres = substr($chiffres, strlen(self::INDICATIF));
        }

        // Forme locale : un seul zero de tete, jamais davantage.
        if (str_starts_with($chiffres, '0')) {
            $chiffres = substr($chiffres, 1);

            // "0212612345678" : le zero precedait l'indicatif.
            while (strlen($chiffres) > self::LONGUEUR_NATIONALE
                && str_starts_with($chiffres, self::INDICATIF)) {
                $chiffres = substr($chiffres, strlen(self::INDICATIF));
            }
        }

        if (strlen($chiffres) !== self::LONGUEUR_NATIONALE) {
            return '';
        }

        if (!in_array($chiffres[0], self::PREFIXES, true)) {
            return '';
        }

        return $chiffres;
    }

    /**
     * Toutes les ecritures possibles d'un meme numero.
     *
     * La base a ete alimentee au fil des annees : on y trouve du
     * 0612345678, du 212612345678, du +212612345678. Chercher un
     * client par son numero, c'est chercher toutes ces formes.
     */
    public static function variantes(?string $numero): array
    {
        $local = self::local($numero);
        $international = self::international($numero);

        $formes = [
            $numero,
            $local,
            $international,
            "+" . $international,
            ltrim($local, "0"),
        ];

        return array_values(array_unique(array_filter(
            $formes,
            fn($f) => is_string($f) && $f !== ""
        )));
    }

    /** Longueurs admises par le plan de numerotation mondial (E.164). */
    private const LONGUEUR_INTERNATIONALE_MIN = 10;
    private const LONGUEUR_INTERNATIONALE_MAX = 15;

    /**
     * Numero etranger, indicatif pays compris et sans signe.
     *
     * On ne devine pas l'indicatif : un numero est retenu tel qu'il a
     * ete saisi, une fois retires les separateurs et le code d'acces
     * international. Rien n'est ajoute ni retranche, faute de quoi on
     * risquerait d'ecrire a quelqu'un d'autre.
     *
     * Chaine vide si la saisie n'a pas une longueur plausible.
     */
    private static function etranger(?string $numero): string
    {
        $chiffres = preg_replace('/[^0-9]/', '', (string) $numero);

        if ($chiffres === '') {
            return '';
        }

        // Code d'acces international compose ("0033...").
        if (str_starts_with($chiffres, '00')) {
            $chiffres = substr($chiffres, 2);
        }

        // Un numero commencant par un seul zero est une forme nationale :
        // sans savoir de quel pays, on ne peut pas la completer.
        if (str_starts_with($chiffres, '0')) {
            return '';
        }

        $longueur = strlen($chiffres);
        if ($longueur < self::LONGUEUR_INTERNATIONALE_MIN
            || $longueur > self::LONGUEUR_INTERNATIONALE_MAX) {
            return '';
        }

        // Un numero marocain mal forme ne doit pas passer par cette
        // porte : il serait envoye tel quel, donc a un inconnu.
        if (str_starts_with($chiffres, self::INDICATIF)) {
            return '';
        }

        return $chiffres;
    }
}
