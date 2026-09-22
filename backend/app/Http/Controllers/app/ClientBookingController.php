<?php

namespace App\Http\Controllers\app;

use App\Http\Controllers\Controller;
use App\Http\Resources\AppResources\BookingStatusResource;
use App\Http\Resources\AppResources\ClientBookingPaginationResource;
use App\Http\Resources\AppResources\ClientBookingResource;
use App\Http\Resources\AppResources\HostBookingResource;
use App\Http\Resources\PaginationResource;
use App\Mail\ReservationMail;
use App\Models\Booking;
use App\Models\BookingStatus;
use App\Models\ClientReview;
use App\Models\Realstate;
use App\Models\TypeBooking;
use Illuminate\Http\Request;
use App\utils\JsonResponses;
use Carbon\Carbon;
use GrahamCampbell\ResultType\Success;
use Illuminate\Support\Facades\Mail;
use Illuminate\Support\Facades\Validator;
use Stripe\PaymentIntent;
use Stripe\Stripe;

class ClientBookingController extends Controller
{

    use JsonResponses;


    public function clientBook(Request $request)
    {

        $validator = Validator::make($request->all(), [
            "checkin" => ["required", "date", "date_format:Y-m-d", "after:now"],
            "checkout" => ["required", "date", "after:checkin", "date_format:Y-m-d"],
            "guest" => ["required", "integer", "gt:0"],
            "realestate" => ["required", "exists:realstates,id"]
        ]);
        if ($validator->fails()) {
            return $this->jsonResponse(false, self::VALIDATION_ERROR, 422, $validator->errors());
        }

        //=============check the transaction type
        $isShort = Realstate::where("id", $request->input("realestate"))->whereHas("type", function ($query) {
            $query->where("code", "=", "rent-short");
        })->exists();
        if (!$isShort) {
            return $this->jsonResponse(false, "unrentable-real-estate", 422, null);
        }

        //=============check is the realstate is available at the given dates
        $checkin = Carbon::createFromFormat("Y-m-d", $request->input("checkin"));
        $checkout = Carbon::createFromFormat("Y-m-d", $request->input("checkout"));
        $busy = Booking::where("realestate_id", "=", $request->input("realestate"))
            ->where(
                function ($query) use ($checkin, $checkout) {
                    $query->where("checkin", "<", $checkout->format("Y-m-d"))
                        ->where("checkout", ">=", $checkin->format("Y-m-d"));
                }
            )->whereHas("status", function ($query) {
                $query->where("code", "=", "payed");
            })->exists();
        if ($busy) {
            return $this->jsonResponse(false, "booking-conflict", 409, null);
        }

        $realestate = Realstate::where("id", $request->input("realestate"))->first();

        //==============add booking
        $data = $validator->validate();
        $nbdays = $checkin->diffInDays($checkout);
        $data["nb_days"] = $nbdays;
        $data["nb_guest"] = $request->input("guest");
        $data["realestate_id"] = $request->input("realestate");
        $data["checkin"] = $checkin;
        $data["checkout"] = $checkout;
        $data["client_id"] = $request->user()->id;
        $data["status_id"] = BookingStatus::where("code", "=", "pending")->first()->id;
        $price = $realestate->price;
        $data["amount"] = $price * $nbdays;
        $data["price"] = $price;
        $type = TypeBooking::where("code", "=", "platform")->first();
        $data["type_id"] = $type->id;
        $booking = Booking::create($data)->fresh();
        //$booking->isRatable = now()->isAfter($checkout);
        $response = new ClientBookingResource($booking);
        //================send email to host
        $host = $realestate->host;

        Mail::to($host->email)->send(
            new ReservationMail(
                title: "Nouvelle demande de réservation",
                subtitle: "Vous avez reçu une nouvelle demande de réservation de {$request->user()->first_name } pour votre propriété {$realestate->name}.",
                checkin: $booking->checkin,
                checkout: $booking->checkout,
                guest: $booking->nb_guest,
                amount: $booking->amount . " MAD",
                subject: "Nouvelle demande de réservation - {$realestate->title}"
            )
        );



        return $this->jsonResponse(true, self::SUCCESS, 201, $response);
    }



    public function bookingStatus()
    {
        $status = BookingStatus::all();
        $response = BookingStatusResource::collection($status);
        return $this->jsonResponse(true, self::SUCCESS, 200, $response);
    }

    public function clientBookings(Request $request)
    {
        $user = $request->user();
        $bookings = Booking::where('client_id', '=', $user->id)
            ->with(['realestate', 'status', 'clientReview', 'paymentMethod', 'client', 'hostReview'])
            ->orderBy('created_at', 'desc');

        if ($request->has('status')) {
            $status = $request->input("status");
            $bookings = $bookings->whereHas('status', function ($query) use ($status) {
                $query->where('code', '=', $status);
            });
        }
        $bookings = $bookings->paginate($request->input("perPage", 10), ['*'], "bookings", $request->input('page', 1));
        $response = new PaginationResource(ClientBookingResource::collection($bookings));
        return $this->jsonResponse(true, self::SUCCESS, 200, $response);
    }

