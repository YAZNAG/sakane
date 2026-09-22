<?php

namespace App\Http\Resources\AppResources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class EtatResource extends JsonResource
{
    /**
     * Transform the resource into an array.
     *
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        return [
            "name" => $this->etat,
            "value" => $this->code
        ];
    }
}
