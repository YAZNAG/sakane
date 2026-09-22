<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (!Schema::hasTable("permissions_retirees")) {
            Schema::create("permissions_retirees", function (Blueprint $table) {
                $table->id();
                $table->unsignedBigInteger("manager_id")->index();
                $table->string("permission", 100);
                $table->timestamps();
                $table->unique(["manager_id", "permission"]);
            });
        }
    }

    public function down(): void
    {
        Schema::dropIfExists("permissions_retirees");
    }
};
