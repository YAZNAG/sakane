<?php

namespace App\Http\Resources\DashboardResource;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class ManagerResource extends JsonResource
{
    private $token;

    public function withToken($token)
    {
        $this->token = $token;
        return $this;
    }
    public function toArray(Request $request): array
    {
        return [
            "id" => $this->id,
            "firstName" => $this->first_name,
            "lastName" => $this->last_name,
            "email" => $this->email,
            "phone" => $this->phone,
            "token" => $this->token,
            "roles" => $this->getRoleNames(),
            "permissions" => $this->getAllPermissions()->map(fn($p) => $p->name)
        ];
    }
}
