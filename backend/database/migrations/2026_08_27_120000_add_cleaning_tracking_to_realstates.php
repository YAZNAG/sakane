<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('realstates', function (Blueprint $table) {
            $table->timestamp('cleaning_started_at')->nullable()->after('cleaning_status');
            $table->timestamp('cleaning_finished_at')->nullable()->after('cleaning_started_at');
            $table->unsignedBigInteger('cleaned_by')->nullable()->after('cleaning_finished_at');
            $table->unsignedInteger('last_cleaning_minutes')->nullable()->after('cleaned_by');
        });
    }

    public function down(): void
    {
        Schema::table('realstates', function (Blueprint $table) {
            $table->dropColumn([
                'cleaning_started_at',
                'cleaning_finished_at',
                'cleaned_by',
                'last_cleaning_minutes',
            ]);
        });
    }
};
