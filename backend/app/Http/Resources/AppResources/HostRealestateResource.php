<?php

namespace App\Http\Resources\AppResources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class HostRealestateResource extends JsonResource
{



    public function toArray(Request $request): array
    {
        $images = [];
        foreach ($this->getMedia('images') as $key => $media) {
            $images[] = [
                "id" => $media->id,
                "url" => $media["original_url"]
            ];
        }

        return [
            "id" => $this->id,
            "title" => $this->title,
            "description" => $this->description,
            "surface" => $this->surface,
            "price" => $this->price,
            "dateConstruction" => $this->date_construction,
            "nbEtages" => $this->nb_etage,
            "nbRooms" => $this->nb_rooms,
            "etage" => $this->etage,
            "tour360Url" => $this->tour_360_url,
            "nbBathroom" => $this->nb_bathroom,
            "rate" => $this->rate,
            "rateCount" => $this->nb_raters,
            "address" => [
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
            ],
            "location" => [
                "latitude" => $this->latitude,
                "longitude" => $this->longitude
            ],
            "category" => [
                "name" => $this->category->category,
                "value" => $this->category->code,
            ],
            "typeTransaction" => [
                "name" => $this->type->type,
                "value" => $this->type->code,
            ],
            "status" => [
                "name" => $this->status->status,
                "value" => $this->status->code,
            ],
            "reviewStatus" => [
                "name" => $this->reviewStatus->status,
                "value" => $this->reviewStatus->code,
            ],
            "etat" => [
                "name" => $this->etat->etat,
                "value" => $this->etat->code,
            ],
            "features" => FeatureResource::collection($this->features),
            "media" =>  $images,
        ];
    }
}
