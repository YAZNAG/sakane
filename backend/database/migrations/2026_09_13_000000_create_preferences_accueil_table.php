<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * L'organisation de l'accueil propre a chaque utilisateur.
 *
 * Une ligne par utilisateur : l'ordre des cartes et les dossiers, et les
 * modules de la barre du bas. Sur le serveur, elle ne se perd plus a la
 * reinstallation de l'application ni en changeant de telephone.
 */
return new class extends Migration
{
    public function up(): void
    {
        if (Schema::hasTable("preferences_accueil")) {
            return;
        }

        Schema::create("preferences_accueil", function (Blueprint $table) {
            $table->id();
            $table->unsignedBigInteger("manager_id")->unique();
            $table->longText("disposition")->nullable();
            $table->text("barre")->nullable();
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists("preferences_accueil");
    }
};
