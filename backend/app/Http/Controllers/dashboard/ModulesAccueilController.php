<?php

namespace App\Http\Controllers\dashboard;

use App\Http\Controllers\Controller;
use App\utils\JsonResponses;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Validator;

/**
 * Les modules de l'accueil de chaque utilisateur : affiches ou masques, et
 * leur nom. L'organisation (ordre, dossiers, barre du bas) reste a
 * AccueilController ; seule la colonne « modules » est lue et ecrite ici.
 */
class ModulesAccueilController extends Controller
{
    use JsonResponses;

    private static function lireModules(int $managerId): array
    {
        $v = DB::table("preferences_accueil")->where("manager_id", $managerId)->value("modules");
        return json_decode((string) $v, true) ?: [];
    }

    private static function ecrire(int $managerId, ?string $modules): void
    {
        if (DB::table("preferences_accueil")->where("manager_id", $managerId)->exists()) {
            DB::table("preferences_accueil")->where("manager_id", $managerId)->update(["modules" => $modules, "updated_at" => now()]);
        } else {
            DB::table("preferences_accueil")->insert(["manager_id" => $managerId, "modules" => $modules, "created_at" => now(), "updated_at" => now()]);
        }
    }

    public function afficher(Request $request)
    {
        return $this->successResponse(["modules" => static::lireModules($request->user()->id)]);
    }

    public function modifier(Request $request)
    {
        $v = Validator::make($request->all(), [
            "modules"           => ["present", "array", "max:80"],
            "modules.*.code"    => ["required", "string", "max:300"],
            "modules.*.visible" => ["required", "boolean"],
            "modules.*.nom"     => ["nullable", "string", "max:40"],
        ], ["modules.*.nom.max" => "Le nom d'un module ne dépasse pas 40 caractères."]);
        if ($v->fails()) return $this->validationErrorResponse($v->errors());

        $modules = collect($request->input("modules", []))->map(fn($m) => [
            "code"    => (string) $m["code"],
            "visible" => (bool) $m["visible"],
            "nom"     => isset($m["nom"]) && trim((string) $m["nom"]) !== "" ? trim((string) $m["nom"]) : null,
        ])->unique("code")->values()->all();

        static::ecrire($request->user()->id, json_encode($modules, JSON_UNESCAPED_UNICODE));
        return $this->successResponse(["modules" => static::lireModules($request->user()->id)]);
    }

    /** Tous les modules reprennent leur nom et redeviennent visibles. */
    public function reinitialiser(Request $request)
    {
        static::ecrire($request->user()->id, null);
        return $this->successResponse(["modules" => []]);
    }
}
