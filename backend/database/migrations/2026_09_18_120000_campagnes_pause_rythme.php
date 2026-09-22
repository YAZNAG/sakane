<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/** Pause et reprise des campagnes, rythme d'envoi et ordre des destinataires. */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table("campagnes", function (Blueprint $t) {
            if (!Schema::hasColumn("campagnes", "par_minute")) $t->unsignedTinyInteger("par_minute")->default(2)->after("nb_echecs");
            if (!Schema::hasColumn("campagnes", "pausee_a")) $t->timestamp("pausee_a")->nullable()->after("terminee_a");
            if (!Schema::hasColumn("campagnes", "reprise_a")) $t->timestamp("reprise_a")->nullable()->after("pausee_a");
            if (!Schema::hasColumn("campagnes", "dernier_envoi_a")) $t->timestamp("dernier_envoi_a")->nullable()->after("reprise_a");
        });
        Schema::table("campagne_destinataires", function (Blueprint $t) {
            if (!Schema::hasColumn("campagne_destinataires", "ordre")) $t->unsignedInteger("ordre")->nullable()->after("client_id");
        });
    }

    public function down(): void
    {
        Schema::table("campagnes", fn(Blueprint $t) => $t->dropColumn(["par_minute", "pausee_a", "reprise_a", "dernier_envoi_a"]));
        Schema::table("campagne_destinataires", fn(Blueprint $t) => $t->dropColumn("ordre"));
    }
};
