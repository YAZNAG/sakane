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
        Schema::create('contracts', function (Blueprint $table) {
            $table->id();
            $table->text("note")->nullable();
            $table->foreignId("owner_id")->nullable()->constrained("owners");
            $table->foreignId("client_id")->nullable()->constrained("users");
            $table->foreignId("realestate_id")->nullable()->constrained("realstates");
            $table->dateTime('signed_date');
            $table->dateTime('expiration_date');
            $table->timestamps();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('contracts');
    }
};
