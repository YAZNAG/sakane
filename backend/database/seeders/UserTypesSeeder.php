<?php

namespace Database\Seeders;

use App\Models\UserType;
use Illuminate\Database\Console\Seeds\WithoutModelEvents;
use Illuminate\Database\Seeder;

class UserTypesSeeder extends Seeder
{
    /**
     * Run the database seeds.
     */
    public function run(): void
    {
        UserType::create([
            "type" => "Client",
            "code" => "client"
        ],);
        UserType::create([
            "type" => "Host",
            "code" => "host"
        ],);
    }
}
