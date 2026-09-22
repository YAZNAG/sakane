<?php

namespace App\Http\Controllers\dashboard;

use App\Http\Controllers\Controller;
use App\Models\Secteur;
use App\utils\JsonResponses;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Validator;

class SecteurController extends Controller
{
    use JsonResponses;

    /** Liste des secteurs, filtrable par ville. */
    public function index(Request $request)
    {
        $secteurs = Secteur::query()
            ->when($request->input("city"), fn($q, $city) => $q->where("city_id", $city))
            ->orderBy("nom")
            ->get()
            ->map(fn($s) => [
                "id"   => $s->id,
                "name" => $s->nom,
                "city" => $s->city_id,
            ]);

        return $this->successResponse($secteurs);
    }

    /** Cree un secteur, ou renvoie celui qui porte deja ce nom. */
    public function store(Request $request)
    {
        $validator = Validator::make($request->all(), [
            "nom"  => ["required", "string", "max:120"],
            "city" => ["nullable", "exists:cities,id"],
        ]);

        if ($validator->fails()) {
            return $this->jsonResponse(false, self::VALIDATION_ERROR, 422, $validator->errors());
        }

        $secteur = Secteur::trouverOuCreer($request->input("nom"), $request->input("city"));

        if (!$secteur) {
            return $this->jsonResponse(false, "Nom de secteur invalide", 422);
        }

        return $this->successResponse([
            "id"   => $secteur->id,
            "name" => $secteur->nom,
            "city" => $secteur->city_id,
        ]);
    }
}
