<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/** Factures numerotees, en-tete de l'agence, historique detaille des envois au syndic. */
return new class extends Migration
{
    public function up(): void
    {
        if (!Schema::hasTable("factures")) {
            Schema::create("factures", function (Blueprint $t) {
                $t->id();
                $t->unsignedInteger("numero")->unique();
                $t->unsignedBigInteger("booking_id")->nullable()->unique();
                $t->date("date_facture");
                $t->string("client_nom", 190)->nullable();
                $t->string("client_ice", 40)->nullable();
                $t->string("client_adresse", 255)->nullable();
                $t->decimal("montant_ttc", 12, 2)->default(0);
                $t->decimal("taux_tva", 5, 2)->default(20);
                $t->unsignedBigInteger("created_by")->nullable();
                $t->timestamps();
            });
        }

        Schema::table("syndic_envois", function (Blueprint $t) {
            if (!Schema::hasColumn("syndic_envois", "message")) $t->text("message")->nullable()->after("erreur");
            if (!Schema::hasColumn("syndic_envois", "source")) $t->string("source", 20)->default("auto")->after("message");
            if (!Schema::hasColumn("syndic_envois", "envoye_par")) $t->unsignedBigInteger("envoye_par")->nullable()->after("source");
        });
        // Un contrat peut etre envoye plusieurs fois (partage, renvoi) : chaque envoi est une ligne.
        $index = collect(DB::select("SHOW INDEX FROM syndic_envois"))->pluck("Key_name")->unique();
        if ($index->contains("syndic_envois_syndic_id_booking_id_unique")) {
            DB::statement("ALTER TABLE syndic_envois DROP INDEX syndic_envois_syndic_id_booking_id_unique");
        }
        DB::statement("ALTER TABLE syndic_envois MODIFY syndic_id BIGINT UNSIGNED NULL");

        $defauts = str_contains(strtolower((string) config("app.name")), "alwed") ? [
            "entete_nom" => "STE ALWED LH", "entete_sous_titre" => "Agence immobilière", "entete_ice" => "003551391900081",
            "entete_adresse" => "Rue Aglou N°36, Hay salam - Agadir", "entete_email" => "Alwed.lh24@gmail.com",
            "entete_tel" => "+212 6 6172-1887", "entete_reseaux" => "Alwedimmobilier", "entete_ville" => "AGADIR",
        ] : [
            "entete_nom" => (string) (config("agence.nom") ?: config("app.name")), "entete_sous_titre" => "Location d'appartements",
            "entete_ice" => "", "entete_adresse" => (string) config("agence.adresse", ""), "entete_email" => "",
            "entete_tel" => (string) config("agence.contact", ""), "entete_reseaux" => "", "entete_ville" => "AGADIR",
        ];
        foreach ($defauts as $cle => $valeur) {
            if (!DB::table("reglages_agence")->where("cle", $cle)->exists()) {
                DB::table("reglages_agence")->insert(["cle" => $cle, "valeur" => $valeur, "created_at" => now(), "updated_at" => now()]);
            }
        }
    }

    public function down(): void
    {
        Schema::dropIfExists("factures");
    }
};
