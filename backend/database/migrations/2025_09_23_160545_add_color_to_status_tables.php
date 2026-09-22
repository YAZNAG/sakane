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
        Schema::table('realstate_status', function (Blueprint $table) {
            $table->string("color")->default("f0f0f0");
        });
        Schema::table('booking_statuses', function (Blueprint $table) {
            $table->string("color")->default("f0f0f0");
        });
        Schema::table('user_status', function (Blueprint $table) {
            $table->string("color")->default("f0f0f0");
        });
        Schema::table('realstate_review_status', function (Blueprint $table) {
            $table->string("color")->default("f0f0f0");
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('realstate_status', function (Blueprint $table) {
            $table->dropColumn("color");
        });
        Schema::table('booking_statuses', function (Blueprint $table) {
            $table->dropColumn("color");
        });
        Schema::table('user_status', function (Blueprint $table) {
            $table->dropColumn("color");
        });
        Schema::table('realstate_review_status', function (Blueprint $table) {
            $table->dropColumn("color");
        });
    }
};
