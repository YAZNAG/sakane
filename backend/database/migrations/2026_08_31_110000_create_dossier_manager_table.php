<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('dossier_manager', function (Blueprint $table) {
            $table->id();
            $table->foreignId('dossier_id')->constrained('dossiers')->cascadeOnDelete();
            $table->foreignId('manager_id')->constrained('managers')->cascadeOnDelete();
            $table->timestamps();

            // Un agent n'est affecte qu'une fois au meme dossier.
            $table->unique(['dossier_id', 'manager_id']);
            $table->index('manager_id');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('dossier_manager');
    }
};
