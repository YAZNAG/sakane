<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // Quartiers / secteurs d'une ville : HAY SALAM, HAY DAKHLA, HAY FOUNTY...
        Schema::create('secteurs', function (Blueprint $table) {
            $table->id();
            $table->string('nom', 120);
            $table->foreignId('city_id')->nullable()->constrained('cities')->nullOnDelete();
            $table->timestamps();

            // Un meme nom ne peut exister deux fois dans la meme ville.
            $table->unique(['nom', 'city_id']);
        });

        Schema::table('realstates', function (Blueprint $table) {
            $table->foreignId('secteur_id')->nullable()->after('city_id')
                ->constrained('secteurs')->nullOnDelete();
        });
    }

    public function down(): void
    {
        Schema::table('realstates', function (Blueprint $table) {
            $table->dropForeign(['secteur_id']);
            $table->dropColumn('secteur_id');
        });
        Schema::dropIfExists('secteurs');
    }
};
