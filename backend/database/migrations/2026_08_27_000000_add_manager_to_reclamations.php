<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('reclamations', function (Blueprint $table) {
            $table->unsignedBigInteger('manager_id')->nullable()->after('realestate_id');
        });
    }

    public function down(): void
    {
        Schema::table('reclamations', function (Blueprint $table) {
            $table->dropColumn('manager_id');
        });
    }
};
