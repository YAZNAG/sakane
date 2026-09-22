<?php

namespace Database\Seeders;

use App\Models\RealstateCategory;
use Illuminate\Database\Console\Seeds\WithoutModelEvents;
use Illuminate\Database\Seeder;

class RealestateCategorySeeder extends Seeder
{
    /**
     * Run the database seeds.
     */
    public function run(): void
    {
        RealstateCategory::create([
            "category"=>"Appartements",
            "code"=>"appartements"
        ]);
        RealstateCategory::create([
            "category"=>"Maisons",
            "code"=>"maisons"
        ]);
        RealstateCategory::create([
            "category"=>" Villas & maisons de luxe",
            "code"=>"villa-ml"
        ]);
        RealstateCategory::create([
            "category"=>"Riad",
            "code"=>"riad"
        ]);
        RealstateCategory::create([
            "category"=>"Locaux commerciaux",
            "code"=>"locaux-commerciaux"
        ]);
        RealstateCategory::create([
            "category"=>"Bureaux",
            "code"=>"bureaux"
        ]);
        RealstateCategory::create([
            "category"=>"Terrains",
            "code"=>"terrains"
        ]);
        RealstateCategory::create([
            "category"=>"Fermes",
            "code"=>"fermes"
        ]);
    }
}
