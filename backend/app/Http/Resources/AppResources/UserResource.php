<?php

namespace App\Http\Resources\AppResources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class UserResource extends JsonResource
{

    private ?string $token;

    public  function __construct($resource, $token)
    {
        parent::__construct($resource);
        $this->token = $token;
    }




    public function toArray(Request $request): array
    {
        $data = [
            "id" => $this->id,
            "firstName" => $this->first_name,
            "lastName" => $this->last_name,
            "email" => $this->email,
            "tel" => $this->tel,
            "type" => $this->type->code,
            "profile" => $this->getFirstMediaUrl('profile_photo'),
            "isEmailVerified" => $this->is_email_verified,
            "address" => $this->city != null
                ? [
                    "address" => $this?->address,
                    "city" => [
                        "id" => $this?->city?->id,
                        "name" => $this?->city?->name,
                        "region" => [
                            "id" => $this?->city?->region?->id,
                            "name" => $this?->city?->region?->name,
                            "country" => [
                                "id" => $this?->city?->region?->country?->id,
                                "name" => $this?->city?->region?->country?->name,
                            ]
                        ]
                    ]
                ]
                : null
        ];
        if ($this->token) {
            $data["accessToken"] = $this->token;
        }
        if ($this->type->code = "host") {
            $data["identityStatus"] = $this->identity_status;
            $data["rib"] = $this->rib;
        }

        return $data;
    }
}
