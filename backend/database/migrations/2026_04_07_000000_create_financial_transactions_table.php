<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('financial_transactions', function (Blueprint $table) {
            $table->id();
            $table->enum('type', ['income', 'expense', 'refund', 'cancellation']);
            $table->decimal('amount', 12, 2);
            $table->string('description');
            $table->foreignId('realestate_id')->nullable()->constrained('realstates')->nullOnDelete();
            $table->foreignId('booking_id')->nullable()->constrained('bookings')->nullOnDelete();
            $table->foreignId('charge_id')->nullable()->constrained('charges')->nullOnDelete();
            $table->date('transaction_date');
            $table->timestamps();

            $table->index(['realestate_id', 'transaction_date']);
            $table->index('transaction_date');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('financial_transactions');
    }
};
