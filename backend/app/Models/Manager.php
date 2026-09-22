<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\SoftDeletes;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Laravel\Sanctum\HasApiTokens;
use Spatie\Permission\Traits\HasRoles;

class Manager extends Authenticatable
{
    use HasApiTokens, SoftDeletes;
    use HasRoles {
        hasPermissionTo as protected droitSelonRoles;
        getAllPermissions as protected droitsSelonRoles;
    }

    /** Droits retires a cet utilisateur, meme si son role les lui donne. */
    private ?array $droitsRetiresCache = null;

    public function droitsRetires(): array
    {
        if ($this->hasRole("admin")) {
            return [];
        }
        if ($this->droitsRetiresCache === null) {
            $this->droitsRetiresCache = \Illuminate\Support\Facades\Schema::hasTable("permissions_retirees")
                ? \Illuminate\Support\Facades\DB::table("permissions_retirees")->where("manager_id", $this->id)->pluck("permission")->all()
                : [];
        }
        return $this->droitsRetiresCache;
    }

    public function hasPermissionTo($permission, $guardName = null): bool
    {
        $nom = is_string($permission) ? $permission : ($permission->name ?? null);
        if ($nom !== null && in_array($nom, $this->droitsRetires(), true)) {
            return false;
        }
        return $this->droitSelonRoles($permission, $guardName);
    }

    public function getAllPermissions(): \Illuminate\Support\Collection
    {
        $retires = $this->droitsRetires();
        return $this->droitsSelonRoles()->reject(fn($p) => in_array($p->name, $retires, true))->values();
    }

    protected $fillable = [
        "first_name",
        "last_name",
        "fcm_token",
        "password",
        "email",
        "phone"
    ];

    /** Dossiers auxquels cet agent a acces. */
    public function dossiers()
    {
        return $this->belongsToMany(Dossier::class, "dossier_manager");
    }

    /**
     * Identifiants des dossiers accessibles, ou null si l'acces n'est
     * pas restreint : administrateur, ou agent sans affectation.
     */
    public function dossiersAutorises(): ?array
    {
        if ($this->hasRole("admin")) {
            return null;
        }

        $ids = $this->dossiers()->pluck("dossiers.id")->all();

        return empty($ids) ? null : $ids;
    }

}
