<?php

namespace App\Http\Resources\AppResources;

use App\Models\Booking;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class TransactionResource extends JsonResource
{
    /**
     * Transform the resource into an array.
     *
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        $data = [
            "id" => $this->id,
            "amount" => $this->amount,
            "details" => $this->details,
            "operationType" => [
                "type" => $this->operation->type,
                "code" => $this->operation->code,
            ]
        ];
        $document = $this->getMedia("document")->first();
        $data["document"] =  $document?->original_url;
        if ($this->is_commission) {
            $data["booking"] = [
                "checkin" => $this->booking->checkin,
                "checkout" => $this->booking->checkout,
                "nbGuest" => $this->booking->nb_guest,
                "amount" => $this->booking->amount,
                "realestate" => new RealestateResource($this->booking->realestate)
            ];
        } else {
            $data["booking"] = new HostBookingResource($this->booking);
        }
        return $data;
    }
}
