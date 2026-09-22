<?php

namespace App\Console\Commands;

use App\Services\EnvoiCampagnes;
use Illuminate\Console\Command;

/**
 * Envoie les messages des campagnes en cours, au rythme de chaque
 * campagne (2 messages par minute par defaut). Appelee chaque minute.
 */
class TraiterCampagnes extends Command
{
    protected $signature = 'campagnes:traiter';

    protected $description = "Envoie les messages des campagnes en cours";

    public function handle(): int
    {
        $n = EnvoiCampagnes::passage();
        if ($n > 0) {
            $this->info("Messages de campagne traites : $n");
        }
        return self::SUCCESS;
    }
}
