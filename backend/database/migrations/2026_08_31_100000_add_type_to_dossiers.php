<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('dossiers', function (Blueprint $table) {
            // Famille de biens a laquelle le dossier appartient :
            // rent-short, rent-long ou selle.
            $table->string('type_code', 20)->nullable()->after('description');
        });

        // Le nom n'est unique qu'au sein d'une famille : "Immeuble A"
        // peut exister a la fois en location et en vente.
        Schema::table('dossiers', function (Blueprint $table) {
            $table->dropUnique(['nom']);
            $table->unique(['nom', 'type_code']);
        });

        // Les dossiers deja crees prennent la famille de leurs biens,
        // lorsqu'elle est sans ambiguite.
        foreach (DB::table('dossiers')->pluck('id') as $id) {
            $types = DB::table('realstates')
                ->join('type_transactions', 'type_transactions.id', '=', 'realstates.transaction_id')
                ->where('realstates.dossier_id', $id)
                ->distinct()
                ->pluck('type_transactions.code');

            if ($types->count() === 1) {
                DB::table('dossiers')->where('id', $id)
                    ->update(['type_code' => $types->first()]);
            }
        }
    }

    public function down(): void
    {
        Schema::table('dossiers', function (Blueprint $table) {
            $table->dropUnique(['nom', 'type_code']);
            $table->dropColumn('type_code');
            $table->unique('nom');
        });
    }
};
