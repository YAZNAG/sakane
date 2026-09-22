<?php

namespace Database\Seeders;

use App\Models\OperationType;
use App\Models\Slider;
use App\Models\TypeBooking;
use App\Models\TypeTransaction;
use App\Models\User;
// use Illuminate\Database\Console\Seeds\WithoutModelEvents;
use Illuminate\Database\Seeder;

class DatabaseSeeder extends Seeder
{
    /**
     * Seed the application's database.
     */
    public function run(): void
    {
        // $this->call(UserTypesSeeder::class);
        // $this->call(TypeTransactionSeeder::class);
        // $this->call(RealestateCategorySeeder::class);
        // $this->call(RealestateEtatSeeder::class);
        // $this->call(CountrySeeder::class);
        // $this->call(RegionSeeder::class);
        // $this->call(CitySeeder::class);
        // $this->call(RealStateReviewStatusSeeder::class);
        // $this->call(RealStateStatusSeeder::class);
        // $this->call(FeatureSeeder::class);
        // $this->call(BookingStatusSeeder::class);
        // $this->call(PaymentMethodSeeder::class);
        // $this->call(AgenceUserSeeder::class);
        // $this->call(OperationTypeSeeder::class);
        // $this->call(AppParamSeeder::class);
        // $this->call(ManagerSeeder::class);
        // $this->call(TypeBookingSeeder::class);
        //$this->call(WhatsappMessageSeeder::class);
        //$this->call(RolesPermisionSeeder::class);
        $this->call(AddDeletePermissionsSeeder::class);
        $this->call(AddDeleteClientSeeder::class);
    }
}
