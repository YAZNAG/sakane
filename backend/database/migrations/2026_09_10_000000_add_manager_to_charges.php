<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Qui a regle la charge, et dont la caisse est donc debitee.
 *
 * Sans cette trace, un mouvement de caisse manquant ne peut plus etre
 * impute : on ignore quel agent a paye. Le cas s'est presente.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table("charges", function (Blueprint $table) {
            if (!Schema::hasColumn("charges", "manager_id")) {
                $table->unsignedBigInteger("manager_id")->nullable()->index()->after("realestate_id");
            }
        });
    }

    public function down(): void
    {
        Schema::table("charges", function (Blueprint $table) {
            $table->dropColumn("manager_id");
        });
    }
};
