<?php

namespace App\Http\Resources\DashboardResource;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class RapportResource extends JsonResource
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
            "name" => $this->name,
            "description" => $this->description,
            "date" => $this->date,
            "images" => $this->getMedia("images")->map(function ($item) {
                return [
                    "id" => $item["id"],
                    "url" => $item["original_url"]
                ];
            })
        ];
    }
}
