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
        Schema::create('host_reviews', function (Blueprint $table) {
            $table->id();
            $table->double("rate")->default(0);
            $table->string("comment",250);
            $table->double("cleanliness")->default(0);
            $table->double("communication")->default(0);
            $table->double("observance_house_rules")->default(0);
            $table->foreignId("host_id")->constrained('users');
            $table->timestamps();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('host_reviews');
    }
};
