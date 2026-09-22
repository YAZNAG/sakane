<?php

namespace App\Services;

use Carbon\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * L'etat d'un appartement aujourd'hui, pour l'afficher en tete des
 * calendriers : desactive, occupe (reservation de l'agence ou d'Airbnb),
 * a nettoyer, en nettoyage, ou disponible.
 */
class EtatBien
{
    public static function pour($bien): array
    {
        $aujourdhui = today()->toDateString();

        if (!empty($bien->desactive_le)) {
            return ["code" => "desactive", "libelle" => "Désactivé", "detail" => "Depuis le " . Carbon::parse($bien->desactive_le)->format("d/m/Y")];
        }

        $sejour = DB::table("bookings")->join("booking_statuses", "booking_statuses.id", "=", "bookings.status_id")
            ->where("bookings.realestate_id", $bien->id)->whereNull("bookings.deleted_at")
            ->where("booking_statuses.code", "<>", "rejected")
            ->where("bookings.checkin", "<=", $aujourdhui)->where("bookings.checkout", ">", $aujourdhui)
            ->orderBy("bookings.checkin")->first(["bookings.checkout", "bookings.airbnb_uid"]);
        if ($sejour) {
            return ["code" => "occupe", "libelle" => !empty($sejour->airbnb_uid) ? "Occupé (Airbnb)" : "Occupé",
                "detail" => "Jusqu'au " . Carbon::parse($sejour->checkout)->format("d/m/Y")];
        }

        if (Schema::hasTable("airbnb_sejours")) {
            $airbnb = DB::table("airbnb_sejours")->where("realestate_id", $bien->id)->where("type", "reservation")
                ->whereNull("booking_id")->where("du", "<=", $aujourdhui)->where("au", ">", $aujourdhui)->first();
            if ($airbnb) {
                return ["code" => "occupe_airbnb", "libelle" => "Réservé sur Airbnb", "detail" => "Jusqu'au " . Carbon::parse($airbnb->au)->format("d/m/Y")];
            }
        }

        $debut = $bien->cleaning_started_at ?? null;
        $fin = $bien->cleaning_finished_at ?? null;
        if ($debut && (!$fin || Carbon::parse($fin)->lt(Carbon::parse($debut)))) {
            return ["code" => "nettoyage", "libelle" => "Nettoyage en cours", "detail" => "Commencé à " . Carbon::parse($debut)->format("H:i")];
        }
        if (($bien->cleaning_status ?? null) === "to_clean") {
            return ["code" => "a_nettoyer", "libelle" => "À nettoyer", "detail" => null];
        }

        $prochaine = DB::table("bookings")->join("booking_statuses", "booking_statuses.id", "=", "bookings.status_id")
            ->where("bookings.realestate_id", $bien->id)->whereNull("bookings.deleted_at")
            ->where("booking_statuses.code", "<>", "rejected")->where("bookings.checkin", ">", $aujourdhui)
            ->min("bookings.checkin");
        return ["code" => "disponible", "libelle" => "Disponible",
            "detail" => $prochaine ? "Prochaine arrivée le " . Carbon::parse($prochaine)->format("d/m/Y") : null];
    }
}
