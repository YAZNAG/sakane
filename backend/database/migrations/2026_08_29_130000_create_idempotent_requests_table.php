<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('idempotent_requests', function (Blueprint $table) {
            $table->id();
            // Cle fournie par l'application, unique par operation.
            $table->string('cle', 80)->unique();
            $table->string('methode', 10);
            $table->string('chemin', 191);
            $table->unsignedSmallInteger('status_code');
            $table->longText('reponse')->nullable();
            $table->foreignId('manager_id')->nullable();
            $table->timestamps();

            $table->index('created_at');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('idempotent_requests');
    }
};
