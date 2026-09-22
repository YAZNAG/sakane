<?php

namespace Database\Seeders;

use App\Models\City;
use Illuminate\Database\Console\Seeds\WithoutModelEvents;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\File;

class CitySeeder extends Seeder
{
    /**
     * Run the database seeds.
     */
    public function run(): void
    {
        $cities_path = database_path("/files/cities.json");
        $json = File::get($cities_path);
        $data = json_decode($json, true);
        foreach ($data["cities"]["data"] as $row) {
            City::create([
                "region_id" => $row["region_id"],
                "name" => $row["names"]["fr"]
            ]);
        }
    }
}
