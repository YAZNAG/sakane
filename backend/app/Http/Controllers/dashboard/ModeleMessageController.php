<?php

namespace App\Http\Controllers\dashboard;

use App\Http\Controllers\Controller;
use App\Http\Resources\DashboardResource\ModeleMessageResource;
use App\Models\WhatsappMessage;
use App\Models\WhatsappMessageHistorique;
use App\Services\CatalogueModeles;
use App\Services\ModelesMessages;
use App\utils\JsonResponses;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Validator;

/**
 * Gestion des modeles de messages depuis l'application.
 *
 * Reserve aux administrateurs : ces textes partent aux clients, une
 * erreur de redaction se voit immediatement chez le destinataire.
 */
class ModeleMessageController extends Controller
{
    use JsonResponses;

    /** Seuls les administrateurs peuvent consulter et modifier. */
    private function refuserSiNonAdmin(Request $request)
    {
        // Deja valide par le controle central des droits.
        if ($request->attributes->get("droit_verifie")) return null;
        $manager = $request->user();
        if (!$manager || !$manager->hasRole('admin')) {
            return $this->jsonResponse(false, self::NO_ACCESS, 403,
                ["msg" => ["Seuls les administrateurs peuvent gérer les modèles de messages."]]);
        }
        return null;
    }

    public function index(Request $request)
    {
        if ($refus = $this->refuserSiNonAdmin($request)) return $refus;

        $modeles = WhatsappMessage::orderBy("categorie")
            ->orderBy("message_name")
            ->get();

        return $this->successResponse(ModeleMessageResource::collection($modeles));
    }

    public function show(Request $request, $id)
    {
        if ($refus = $this->refuserSiNonAdmin($request)) return $refus;

        $modele = WhatsappMessage::with("historique.auteur")->find($id);
        if (!$modele) {
            return $this->notFoundResponse("Modèle introuvable");
        }

        return $this->successResponse(new ModeleMessageResource($modele));
    }

    /**
     * Enregistre un nouveau texte et conserve l'ancien dans l'historique.
     */
    public function update(Request $request, $id)
    {
        if ($refus = $this->refuserSiNonAdmin($request)) return $refus;

        $validator = Validator::make($request->all(), [
            "contenu" => ["required", "string", "max:4000"],
            "actif"   => ["nullable", "boolean"],
        ]);
        if ($validator->fails()) {
            return $this->validationErrorResponse($validator->errors());
        }

        $modele = WhatsappMessage::find($id);
        if (!$modele) {
            return $this->notFoundResponse("Modèle introuvable");
        }

        $nouveau = trim($request->input("contenu"));
        $ancien  = $modele->message;

        DB::transaction(function () use ($modele, $nouveau, $ancien, $request) {
            if ($nouveau !== $ancien) {
                WhatsappMessageHistorique::create([
                    "whatsapp_message_id" => $modele->id,
                    "contenu_avant"       => $ancien,
                    "contenu_apres"       => $nouveau,
                    "manager_id"          => $request->user()?->id,
                ]);
            }

            $modele->message    = $nouveau;
            $modele->updated_by = $request->user()?->id;
            if ($request->has("actif")) {
                $modele->actif = $request->boolean("actif");
            }
            $modele->save();
        });

        return $this->successResponse(
            new ModeleMessageResource($modele->fresh(["historique.auteur"]))
        );
    }

    /** Revient au texte fourni avec l'application. */
    public function restaurer(Request $request, $id)
    {
        if ($refus = $this->refuserSiNonAdmin($request)) return $refus;

        $modele = WhatsappMessage::find($id);
        if (!$modele) {
            return $this->notFoundResponse("Modèle introuvable");
        }

        $defaut = $modele->defaut ?? CatalogueModeles::defaut($modele->code);
        if (!$defaut) {
            return $this->validationErrorResponse([
                "defaut" => ["Aucun modèle d'origine n'est disponible."]
            ]);
        }

        DB::transaction(function () use ($modele, $defaut, $request) {
            if ($defaut !== $modele->message) {
                WhatsappMessageHistorique::create([
                    "whatsapp_message_id" => $modele->id,
                    "contenu_avant"       => $modele->message,
                    "contenu_apres"       => $defaut,
                    "manager_id"          => $request->user()?->id,
                ]);
            }
            $modele->message    = $defaut;
            $modele->actif      = true;
            $modele->updated_by = $request->user()?->id;
            $modele->save();
        });

        return $this->successResponse(
            new ModeleMessageResource($modele->fresh(["historique.auteur"]))
        );
    }

    /**
     * Apercu du rendu avec des valeurs d'exemple, avant enregistrement.
     * Signale aussi les variables restees sans valeur.
     */
    public function apercu(Request $request)
    {
        if ($refus = $this->refuserSiNonAdmin($request)) return $refus;

        $validator = Validator::make($request->all(), [
            "contenu" => ["required", "string", "max:4000"],
        ]);
        if ($validator->fails()) {
            return $this->validationErrorResponse($validator->errors());
        }

        $rendu = ModelesMessages::remplacer(
            $request->input("contenu"),
            CatalogueModeles::exemples()
        );

        return $this->successResponse([
            "apercu"    => $rendu,
            "inconnues" => ModelesMessages::variablesNonRemplies($rendu),
        ]);
    }

    /** Joint une image au modele : elle partira avec le message. */
    public function deposerImage(Request $request, $id)
    {
        if ($refus = $this->refuserSiNonAdmin($request)) return $refus;

        $validator = Validator::make($request->all(), [
            "image" => ["required", "image", "mimes:png,jpg,jpeg", "max:4096"],
        ]);
        if ($validator->fails()) {
            return $this->validationErrorResponse($validator->errors());
        }

        $modele = WhatsappMessage::find($id);
        if (!$modele) {
            return $this->notFoundResponse("Modèle introuvable");
        }

        $modele->addMediaFromRequest("image")->toMediaCollection("image");

        return $this->successResponse(
            new ModeleMessageResource($modele->fresh(["historique.auteur"]))
        );
    }

    /** Retire l'image : le message repart en texte seul. */
    public function retirerImage(Request $request, $id)
    {
        if ($refus = $this->refuserSiNonAdmin($request)) return $refus;

        $modele = WhatsappMessage::find($id);
        if (!$modele) {
            return $this->notFoundResponse("Modèle introuvable");
        }

        $modele->clearMediaCollection("image");

        return $this->successResponse(
            new ModeleMessageResource($modele->fresh(["historique.auteur"]))
        );
    }

    /** Variables utilisables, avec leur signification. */
    public function variables(Request $request)
    {
        if ($refus = $this->refuserSiNonAdmin($request)) return $refus;

        $exemples = CatalogueModeles::exemples();
        $liste = [];
        foreach ($exemples as $variable => $exemple) {
            $liste[] = [
                "variable" => $variable,
                "exemple"  => $exemple,
                "libelle"  => CatalogueModeles::VARIABLES_COMMUNES[$variable] ?? null,
            ];
        }

        return $this->successResponse($liste);
    }
}
