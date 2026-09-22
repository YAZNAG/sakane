<?php

namespace App\Http\Resources\DashboardResource;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class ReclamationResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        
        return [
            'id'          => $this->id,
            'note'        => $this->note,
            'status'      => $this->status,
            'realestateId'=> $this->realestate_id,
            'realestate'  => $this->whenLoaded('realestate', fn() => [
                'id'    => $this->realestate->id,
                'title' => $this->realestate->title,
            ]),
            'images'      => $this->getMedia('images')->map(fn($item) => [
                'id'  => $item->id,
                'url' => $item->original_url,
            ]),
            'signaledBy'  => $this->whenLoaded('manager', fn() => [
                'id'   => $this->manager?->id,
                'name' => trim(($this->manager?->first_name ?? '') . ' ' . ($this->manager?->last_name ?? '')),
            ]),
            'createdAt'   => $this->created_at?->toISOString(),
        ];
    }
}
