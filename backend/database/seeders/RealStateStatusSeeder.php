<?php

namespace Database\Seeders;

use App\Models\RealstateStatus;
use Illuminate\Database\Console\Seeds\WithoutModelEvents;
use Illuminate\Database\Seeder;

class RealStateStatusSeeder extends Seeder
{
    /**
     * Run the database seeds.
     */
    public function run(): void
    {
        RealstateStatus::create([
            "status" => "Actif",
            "code" => "active",
        ]);
        RealstateStatus::create([
            "status" => "En attente",
            "code" => "pending",
        ]);
        RealstateStatus::create([
            "status" => "En pause",
            "code" => "paused",
        ]);
        RealstateStatus::create([
            "status" => "En maintenance",
            "code" => "maintenance",
        ]);
    }
}
