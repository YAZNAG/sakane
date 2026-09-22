<?php

namespace App\Services;

use App\Models\User;
use Illuminate\Support\Collection;

/**
 * Construit la liste des clients vises par une campagne.
 *
 * Sont systematiquement ecartes : les clients sans numero de telephone
 * et ceux qui ont refuse les messages promotionnels.
 */
class SelectionClients
{
    /** Segments proposes au gerant. */
    public const SEGMENTS = [
        "tous"            => "Tous les clients",
        "avec_reservation" => "Clients ayant déjà réservé",
        "sans_reservation" => "Clients n'ayant jamais réservé",
        "par_bien"        => "Clients ayant séjourné dans un bien",
        "par_periode"     => "Clients ayant réservé sur une période",
        "en_sejour"       => "Clients actuellement en séjour",
        "selection"       => "Sélection manuelle",
    ];

    /**
     * @param array $segment ["type" => ..., "realestate" => ..., "du" => ...,
     *                        "au" => ..., "clients" => [ids]]
     */
    public function construire(array $segment): Collection
    {
        $type = $segment["type"] ?? "tous";

        $requete = User::query()
            ->whereHas("type", function ($q) {
                $q->where("code", "=", "client");
            })
            ->where("from_platform", "=", "0")
            ->whereNotNull("tel")
            ->where("tel", "!=", "")
            // Respect du refus : ces clients ne sont jamais sollicites.
            ->where("accepte_promotions", "=", 1);

        switch ($type) {
            case "avec_reservation":
                $requete->whereHas("bookings");
                break;

            case "sans_reservation":
                $requete->whereDoesntHave("bookings");
                break;

            case "par_bien":
                $bien = $segment["realestate"] ?? null;
                $requete->whereHas("bookings", function ($q) use ($bien) {
                    $q->where("realestate_id", "=", $bien);
                });
                break;

            case "par_periode":
                $du = $segment["du"] ?? null;
                $au = $segment["au"] ?? null;
                $requete->whereHas("bookings", function ($q) use ($du, $au) {
                    if ($du) $q->whereDate("checkin", ">=", $du);
                    if ($au) $q->whereDate("checkin", "<=", $au);
                });
                break;

            case "en_sejour":
                $requete->whereHas("bookings", function ($q) {
                    $q->whereDate("checkin", "<=", today())
                        ->whereDate("checkout", ">=", today());
                });
                break;

            case "selection":
                $requete->whereIn("id", $segment["clients"] ?? []);
                break;
        }

        $clients = $requete->orderBy("first_name")->get();

        // Un numero incomplet ne part pas : ecrire a un inconnu serait pire
        // qu'un destinataire manquant. Deux fiches partageant le meme
        // numero ne recoivent qu'un seul message.
        return $clients
            ->filter(fn($c) => static::normaliserTelephone($c->tel) !== '')
            ->unique(fn($c) => static::normaliserTelephone($c->tel))
            ->values();
    }

    /** Format attendu par la passerelle : indicatif pays compris. */
    public static function normaliserTelephone(?string $tel): string
    {
        return Telephone::international($tel);
    }
}
