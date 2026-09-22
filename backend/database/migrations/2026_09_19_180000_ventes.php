<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/** Vente : mandats du proprietaire, visites des acheteurs, statut du bien. */
return new class extends Migration
{
    public function up(): void
    {
        if (!Schema::hasColumn("realstates", "vente_statut")) {
            Schema::table("realstates", fn(Blueprint $t) => $t->string("vente_statut", 20)->nullable()->after("syndic_id"));
        }
        if (!Schema::hasTable("mandats_vente")) {
            Schema::create("mandats_vente", function (Blueprint $t) {
                $t->id();
                $t->unsignedBigInteger("realestate_id")->index();
                $t->string("proprietaire_nom", 190);
                $t->string("proprietaire_cin", 40)->nullable();
                $t->string("proprietaire_nationalite", 60)->nullable();
                $t->string("proprietaire_adresse", 255)->nullable();
                $t->string("proprietaire_tel", 40)->nullable();
                $t->string("type_bien", 60)->nullable();
                $t->string("ville", 80)->nullable();
                $t->decimal("surface", 10, 2)->nullable();
                $t->string("titre_foncier", 80)->nullable();
                $t->string("adresse_bien", 255)->nullable();
                $t->decimal("prix_demande", 14, 2)->nullable();
                $t->decimal("commission", 5, 2)->default(2.5);
                $t->unsignedSmallInteger("duree_mois")->default(12);
                $t->date("date_signature");
                $t->text("remarques")->nullable();
                $t->unsignedBigInteger("created_by")->nullable();
                $t->timestamps();
                $t->softDeletes();
            });
        }
        if (!Schema::hasTable("visites_vente")) {
            Schema::create("visites_vente", function (Blueprint $t) {
                $t->id();
                $t->unsignedBigInteger("realestate_id")->index();
                $t->unsignedBigInteger("client_id")->nullable();
                $t->string("visiteur_nom", 190);
                $t->string("visiteur_cin", 40)->nullable();
                $t->string("visiteur_nationalite", 60)->nullable();
                $t->string("visiteur_adresse", 255)->nullable();
                $t->string("visiteur_tel", 40)->nullable();
                $t->date("date_visite");
                $t->decimal("commission", 5, 2)->default(2.5);
                // interesse, a_relancer, pas_interesse, offre
                $t->string("suite", 20)->nullable();
                $t->text("remarques")->nullable();
                $t->unsignedBigInteger("agent_id")->nullable();
                $t->timestamps();
                $t->softDeletes();
            });
        }
        if (!DB::table("reglages_agence")->where("cle", "entete_adresse_ar")->exists()) {
            DB::table("reglages_agence")->insert(["cle" => "entete_adresse_ar", "valeur" => "حي السلام زنقة اكلو رقم 36 أكادير", "created_at" => now(), "updated_at" => now()]);
        }
    }

    public function down(): void
    {
        Schema::dropIfExists("visites_vente");
        Schema::dropIfExists("mandats_vente");
        if (Schema::hasColumn("realstates", "vente_statut")) {
            Schema::table("realstates", fn(Blueprint $t) => $t->dropColumn("vente_statut"));
        }
    }
};
