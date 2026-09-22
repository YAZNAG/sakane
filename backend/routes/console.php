<?php

use App\Jobs\AddTransactions;
use App\Jobs\MarkBookingCompleted;
use App\Jobs\SendRappelToClientNotification;
use App\Jobs\ProgramedCharges;
use Illuminate\Foundation\Console\ClosureCommand;
use Illuminate\Foundation\Inspiring;
use Illuminate\Support\Facades\Artisan;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\File;
use Illuminate\Support\Facades\Schedule;

Artisan::command('inspire', function () {
    /** @var ClosureCommand $this */
    $this->comment(Inspiring::quote());
})->purpose('Display an inspiring quote');

Schedule::call(new AddTransactions())->everyFiveMinutes();
Schedule::call(new MarkBookingCompleted())->dailyAt("12:30");
Schedule::call(new SendRappelToClientNotification())->dailyAt("18:00");
Schedule::call(new ProgramedCharges())->dailyAt("12:00");


Schedule::command('backup:clean')->dailyAt('00:00');
Schedule::command('backup:run')->dailyAt('00:30');
Schedule::command('backup:run')->dailyAt('13:30');

// Les cles d'idempotence ne servent qu'au rattrapage des operations
// hors connexion : au dela d'un mois elles n'ont plus d'utilite.
Schedule::call(function () {
    DB::table('idempotent_requests')
        ->where('created_at', '<', now()->subDays(30))
        ->delete();
})->daily();

// Les campagnes sont envoyees par petits paquets pour ne pas saturer
// la passerelle WhatsApp ni faire bloquer le compte.
Schedule::command('campagnes:traiter')->everyMinute()->withoutOverlapping();

// Calendriers Airbnb des biens relies.
Schedule::command('airbnb:synchroniser')->everyFifteenMinutes()->withoutOverlapping();

// Rappels de reservation et message post-sejour : un passage par quart
// d'heure suffit, les rappels se comptent en heures.
Schedule::command('rappels:envoyer')->everyFifteenMinutes()->withoutOverlapping();

// Relances des loyers de la location longue duree, une fois par jour.
Schedule::command('loyers:relances')->dailyAt('10:00')->withoutOverlapping();

// Les images des envois test ne servent que le temps que WhatsApp les
// telecharge : au dela d'une journee elles n'ont plus d'utilite.
Schedule::call(function () {
    $dossier = storage_path('app/public/tests-campagnes');
    if (!File::isDirectory($dossier)) {
        return;
    }
    foreach (File::files($dossier) as $fichier) {
        if (File::lastModified($fichier) < now()->subDay()->getTimestamp()) {
            File::delete($fichier);
        }
    }
})->dailyAt('03:30');
