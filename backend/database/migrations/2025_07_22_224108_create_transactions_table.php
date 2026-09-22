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
        Schema::create('transactions', function (Blueprint $table) {
            $table->id();
            $table->double("amount");
            $table->json("details")->nullable();
            $table->foreignId("user_id")->constrained("users");
            $table->foreignId("operation_id")->constrained("operation_types");
            $table->foreignId("booking_id")->nullable()->constrained("bookings");
            $table->timestamps();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('transactions');
    }
};
