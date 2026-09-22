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
        Schema::table('bookings', function (Blueprint $table) {
            $table->softDeletes();
        });
        Schema::table('charges', function (Blueprint $table) {
            $table->softDeletes();
        });
        Schema::table('users', function (Blueprint $table) {
            $table->softDeletes();
        });
        Schema::table('owners', function (Blueprint $table) {
            $table->softDeletes();
        });
        Schema::table('programed_charges', function (Blueprint $table) {
            $table->softDeletes();
        });
        Schema::table('realestate_rapports', function (Blueprint $table) {
            $table->softDeletes();
        });
        Schema::table('realstates', function (Blueprint $table) {
            $table->softDeletes();
        });
        Schema::table('sliders', function (Blueprint $table) {
            $table->softDeletes();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('tables', function (Blueprint $table) {
            Schema::table('bookings', function (Blueprint $table) {
                $table->dropSoftDeletes();
            });

            Schema::table('charges', function (Blueprint $table) {
                $table->dropSoftDeletes();
            });

            Schema::table('users', function (Blueprint $table) {
                $table->dropSoftDeletes();
            });
            Schema::table('owners', function (Blueprint $table) {
                $table->dropSoftDeletes();
            });

            Schema::table('programed_charges', function (Blueprint $table) {
                $table->dropSoftDeletes();
            });

            Schema::table('realestate_rapports', function (Blueprint $table) {
                $table->dropSoftDeletes();
            });

            Schema::table('realstates', function (Blueprint $table) {
                $table->dropSoftDeletes();
            });

            Schema::table('sliders', function (Blueprint $table) {
                $table->dropSoftDeletes();
            });
        });
    }
};
