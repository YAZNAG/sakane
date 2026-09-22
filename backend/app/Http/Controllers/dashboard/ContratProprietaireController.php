<?php

namespace App\Http\Controllers\dashboard;

use App\Http\Controllers\Controller;
use App\Models\ContratProprietaire;
use App\Models\Owner;
use App\Models\Realstate;
use App\utils\JsonResponses;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Facades\Validator;

/** Les contrats signes avec un proprietaire, joints par appartement. */
class ContratProprietaireController extends Controller
{
    use JsonResponses;

    private function refuserSansDroit(Request $request)
    {
        // Deja valide par le controle central des droits.
        if ($request->attributes->get("droit_verifie")) return null;
        $manager = $request->user();
        if (!$manager || !($manager->hasRole("admin") || $manager->can("update_owner"))) {
            return $this->jsonResponse(false, self::NO_ACCESS, 403,
                ["msg" => ["Vous n'avez pas l'autorisation de gérer les contrats des propriétaires."]]);
        }
        return null;
    }

    public function store(Request $request, $id)
    {
        if ($refus = $this->refuserSansDroit($request)) return $refus;

        $owner = Owner::find($id);
        if (!$owner) {
            return $this->notFoundResponse("Propriétaire introuvable");
        }

        $validator = Validator::make($request->all(), [
            "fichier"    => ["required", "file", "mimes:pdf,jpg,jpeg,png", "max:15360"],
            "bien"       => ["nullable", "integer"],
            "titre"      => ["nullable", "string", "max:150"],
            "dateDebut"  => ["nullable", "date_format:Y-m-d"],
            "dateFin"    => ["nullable", "date_format:Y-m-d", "after_or_equal:dateDebut"],
        ], [
            "fichier.required" => "Choisissez le contrat à joindre (PDF ou photo).",
            "fichier.mimes"    => "Le contrat doit être un PDF ou une photo (JPG, PNG).",
            "fichier.max"      => "Le fichier dépasse 15 Mo.",
            "dateFin.after_or_equal" => "La date de fin doit suivre la date de début.",
        ]);
        if ($validator->fails()) {
            return $this->validationErrorResponse($validator->errors());
        }

        $bienId = $request->input("bien");
        if ($bienId && !Realstate::where("id", $bienId)->where("owner_id", $owner->id)->exists()) {
            return $this->validationErrorResponse(["bien" => ["Cet appartement n'appartient pas à ce propriétaire."]]);
        }

        $fichier = $request->file("fichier");
        $chemin = $fichier->store("contrats-proprietaires/" . $owner->id, "public");

        $contrat = ContratProprietaire::create([
            "owner_id"      => $owner->id,
            "realestate_id" => $bienId ?: null,
            "titre"         => $request->input("titre"),
            "date_debut"    => $request->input("dateDebut"),
            "date_fin"      => $request->input("dateFin"),
            "fichier"       => $chemin,
            "nom_fichier"   => $fichier->getClientOriginalName(),
            "type_mime"     => $fichier->getMimeType(),
            "taille"        => $fichier->getSize(),
            "created_by"    => $request->user()?->id,
        ]);

        return $this->createdResponse($contrat->load(["bien", "auteur"])->versTableau());
    }

    public function destroy(Request $request, $id)
    {
        if ($refus = $this->refuserSansDroit($request)) return $refus;

        $contrat = ContratProprietaire::find($id);
        if (!$contrat) {
            return $this->notFoundResponse("Contrat introuvable");
        }

        Storage::disk("public")->delete($contrat->fichier);
        $contrat->delete();

        return $this->successResponse(["supprime" => true]);
    }
}
