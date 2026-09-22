<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/** Le contrat cree depuis une reservation Airbnb : le lien dans les deux sens. */
return new class extends Migration
{
    public function up(): void
    {
        if (!Schema::hasColumn("airbnb_sejours", "booking_id")) {
            Schema::table("airbnb_sejours", fn(Blueprint $t) => $t->unsignedBigInteger("booking_id")->nullable()->index()->after("lien"));
        }
        if (!Schema::hasColumn("bookings", "airbnb_uid")) {
            Schema::table("bookings", fn(Blueprint $t) => $t->string("airbnb_uid", 255)->nullable()->after("realestate_id"));
        }
    }

    public function down(): void
    {
        Schema::table("airbnb_sejours", fn(Blueprint $t) => $t->dropColumn("booking_id"));
        Schema::table("bookings", fn(Blueprint $t) => $t->dropColumn("airbnb_uid"));
    }
};
