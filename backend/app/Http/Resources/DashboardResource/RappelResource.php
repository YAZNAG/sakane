<?php

namespace App\Http\Resources\DashboardResource;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class RappelResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            "id"             => $this->id,
            "code"           => $this->code,
            "libelle"        => $this->libelle,
            "moment"         => $this->moment,
            "decalageHeures" => $this->decalage_heures,
            "delaiLisible"   => $this->delaiLisible(),
            "versClient"     => (bool) $this->vers_client,
            "versAgent"      => (bool) $this->vers_agent,
            "modeleClient"   => $this->modele_client,
            "modeleAgent"    => $this->modele_agent,
            "actif"          => (bool) $this->actif,
            "ordre"          => $this->ordre,
        ];
    }
}
