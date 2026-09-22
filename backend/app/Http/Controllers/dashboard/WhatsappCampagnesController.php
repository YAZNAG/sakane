<?php

namespace App\Http\Controllers\dashboard;

use App\Http\Controllers\Controller;
use App\Services\WhatsappCampagnes;
use App\utils\JsonResponses;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Validator;
use Throwable;

/** Le numero WhatsApp reserve aux campagnes. */
class WhatsappCampagnesController extends Controller
{
    use JsonResponses;

    /** Les essais le remplacent pour ne pas appeler Wasender. */
    public static $lecteur = null;

    private function admin(Request $request): bool
    {
        return (bool) ($request->attributes->get("droit_verifie") || $request->user()?->hasRole("admin"));
    }

    public function afficher(Request $request)
    {
        return $this->successResponse(WhatsappCampagnes::etat());
    }

    public function modifier(Request $request)
    {
        if (!$this->admin($request)) {
            return $this->jsonResponse(false, self::NO_ACCESS, 403, ["msg" => ["Réservé aux administrateurs."]]);
        }
        $v = Validator::make($request->all(), ["cle" => ["required", "string", "min:20", "max:200"]],
            ["cle.required" => "Collez la clé API de la session Wasender des campagnes.", "cle.min" => "Cette clé API est trop courte."]);
        if ($v->fails()) return $this->validationErrorResponse($v->errors());
        $cle = trim($request->input("cle"));
        if ($cle === config("services.whatsapp.wasender_key")) {
            return $this->validationErrorResponse(["cle" => ["C'est la clé du numéro principal : utilisez la clé d'une autre session."]]);
        }
        try {
            $infos = is_callable(static::$lecteur) ? (static::$lecteur)($cle) : WhatsappCampagnes::lire($cle);
        } catch (Throwable $th) {
            return $this->validationErrorResponse(["cle" => ["Wasender refuse cette clé ou la session n'est pas connectée : " . mb_substr($th->getMessage(), 0, 200)]]);
        }
        WhatsappCampagnes::enregistrer($cle, $infos);
        return $this->successResponse(WhatsappCampagnes::etat());
    }

    /** Retour au numero principal. */
    public function supprimer(Request $request)
    {
        if (!$this->admin($request)) {
            return $this->jsonResponse(false, self::NO_ACCESS, 403, ["msg" => ["Réservé aux administrateurs."]]);
        }
        WhatsappCampagnes::enregistrer(null);
        return $this->successResponse(WhatsappCampagnes::etat());
    }
}
