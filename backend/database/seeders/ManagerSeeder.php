<?php

namespace Database\Seeders;

use App\Models\Manager;
use Illuminate\Database\Console\Seeds\WithoutModelEvents;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\Hash;

class ManagerSeeder extends Seeder
{

    public function run(): void
    {
        Manager::create([
            "first_name" => "Saad",
            "last_name" => "el",
            "email" => "elsaadev@gmail.com",
            "password" => Hash::make("password")
        ]);
    }
}
