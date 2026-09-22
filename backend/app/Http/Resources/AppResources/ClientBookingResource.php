<?php

namespace App\Http\Resources\AppResources;

use App\Models\HostReview;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class ClientBookingResource extends JsonResource
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
            "realestate" => new RealestateResource($this->realestate),
            "status" => new BookingStatusResource($this->status),
            "myRate" => new ClientReviewResource($this->clientReview),
            "hostRate" => new HostReviewResource($this->hostReview),
        ];
    }
}
