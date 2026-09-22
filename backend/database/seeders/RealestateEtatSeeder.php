<?php

namespace Database\Seeders;

use App\Models\RealstateEtat;
use Illuminate\Database\Console\Seeds\WithoutModelEvents;
use Illuminate\Database\Seeder;

class RealestateEtatSeeder extends Seeder
{
    /**
     * Run the database seeds.
     */
    public function run(): void
    {
        RealstateEtat::create(
            [
                "etat" => "Nouveau",
                "code" => "nouveau"
            ]
        );
        RealstateEtat::create(
            [
                "etat" => "Bon état",
                "code" => "bon-etat"
            ]
        );
        RealstateEtat::create(
            [
                "etat" => "À rénover",
                "code" => "renover"
            ]
        );
    }
}
