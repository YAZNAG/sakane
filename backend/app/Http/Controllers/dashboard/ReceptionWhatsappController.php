<?php

namespace App\Http\Controllers\dashboard;

use App\Http\Controllers\Controller;
use App\Models\Manager;
use App\Services\ReceptionWhatsapp;
use App\utils\JsonResponses;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Validator;

/**
 * Reglage de la reception des messages WhatsApp. Chacun regle la sienne ;
 * un administrateur peut regler celle de tout utilisateur.
 */
class ReceptionWhatsappController extends Controller
{
    use JsonResponses;

    private function cible(Request $request, $id)
    {
        $moi = $request->user();
        $cible = $id === null ? $moi : Manager::find($id);
        if (!$cible) {
            return $this->notFoundResponse("Utilisateur introuvable");
        }
        if ((int) $cible->id !== (int) $moi->id && !$moi->hasRole("admin") && !\App\Services\CataloguePermissions::peut($moi, "manage_team_whatsapp")) {
            return $this->jsonResponse(false, self::NO_ACCESS, 403,
                ["msg" => ["Seul un administrateur peut régler la réception d'un autre utilisateur."]]);
        }
        return $cible;
    }

    public function afficher(Request $request, $id = null)
    {
        $cible = $this->cible($request, $id);
        if (!$cible instanceof Manager) return $cible;
        return $this->successResponse(ReceptionWhatsapp::reglages($cible));
    }

    public function modifier(Request $request, $id = null)
    {
        $cible = $this->cible($request, $id);
        if (!$cible instanceof Manager) return $cible;

        $v = Validator::make($request->all(), [
            "actif"         => ["nullable", "boolean"],
            "typesCoupes"   => ["nullable", "array"],
            "typesCoupes.*" => ["string", "in:" . implode(",", array_keys(ReceptionWhatsapp::TYPES))],
        ]);
        if ($v->fails()) return $this->validationErrorResponse($v->errors());

        if ($request->has("actif")) {
            $cible->whatsapp_actif = $request->boolean("actif");
        }
        if ($request->has("typesCoupes")) {
            $coupes = array_values(array_unique((array) $request->input("typesCoupes", [])));
            $cible->whatsapp_types_coupes = $coupes ? json_encode($coupes) : null;
        }
        $cible->save();

        return $this->successResponse(ReceptionWhatsapp::reglages($cible->fresh()));
    }

    /** Vue d'ensemble pour l'administrateur : qui recoit quoi. */
    public function liste(Request $request)
    {
        if (!$request->attributes->get("droit_verifie") && !$request->user()->hasRole("admin")) {
            return $this->jsonResponse(false, self::NO_ACCESS, 403, ["msg" => ["Réservé aux administrateurs."]]);
        }
        return $this->successResponse(Manager::orderBy("first_name")->get()->map(fn($m) => ReceptionWhatsapp::reglages($m))->values());
    }
}
