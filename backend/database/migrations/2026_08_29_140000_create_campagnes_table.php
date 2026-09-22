<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('campagnes', function (Blueprint $table) {
            $table->id();
            $table->string('titre', 160);
            $table->text('message');
            $table->string('lien', 500)->nullable();

            // Criteres de selection des destinataires, conserves pour
            // pouvoir reconstituer la liste et rejouer une campagne.
            $table->json('segment')->nullable();

            $table->enum('statut', [
                'brouillon',
                'programmee',
                'en_cours',
                'terminee',
                'annulee',
            ])->default('brouillon');

            $table->timestamp('planifiee_a')->nullable();
            $table->timestamp('demarree_a')->nullable();
            $table->timestamp('terminee_a')->nullable();

            $table->unsignedInteger('nb_destinataires')->default(0);
            $table->unsignedInteger('nb_envoyes')->default(0);
            $table->unsignedInteger('nb_echecs')->default(0);

            $table->foreignId('created_by')->nullable();
            $table->timestamps();

            $table->index(['statut', 'planifiee_a']);
        });

        Schema::create('campagne_destinataires', function (Blueprint $table) {
            $table->id();
            $table->foreignId('campagne_id')->constrained('campagnes')->cascadeOnDelete();
            $table->foreignId('client_id')->nullable();
            $table->string('telephone', 30);

            // Message reellement envoye, variables deja remplacees.
            $table->text('message_final');

            $table->enum('statut', ['en_attente', 'envoye', 'echec', 'ignore'])
                ->default('en_attente');
            $table->string('erreur', 500)->nullable();
            $table->timestamp('envoye_a')->nullable();
            $table->unsignedTinyInteger('tentatives')->default(0);
            $table->timestamps();

            // Un client ne peut figurer qu'une seule fois dans une campagne.
            $table->unique(['campagne_id', 'client_id']);
            // Ni deux fois le meme numero, si deux fiches le partagent.
            $table->unique(['campagne_id', 'telephone']);
            $table->index(['campagne_id', 'statut']);
        });

        Schema::table('users', function (Blueprint $table) {
            // Refus de recevoir des messages promotionnels.
            $table->boolean('accepte_promotions')->default(true)->after('tel');
        });
    }

    public function down(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->dropColumn('accepte_promotions');
        });
        Schema::dropIfExists('campagne_destinataires');
        Schema::dropIfExists('campagnes');
    }
};
