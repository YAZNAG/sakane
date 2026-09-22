<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Caisses, mouvements et remises.
 *
 * Une caisse est un detenteur d'argent : la poche d'un agent, le coffre
 * de l'agence, un compte en banque. Un mouvement est de l'argent qui
 * entre ou sort de ce detenteur.
 */
return new class extends Migration
{
    public function up(): void
    {
        if (!Schema::hasTable("caisses")) {
            Schema::create("caisses", function (Blueprint $table) {
                $table->id();
                $table->string("nom");
                // agent : la poche d'une personne. agence : le coffre.
                // banque : un compte, ou aucune espece ne transite.
                $table->enum("type", ["agent", "agence", "banque"])->default("agent");
                $table->unsignedBigInteger("manager_id")->nullable()->index();
                $table->boolean("actif")->default(true);
                $table->timestamps();
            });
        }

        if (!Schema::hasTable("remises_caisse")) {
            Schema::create("remises_caisse", function (Blueprint $table) {
                $table->id();
                $table->unsignedBigInteger("caisse_source_id")->index();
                $table->unsignedBigInteger("caisse_destination_id")->index();
                // Deux montants : ce que l'agent annonce, ce que l'admin
                // compte. L'ecart entre les deux est la raison d'etre de
                // cette table.
                $table->decimal("montant_declare", 12, 2);
                $table->decimal("montant_recu", 12, 2)->nullable();
                $table->enum("statut", ["en_attente", "confirmee", "refusee"])
                    ->default("en_attente")->index();
                $table->unsignedBigInteger("declare_par")->nullable();
                $table->unsignedBigInteger("confirme_par")->nullable();
                $table->timestamp("declare_le")->nullable();
                $table->timestamp("confirme_le")->nullable();
                $table->text("commentaire")->nullable();
                $table->timestamps();
            });
        }

        if (!Schema::hasTable("mouvements_caisse")) {
            Schema::create("mouvements_caisse", function (Blueprint $table) {
                $table->id();
                $table->unsignedBigInteger("caisse_id")->index();
                $table->enum("sens", ["entree", "sortie"]);
                $table->decimal("montant", 12, 2);
                $table->string("motif", 40)->index();
                $table->string("libelle")->nullable();

                // Ce qui a provoque le mouvement, quand il vient de
                // l'application plutot que d'une saisie a la main.
                $table->unsignedBigInteger("booking_id")->nullable()->index();
                $table->unsignedBigInteger("charge_id")->nullable()->index();
                $table->unsignedBigInteger("remise_id")->nullable()->index();

                // Qui a saisi, et quand l'argent a reellement bouge.
                $table->unsignedBigInteger("manager_id")->nullable()->index();
                $table->timestamp("effectue_le")->index();

                // Un mouvement ne se supprime pas : il se contre-passe.
                $table->unsignedBigInteger("contrepasse_id")->nullable();

                $table->text("commentaire")->nullable();
                $table->timestamps();
            });
        }
    }

    public function down(): void
    {
        Schema::dropIfExists("mouvements_caisse");
        Schema::dropIfExists("remises_caisse");
        Schema::dropIfExists("caisses");
    }
};
