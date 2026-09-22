<?php

namespace Database\Seeders;

use App\Models\User;
use App\Models\UserType;
use Carbon\Carbon;
use Illuminate\Database\Console\Seeds\WithoutModelEvents;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\Hash;

class AgenceUserSeeder extends Seeder
{
    /**
     * Run the database seeds.
     */
    public function run(): void
    {
        $type = UserType::where("code", "=", "host")->first()->id;
        User::create([
            "first_name" => "Vacances",
            "last_name" => "Agadir",
            "tel" => "0600000000",
            "address" => "Address",
            "email" => "mohamed.babakhyi@gmail.com",
            "password" => Hash::make("password"),
            "type_id" => $type,
            "agence" => true,
            "identity_status" => "valid",
            "email_verified_at" => Carbon::now(),
            "city_id" => 255
        ]);
    }
}
