<?php

namespace App\Http\Resources\DashboardResource;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class ClientResource extends JsonResource
{

    public function toArray(Request $request): array
    {
        return [
            "id" => $this->id,
            "firstName" => $this->first_name,
            "lastName" => $this->last_name,
            "firstNameAr" => $this->first_name_ar,
            "lastNameAr" => $this->last_name_ar,
            "email" => $this->email,
            "tel" => $this->tel,
            "acceptePromotions" => (bool) ($this->accepte_promotions ?? true),
            "identityNumber" => $this->identity_number,
            "nationalite" => $this->nationalite,
            // Liste noire : plus de nouvelle reservation pour ce client.
            "listeNoire" => $this->liste_noire_le ? [
                "le"    => \Carbon\Carbon::parse($this->liste_noire_le)->toISOString(),
                "motif" => $this->liste_noire_motif,
                "par"   => optional(\App\Models\Manager::find($this->liste_noire_par),
                    fn($m) => trim(($m->first_name ?? "") . " " . ($m->last_name ?? ""))),
            ] : null,
            "type" => $this->type->code,
            "documentsProvided" => isset($this->documents) ? explode(";", $this->documents) : null,
            "profile" => $this->getFirstMediaUrl('profile_photo'),
            "bookings" => BookingResource::collection($this->whenLoaded("bookings")),
            "documents" => $this->getMedia("documents")->map(function ($item) {
                return [
                    "id" => $item["id"],
                    "url" => $item["original_url"]
                ];
            })
        ];
    }
}
