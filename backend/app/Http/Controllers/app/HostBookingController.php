<?php

namespace App\Http\Controllers\app;

use App\Http\Controllers\Controller;
use App\Http\Resources\AppResources\HostBookingResource;
use App\Http\Resources\PaginationResource;
use App\Mail\ReservationMail;
use App\Models\Booking;
use App\Models\BookingStatus;
use App\Models\HostReview;
use App\utils\JsonResponses;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Mail;
use Illuminate\Support\Facades\Validator;

class HostBookingController extends Controller
{
    use JsonResponses;

    public function index(Request $request)
    {
        $user = $request->user();
        if ($user->type->code != "host") {
            return $this->jsonResponse(false, "not-host", 403, null);
        }
        $bookings = Booking::whereHas("realestate", function ($query) use ($user) {
            $query->where("host_id", "=", $user->id);
        })->when($request->filled("status"), function ($query) use ($request) {
            $query->whereHas("status", function ($query) use ($request) {
                $query->where("code", "=", $request->input("status"));
            });
        })->with(['realestate', 'status', 'clientReview', 'paymentMethod', 'client', 'hostReview'])
            ->orderBy("created_at", 'desc')
            ->paginate($request->input("perPage", 10), ['*'], 'page', $request->input("page", 1));

        $response = new PaginationResource(HostBookingResource::collection($bookings));
        return $this->jsonResponse(true, self::SUCCESS, 200, $response);
    }


    public function rejectBooking(Request $request, $id)
    {
        $user = $request->user();
        $booking = Booking::where("id", "=", $id)
            ->whereHas("realestate", function ($query) use ($user) {
                $query->where("host_id", "=", $user->id);
            })->whereHas("status", function ($query) {
                $query->where("code", "=", "pending");
            })->first();
        if (!$booking) {
            return $this->jsonResponse(false, self::NOT_FOUND, 404, null);
        }
        $status = BookingStatus::where("code", "=", "rejected")->first();
        $booking->status_id = $status->id;
        $booking->save();
        $response = new HostBookingResource($booking);

        //send email to client
        Mail::to($booking->client->email)->send(new ReservationMail(
            title: "Réservation refusée",
            subtitle: "Nous sommes désolés de vous informer que l'hôte a refusé votre demande de réservation pour {$booking->realestate->title}. Nous vous encourageons à explorer d'autres propriétés disponibles.",
            checkin: $booking->checkin,
            checkout: $booking->checkout,
            guest: $booking->nb_guest,
            amount: $booking->amount . " MAD",
            subject: "Demande de réservation refusée - {$booking->realestate->title}"
        ));


        return $this->jsonResponse(true, self::SUCCESS, 200, $response);
    }

    public function confirmBooking(Request $request, $id)
    {
        $user = $request->user();
        $booking = Booking::where("id", "=", $id)
            ->whereHas("realestate", function ($query) use ($user) {
                $query->where("host_id", "=", $user->id);
            })->whereHas("status", function ($query) {
                $query->where("code", "=", "pending");
            })->first();
        if (!$booking) {
            return $this->jsonResponse(false, self::NOT_FOUND, 404, null);
        }
        $status = BookingStatus::where("code", "=", "confirmed")->first();
        $booking->status_id = $status->id;
        $booking->save();
        $response = new HostBookingResource($booking);


        //==========send email to client
        Mail::to($booking->client->email)->send(new ReservationMail(
            title: "Réservation confirmée !",
            subtitle: "Bonne nouvelle ! L'hôte a confirmé votre réservation pour {$booking->realestate->title}. Veuillez procéder au paiement pour finaliser votre réservation.",
            checkin: $booking->checkin,
            checkout: $booking->checkout,
            guest: $booking->nb_guest,
            amount: $booking->amount . " MAD",
            subject: "Votre réservation a été confirmée - Paiement requis"
        ));



        return $this->jsonResponse(true, self::SUCCESS, 200, $response);
    }


    public function rateBooking(Request $request, $id)
    {
        $user = $request->user();
        $booking = Booking::where("id", "=", $id)
            ->whereHas("realestate", function ($query) use ($user) {
                $query->where("host_id", "=", $user->id);
            })->first();
        if (!$booking->is_ratable) {
            return $this->jsonResponse(false, "you-can-rate-after-checkout", 403, null);
        }
        $validator = Validator::make($request->all(), [
            "comment" => ['required', 'max:200'],
            "observanceHouseRules" => ['required', 'integer', 'gt:0', 'lte:5'],
            "communication" => ['required', 'integer', 'gt:0', 'lte:5'],
            "cleanliness" => ['required', 'integer', 'gt:0', 'lte:5'],
        ]);
        if ($validator->fails()) {
            return $this->jsonResponse(true, self::VALIDATION_ERROR, 422, $validator->errors());
        }
        //create review
        $rate = ($request->input("observanceHouseRules") + $request->input("communication") + $request->input("cleanliness")) / 3;

        $data = $validator->validated();
        $data["rate"] = $rate;
        $data["host_id"] = $user->id;
        $data["observance_house_rules"] = $data["observanceHouseRules"];
        $hostReview = HostReview::create($data);
        //update booking
        $booking->host_review_id = $hostReview->id;
        $booking->save();
        //update client rate
        $client = $booking->client;
        $total = $client->rate * $client->nb_raters;
        $total += $rate;
        $newRate = $total / ($client->nb_raters + 1);
        $client->rate = $newRate;
        $client->nb_raters = $client->nb_raters + 1;
        $client->save();
        //return response
        $response = new HostBookingResource($booking);
        return $this->jsonResponse(true, self::SUCCESS, 200, $response);
    }
}
