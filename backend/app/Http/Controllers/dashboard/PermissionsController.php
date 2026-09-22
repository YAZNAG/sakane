<?php

namespace App\Http\Controllers\dashboard;

use App\Http\Controllers\Controller;
use App\Models\Manager;
use App\Services\CataloguePermissions;
use App\utils\JsonResponses;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Validator;
use Spatie\Permission\Models\Permission;
use Spatie\Permission\Models\Role;
use Spatie\Permission\PermissionRegistrar;

/**
 * Les droits de chaque role, et les exceptions de chaque utilisateur.
 *
 * Par role : la liste des droits du role. Par utilisateur : des droits
 * accordes en plus de son role, ou retires malgre son role. Le role
 * « admin » et ses utilisateurs gardent tous les droits : ils ne sont pas
 * modifiables, pour qu aucune manipulation ne prive l agence de son acces.
 */
class PermissionsController extends Controller
{
    use JsonResponses;

    private const GUARD = "managers";

    private function refuser(Request $request)
    {
        return $request->user()?->hasRole("admin") ? null
            : $this->jsonResponse(false, self::NO_ACCESS, 403, ["msg" => ["Les droits se règlent depuis un compte administrateur."]]);
    }

    private static function roleTableau(Role $r, array $compte): array
    {
        return [
            "nom" => $r->name,
            "libelle" => CataloguePermissions::ROLES[$r->name] ?? ucfirst($r->name),
            "utilisateurs" => $compte[$r->name] ?? 0,
            "modifiable" => $r->name !== "admin",
            "permissions" => $r->permissions->pluck("name")->values()->all(),
        ];
    }

    private static function retires(int $id): array
    {
        return DB::table("permissions_retirees")->where("manager_id", $id)->pluck("permission")->all();
    }

    private static function utilisateurResume(Manager $m): array
    {
        $roles = $m->roles->pluck("name")->all();
        $admin = in_array("admin", $roles, true);
        $accordes = $m->permissions->pluck("name")->all();
        $retires = static::retires($m->id);
        return [
            "id" => $m->id,
            "nom" => trim(($m->first_name ?? "") . " " . ($m->last_name ?? "")) ?: ("Utilisateur #" . $m->id),
            "roles" => $roles,
            "rolesLibelles" => array_map(fn($r) => CataloguePermissions::ROLES[$r] ?? ucfirst($r), $roles),
            "admin" => $admin,
            "modifiable" => !$admin,
            "accordes" => count($accordes),
            "retires" => count($retires),
            "personnalise" => !$admin && (count($accordes) + count($retires)) > 0,
        ];
    }

    public function afficher(Request $request)
    {
        if ($refus = $this->refuser($request)) return $refus;
        $managers = Manager::with(["roles", "permissions"])->orderBy("first_name")->get();
        $compte = $managers->flatMap(fn($m) => $m->roles->pluck("name"))->countBy()->all();
        $roles = Role::with("permissions")->where("guard_name", self::GUARD)->orderBy("name")->get();
        return $this->successResponse([
            "modules" => CataloguePermissions::modules(self::GUARD),
            "roles" => $roles->map(fn($r) => static::roleTableau($r, $compte))->values(),
            "utilisateurs" => $managers->map(fn($m) => static::utilisateurResume($m))->values(),
            "totalDroits" => Permission::where("guard_name", self::GUARD)->count(),
        ]);
    }

