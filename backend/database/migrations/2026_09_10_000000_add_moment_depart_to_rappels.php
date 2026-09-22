<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

/**
 * Un rappel peut etre declenche par un geste, pas seulement par une date.
 *
 * Les dates d'arrivee et de sortie sont des jours sans heure : un
 * decalage calcule dessus tombe au milieu de la nuit. Le constat du
 * depart, lui, arrive quand le client part vraiment.
 */
return new class extends Migration
{
    public function up(): void
    {
        DB::statement("ALTER TABLE rappels MODIFY moment "
            . "ENUM('checkin', 'checkout', 'depart') NOT NULL DEFAULT 'checkin'");

        DB::table('rappels')->where('code', 'post-sejour')->update([
            'moment'          => 'depart',
            'decalage_heures' => 0,
        ]);
    }

    public function down(): void
    {
        DB::table('rappels')->where('moment', 'depart')->update([
            'moment'          => 'checkout',
            'decalage_heures' => 3,
        ]);

        DB::statement("ALTER TABLE rappels MODIFY moment "
            . "ENUM('checkin', 'checkout') NOT NULL DEFAULT 'checkin'");
    }
};
