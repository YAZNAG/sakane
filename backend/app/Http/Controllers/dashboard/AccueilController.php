<?php

namespace App\Http\Controllers\dashboard;

use App\Http\Controllers\Controller;
use App\utils\JsonResponses;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Validator;

/**
 * L'organisation de l'accueil de chaque utilisateur : ordre des cartes,
 * dossiers et leurs icones, modules de la barre du bas.
 *
 * Gardee sur le serveur, elle suit l'utilisateur d'un telephone a
 * l'autre et survit aux mises a jour comme aux reinstallations.
 */
class AccueilController extends Controller
{
    use JsonResponses;

    public function lire(Request $request)
    {
        $ligne = DB::table("preferences_accueil")
            ->where("manager_id", $request->user()->id)
            ->first();

        return $this->successResponse([
            "disposition" => $ligne && $ligne->disposition !== null ? json_decode($ligne->disposition, true) : null,
            "barre"       => $ligne && $ligne->barre !== null ? json_decode($ligne->barre, true) : null,
        ]);
    }

    public function enregistrer(Request $request)
    {
        $validation = Validator::make($request->all(), [
            "disposition"   => ["nullable", "array", "max:200"],
            "barre"         => ["nullable", "array", "max:10"],
            "barre.*"       => ["string", "max:300"],
        ]);

        if ($validation->fails()) {
            return $this->validationErrorResponse($validation->errors());
        }

        $valeurs = [
            "disposition" => $request->input("disposition") === null
                ? null
                : json_encode($request->input("disposition"), JSON_UNESCAPED_UNICODE),
            "barre"       => $request->input("barre") === null
                ? null
                : json_encode(array_values($request->input("barre")), JSON_UNESCAPED_UNICODE),
            "updated_at"  => now(),
        ];

        $managerId = $request->user()->id;
        $existe = DB::table("preferences_accueil")->where("manager_id", $managerId)->exists();

        if ($existe) {
            DB::table("preferences_accueil")->where("manager_id", $managerId)->update($valeurs);
        } else {
            DB::table("preferences_accueil")->insert($valeurs + [
                "manager_id" => $managerId,
                "created_at" => now(),
            ]);
        }

        return $this->successResponse(null);
    }
}
