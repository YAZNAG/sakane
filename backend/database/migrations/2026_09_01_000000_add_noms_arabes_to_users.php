<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Nom et prenom en arabe.
 *
 * La CIN marocaine porte les deux graphies. Les contrats et les
 * bulletins destines aux autorites reclament l'arabe ; l'application
 * ne savait jusqu'ici stocker que le latin.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table("users", function (Blueprint $table) {
            if (!Schema::hasColumn("users", "first_name_ar")) {
                $table->string("first_name_ar", 100)->nullable()->after("last_name");
            }
            if (!Schema::hasColumn("users", "last_name_ar")) {
                $table->string("last_name_ar", 100)->nullable()->after("first_name_ar");
            }
        });
    }

    public function down(): void
    {
        Schema::table("users", function (Blueprint $table) {
            $table->dropColumn(["first_name_ar", "last_name_ar"]);
        });
    }
};
