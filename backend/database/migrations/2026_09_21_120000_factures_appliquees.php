<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/** La facture appliquee : montants figes (H.T, T.V.A, T.T.C), date et auteur. */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table("factures", function (Blueprint $t) {
            if (!Schema::hasColumn("factures", "montant_ht")) $t->decimal("montant_ht", 12, 2)->nullable()->after("taux_tva");
            if (!Schema::hasColumn("factures", "montant_tva")) $t->decimal("montant_tva", 12, 2)->nullable()->after("montant_ht");
            if (!Schema::hasColumn("factures", "appliquee_le")) $t->timestamp("appliquee_le")->nullable()->after("montant_tva");
            if (!Schema::hasColumn("factures", "appliquee_par")) $t->unsignedBigInteger("appliquee_par")->nullable()->after("appliquee_le");
        });
    }

    public function down(): void
    {
        Schema::table("factures", fn(Blueprint $t) => $t->dropColumn(["montant_ht", "montant_tva", "appliquee_le", "appliquee_par"]));
    }
};
