<?php

namespace App\Services;

/**
 * Types d'invites d'une reservation.
 *
 * La base stocke des codes anglais - c'est un enum, on n'y touche pas.
 * Ce qui s'affiche, en revanche, doit parler a l'agent comme au client :
 * le francais, puis l'arabe entre parentheses.
 */
class TypesInvites
{
    private const LIBELLES = [
        "Males"                  => ["Hommes", "\u{631}\u{62C}\u{627}\u{644}"],
        "Females"                => ["Femmes", "\u{646}\u{633}\u{627}\u{621}"],
        "Family"                 => ["Famille", "\u{639}\u{627}\u{626}\u{644}\u{629}"],
        "Professional visitors"  => ["Visiteurs professionnels", "\u{632}\u{648}\u{627}\u{631} \u{645}\u{647}\u{646}\u{64A}\u{648}\u{646}"],
    ];

    /** Les codes tels que la base les attend. */
    public static function codes(): array
    {
        return array_keys(self::LIBELLES);
    }

    /** "Hommes (رجال)" ; le code inconnu se rend tel quel. */
    public static function libelle(?string $code): string
    {
        if ($code === null || $code === "") {
            return "";
        }
        if (!isset(self::LIBELLES[$code])) {
            return $code;
        }
        [$fr, $ar] = self::LIBELLES[$code];
        return $fr . " (" . $ar . ")";
    }

    /** Le francais seul, pour les colonnes etroites. */
    public static function francais(?string $code): string
    {
        if ($code === null || $code === "" || !isset(self::LIBELLES[$code])) {
            return $code ?? "";
        }
        return self::LIBELLES[$code][0];
    }

    /** Liste destinee aux applications : code, francais, arabe, libelle. */
    public static function liste(): array
    {
        $sortie = [];
        foreach (self::LIBELLES as $code => [$fr, $ar]) {
            $sortie[] = [
                "code"     => $code,
                "francais" => $fr,
                "arabe"    => $ar,
                "libelle"  => $fr . " (" . $ar . ")",
            ];
        }
        return $sortie;
    }
}
