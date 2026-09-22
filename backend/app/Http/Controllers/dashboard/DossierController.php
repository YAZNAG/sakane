<?php

namespace App\Http\Controllers\dashboard;

use App\Http\Controllers\Controller;
use App\Models\Dossier;
use App\Models\Realstate;
use App\utils\JsonResponses;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Validator;

/**
 * Dossiers de rangement des biens.
 *
 * La consultation est ouverte a tous les gestionnaires : ils naviguent
 * par dossier. La creation et la modification sont reservees aux
 * administrateurs, car elles reorganisent le classement pour tout le
 * monde.
 */
class DossierController extends Controller
{
    use JsonResponses;

    private function refuserSiNonAdmin(Request $request)
    {
        // Deja valide par le controle central des droits.
        if ($request->attributes->get("droit_verifie")) return null;
        $manager = $request->user();
        if (!$manager || !$manager->hasRole('admin')) {
            return $this->jsonResponse(false, self::NO_ACCESS, 403,
                ["msg" => ["Seuls les administrateurs peuvent gérer les dossiers."]]);
        }
        return null;
    }

    public function index(Request $request)
    {
        // Filtrable par famille : chaque famille a ses propres dossiers.
        $dossiers = Dossier::with('managers')->withCount('realestates')
            ->when($request->input('type'),
                fn($q, $type) => $q->where('type_code', $type))
            ->orderBy('ordre')
            ->orderBy('nom')
            ->get()
            ->map(fn($d) => [
                "id"          => $d->id,
                "nom"         => $d->nom,
                "description" => $d->description,
                "type"        => $d->type_code,
                "ordre"       => $d->ordre,
                "nombreBiens" => $d->realestates_count,
                "agents"      => $d->managers->map(fn($m) => [
                    "id"  => $m->id,
                    "nom" => trim(($m->first_name ?? '') . ' ' . ($m->last_name ?? '')),
                ])->values(),
            ]);

        return $this->successResponse($dossiers);
    }

    public function store(Request $request)
    {
        if ($refus = $this->refuserSiNonAdmin($request)) return $refus;

        $validator = Validator::make($request->all(), [
            "nom"         => ["required", "string", "max:120"],
            "description" => ["nullable", "string", "max:300"],
            "type"        => ["nullable", "string", "max:20"],
            "biens"       => ["nullable", "array"],
            "biens.*"     => ["exists:realstates,id"],
        ]);
        if ($validator->fails()) {
            return $this->validationErrorResponse($validator->errors());
        }

        // Le nom n'a besoin d'etre unique qu'au sein de sa famille.
        $existeDeja = Dossier::where("nom", trim($request->input("nom")))
            ->where("type_code", $request->input("type"))
            ->exists();
        if ($existeDeja) {
            return $this->validationErrorResponse([
                "nom" => ["Un dossier porte déjà ce nom dans cette catégorie."]
            ]);
        }

        $dossier = DB::transaction(function () use ($request) {
            $dossier = Dossier::create([
                "nom"         => trim($request->input("nom")),
                "description" => $request->input("description"),
                "type_code"   => $request->input("type"),
                "ordre"       => (int) Dossier::max('ordre') + 1,
                "created_by"  => $request->user()?->id,
            ]);

            // Les biens indiques rejoignent le dossier des sa creation.
            $biens = $request->input("biens", []);
            if (!empty($biens)) {
                Realstate::whereIn('id', $biens)
                    ->update(['dossier_id' => $dossier->id]);
            }

            return $dossier;
        });

        return $this->createdResponse([
            "id"          => $dossier->id,
            "nom"         => $dossier->nom,
            "description" => $dossier->description,
            "type"        => $dossier->type_code,
            "ordre"       => $dossier->ordre,
            "nombreBiens" => $dossier->realestates()->count(),
        ]);
    }

    public function update(Request $request, $id)
    {
        if ($refus = $this->refuserSiNonAdmin($request)) return $refus;

        $dossier = Dossier::find($id);
        if (!$dossier) {
            return $this->notFoundResponse("Dossier introuvable");
        }

        $validator = Validator::make($request->all(), [
            "nom"         => ["sometimes", "string", "max:120"],
            "description" => ["nullable", "string", "max:300"],
            "ordre"       => ["nullable", "integer", "min:0"],
        ]);
        if ($validator->fails()) {
            return $this->validationErrorResponse($validator->errors());
        }

        $dossier->fill($request->only(["nom", "description", "ordre"]));
        $dossier->save();

        return $this->successResponse([
            "id"          => $dossier->id,
            "nom"         => $dossier->nom,
            "description" => $dossier->description,
            "type"        => $dossier->type_code,
            "ordre"       => $dossier->ordre,
            "nombreBiens" => $dossier->realestates()->count(),
        ]);
    }

    /**
     * Supprime un dossier. Les biens qu'il contenait ne sont pas
     * supprimes : ils redeviennent simplement sans dossier.
     */
    public function destroy(Request $request, $id)
    {
        if ($refus = $this->refuserSiNonAdmin($request)) return $refus;

        $dossier = Dossier::find($id);
        if (!$dossier) {
            return $this->notFoundResponse("Dossier introuvable");
        }

        // Un dossier plein ne se supprime pas : il faudrait d'abord
        // decider ou vont ses biens, et ce choix revient a l'utilisateur.
        $nombre = $dossier->realestates()->count();
        if ($nombre > 0) {
            return $this->validationErrorResponse([
                "dossier" => [
                    "Ce dossier contient {$nombre} bien(s). Déplacez-les avant de le supprimer."
                ]
            ]);
        }

        $dossier->delete();

        return $this->successResponse(["supprime" => true]);
    }

