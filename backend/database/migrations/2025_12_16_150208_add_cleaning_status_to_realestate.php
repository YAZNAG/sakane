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
        Schema::table('realstates', function (Blueprint $table) {
            $table->enum("cleaning_status", ["cleaning", "cleaned"])->nullable();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('realstates', function (Blueprint $table) {
            $table->dropColumn("cleaning_status");
        });
    }
};
