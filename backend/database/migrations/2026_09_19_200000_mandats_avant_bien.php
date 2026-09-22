<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/** Mandat avant le bien : proprietaire lie, signature, bien facultatif. */
return new class extends Migration
{
    public function up(): void
    {
        DB::statement("ALTER TABLE mandats_vente MODIFY realestate_id BIGINT UNSIGNED NULL");
        Schema::table("mandats_vente", function (Blueprint $t) {
            if (!Schema::hasColumn("mandats_vente", "owner_id")) $t->unsignedBigInteger("owner_id")->nullable()->after("realestate_id");
            if (!Schema::hasColumn("mandats_vente", "signature")) $t->string("signature", 255)->nullable()->after("remarques");
            if (!Schema::hasColumn("mandats_vente", "signe_le")) $t->timestamp("signe_le")->nullable()->after("signature");
        });
        Schema::table("owners", function (Blueprint $t) {
            if (!Schema::hasColumn("owners", "cin")) $t->string("cin", 40)->nullable()->after("tel");
            if (!Schema::hasColumn("owners", "nationalite")) $t->string("nationalite", 60)->nullable()->after("cin");
        });
    }

    public function down(): void
    {
        Schema::table("mandats_vente", fn(Blueprint $t) => $t->dropColumn(["owner_id", "signature", "signe_le"]));
        Schema::table("owners", fn(Blueprint $t) => $t->dropColumn(["cin", "nationalite"]));
    }
};
