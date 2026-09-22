<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/** Facture appliquee a la creation : la T.V.A est comprise dans le total de la reservation. */
return new class extends Migration
{
    public function up(): void
    {
        if (!Schema::hasColumn("factures", "tva_incluse")) {
            Schema::table("factures", fn(Blueprint $t) => $t->boolean("tva_incluse")->default(false)->after("montant_tva"));
        }
    }

    public function down(): void
    {
        Schema::table("factures", fn(Blueprint $t) => $t->dropColumn("tva_incluse"));
    }
};
