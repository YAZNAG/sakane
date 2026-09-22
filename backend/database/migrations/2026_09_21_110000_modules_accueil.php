<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/** Modules masques, ajoutes ou renommes sur l'accueil de chaque utilisateur. */
return new class extends Migration
{
    public function up(): void
    {
        if (!Schema::hasColumn("preferences_accueil", "modules")) {
            Schema::table("preferences_accueil", fn(Blueprint $t) => $t->longText("modules")->nullable()->after("barre"));
        }
    }

    public function down(): void
    {
        if (Schema::hasColumn("preferences_accueil", "modules")) {
            Schema::table("preferences_accueil", fn(Blueprint $t) => $t->dropColumn("modules"));
        }
    }
};
