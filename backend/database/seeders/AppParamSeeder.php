<?php

namespace Database\Seeders;

use App\Models\AppParam;
use Illuminate\Database\Console\Seeds\WithoutModelEvents;
use Illuminate\Database\Seeder;

class AppParamSeeder extends Seeder
{
    /**
     * Run the database seeds.
     */
    public function run(): void
    {
        AppParam::create([
            "name" => "platform-percentage",
            "value" => "20"
        ]);
    }
}
