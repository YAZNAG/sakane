<?php

namespace App\Http\Resources\AppResources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class HostBookingResource extends JsonResource
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
            "amount" => $this->amount,
            "checkin" => $this->checkin,
            "checkout" => $this->checkout,
            "nbGuest" => $this->nb_guest,
            "isRatable" => $this->is_ratable,
            "client" => new ClientProfileResource($this->client),
            "realestate" => new HostRealestateResource($this->realestate),
            "status" => new BookingStatusResource($this->status),
            "clientRate" => new ClientReviewResource($this->clientReview),
            "myRate" => new HostReviewResource($this->hostReview),
        ];
    }
}
