<?php

namespace App\Http\Resources\AppResources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class ClientProfileResource extends JsonResource
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
            "firstName" => $this->first_name,
            "lastName" => $this->last_name,
            "rate" => $this->rate,
            "nbRates" => $this->nb_raters,
            "type" => "client",
            "isEmailVerified" => $this->is_email_verified,
            "profile" => $this->getFirstMediaUrl('profile_photo'),
        ];
    }
}
