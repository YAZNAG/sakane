<?php

namespace Database\Seeders;

use App\Models\TypeBooking;
use Illuminate\Database\Console\Seeds\WithoutModelEvents;
use Illuminate\Database\Seeder;

class TypeBookingSeeder extends Seeder
{
    /**
     * Run the database seeds.
     */
    public function run(): void
    {
        TypeBooking::create([
            "type" => "Platform",
            "code" => "platform"
        ]);
        TypeBooking::create([
            "type" => "Monde réel",
            "code" => "realworld"
        ]);
    }
}
