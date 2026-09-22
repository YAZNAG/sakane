<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Liste noire des clients, auteur et remboursement des suppressions de
 * reservation, syndics et contrats des proprietaires.
 */
return new class extends Migration
{
    public function up(): void
    {
        if (!Schema::hasColumn("users", "liste_noire_le")) {
            Schema::table("users", function (Blueprint $t) {
                $t->timestamp("liste_noire_le")->nullable();
                $t->string("liste_noire_motif", 300)->nullable();
                $t->unsignedBigInteger("liste_noire_par")->nullable();
            });
        }

        if (!Schema::hasColumn("bookings", "supprimee_par")) {
            Schema::table("bookings", function (Blueprint $t) {
                $t->unsignedBigInteger("supprimee_par")->nullable();
                $t->boolean("rembourse_suppression")->nullable();
                $t->decimal("montant_rembourse_suppression", 12, 2)->nullable();
            });
        }

        if (!Schema::hasTable("syndics")) {
            Schema::create("syndics", function (Blueprint $t) {
                $t->id();
                $t->string("nom", 150);
                $t->string("telephone", 30);
                $t->boolean("actif")->default(true);
                $t->text("notes")->nullable();
                $t->unsignedBigInteger("created_by")->nullable();
                $t->timestamps();
                $t->softDeletes();
            });
        }

        if (!Schema::hasColumn("realstates", "syndic_id")) {
            Schema::table("realstates", function (Blueprint $t) {
                $t->unsignedBigInteger("syndic_id")->nullable()->index();
            });
        }

        if (!Schema::hasTable("syndic_envois")) {
            Schema::create("syndic_envois", function (Blueprint $t) {
                $t->id();
                $t->unsignedBigInteger("syndic_id")->index();
                $t->unsignedBigInteger("booking_id")->index();
                $t->string("telephone", 30)->nullable();
                $t->string("statut", 20);
                $t->text("erreur")->nullable();
                $t->timestamps();
                $t->unique(["syndic_id", "booking_id"]);
            });
        }

        if (!Schema::hasTable("contrats_proprietaires")) {
            Schema::create("contrats_proprietaires", function (Blueprint $t) {
                $t->id();
                $t->unsignedBigInteger("owner_id")->index();
                $t->unsignedBigInteger("realestate_id")->nullable()->index();
                $t->string("titre", 150)->nullable();
                $t->date("date_debut")->nullable();
                $t->date("date_fin")->nullable();
                $t->string("fichier");
                $t->string("nom_fichier")->nullable();
                $t->string("type_mime", 100)->nullable();
                $t->unsignedBigInteger("taille")->nullable();
                $t->unsignedBigInteger("created_by")->nullable();
                $t->timestamps();
            });
        }
    }

    public function down(): void
    {
        Schema::dropIfExists("contrats_proprietaires");
        Schema::dropIfExists("syndic_envois");
        if (Schema::hasColumn("realstates", "syndic_id")) {
            Schema::table("realstates", fn(Blueprint $t) => $t->dropColumn("syndic_id"));
        }
        Schema::dropIfExists("syndics");
        if (Schema::hasColumn("bookings", "supprimee_par")) {
            Schema::table("bookings", fn(Blueprint $t) => $t->dropColumn(["supprimee_par", "rembourse_suppression", "montant_rembourse_suppression"]));
        }
        if (Schema::hasColumn("users", "liste_noire_le")) {
            Schema::table("users", fn(Blueprint $t) => $t->dropColumn(["liste_noire_le", "liste_noire_motif", "liste_noire_par"]));
        }
    }
};
