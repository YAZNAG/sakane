<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Ce qu'il faut savoir d'une charge annulee.
 *
 * Annuler n'efface pas : la charge reste, avec la date, l'auteur de
 * l'annulation et ce qui a ete rendu. Sans ces colonnes, une charge
 * annulee ne se distinguait pas d'une charge oubliee.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table("charges", function (Blueprint $table) {
            if (!Schema::hasColumn("charges", "cancelled_at")) {
                $table->timestamp("cancelled_at")->nullable()->after("status");
            }
            if (!Schema::hasColumn("charges", "cancelled_by")) {
                $table->unsignedBigInteger("cancelled_by")->nullable()->after("cancelled_at");
            }
            if (!Schema::hasColumn("charges", "montant_rembourse")) {
                $table->decimal("montant_rembourse", 10, 2)->nullable()->after("cancelled_by");
            }
            if (!Schema::hasColumn("charges", "motif_annulation")) {
                $table->string("motif_annulation", 500)->nullable()->after("montant_rembourse");
            }
        });
    }

    public function down(): void
    {
        Schema::table("charges", function (Blueprint $table) {
            $table->dropColumn(["cancelled_at", "cancelled_by", "montant_rembourse", "motif_annulation"]);
        });
    }
};
