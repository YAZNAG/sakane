<?php

namespace App\Http\Resources\AppResources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class ClientReviewResource extends JsonResource
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
            "rate" => $this->rate,
            "comment" => $this->comment,
            "cleanliness" => $this->cleanliness,
            "accuracy" => $this->accuracy,
            "location" => $this->location,
            "communication" => $this->communication,
            "client" => ClientProfileResource::make($this->whenLoaded('client'))
        ];
    }
}
