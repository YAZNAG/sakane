<?php

namespace App\Services;

use App\Models\Booking;
use Carbon\Carbon;

/**
 * Les lignes d'un export de reservations.
 *
 * Excel et PDF partent des memes donnees : elles sont montees ici une
 * seule fois, pour que les deux fichiers ne puissent pas diverger.
 */
class ReservationsExportees
{
    public const COLONNES = [
        "N\u{B0}", "Bien", "Client", "T\u{E9}l\u{E9}phone", "Arriv\u{E9}e", "D\u{E9}part",
        "Nuits", "Invit\u{E9}s", "Type d'invit\u{E9}", "Statut",
        "Montant (MAD)", "Paiement (MAD)", "Reste (MAD)", "Caution (MAD)", "Cr\u{E9}\u{E9}e le",
    ];

    /**
     * @param int[] $biens    identifiants de biens ; vide = aucun filtre
     * @param int[] $clients  identifiants de clients ; vide = aucun filtre
     */
    public static function lignes(
        array $biens = [],
        array $clients = [],
        ?string $du = null,
        ?string $au = null,
        ?array $biensAutorises = null
    ): array {
        return static::requete($biens, $clients, $du, $au, $biensAutorises)
            ->get()
            ->map(fn($b) => static::ligne($b))
            ->all();
    }

    public static function requete(
        array $biens = [],
        array $clients = [],
        ?string $du = null,
        ?string $au = null,
        ?array $biensAutorises = null
    ) {
        $query = Booking::with(["client", "realestate", "status"])
            ->orderByDesc("checkin");

        if (!empty($biens)) {
            $query->whereIn("realestate_id", $biens);
        }
        if (!empty($clients)) {
            $query->whereIn("client_id", $clients);
        }

        // Un agent n'exporte que les dossiers qui lui sont confies.
        if ($biensAutorises !== null) {
            $query->whereIn("realestate_id", function ($sous) use ($biensAutorises) {
                $sous->select("id")->from("realstates")->whereIn("dossier_id", $biensAutorises);
            });
        }

        if ($du) {
            $query->whereDate("checkin", ">=", Carbon::parse($du)->toDateString());
        }
        if ($au) {
            $query->whereDate("checkin", "<=", Carbon::parse($au)->toDateString());
        }

        return $query;
    }

    private static function ligne(Booking $b): array
    {
        $montant = (float) ($b->amount ?? 0);
        $avance  = (float) ($b->avance ?? 0);

        return [
            $b->id,
            $b->realestate->title ?? "-",
            trim(($b->client->first_name ?? "") . " " . ($b->client->last_name ?? "")) ?: "-",
            Telephone::local($b->client->tel ?? ""),
            static::date($b->checkin),
            static::date($b->checkout),
            $b->nb_days ?? 0,
            $b->nb_guest ?? 0,
            TypesInvites::libelle($b->type_guest),
            $b->status->name ?? "-",
            round($montant, 2),
            round($avance, 2),
            round(max(0, $montant - $avance), 2),
            round((float) ($b->caution ?? 0), 2),
            static::date($b->created_at),
        ];
    }

    /**
     * Le modele ne convertit pas toutes ces colonnes : selon le chemin
     * on recoit un objet date ou une chaine. On accepte les deux.
     */
    private static function date($valeur): string
    {
        if (empty($valeur)) {
            return "";
        }
        try {
            return $valeur instanceof \DateTimeInterface
                ? Carbon::instance($valeur)->format("d/m/Y")
                : Carbon::parse((string) $valeur)->format("d/m/Y");
        } catch (\Throwable $e) {
            return (string) $valeur;
        }
    }

    /** Totaux des colonnes monetaires, pour la derniere ligne. */
    public static function totaux(array $lignes): array
    {
        $somme = fn(int $i) => array_sum(array_map(fn($l) => (float) $l[$i], $lignes));

        return [
            "TOTAL", "", "", "", "", "",
            array_sum(array_map(fn($l) => (int) $l[6], $lignes)),
            array_sum(array_map(fn($l) => (int) $l[7], $lignes)),
            "", "",
            round($somme(10), 2),
            round($somme(11), 2),
            round($somme(12), 2),
            round($somme(13), 2),
            "",
        ];
    }
}
