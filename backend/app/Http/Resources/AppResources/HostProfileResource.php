<?php

namespace App\Http\Resources\AppResources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class HostProfileResource extends JsonResource
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
            "rate" => $this->host_rate,
            "nbRates" => $this->host_nb_raters,
            "type"=>"host",
            "profile" => $this->getFirstMediaUrl('profile_photo'),
            "isEmailVerified" => $this->is_email_verified,
            "isIdentityVerified" => $this->is_identity_verified,
        ];
    }
}
