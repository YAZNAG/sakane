<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('whatsapp_messages', function (Blueprint $table) {
            // Texte d'origine, conserve pour pouvoir revenir en arriere.
            $table->text('defaut')->nullable()->after('message');
            $table->string('description', 300)->nullable()->after('defaut');
            $table->string('categorie', 60)->default('general')->after('description');
            $table->json('variables')->nullable()->after('categorie');
            $table->string('langue', 5)->default('fr')->after('variables');
            $table->boolean('actif')->default(true)->after('langue');
            $table->foreignId('updated_by')->nullable()->after('actif');
        });

        // Les modeles deja en base deviennent leur propre valeur d'origine.
        DB::statement("UPDATE whatsapp_messages SET defaut = message WHERE defaut IS NULL");

        Schema::table('whatsapp_messages', function (Blueprint $table) {
            $table->unique(['code', 'langue']);
        });

        Schema::create('whatsapp_message_historique', function (Blueprint $table) {
            $table->id();
            $table->foreignId('whatsapp_message_id')
                ->constrained('whatsapp_messages')->cascadeOnDelete();
            $table->text('contenu_avant')->nullable();
            $table->text('contenu_apres');
            $table->foreignId('manager_id')->nullable();
            $table->timestamps();

            $table->index('whatsapp_message_id');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('whatsapp_message_historique');
        Schema::table('whatsapp_messages', function (Blueprint $table) {
            $table->dropUnique(['code', 'langue']);
            $table->dropColumn([
                'defaut', 'description', 'categorie',
                'variables', 'langue', 'actif', 'updated_by',
            ]);
        });
    }
};
