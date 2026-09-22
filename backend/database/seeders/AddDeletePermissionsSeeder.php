<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use Spatie\Permission\Models\Permission;
use Spatie\Permission\Models\Role;

class AddDeletePermissionsSeeder extends Seeder
{
    public function run(): void
    {
        $newPermissions = [
            'delete_charge',
            'delete_reservation',
            'delete_property',
            'delete_owner',
            'delete_user',
        ];

        foreach ($newPermissions as $perm) {
            Permission::firstOrCreate(['name' => $perm, 'guard_name' => 'managers']);
        }

        $admin = Role::where(['name' => 'admin', 'guard_name' => 'managers'])->first();
        if ($admin) {
            $admin->givePermissionTo($newPermissions);
        }

        $agent = Role::where(['name' => 'agent', 'guard_name' => 'managers'])->first();
        if ($agent) {
            $agent->givePermissionTo(['view_charges', 'create_charge']);
        }
    }
}
