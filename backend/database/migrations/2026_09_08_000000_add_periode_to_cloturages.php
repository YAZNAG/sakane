<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Ce qui s'est passe entre deux clotures.
 *
 * Les totaux sont figes a la cloture plutot que recalcules : un
 * mouvement anterieur saisi apres coup changerait un rapport deja
 * signe, et l'on ne saurait plus ce qui avait ete constate ce jour-la.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table("cloturages_caisse", function (Blueprint $table) {
            foreach ([
                "montant_depart", "total_entrees", "total_sorties", "total_remis",
            ] as $colonne) {
                if (!Schema::hasColumn("cloturages_caisse", $colonne)) {
                    $table->decimal($colonne, 12, 2)->default(0)->after("caisse_id");
                }
            }

            if (!Schema::hasColumn("cloturages_caisse", "debut_periode")) {
                $table->timestamp("debut_periode")->nullable()->after("caisse_id");
            }
        });
    }

    public function down(): void
    {
        Schema::table("cloturages_caisse", function (Blueprint $table) {
            $table->dropColumn([
                "debut_periode", "montant_depart",
                "total_entrees", "total_sorties", "total_remis",
            ]);
        });
    }
};
