<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/** Colocataires du bail et identite de l'agence qui figure sur le contrat. */
return new class extends Migration
{
    public function up(): void
    {
        if (!Schema::hasColumn("baux", "colocataires")) {
            Schema::table("baux", fn(Blueprint $t) => $t->json("colocataires")->nullable()->after("remarques"));
        }

        // Valeurs reprises du contrat type de l'agence ; modifiables ensuite.
        $defauts = [
            "bail_societe"           => "الشركة العقارية ALWED LH",
            "bail_representant"      => "السيد هشام لوريدة",
            "bail_representant_cin"  => "SL 7480",
            "bail_representant_adresse" => "حي السلام المركب السكني النصر 3 أكادير",
            "bail_ville"             => "أكادير",
        ];
        foreach ($defauts as $cle => $valeur) {
            if (!DB::table("reglages_agence")->where("cle", $cle)->exists()) {
                DB::table("reglages_agence")->insert(["cle" => $cle, "valeur" => $valeur, "created_at" => now(), "updated_at" => now()]);
            }
        }
    }

    public function down(): void
    {
        if (Schema::hasColumn("baux", "colocataires")) {
            Schema::table("baux", fn(Blueprint $t) => $t->dropColumn("colocataires"));
        }
    }
};
