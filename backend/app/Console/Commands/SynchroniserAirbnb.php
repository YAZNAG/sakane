<?php

namespace App\Console\Commands;

use App\Services\SyncAirbnb;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;

/** Relit les calendriers Airbnb de tous les biens relies. */
class SynchroniserAirbnb extends Command
{
    protected $signature = 'airbnb:synchroniser';

    protected $description = 'Importe les calendriers Airbnb des biens relies';

    public function handle(): int
    {
        $n = 0;
        foreach (DB::table("airbnb_calendriers")->whereNotNull("url_import")->get() as $cal) {
            SyncAirbnb::importer($cal);
            $n++;
            usleep(500000);
        }
        if ($n > 0) {
            $this->info("Calendriers Airbnb lus : $n");
        }
        return self::SUCCESS;
    }
}
