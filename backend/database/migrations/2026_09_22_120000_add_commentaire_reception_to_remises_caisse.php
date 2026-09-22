<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (!Schema::hasColumn("remises_caisse", "commentaire_reception")) {
            Schema::table("remises_caisse", function (Blueprint $table) {
                $table->text("commentaire_reception")->nullable()->after("commentaire");
            });
        }
    }

    public function down(): void
    {
        if (Schema::hasColumn("remises_caisse", "commentaire_reception")) {
            Schema::table("remises_caisse", fn(Blueprint $table) => $table->dropColumn("commentaire_reception"));
        }
    }
};
