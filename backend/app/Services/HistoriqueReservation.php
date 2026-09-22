<?php

namespace App\Services;

use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Throwable;

/** L'historique des modifications d'une reservation. */
class HistoriqueReservation
{
    public static function noter(array $l): void
    {
        try {
            DB::table("booking_modifications")->insert($l + ["created_at" => now(), "updated_at" => now()]);
        } catch (Throwable $th) {
            Log::warning("Historique de reservation non enregistre : " . $th->getMessage());
        }
    }
}
