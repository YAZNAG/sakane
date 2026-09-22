<?php

namespace App\Jobs;

use App\Models\Booking;
use App\Models\BookingStatus;
use App\Models\OperationType;
use App\Models\Transaction;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Throwable;

class MarkBookingCompleted
{


    public function __invoke()
    {
        Log::info("cron job (" . static::class . ") executed successfully at- " . now());
        $bookings = Booking::where("checkout", "<", now())
            ->whereHas("status", function ($query) {
                $query->where("code", "=", "payed");
            })->get();
        $completedStatus = BookingStatus::where("code", "=", "completed")->first();
        $successOperation = OperationType::where("code", "=", "success-payment")->first();
        foreach ($bookings as $booking) {
            DB::beginTransaction();
            try {
                //mark booking as completed
                $booking->status_id = $completedStatus->id;
                $booking->save();
                //update transactions status
                $transactions = Transaction::where("booking_id", "=", $booking->id)->get();
                foreach ($transactions as $transaction) {
                    $transaction->operation_id = $successOperation->id;
                    $transaction->save();
                    $user = $transaction->user;
                    $user->balance += $transaction->amount;
                    $user->save();
                }
                //send email to client & host
                DB::commit();
            } catch (Throwable $th) {
                DB::rollBack();
                Log::error("mark-booking-completed" . $th->getMessage());
            }
        }
    }
}
