<?php

namespace App\Http\Resources\AppResources;

use App\Models\Feature;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;
use Illuminate\Support\Arr;

class RealestateResource extends JsonResource
{
    protected bool $isFavorite = false;
    protected ?bool $isReservable = null;

    protected  $reservedDates = null;



    public function setIsFavorite($favorites)
    {
        $this->isFavorite = $favorites;
        return $this;
    }

    public function setIsReservable($isReservable)
    {
        $this->isReservable = $isReservable;
        return $this;
    }

    public function setReservedDates($reservedDates)
    {
        $this->reservedDates = $reservedDates;
        return $this;
    }
    public function toArray(Request $request): array
    {
        $images = [];
        foreach ($this->getMedia('images') as $key => $media) {
            $images[] = [
                "id" => $media->id,
                "url" => $media["original_url"]
            ];
        }
        $data = [
            "id" => $this->id,
            "title" => $this->title,
            "description" => $this->description,
            "isFavorite" => $this->isFavorite,
            "surface" => $this->surface,
            "price" => $this->price,
            "dateConstruction" => $this->date_construction,
            "nbEtages" => $this->nb_etage,
            "nbRooms" => $this->nb_rooms,
            "etage" => $this->etage,
            "nbBathroom" => $this->nb_bathroom,
            "rate" => $this->rate,
            "rateCount" => $this->nb_raters,
            "tour360Url" => $this->tour_360_url,
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
            "etat" => [
                "name" => $this->etat->etat,
                "code" => $this->etat->code,
            ],
            "host" => new HostProfileResource($this->host),
            "features" => FeatureResource::collection($this->features),
            "media" =>  $images,
        ];

        if ($this->isReservable !== null) {
            $data["isReservable"] = $this->isReservable;
        }
        if ($this->reservedDates !== null) {
            $data["reservedDates"] = $this->reservedDates;
        }

        return $data;
    }
}
