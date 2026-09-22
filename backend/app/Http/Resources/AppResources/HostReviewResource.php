<?php

namespace App\Http\Resources\AppResources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class HostReviewResource extends JsonResource
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
            "communication" => $this->communication,
            "observanceHouseRules" => $this->observance_house_rules,
            "host" => HostProfileResource::make($this->whenLoaded("host"))
        ];
    }
}
