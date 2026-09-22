<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('rappels', function (Blueprint $table) {
            $table->id();
            $table->string('code', 60)->unique();
            $table->string('libelle', 120);

            // Point de reference : arrivee du client ou fin du sejour.
            $table->enum('moment', ['checkin', 'checkout'])->default('checkin');

            // Decalage en heures : negatif avant, positif apres.
            // -72 = trois jours avant l'arrivee, +3 = trois heures apres le depart.
            $table->integer('decalage_heures');

            $table->boolean('vers_client')->default(true);
            $table->boolean('vers_agent')->default(false);

            // Codes des modeles de messages utilises.
            $table->string('modele_client', 60)->nullable();
            $table->string('modele_agent', 60)->nullable();

            $table->boolean('actif')->default(true);
            $table->unsignedSmallInteger('ordre')->default(0);
            $table->timestamps();

            $table->index(['actif', 'moment']);
        });

        Schema::create('rappels_envoyes', function (Blueprint $table) {
            $table->id();
            $table->foreignId('booking_id')->constrained('bookings')->cascadeOnDelete();
            $table->foreignId('rappel_id')->constrained('rappels')->cascadeOnDelete();
            $table->enum('destinataire', ['client', 'agent']);
            $table->string('telephone', 30)->nullable();

            $table->enum('statut', ['a_envoyer', 'envoye', 'echec'])->default('a_envoyer');
            $table->string('erreur', 500)->nullable();
            $table->timestamp('envoye_a')->nullable();
            $table->unsignedTinyInteger('tentatives')->default(0);
            $table->timestamps();

            // Un rappel ne part qu'une fois par reservation et par destinataire.
            $table->unique(['booking_id', 'rappel_id', 'destinataire'], 'rappel_unique');
            $table->index(['statut']);
        });

        Schema::table('bookings', function (Blueprint $table) {
            // Avance encaissee et caution, utilisees par les rappels
            // comme par le bulletin d'hebergement.
            $table->decimal('avance', 10, 2)->default(0)->after('amount');
            $table->decimal('caution', 10, 2)->default(0)->after('avance');
            $table->text('remarques')->nullable()->after('caution');
        });
    }

    public function down(): void
    {
        Schema::table('bookings', function (Blueprint $table) {
            $table->dropColumn(['avance', 'caution', 'remarques']);
        });
        Schema::dropIfExists('rappels_envoyes');
        Schema::dropIfExists('rappels');
    }
};
