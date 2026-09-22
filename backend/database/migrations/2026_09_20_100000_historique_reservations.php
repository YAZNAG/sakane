<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/** Historique des modifications d'une reservation, auteur des ecritures, paiement des factures. */
return new class extends Migration
{
    public function up(): void
    {
        if (!Schema::hasTable("booking_modifications")) {
            Schema::create("booking_modifications", function (Blueprint $t) {
                $t->id();
                $t->unsignedBigInteger("booking_id")->index();
                // prolongation, raccourcissement, prix
                $t->string("type", 20);
                $t->date("ancien_checkout")->nullable();
                $t->date("nouveau_checkout")->nullable();
                $t->integer("nuits_delta")->default(0);
                $t->decimal("ancien_prix_nuit", 12, 2)->nullable();
                $t->decimal("nouveau_prix_nuit", 12, 2)->nullable();
                $t->decimal("ancien_total", 12, 2)->nullable();
                $t->decimal("nouveau_total", 12, 2)->nullable();
                $t->decimal("ecart", 12, 2)->default(0);
                $t->decimal("encaisse", 12, 2)->default(0);
                $t->decimal("rembourse", 12, 2)->default(0);
                $t->unsignedBigInteger("manager_id")->nullable();
                $t->timestamps();
            });
        }
        if (!Schema::hasColumn("financial_transactions", "manager_id")) {
            Schema::table("financial_transactions", fn(Blueprint $t) => $t->unsignedBigInteger("manager_id")->nullable()->after("charge_id"));
        }
        Schema::table("factures", function (Blueprint $t) {
            if (!Schema::hasColumn("factures", "statut_paiement")) $t->string("statut_paiement", 20)->default("non_paye")->after("taux_tva");
            if (!Schema::hasColumn("factures", "paye_le")) $t->timestamp("paye_le")->nullable()->after("statut_paiement");
            if (!Schema::hasColumn("factures", "montant_encaisse")) $t->decimal("montant_encaisse", 12, 2)->default(0)->after("paye_le");
            if (!Schema::hasColumn("factures", "encaisse_par")) $t->unsignedBigInteger("encaisse_par")->nullable()->after("montant_encaisse");
            if (!Schema::hasColumn("factures", "mouvement_caisse_id")) $t->unsignedBigInteger("mouvement_caisse_id")->nullable()->after("encaisse_par");
        });
    }

    public function down(): void
    {
        Schema::dropIfExists("booking_modifications");
    }
};
