<?php

namespace App\Http\Resources\DashboardResource;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class OwnerResource extends JsonResource
{
    /**
     * Transform the resource into an array.
     *
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        return [
            "id" => $this->id,
            "name" => $this->name,
            "email" => $this->email,
            "tel" => $this->tel,
            "rib" => $this->rib,
            "address" => $this->address,
            "contrats" => \App\Models\ContratProprietaire::with(["bien", "auteur"])
                ->where("owner_id", $this->id)
                ->orderByDesc("created_at")
                ->get()
                ->map(fn($c) => $c->versTableau())
                ->values(),
            "realestates" => RealestateResource::collection($this->whenLoaded("realestates"))
        ];
    }
}