    /** Remplace les droits d un role par ceux envoyes. */
    public function modifier(Request $request, $role)
    {
        if ($refus = $this->refuser($request)) return $refus;
        $r = Role::where("guard_name", self::GUARD)->where("name", $role)->first();
        if (!$r) return $this->notFoundResponse("Rôle introuvable");
        if ($r->name === "admin") {
            return $this->validationErrorResponse(["msg" => ["Le rôle administrateur garde tous les droits : il n'est pas modifiable."]]);
        }
        $v = Validator::make($request->all(), [
            "permissions" => ["present", "array"],
            "permissions.*" => ["string", "max:100"],
        ]);
        if ($v->fails()) return $this->validationErrorResponse($v->errors());

        $demandes = array_values(array_unique((array) $request->input("permissions", [])));
        if ($inconnus = $this->inconnus($demandes)) {
            return $this->validationErrorResponse(["permissions" => ["Droits inconnus : " . implode(", ", $inconnus)]]);
        }
        $r->syncPermissions($demandes);
        app(PermissionRegistrar::class)->forgetCachedPermissions();

        $compte = Manager::with("roles")->get()->flatMap(fn($m) => $m->roles->pluck("name"))->countBy()->all();
        return $this->successResponse(static::roleTableau($r->fresh("permissions"), $compte));
    }

    private function inconnus(array $noms): array
    {
        $connus = Permission::where("guard_name", self::GUARD)->pluck("name")->all();
        return array_values(array_diff($noms, $connus));
    }

    /**
     * Les droits d un utilisateur, un par un : ce que donne son role, ce
     * qui lui est accorde en plus, ce qui lui est retire, et le resultat.
     */
    public function utilisateur(Request $request, $id)
    {
        if ($refus = $this->refuser($request)) return $refus;
        $m = Manager::with(["roles.permissions", "permissions"])->find($id);
        if (!$m) return $this->notFoundResponse("Utilisateur introuvable");

        $parRole = $m->roles->flatMap(fn($r) => $r->permissions->pluck("name"))->unique()->values()->all();
        $accordes = $m->permissions->pluck("name")->values()->all();
        $retires = static::retires($m->id);
        $effectifs = $m->getAllPermissions()->pluck("name")->values()->all();

        return $this->successResponse(array_merge(static::utilisateurResume($m), [
            "parRole" => $parRole,
            "listeAccordes" => $accordes,
            "listeRetires" => $retires,
            "effectifs" => $effectifs,
        ]));
    }

    /**
     * Enregistre les exceptions d un utilisateur : droits accordes en plus
     * de son role, droits retires malgre son role.
     */
    public function modifierUtilisateur(Request $request, $id)
    {
        if ($refus = $this->refuser($request)) return $refus;
        $m = Manager::with("roles")->find($id);
        if (!$m) return $this->notFoundResponse("Utilisateur introuvable");
        if ($m->hasRole("admin")) {
            return $this->validationErrorResponse(["msg" => ["Un administrateur garde tous les droits : ses accès ne se règlent pas un par un."]]);
        }
        $v = Validator::make($request->all(), [
            "accordes" => ["present", "array"],
            "accordes.*" => ["string", "max:100"],
            "retires" => ["present", "array"],
            "retires.*" => ["string", "max:100"],
        ]);
        if ($v->fails()) return $this->validationErrorResponse($v->errors());

        $accordes = array_values(array_unique((array) $request->input("accordes", [])));
        $retires = array_values(array_unique((array) $request->input("retires", [])));
        if ($inconnus = $this->inconnus(array_merge($accordes, $retires))) {
            return $this->validationErrorResponse(["msg" => ["Droits inconnus : " . implode(", ", $inconnus)]]);
        }
        if ($deux = array_values(array_intersect($accordes, $retires))) {
            return $this->validationErrorResponse(["msg" => ["Un droit ne peut pas être à la fois accordé et retiré : " . implode(", ", $deux)]]);
        }

        DB::transaction(function () use ($m, $accordes, $retires) {
            $m->syncPermissions($accordes);
            DB::table("permissions_retirees")->where("manager_id", $m->id)->delete();
            $maintenant = now();
            DB::table("permissions_retirees")->insert(array_map(fn($p) => [
                "manager_id" => $m->id, "permission" => $p, "created_at" => $maintenant, "updated_at" => $maintenant,
            ], $retires));
        });
        app(PermissionRegistrar::class)->forgetCachedPermissions();

        return $this->utilisateur($request, $m->id);
    }
}
