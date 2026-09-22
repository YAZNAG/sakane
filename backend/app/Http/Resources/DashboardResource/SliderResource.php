<?php

namespace App\Http\Resources\DashboardResource;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class SliderResource extends JsonResource
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
            "isActive" => $this->is_active,
            "images" => $this->getMedia("images")->collect()->map(function ($media) {
                return [
                    "id" => $media->id,
                    "url" => $media->original_url
                ];
            })
        ];
    }
}
