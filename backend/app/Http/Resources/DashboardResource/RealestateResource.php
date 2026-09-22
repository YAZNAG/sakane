<?php

namespace App\Http\Resources\DashboardResource;

use App\Http\Resources\AppResources\FeatureResource;
use App\Http\Resources\AppResources\HostProfileResource;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class RealestateResource extends JsonResource
{

    protected  $reservedDates = null;
    public function setReservedDates($reservedDates)
    {
        $this->reservedDates = $reservedDates;
        return $this;
    }

    public function toArray(Request $request): array
    {
        $images = [];
        foreach ($this->getMedia('images') as $key => $media) {
            // On sert la version allegee : l'original fait souvent plus d'1 Mo.
            // Si la conversion n'existe pas encore, on retombe sur l'original.
            $apercu = $media->hasGeneratedConversion('apercu')
                ? $media->getUrl('apercu')
                : $media["original_url"];
            $vignette = $media->hasGeneratedConversion('vignette')
                ? $media->getUrl('vignette')
                : $apercu;

            $images[] = [
                "id" => $media->id,
                "url" => $apercu,
                "thumbUrl" => $vignette,
                "urlOriginal" => $media["original_url"],
            ];
        }
        $data = [
            "id" => $this->id,
            "desactiveLe" => $this->desactive_le,
            // L'etat du jour : occupe, reserve sur Airbnb, a nettoyer, disponible...
            "statutJour" => \App\Services\EtatBien::pour($this->resource),
            "title" => $this->title,
            "description" => $this->description,
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
            "cleaningStatus"     => $this->cleaning_status,
            "checkoutAt"         => $this->checkout_at?->toISOString(),
            "cleaningStartedAt"  => $this->cleaning_started_at?->toISOString(),
            "cleaningFinishedAt" => $this->cleaning_finished_at?->toISOString(),
            "cleaningMinutes"    => $this->last_cleaning_minutes,
            "cleanedBy"          => $this->whenLoaded('cleaner', fn() => [
                'id'   => $this->cleaner?->id,
                'name' => trim(($this->cleaner?->first_name ?? '') . ' ' . ($this->cleaner?->last_name ?? '')),
            ]),
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
            "dossier" => $this->dossier ? [
                "id"  => $this->dossier->id,
                "nom" => $this->dossier->nom,
            ] : null,
            "secteur" => $this->secteur ? [
                "id"   => $this->secteur->id,
                "name" => $this->secteur->nom,
            ] : null,
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
            "status" => [
                "name" => $this->status->status,
                "value" => $this->status->code,
                "color" => $this->status->color
            ],
            "features" => FeatureResource::collection($this->features),
            "owner" => new OwnerResource($this->owner),
            "booking" => new BookingResource($this->whenLoaded("booking")),
            "hasTodayBookings" => ($this->todayBookings ?? 0) > 0,
            "media" =>  $images,
            "nextCheckin" => $this->nextCheckin
        ];

        if ($this->reservedDates !== null) {
            $data["reservedDates"] = $this->reservedDates;
        }

        return $data;
    }
}
