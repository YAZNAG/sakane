<?php

namespace App\Services;

use Illuminate\Support\Facades\DB;

/**
 * Heures d'arrivee et de depart d'un sejour.
 *
 * Celles convenues avec le client priment ; a defaut, les heures par
 * defaut reglees dans l'application, puis celles du fichier de reglages.
 */
class HeuresSejour
{
    private static ?array $reglages = null;

    public static function oublier(): void
    {
        static::$reglages = null;
    }

    private static function reglage(string $cle): ?string
    {
        if (static::$reglages === null) {
            try {
                static::$reglages = DB::table("reglages_agence")->whereIn("cle", ["heure_arrivee_defaut", "heure_depart_defaut"])->pluck("valeur", "cle")->all();
            } catch (\Throwable $e) {
                static::$reglages = [];
            }
        }
        $v = trim((string) (static::$reglages[$cle] ?? ""));
        return $v !== "" ? $v : null;
    }

    public static function defautArrivee(): string
    {
        return static::defaut(static::reglage("heure_arrivee_defaut") ?? config("agence.heure_checkin", "14h00"));
    }

    public static function defautDepart(): string
    {
        return static::defaut(static::reglage("heure_depart_defaut") ?? config("agence.heure_checkout", "12h00"));
    }

    public static function arrivee($booking): string
    {
        return static::formater($booking->heure_arrivee ?? null) ?: static::defautArrivee();
    }

    public static function depart($booking): string
    {
        return static::formater($booking->heure_depart ?? null) ?: static::defautDepart();
    }

    /** Vrai lorsque l'heure a ete saisie, et non deduite d'un usage. */
    public static function convenue($booking, string $quoi): bool
    {
        $valeur = $quoi === "arrivee" ? ($booking->heure_arrivee ?? null) : ($booking->heure_depart ?? null);
        return static::formater($valeur) !== "";
    }

    /** "14:30" a partir de ce que la base rend, quelle qu'en soit la forme. */
    private static function formater($valeur): string
    {
        if (empty($valeur)) {
            return "";
        }
        try {
            return $valeur instanceof \DateTimeInterface
                ? \Carbon\Carbon::instance($valeur)->format("H:i")
                : \Carbon\Carbon::parse((string) $valeur)->format("H:i");
        } catch (\Throwable $e) {
            return "";
        }
    }

    /** Les valeurs d'usage s'ecrivent "14h00" : on les uniformise. */
    private static function defaut(string $usage): string
    {
        return str_replace("h", ":", trim($usage));
    }
}
