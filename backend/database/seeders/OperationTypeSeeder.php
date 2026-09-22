<?php

namespace Database\Seeders;

use App\Models\OperationType;
use Illuminate\Database\Console\Seeds\WithoutModelEvents;
use Illuminate\Database\Seeder;

class OperationTypeSeeder extends Seeder
{
    /**
     * Run the database seeds.
     */
    public function run(): void
    {
        $data = [
            [
                "type" => "Paiement réussi",
                "code" => "success-payment"
            ],
            [
                "type" => "Paiement en attente",
                "code" => "payment-on-hold"
            ],
            [
                "type" => "Transfert",
                "code" => "transfert"
            ],
        ];
        OperationType::insert($data);
    }
}
