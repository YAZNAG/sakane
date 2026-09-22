<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    public function up(): void
    {
        DB::statement("ALTER TABLE financial_transactions MODIFY COLUMN type ENUM('income','expense','refund','cancellation','expense_reversal')");
    }

    public function down(): void
    {
        DB::table('financial_transactions')->where('type', 'expense_reversal')->delete();
        DB::statement("ALTER TABLE financial_transactions MODIFY COLUMN type ENUM('income','expense','refund','cancellation')");
    }
};
