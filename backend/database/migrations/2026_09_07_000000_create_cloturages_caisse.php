<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Les cloturages de caisse.
 *
 * On y conserve les deux montants - celui que le systeme calcule et
 * celui que l'agent a compte - plutot que le seul ecart : garder les
 * deux permet de refaire le raisonnement des mois plus tard.
 */
return new class extends Migration
{
    public function up(): void
    {
        if (Schema::hasTable("cloturages_caisse")) {
            return;
        }

        Schema::create("cloturages_caisse", function (Blueprint $table) {
            $table->id();
            $table->unsignedBigInteger("caisse_id")->index();
            $table->decimal("solde_theorique", 12, 2);
            $table->decimal("montant_compte", 12, 2);
            $table->decimal("ecart", 12, 2)->default(0);
            $table->unsignedBigInteger("cloture_par")->nullable();
            $table->timestamp("cloture_le")->index();
            $table->text("commentaire")->nullable();
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists("cloturages_caisse");
    }
};
