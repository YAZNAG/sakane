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
        Schema::create('programed_charges', function (Blueprint $table) {
            $table->id();
            $table->string("nom");
            $table->string("description");
            $table->double("amount");
            $table->enum("type", ["week", "month", "year"]);
            $table->integer("month")->nullable();
            $table->integer("day")->nullable();
            $table->enum("day_name", ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"])->nullable();
            $table->foreignId("realestate_id")->nullable()->constrained("realstates");
            $table->timestamps();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('programed_charges');
    }
};
