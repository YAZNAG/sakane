<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

/** Un nouveau genre de caisse : la caisse Airbnb. */
return new class extends Migration
{
    public function up(): void
    {
        DB::statement("ALTER TABLE caisses MODIFY COLUMN type ENUM('agent','agence','banque','airbnb') NOT NULL DEFAULT 'agent'");
    }

    public function down(): void
    {
        DB::statement("ALTER TABLE caisses MODIFY COLUMN type ENUM('agent','agence','banque') NOT NULL DEFAULT 'agent'");
    }
};