    /** Agents autorises sur un dossier. Remplace l'affectation existante. */
    public function affecterAgents(Request $request, $id)
    {
        if ($refus = $this->refuserSiNonAdmin($request)) return $refus;

        $validator = Validator::make($request->all(), [
            "agents"   => ["present", "array"],
            "agents.*" => ["exists:managers,id"],
        ]);
        if ($validator->fails()) {
            return $this->validationErrorResponse($validator->errors());
        }

        $dossier = Dossier::find($id);
        if (!$dossier) {
            return $this->notFoundResponse("Dossier introuvable");
        }

        $dossier->managers()->sync($request->input("agents", []));

        return $this->successResponse([
            "id"     => $dossier->id,
            "agents" => $dossier->managers()->get()->map(fn($m) => [
                "id"  => $m->id,
                "nom" => trim(($m->first_name ?? '') . ' ' . ($m->last_name ?? '')),
            ])->values(),
        ]);
    }

    /** Dossiers accessibles a un agent, regles depuis son profil. */
    public function dossiersDeLAgent(Request $request, $managerId)
    {
        if ($refus = $this->refuserSiNonAdmin($request)) return $refus;

        $manager = \App\Models\Manager::find($managerId);
        if (!$manager) {
            return $this->notFoundResponse("Agent introuvable");
        }

        if ($request->isMethod("put")) {
            $validator = Validator::make($request->all(), [
                "dossiers"   => ["present", "array"],
                "dossiers.*" => ["exists:dossiers,id"],
            ]);
            if ($validator->fails()) {
                return $this->validationErrorResponse($validator->errors());
            }
            $manager->dossiers()->sync($request->input("dossiers", []));
        }

        return $this->successResponse([
            "manager"  => $manager->id,
            "dossiers" => $manager->dossiers()->get()->map(fn($d) => [
                "id"   => $d->id,
                "nom"  => $d->nom,
                "type" => $d->type_code,
            ])->values(),
        ]);
    }

    /**
     * Range des biens dans un dossier, ou les en sort.
     * [dossier] a null retire les biens de tout dossier.
     */
    public function affecter(Request $request)
    {
        if ($refus = $this->refuserSiNonAdmin($request)) return $refus;

        $validator = Validator::make($request->all(), [
            "biens"   => ["required", "array", "min:1"],
            "biens.*" => ["exists:realstates,id"],
            "dossier" => ["nullable", "exists:dossiers,id"],
        ]);
        if ($validator->fails()) {
            return $this->validationErrorResponse($validator->errors());
        }

        $biens = $request->input("biens");
        $dossier = $request->input("dossier") ? Dossier::find($request->input("dossier")) : null;

        // Un dossier d'une autre famille (vacances, longue duree, vente)
        // fait changer la categorie du bien.
        $typeId = ($dossier && $dossier->type_code)
            ? \App\Models\TypeTransaction::where("code", $dossier->type_code)->value("id")
            : null;
        $aChanger = $typeId
            ? Realstate::whereIn('id', $biens)
                ->where(fn($q) => $q->whereNull('transaction_id')->orWhere('transaction_id', '<>', $typeId))
                ->pluck('id')
            : collect();

        if ($aChanger->isNotEmpty()) {
            // Un bien ne change pas de categorie avec des sejours en cours ou a venir.
            $occupes = \App\Models\Booking::with('realestate:id,title')
                ->whereIn('realestate_id', $aChanger)
                ->where('checkout', '>=', today()->toDateString())
                ->get()
                ->map(fn($b) => $b->realestate?->title)
                ->filter()
                ->unique()
                ->values();

            if ($occupes->isNotEmpty()) {
                return $this->validationErrorResponse(["dossier" => [
                    "Réservations en cours ou à venir pour : " . $occupes->implode(', ')
                    . ". Terminez-les ou supprimez-les avant de changer la catégorie de ces biens."
                ]]);
            }
        }

        if ($aChanger->isNotEmpty()) {
            // Ni avec un bail de location longue duree en cours.
            $loues = \App\Models\Bail::with('bien:id,title')->whereIn('realestate_id', $aChanger)
                ->where('statut', 'actif')->get()->map(fn($b) => $b->bien?->title)->filter()->unique()->values();
            if ($loues->isNotEmpty()) {
                return $this->validationErrorResponse(["dossier" => [
                    "Bail en cours pour : " . $loues->implode(', ')
                    . ". Terminez le bail avant de changer la catégorie de ces biens."
                ]]);
            }
        }

        $nombre = DB::transaction(function () use ($biens, $request, $typeId, $aChanger) {
            $nombre = Realstate::whereIn('id', $biens)
                ->update(['dossier_id' => $request->input("dossier")]);
            if ($typeId && $aChanger->isNotEmpty()) {
                Realstate::whereIn('id', $aChanger)->update(['transaction_id' => $typeId]);
            }
            return $nombre;
        });

        return $this->successResponse([
            "biensDeplaces"    => $nombre,
            "categorieChangee" => $aChanger->count(),
        ]);
    }
}
