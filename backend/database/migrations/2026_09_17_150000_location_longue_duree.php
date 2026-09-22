<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Location longue duree : le bail, l'echeancier des loyers, les
 * paiements et le suivi des relances.
 */
return new class extends Migration
{
    public function up(): void
    {
        if (!Schema::hasTable("baux")) {
            Schema::create("baux", function (Blueprint $t) {
                $t->id();
                $t->unsignedBigInteger("realestate_id")->index();
                $t->unsignedBigInteger("client_id")->index();
                $t->date("date_debut");
                $t->date("date_fin");
                $t->unsignedSmallInteger("duree_mois");
                $t->decimal("loyer", 12, 2);
                $t->decimal("charges", 12, 2)->default(0);
                $t->decimal("depot", 12, 2)->default(0);
                // non_recu, recu, restitue
                $t->string("depot_statut", 20)->default("non_recu");
                $t->decimal("depot_rendu", 12, 2)->nullable();
                $t->string("compteur_eau_entree", 40)->nullable();
                $t->string("compteur_elec_entree", 40)->nullable();
                $t->string("compteur_eau_sortie", 40)->nullable();
                $t->string("compteur_elec_sortie", 40)->nullable();
                $t->text("remarques")->nullable();
                $t->boolean("relances_actives")->default(true);
                // actif, termine
                $t->string("statut", 20)->default("actif")->index();
                $t->date("termine_le")->nullable();
                $t->string("motif_fin", 255)->nullable();
                $t->unsignedBigInteger("created_by")->nullable();
                $t->unsignedBigInteger("termine_par")->nullable();
                $t->timestamps();
                $t->softDeletes();
            });
        }

        if (!Schema::hasTable("loyers")) {
            Schema::create("loyers", function (Blueprint $t) {
                $t->id();
                $t->unsignedBigInteger("bail_id")->index();
                $t->unsignedBigInteger("realestate_id")->index();
                $t->date("periode_debut");
                $t->date("periode_fin");
                $t->date("echeance")->index();
                $t->decimal("montant", 12, 2);
                $t->decimal("paye", 12, 2)->default(0);
                $t->timestamps();
                $t->unique(["bail_id", "periode_debut"]);
            });
        }

        if (!Schema::hasTable("loyer_paiements")) {
            Schema::create("loyer_paiements", function (Blueprint $t) {
                $t->id();
                $t->unsignedBigInteger("loyer_id")->index();
                $t->unsignedBigInteger("bail_id")->index();
                $t->decimal("montant", 12, 2);
                $t->date("paye_le");
                // especes, virement, cheque
                $t->string("mode", 20)->default("especes");
                $t->string("reference", 100)->nullable();
                $t->string("remarque", 255)->nullable();
                $t->unsignedBigInteger("manager_id")->nullable();
                $t->unsignedBigInteger("mouvement_caisse_id")->nullable();
                $t->timestamp("quittance_envoyee_le")->nullable();
                $t->timestamp("annule_le")->nullable();
                $t->unsignedBigInteger("annule_par")->nullable();
                $t->string("motif_annulation", 255)->nullable();
                $t->timestamps();
            });
        }

        if (!Schema::hasTable("loyer_relances")) {
            Schema::create("loyer_relances", function (Blueprint $t) {
                $t->id();
                $t->unsignedBigInteger("loyer_id");
                // avant, jour, retard
                $t->string("type", 20);
                $t->string("telephone", 30)->nullable();
                // envoye, echec, ignore
                $t->string("statut", 20);
                $t->string("erreur", 500)->nullable();
                $t->timestamps();
                $t->unique(["loyer_id", "type"]);
            });
        }

        if (!Schema::hasColumn("mouvements_caisse", "bail_id")) {
            Schema::table("mouvements_caisse", function (Blueprint $t) {
                $t->unsignedBigInteger("bail_id")->nullable()->after("remise_id");
            });
        }
    }

    public function down(): void
    {
        if (Schema::hasColumn("mouvements_caisse", "bail_id")) {
            Schema::table("mouvements_caisse", fn(Blueprint $t) => $t->dropColumn("bail_id"));
        }
        Schema::dropIfExists("loyer_relances");
        Schema::dropIfExists("loyer_paiements");
        Schema::dropIfExists("loyers");
        Schema::dropIfExists("baux");
    }
};
