<?php

namespace Database\Seeders;

use App\Models\Region;
use Illuminate\Database\Console\Seeds\WithoutModelEvents;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\File;

class RegionSeeder extends Seeder
{
    /**
     * Run the database seeds.
     */
    public function run(): void
    {
        $region_path = database_path("/files/regions.json");
        $data = json_decode(File::get($region_path), true);
        foreach ($data["regions"]["data"] as $row) {
            Region::create([
                "name" => $row["names"]["fr"],
                "country_id" => 1
            ]);
        }
    }
}
