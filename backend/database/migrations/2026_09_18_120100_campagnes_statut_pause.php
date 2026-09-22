<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

/** Une campagne peut etre mise en pause. */
return new class extends Migration
{
    public function up(): void
    {
        DB::statement("ALTER TABLE campagnes MODIFY statut ENUM('brouillon','programmee','en_cours','en_pause','terminee','annulee') NOT NULL DEFAULT 'brouillon'");
    }

    public function down(): void
    {
        DB::statement("UPDATE campagnes SET statut = 'en_cours' WHERE statut = 'en_pause'");
        DB::statement("ALTER TABLE campagnes MODIFY statut ENUM('brouillon','programmee','en_cours','terminee','annulee') NOT NULL DEFAULT 'brouillon'");
    }
};
