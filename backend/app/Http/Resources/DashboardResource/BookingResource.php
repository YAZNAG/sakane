<?php

namespace App\Http\Resources\DashboardResource;

use App\Http\Resources\AppResources\BookingStatusResource;
use App\Http\Resources\AppResources\ClientProfileResource;
use App\Http\Resources\AppResources\ClientReviewResource;
use App\Http\Resources\AppResources\HostReviewResource;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class BookingResource extends JsonResource
{

    public function toArray(Request $request): array
    {
        return [
            "id" => $this->id,
            "amount" => $this->amount,
            "checkin" => $this->checkin,
            "checkout" => $this->checkout,
            "heureArrivee" => \App\Services\HeuresSejour::convenue($this, "arrivee")
                ? \App\Services\HeuresSejour::arrivee($this) : null,
            "heureDepart" => \App\Services\HeuresSejour::convenue($this, "depart")
                ? \App\Services\HeuresSejour::depart($this) : null,
            "nbGuest" => $this->nb_guest,
            "isRatable" => $this->is_ratable,
            "nightPrice" => $this->night_price,
            "client" => new ClientProfileResource($this->whenLoaded("client")),
            "realestate" => new RealestateResource($this->whenLoaded("realestate")),
            "status" => new BookingStatusResource($this->whenLoaded("status")),
            "clientReview" => new ClientReviewResource($this->whenLoaded("clientReview")),
            "myReview" => new HostReviewResource($this->whenLoaded("hostReview")),
            // L'agent qui a enregistre la reservation.
            "creePar" => $this->manager
                ? trim(($this->manager->first_name ?? "") . " " . ($this->manager->last_name ?? ""))
                : null,
            // La liste montre « Appliquer la facture » ou, une fois appliquee, « Facture ».
            "factureAppliquee" => \Illuminate\Support\Facades\DB::table("factures")->where("booking_id", $this->id)->whereNotNull("appliquee_le")->exists(),
            "privateContract" => $this->getFirstMediaUrl("contract-private"),
            "publicContract" => $this->getFirstMediaUrl("contract-public"),
            // Etat des rappels : a envoyer, envoye ou echec.
            "rappels" => \App\Models\RappelEnvoye::with("rappel")
                ->where("booking_id", $this->id)
                ->get()
                ->map(fn($r) => [
                    "rappel"       => $r->rappel?->libelle,
                    "destinataire" => $r->destinataire,
                    "statut"       => $r->statut,
                    "erreur"       => $r->erreur,
                    "envoyeA"      => $r->envoye_a?->toISOString(),
                ]),
        ];
    }
}
