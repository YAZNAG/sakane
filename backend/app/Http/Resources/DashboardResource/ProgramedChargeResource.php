<?php

namespace App\Http\Resources\DashboardResource;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class ProgramedChargeResource extends JsonResource
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
            "nom" => $this->nom,
            "description" => $this->description,
            "amount" => $this->amount,
            "type" => $this->type,
            "month" => $this->month,
            "day" => $this->day,
            "dayName" => $this->day_name,
            "realestate" => new RealestateResource($this->whenLoaded("realestate"))
        ];
    }
}
