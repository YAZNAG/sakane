<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Les sessions de caisse : une caisse ouverte, puis close.
 *
 * Le numero est propre au detenteur - sa premiere caisse, sa deuxieme -
 * pour qu'un agent parle de "ma caisse n 3" sans avoir a citer un
 * identifiant global.
 */
return new class extends Migration
{
    public function up(): void
    {
        if (!Schema::hasTable("sessions_caisse")) {
            Schema::create("sessions_caisse", function (Blueprint $table) {
                $table->id();
                $table->unsignedBigInteger("caisse_id")->index();
                $table->unsignedInteger("numero")->default(1);
                $table->decimal("montant_ouverture", 12, 2)->default(0);
                // Vrai lorsque le fond vient du montant compte a la
                // cloture precedente, faux lorsqu'il a ete saisi.
                $table->boolean("reporte")->default(false);
                $table->timestamp("ouverte_le")->index();
                $table->unsignedBigInteger("ouverte_par")->nullable();
                $table->timestamp("close_le")->nullable();
                $table->unsignedBigInteger("cloturage_id")->nullable();
                $table->timestamps();

                $table->index(["caisse_id", "close_le"]);
            });
        }

        Schema::table("mouvements_caisse", function (Blueprint $table) {
            if (!Schema::hasColumn("mouvements_caisse", "session_id")) {
                $table->unsignedBigInteger("session_id")->nullable()->index()->after("caisse_id");
            }
        });

        Schema::table("cloturages_caisse", function (Blueprint $table) {
            if (!Schema::hasColumn("cloturages_caisse", "session_id")) {
                $table->unsignedBigInteger("session_id")->nullable()->index()->after("caisse_id");
            }
        });
    }

    public function down(): void
    {
        Schema::table("mouvements_caisse", function (Blueprint $table) {
            $table->dropColumn("session_id");
        });
        Schema::table("cloturages_caisse", function (Blueprint $table) {
            $table->dropColumn("session_id");
        });
        Schema::dropIfExists("sessions_caisse");
    }
};
