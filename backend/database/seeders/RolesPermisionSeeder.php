<?php

namespace Database\Seeders;

use App\Models\Manager;
use Illuminate\Database\Console\Seeds\WithoutModelEvents;
use Illuminate\Database\Seeder;
use Spatie\Permission\Models\Permission;
use Spatie\Permission\Models\Role;

class RolesPermisionSeeder extends Seeder
{
    /**
     * Run the database seeds.
     */
    public function run(): void
    {
        Permission::where('guard_name', 'managers')->delete();
        Role::where('guard_name', 'managers')->delete();
        // Roles
        $admin = Role::create(['name' => 'admin', 'guard_name' => 'managers',]);
        $agent = Role::create(['name' => 'agent', 'guard_name' => 'managers',]);
        $cleaner = Role::create(['name' => 'nettoyeuse', 'guard_name' => 'managers',]);

        // // Permissions
        $permissions = [
            'create_property',
            'update_property',

            'create_reservation',
            'extend_reservation',
            'reduce_reservation',
            'confirm_checkout',
            'confirm_checkin',
            'view_reservations',

            'create_owner',
            'update_owner',
            'view_owners',

            'finish_cleaning',

            'create_charge',
            'view_charges',

            'create_client',
            'update_client',
            'view_clients',

            'view_users',
            'create_user',



            'view_available_properties',
            'view_reserved_properties',
            'view_cleaning_properties',
            'view_today_checkouts',

            'view_reports',
            'create_report',

            'view_reclamations',
            'create_reclamation',
            'close_reclamation',

            "view_slider",
            "create_slider",
            "activate_slider",
            "activate_announce",
            "cancel_announce",

            "view_stats",

            "view_contract",
            "create_contract"
        ];

        // Create permissions
        foreach ($permissions as $permission) {
            Permission::firstOrCreate(['name' => $permission, 'guard_name' => 'managers']);
        }

        // Assign permissions to roles
        $admin->givePermissionTo($permissions);
        $agent->givePermissionTo([
            'create_reservation',
            'extend_reservation',
            'reduce_reservation',
            'confirm_checkout',
            'confirm_checkin',
            'view_reservations',

            'create_client',
            'update_client',
            'view_clients',

            'view_available_properties',
            'view_reserved_properties',
            'view_cleaning_properties',
            'view_today_checkouts',

            'view_reclamations',
            'create_reclamation',
            'close_reclamation',

            'finish_cleaning',
        ]);
        $cleaner->givePermissionTo([
            'finish_cleaning',
            'view_cleaning_properties',
            'view_today_checkouts',


            'view_cleaning_properties',
            'view_today_checkouts',

            'view_reclamations',
            'create_reclamation',
        ]);

        $managers = Manager::all();
        foreach ($managers as $manager) {
            $manager->assignRole("admin");
        }
    }
}
