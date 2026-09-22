<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        Schema::table("users", function (Blueprint $table) {
            $table->double("host_rate")->default(0);
            $table->integer("host_nb_raters")->default(0);
            $table->enum("identity_status", ["pending", "valid", "invalid"])->default("invalid");
            $table->boolean("agence")->default(false);
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table("users", function (Blueprint $table) {
            $table->dropColumn("agence");
            $table->dropColumn("host_rate");
            $table->dropColumn("identity_status");
            $table->dropColumn("host_nb_raters");
        });
    }
};
