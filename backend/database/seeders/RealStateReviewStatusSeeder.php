<?php

namespace Database\Seeders;

use App\Models\RealstateReviewStatus;
use Illuminate\Database\Console\Seeds\WithoutModelEvents;
use Illuminate\Database\Seeder;

class RealStateReviewStatusSeeder extends Seeder
{
    /**
     * Run the database seeds.
     */
    public function run(): void
    {
        RealstateReviewStatus::create([
            "status"=>"En révision",
            "code"=>"in-review"
        ]);
        RealstateReviewStatus::create([
            "status"=>"légale",
            "code"=>"legal"
        ]);
        RealstateReviewStatus::create([
            "status"=>"illégale",
            "code"=>"illegal"
        ]);
    }
}
