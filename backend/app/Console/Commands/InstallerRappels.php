<?php

namespace App\Console\Commands;

use App\Models\Rappel;
use App\Services\CatalogueRappels;
use Illuminate\Console\Command;

/**
 * Installe les rappels proposes par defaut. Les reglages deja modifies
 * par le gerant ne sont pas ecrases.
 */
class InstallerRappels extends Command
{
    protected $signature = 'rappels:installer';

    protected $description = "Installe les rappels de reservation par defaut";

    public function handle(): int
    {
        $crees = 0;
        foreach (CatalogueRappels::tous() as $modele) {
            if (Rappel::where('code', $modele['code'])->exists()) {
                continue;
            }
            Rappel::create($modele);
            $crees++;
        }

        $this->info("Rappels : {$crees} cree(s), "
            . Rappel::count() . " au total.");
        return self::SUCCESS;
    }
}
