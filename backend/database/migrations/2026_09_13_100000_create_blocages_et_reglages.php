<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Dates bloquees des biens, et reglages de l'agence (numero et message du
 * syndic pour le partage des contrats).
 */
return new class extends Migration
{
    public function up(): void
    {
        if (!Schema::hasTable("blocages_biens")) {
            Schema::create("blocages_biens", function (Blueprint $table) {
                $table->id();
                $table->unsignedBigInteger("realestate_id")->index();
                $table->date("date_debut");
                $table->date("date_fin");
                $table->string("motif", 200)->nullable();
                $table->unsignedBigInteger("created_by")->nullable();
                $table->timestamps();
            });
        }

        if (!Schema::hasTable("reglages_agence")) {
            Schema::create("reglages_agence", function (Blueprint $table) {
                $table->id();
                $table->string("cle", 100)->unique();
                $table->text("valeur")->nullable();
                $table->timestamps();
            });
        }
    }

    public function down(): void
    {
        Schema::dropIfExists("blocages_biens");
        Schema::dropIfExists("reglages_agence");
    }
};
