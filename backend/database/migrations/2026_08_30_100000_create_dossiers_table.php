<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('dossiers', function (Blueprint $table) {
            $table->id();
            $table->string('nom', 120);
            $table->string('description', 300)->nullable();

            // Ordre d'affichage choisi par l'administrateur.
            $table->unsignedSmallInteger('ordre')->default(0);

            $table->foreignId('created_by')->nullable();
            $table->timestamps();

            $table->unique('nom');
        });

        Schema::table('realstates', function (Blueprint $table) {
            // Un bien appartient a un dossier au plus. La suppression du
            // dossier ne supprime pas les biens : ils redeviennent libres.
            $table->foreignId('dossier_id')->nullable()->after('secteur_id')
                ->constrained('dossiers')->nullOnDelete();
        });
    }

    public function down(): void
    {
        Schema::table('realstates', function (Blueprint $table) {
            $table->dropForeign(['dossier_id']);
            $table->dropColumn('dossier_id');
        });
        Schema::dropIfExists('dossiers');
    }
};
