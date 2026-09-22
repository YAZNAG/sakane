<?php

namespace Database\Seeders;

use App\Models\BookingStatus;
use Illuminate\Database\Console\Seeds\WithoutModelEvents;
use Illuminate\Database\Seeder;

class BookingStatusSeeder extends Seeder
{
    /**
     * Run the database seeds.
     */
    public function run(): void
    {
        BookingStatus::create([
            "status" => "En attente",
            "code" => "pending"
        ]);
        BookingStatus::create([
            "status" => "Confirmé",
            "code" => "confirmed"
        ]);
        BookingStatus::create([
            "status" => "Rejetée",
            "code" => "rejected"
        ]);
        BookingStatus::create([
            "status" => "Payé",
            "code" => "payed"
        ]);
        BookingStatus::create([
            "status" => "Terminé",
            "code" => "completed"
        ]);
    }
}
