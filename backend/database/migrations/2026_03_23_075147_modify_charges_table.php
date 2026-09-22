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
        Schema::table("charges", function (Blueprint $table) {
            $table->string("nom")->nullable();
            $table->string("description")->nullable();
            $table->enum("type", ["fix", "variable"])->default("fix");
            $table->enum("status", ["pending", "payed", "cancelled"])->default("payed");
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table("charges", function (Blueprint $table) {
            $table->dropColumn(['nom', 'description', 'type', 'status']);
        });
    }
};
