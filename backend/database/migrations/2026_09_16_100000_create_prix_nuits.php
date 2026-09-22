<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/** Prix d'une nuit fixe pour une date precise, a la place du prix habituel du bien. */
return new class extends Migration
{
    public function up(): void
    {
        if (!Schema::hasTable("prix_nuits")) {
            Schema::create("prix_nuits", function (Blueprint $t) {
                $t->id();
                $t->unsignedBigInteger("realestate_id");
                $t->date("date");
                $t->decimal("prix", 12, 2);
                $t->unsignedBigInteger("created_by")->nullable();
                $t->timestamps();
                $t->unique(["realestate_id", "date"]);
            });
        }
    }

    public function down(): void
    {
        Schema::dropIfExists("prix_nuits");
    }
};
