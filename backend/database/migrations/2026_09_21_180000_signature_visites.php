<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/** La signature du visiteur sur son recu de visite. */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table("visites_vente", function (Blueprint $t) {
            if (!Schema::hasColumn("visites_vente", "signature")) $t->string("signature")->nullable();
            if (!Schema::hasColumn("visites_vente", "signe_le")) $t->timestamp("signe_le")->nullable();
        });
    }

    public function down(): void
    {
        Schema::table("visites_vente", fn(Blueprint $t) => $t->dropColumn(["signature", "signe_le"]));
    }
};
