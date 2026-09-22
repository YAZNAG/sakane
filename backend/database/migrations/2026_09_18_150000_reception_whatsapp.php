<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/** Reception des messages WhatsApp par utilisateur : en tout, et type par type. */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table("managers", function (Blueprint $t) {
            if (!Schema::hasColumn("managers", "whatsapp_actif")) $t->boolean("whatsapp_actif")->default(true)->after("phone");
            if (!Schema::hasColumn("managers", "whatsapp_types_coupes")) $t->json("whatsapp_types_coupes")->nullable()->after("whatsapp_actif");
        });
    }

    public function down(): void
    {
        Schema::table("managers", fn(Blueprint $t) => $t->dropColumn(["whatsapp_actif", "whatsapp_types_coupes"]));
    }
};