    public function clientBooking(Request $request, $id)
    {
        $user = $request->user();
        $booking = Booking::with('status')
            ->where('id', '=', $id)->where('client_id', '=', $user->id)->first();
        if (!$booking) {
            return $this->jsonResponse(false, "invalid-action", 422, null);
        }
        $response = new ClientBookingResource($booking);
        return $this->jsonResponse(true, self::SUCCESS, 200, $response);
    }

    public function clientRateBooking(Request $request, $id)
    {
        $user = $request->user();
        $booking = Booking::where("id", '=', $id)->where('client_id', '=', $user->id)->first();
        if (!$booking) {
            return $this->jsonResponse(false, self::NOT_FOUND, 404, null);
        }
        if (!$booking->is_ratable) {
            return $this->jsonResponse(false, "you-can-rate-after-checkout", 403, null);
        }
        $validator = Validator::make($request->all(), [
            "comment" => ['required', 'max:200'],
            "cleanliness" => ['required', 'integer', 'gt:0', 'lte:5'],
            "accuracy" => ['required', 'integer', 'gt:0', 'lte:5'],
            "communication" => ['required', 'integer', 'gt:0', 'lte:5'],
            "location" => ['required', 'integer', 'gt:0', 'lte:5'],
        ]);
        if ($validator->fails()) {
            return $this->jsonResponse(true, self::VALIDATION_ERROR, 422, $validator->errors());
        }
        $rate = ($request->input('cleanliness') + $request->input('accuracy') + $request->input('communication') + $request->input('location')) / 4;
        $data = $validator->validated();
        $data['rate'] = $rate;
        $data['client_id'] = $user->id;
        $clientReview = ClientReview::create($data);
        $booking->client_review_id = $clientReview->id;
        $booking->save();
        //====update host
        $host = $booking->realestate->host;
        $total = $host->host_nb_raters * $host->host_rate;
        $total = $total + $rate;
        $newRate = $total / ($host->host_nb_raters + 1);
        $host->host_rate = $newRate;
        $host->host_nb_raters = $host->host_nb_raters + 1;
        $host->save();
        //======update realestate
        $realestate = $booking->realestate;
        $total = $booking->rate * $booking->nb_raters;
        $total = $total + $rate;
        $newRate = $total / ($booking->nb_raters + 1);
        $realestate->rate = $newRate;
        $realestate->nb_raters = $realestate->nb_raters + 1;
        $realestate->save();

        $response = new ClientBookingResource($booking);

        return $this->jsonResponse(true, self::SUCCESS, 201, $response);
    }


    public function clientPayBooking(Request $request, $id)
    {
        $user = $request->user();
        $booking = Booking::where('id', '=', $id)->where('client_id', '=', $user->id)->first();
        if (!$booking) {
            return $this->jsonResponse(false, "invalid-action", 422, null);
        }
        if ($booking->status->code != "confirmed") {
            return $this->jsonResponse(false, "booking not confirmed", 422, null);
        }
        Stripe::setApiKey(config('services.stripe.secret'));
        $amount = $booking->amount * 100;
        $intent = PaymentIntent::create([
            'amount' => $amount,
            'currency' => 'mad',
            'automatic_payment_methods' => ['enabled' => true],
            'metadata' => [
                'booking_id' => $booking->id
            ]
        ]);
        $response = [
            "clientSecret" => $intent->client_secret
        ];
        return $this->jsonResponse(true, self::SUCCESS, 200, $response);
    }


    // public function confirmBooking($id)
    // {
    //     $booking = Booking::find($id);
    //     if (!$booking) {
    //         return $this->jsonResponse(false, "not-found", 404, null);
    //     }
    //     $bookingStatus = BookingStatus::where('code', '=', 'confirmed')->first();
    //     $booking->status_id = $bookingStatus->id;
    //     $booking->save();
    //     return $this->jsonResponse(true, self::SUCCESS, 200, null);
    // }

    // public function rejectBooking($id)
    // {
    //     $booking = Booking::find($id);
    //     if (!$booking) {
    //         return $this->jsonResponse(false, "not-found", 404, null);
    //     }
    //     $bookingStatus = BookingStatus::where('code', '=', 'rejected')->first();
    //     $booking->status_id = $bookingStatus->id;
    //     $booking->save();
    //     return $this->jsonResponse(true, self::SUCCESS, 200, null);
    // }

    public function hostBookings(Request $request)
    {
        $bookings = Booking::with('status')
            ->whereHas('status', function ($query) {
                $query->where('code', '=', 'pending');
            })
            ->orderBy('created_at', 'desc')
            ->get();
        $response = HostBookingResource::collection($bookings);
        return $this->jsonResponse(true, self::SUCCESS, 200, $response);
    }


    // public function hostConfirmBooking(Request $request, $id)
    // {
    //     $booking = Booking::find($id);
    //     if (!$booking) {
    //         return $this->jsonResponse(false, "not-found", 404, null);
    //     }
    //     $bookingStatus = BookingStatus::where('code', '=', 'confirmed')->first();
    //     $booking->status_id = $bookingStatus->id;
    //     $booking->save();
    //     return $this->jsonResponse(true, self::SUCCESS, 200, null);
    // }
}
