<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // Trois etats : a nettoyer, en cours de nettoyage, propre
        DB::statement("ALTER TABLE realstates MODIFY COLUMN cleaning_status ENUM('to_clean','cleaning','cleaned')");

        Schema::table('realstates', function (Blueprint $table) {
            // heure du depart du client, distincte du debut effectif du menage
            $table->timestamp('checkout_at')->nullable()->after('cleaning_status');
        });

        // Les appartements actuellement en nettoyage passent en attente :
        // la femme de menage declarera le debut proprement.
        DB::table('realstates')
            ->where('cleaning_status', 'cleaning')
            ->update([
                'cleaning_status'     => 'to_clean',
                'checkout_at'         => DB::raw('cleaning_started_at'),
                'cleaning_started_at' => null,
            ]);
    }

    public function down(): void
    {
        DB::table('realstates')->where('cleaning_status', 'to_clean')
            ->update(['cleaning_status' => 'cleaning']);
        DB::statement("ALTER TABLE realstates MODIFY COLUMN cleaning_status ENUM('cleaning','cleaned')");
        Schema::table('realstates', function (Blueprint $table) {
            $table->dropColumn('checkout_at');
        });
    }
};
