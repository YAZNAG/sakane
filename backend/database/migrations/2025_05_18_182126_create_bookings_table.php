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
        Schema::create('bookings', function (Blueprint $table) {
            $table->id();
            $table->date("checkin");
            $table->date("checkout");
            $table->integer("nb_days");
            $table->double("amount");
            $table->integer("nb_guest");
            $table->foreignId("status_id")->constrained("booking_statuses");
            $table->foreignId("payment_method")->nullable()->constrained("payment_methods");
            $table->foreignId("client_id")->constrained("users");
            $table->foreignId("realestate_id")->constrained("realstates");
            $table->foreignId("client_review_id")->nullable()->constrained("client_reviews");
            $table->foreignId("host_review_id")->nullable()->constrained("host_reviews");
            $table->timestamps();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('bookings');
    }
};
