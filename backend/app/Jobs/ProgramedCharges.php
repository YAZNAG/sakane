<?php

namespace app\Jobs;

use App\Services\ModelesMessages;
use App\Models\Charge;
use App\Models\Manager;
use App\Models\ProgramedCharge;
use Carbon\Carbon;
use Illuminate\Support\Facades\Log;
use Throwable;
use WasenderApi\WasenderClient;

class ProgramedCharges
{


    public function __invoke()
    {
        Log::info("cron job (" . static::class . ") executed successfully at- " . now());
        $today = Carbon::now();
        $dayName = $today->format('l');
        $dayOfMonth = (int) $today->format('j');
        $month = (int) $today->format('n');

        $query = ProgramedCharge::query();

        $charges = $query->where(function ($q) use ($dayName, $dayOfMonth, $month) {

            $q->where(function ($q) use ($dayName) {
                $q->where('type', 'week')
                    ->where('day_name', $dayName);
            })

                ->orWhere(function ($q) use ($dayOfMonth) {
                    $q->where('type', 'month')
                        ->where('day', $dayOfMonth);
                })

                ->orWhere(function ($q) use ($dayOfMonth, $month) {
                    $q->where('type', 'year')
                        ->where('month', $month)
                        ->where('day', $dayOfMonth);
                });
        })->get();



        foreach ($charges as $programedCharge) {
            $charge = Charge::create([
                'nom'         => $programedCharge->nom,
                'description'         => $programedCharge->description,
                'amount'       => $programedCharge->amount,
                'status'       => "pending",
                'type' => 'fix',
                'realestate_id' => $programedCharge->realestate_id,
            ]);
            $this->sendNotification($charge);
        }
    }


    public function sendNotification(Charge $charge)
    {
        $wa = new WasenderClient(config("services.whatsapp.wasender_key"));
        $adminPhones = Manager::role("admin")->get()->map(function ($admin) {
            return str_replace("+", "", $admin->phone);
        });

        $msg = $this->buildMessage($charge->nom ?? $charge->name ?? '-', $charge->amount, $charge->realestate?->title);
        $adminPhones = \App\Services\ReceptionWhatsapp::filtrer($adminPhones, "charge-programmee");
        foreach ($adminPhones as $phone) {
            try {
                $wa->sendText($phone, $msg);
            } catch (Throwable $th) {
                Log::error($th);
            }
        }
    }

    private function buildMessage(?string $name, float $amount, ?string $realestate): string
    {
        $realestateLine = $realestate ? "🏠 Bien       : {$realestate}\n" : "";

        return ModelesMessages::rendu("programed-charge", [
            "{apartment_name}" => $charge->realestate?->title ?? '',
            "{amount}"         => number_format((float) $charge->amount, 2, ',', ' '),
            "{label}"          => $charge->nom ?? '',
        ]);
    }
}
