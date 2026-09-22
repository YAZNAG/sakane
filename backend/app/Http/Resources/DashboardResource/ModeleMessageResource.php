<?php

namespace App\Http\Resources\DashboardResource;

use App\Services\CatalogueModeles;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class ModeleMessageResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            "id"            => $this->id,
            "code"          => $this->code,
            "nom"           => $this->message_name,
            "description"   => $this->description,
            "categorie"     => $this->categorie ?? "general",
            "contenu"       => $this->message,
            "defaut"        => $this->defaut,
            "image"         => $this->imageUrl(),
            "variables"     => $this->variables ?? array_keys(CatalogueModeles::VARIABLES_COMMUNES),
            "langue"        => $this->langue ?? "fr",
            "actif"         => (bool) ($this->actif ?? true),
            "personnalise"  => $this->estPersonnalise(),
            "modifieLe"     => $this->updated_at?->toISOString(),
            "historique"    => $this->whenLoaded("historique", function () {
                return $this->historique->map(fn($h) => [
                    "id"            => $h->id,
                    "contenuAvant"  => $h->contenu_avant,
                    "contenuApres"  => $h->contenu_apres,
                    "auteur"        => $h->auteur
                        ? trim(($h->auteur->first_name ?? '') . ' ' . ($h->auteur->last_name ?? ''))
                        : null,
                    "date"          => $h->created_at?->toISOString(),
                ]);
            }),
        ];
    }
}
