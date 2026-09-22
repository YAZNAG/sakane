<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/** La nationalite du client, reprise dans le contrat. */
return new class extends Migration
{
    public function up(): void
    {
        if (!Schema::hasColumn("users", "nationalite")) {
            Schema::table("users", fn(Blueprint $t) => $t->string("nationalite", 60)->nullable()->after("identity_number"));
        }
    }

    public function down(): void
    {
        Schema::table("users", fn(Blueprint $t) => $t->dropColumn("nationalite"));
    }
};
