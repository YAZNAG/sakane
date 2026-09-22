<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Heures d'arrivee et de depart convenues avec le client.
 *
 * Les colonnes checkin et checkout sont de type date et ne portent pas
 * d'heure. Les convertir toucherait toute la logique de disponibilite,
 * qui compare des dates ; deux colonnes d'heure viennent donc a cote.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table("bookings", function (Blueprint $table) {
            if (!Schema::hasColumn("bookings", "heure_arrivee")) {
                $table->time("heure_arrivee")->nullable()->after("checkout");
            }
            if (!Schema::hasColumn("bookings", "heure_depart")) {
                $table->time("heure_depart")->nullable()->after("heure_arrivee");
            }
        });
    }

    public function down(): void
    {
        Schema::table("bookings", function (Blueprint $table) {
            $table->dropColumn(["heure_arrivee", "heure_depart"]);
        });
    }
};
