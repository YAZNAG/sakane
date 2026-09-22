<?php

namespace Database\Seeders;

use Illuminate\Database\Console\Seeds\WithoutModelEvents;
use Illuminate\Database\Seeder;
use Spatie\Permission\Models\Permission;
use Spatie\Permission\Models\Role;

class AddDeleteClientSeeder extends Seeder
{
    /**
     * Run the database seeds.
     */
    public function run(): void
    {
        Permission::firstOrCreate(['name' => "delete_client", 'guard_name' => 'managers']);
        $admin = Role::where(['name' => 'admin', 'guard_name' => 'managers'])->first();
        if ($admin) {
            $admin->givePermissionTo("delete_client");
        }
    }
}
