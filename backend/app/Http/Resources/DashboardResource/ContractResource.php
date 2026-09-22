<?php

namespace App\Http\Resources\DashboardResource;

use App\Http\Resources\AppResources\ClientProfileResource;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class ContractResource extends JsonResource
{
    /**
     * Transform the resource into an array.
     *
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        $documents = [];
        foreach ($this->getMedia('documents') as $key => $media) {
            $documents[] = [
                "id" => $media->id,
                "url" => $media["original_url"]
            ];
        }
        return [
            "id" => $this->id,
            "signed_date" => $this->signed_date,
            "expiration_date" => $this->expiration_date,
            "note" => $this->note,
            "owner" => new OwnerResource($this->owner),
            "client" => new ClientProfileResource($this->client),
            "realestate" => new RealestateResource($this->realestate),
            "documents" => $documents
        ];
    }
}
