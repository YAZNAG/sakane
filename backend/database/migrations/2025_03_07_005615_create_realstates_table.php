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
        Schema::create('realstates', function (Blueprint $table) {
            $table->id();
            $table->string("title", 250);
            $table->string("description", 500);
            $table->integer("surface");
            $table->double("price");
            $table->string("address", 250);
            $table->date("date_construction")->nullable();
            $table->smallInteger("nb_etage")->nullable();
            $table->smallInteger("nb_rooms")->nullable();
            $table->smallInteger("etage")->nullable();
            $table->smallInteger("nb_bathroom")->nullable();
            $table->double("rate")->default(0);
            $table->integer("nb_raters")->default(0);
            $table->double("latitude")->nullable();
            $table->double("longitude")->nullable();
            $table->foreignId("category_id")->constrained("realstate_categories");
            $table->foreignId("transaction_id")->constrained("type_transactions");
            $table->foreignId("owner_id")->nullable()->constrained("owners");
            $table->foreignId("host_id")->constrained("users");
            $table->foreignId("status_id")->constrained("realstate_status");
            $table->foreignId("review_status_id")->constrained("realstate_status");
            $table->foreignId("city_id")->constrained("cities");
            $table->foreignId("etat_id")->nullable()->constrained("realstate_etats");
            $table->timestamps();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('realstates');
    }
};
