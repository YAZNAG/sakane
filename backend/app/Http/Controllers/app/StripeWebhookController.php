<?php

namespace App\Http\Controllers\app;

use App\Http\Controllers\Controller;
use App\Models\AppParam;
use App\Models\Booking;
use App\Models\BookingStatus;
use App\Models\OperationType;
use App\Models\PaymentMethod;
use App\Models\Transaction;
use App\Models\User;
use App\utils\JsonResponses;
use GrahamCampbell\ResultType\Success;
use GuzzleHttp\Promise\Create;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Stripe\BalanceTransaction;
use Stripe\Charge;
use Stripe\Stripe;
use Stripe\Webhook;
use Throwable;

class StripeWebhookController extends Controller
{
    use JsonResponses;
    public function paymentSuccess(Request $request)
    {
        Stripe::setApiKey(config('services.stripe.secret'));

        $payload = $request->getContent();
        $sigHeader = $request->header('Stripe-Signature');
        $secret = config('services.stripe.webhook_secret');

        try {
            $event = Webhook::constructEvent($payload, $sigHeader, $secret);
            Log::info('Stripe Event:', (array) $event);
        } catch (\UnexpectedValueException $e) {
            return response()->json(['error' => 'Invalid payload'], 400);
        } catch (\Stripe\Exception\SignatureVerificationException $e) {
            return response()->json(['error' => 'Invalid signature'], 400);
        }


        if ($event->type !== 'payment_intent.succeeded') {
            return $this->jsonResponse(false, "payment-not-success", 400, null);
        }
        $data = $event->data->object;
        $bookingId = $data->metadata->booking_id ?? null;

        if (!$bookingId) {
            $this->jsonResponse(false, "booking-not-found", 404, null);
        }
        DB::beginTransaction();
        try {
            $booking = Booking::find($bookingId);
            $status = BookingStatus::where("code", "=", "payed")->first()->id;
            $paymentMethod = PaymentMethod::where("code", "=", "stripe")->first()->id;
            $booking->status_id = $status;
            $booking->payment_method = $paymentMethod;
            $booking->payment_intent = $data->id;
            $booking->save();
            DB::commit();
            return $this->jsonResponse(true, self::SUCCESS, 200, null);
        } catch (Throwable $th) {
            DB::rollBack();
            Log::error("stripe-web-hook-error" . $th->getMessage());
        }
    }
}
