<?php

namespace App\Jobs;

use App\Mail\ReservationMail;
use App\Models\AppParam;
use App\Models\Booking;
use App\Models\OperationType;
use App\Models\Transaction;
use App\Models\User;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Mail;
use Stripe\BalanceTransaction;
use Stripe\Charge;
use Stripe\PaymentIntent;
use Stripe\Stripe;
use Throwable;

class AddTransactions
{

    public function __invoke()
    {
        Log::info("cron job (" . static::class . ") executed successfully at- " . now());
        Stripe::setApiKey(config('services.stripe.secret'));
        $bookings = Booking::with("realestate.host")->whereNotNull("payment_intent")->where("is_cron_pass", "=", 0)->get();
        foreach ($bookings as $booking) {
            DB::beginTransaction();
            try {
                $intent_id = $booking->payment_intent;
                $intent = PaymentIntent::retrieve($intent_id);
                $charge_id = $intent->latest_charge;
                $charge = Charge::retrieve($charge_id);
                $transactionId = $charge->balance_transaction;
                $balanceTransaction = BalanceTransaction::retrieve($transactionId);
                //values
                $total = $balanceTransaction->amount / 100;
                $fee = $balanceTransaction->fee / 100;
                $net = $balanceTransaction->net / 100;
                //add trnsactions
                $this->addTransactionForHostAndPlatform($total, $fee, $net, $booking);
                //update booking
                $booking->is_cron_pass = 1;
                $booking->save();
                DB::commit();
            } catch (Throwable $th) {
                DB::rollBack();
                Log::error("stripe-error" . $th->getMessage());
            }
        }
    }


    private function addTransactionForHostAndPlatform($total, $fee, $net, Booking $booking)
    {
        $host = $booking->realestate->host;
        $operation = OperationType::where("code", "=", "payment-on-hold")->first();
        if ($host->agence === true) {

            Transaction::create([
                "amount" => $net,
                "details" => [
                    "total" => $total,
                    "frais Stripe" => $fee,
                ],
                "user_id" => $host->id,
                "operation_id" => $operation->id,
                "booking_id" => $booking->id
            ]);
            //send email to agence
        } else {
            $param = AppParam::where("name", "=", "platform-percentage")->first();
            $platformPercentage = $param->value;
            $platformAmount = ($net * ((float)$platformPercentage)) / 100;
            $hostAmount = $net - $platformAmount;
            //create transaction for host
            Transaction::create([
                "amount" => $hostAmount,
                "details" => [
                    "total" => $total,
                    "frais Stripe" => $fee,
                    "frais de plateforme" => $platformAmount,
                ],
                "user_id" => $host->id,
                "operation_id" => $operation->id,
                "booking_id" => $booking->id
            ]);
            //create transaction for agence
            $agence = User::where("agence", "=", true)->first();
            Transaction::create([
                "amount" => $platformAmount,
                "details" => [
                    "total" => $total,
                    "frais Stripe" => $fee,
                    "Frais de l'hôte" => $hostAmount
                ],
                "user_id" => $agence->id,
                "operation_id" => $operation->id,
                "booking_id" => $booking->id,
                "is_commission" => true
            ]);
            //send email to agence and host

        }
        Mail::to($host->email)->send(new ReservationMail(
            title: "Paiement reçu",
            subtitle: "Le paiement pour la réservation de {$booking->client->name} a été effectué avec succès. La réservation est maintenant complète.",
            checkin: $booking->checkin,
            checkout: $booking->checkout,
            guest: $booking->nb_guest,
            amount: $booking->amount . " MAD",
            subject: "Paiement reçu - Réservation confirmée"
        ));
    }
}
