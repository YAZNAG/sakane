<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/** Calendriers Airbnb lies aux biens, et sejours importes. */
return new class extends Migration
{
    public function up(): void
    {
        if (!Schema::hasTable("airbnb_calendriers")) {
            Schema::create("airbnb_calendriers", function (Blueprint $t) {
                $t->id();
                $t->unsignedBigInteger("realestate_id")->unique();
                $t->text("url_import")->nullable();
                $t->string("jeton_export", 64)->unique();
                $t->timestamp("derniere_sync_a")->nullable();
                $t->string("dernier_statut", 20)->nullable();
                $t->string("derniere_erreur", 500)->nullable();
                $t->timestamp("derniere_lecture_export_a")->nullable();
                $t->timestamps();
            });
        }
        if (!Schema::hasTable("airbnb_sejours")) {
            Schema::create("airbnb_sejours", function (Blueprint $t) {
                $t->id();
                $t->unsignedBigInteger("realestate_id")->index();
                $t->string("uid", 255);
                $t->date("du");
                $t->date("au");
                $t->string("type", 20)->default("reservation");
                $t->string("resume", 255)->nullable();
                $t->text("description")->nullable();
                $t->string("lien", 500)->nullable();
                $t->timestamps();
                $t->unique(["realestate_id", "uid"]);
            });
        }
    }

    public function down(): void
    {
        Schema::dropIfExists("airbnb_sejours");
        Schema::dropIfExists("airbnb_calendriers");
    }
};
