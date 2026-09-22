<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/** Un bien peut etre desactive : il sort des listes et des statistiques a partir de cette date. */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table("realstates", function (Blueprint $t) {
            if (!Schema::hasColumn("realstates", "desactive_le")) $t->timestamp("desactive_le")->nullable()->index();
            if (!Schema::hasColumn("realstates", "desactive_par")) $t->unsignedBigInteger("desactive_par")->nullable();
            if (!Schema::hasColumn("realstates", "desactive_motif")) $t->string("desactive_motif", 255)->nullable();
        });
    }

    public function down(): void
    {
        Schema::table("realstates", fn(Blueprint $t) => $t->dropColumn(["desactive_le", "desactive_par", "desactive_motif"]));
    }
};
