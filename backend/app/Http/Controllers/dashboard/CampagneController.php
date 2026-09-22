<?php

namespace App\Http\Controllers\dashboard;

use App\Http\Controllers\Controller;
use App\Http\Resources\DashboardResource\CampagneResource;
use App\Models\Campagne;
use App\Models\CampagneDestinataire;
use App\Models\User;
use App\Services\SelectionClients;
use App\Services\Telephone;
use App\utils\JsonResponses;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Facades\Validator;
use Throwable;
use WasenderApi\WasenderClient;

class CampagneController extends Controller
{
    use JsonResponses;

    /** Historique des campagnes, de la plus recente a la plus ancienne. */
    public function index()
    {
        $campagnes = Campagne::with("auteur")->orderByDesc("created_at")->get();
        $comptes = CampagneDestinataire::whereIn("campagne_id", $campagnes->pluck("id")->all() ?: [0])
            ->selectRaw("campagne_id, statut, count(*) n")->groupBy("campagne_id", "statut")->get()
            ->groupBy("campagne_id")->map(fn($l) => $l->pluck("n", "statut"));
        $campagnes->each(fn($c) => $c->comptes = $comptes[$c->id] ?? collect());
        return $this->successResponse(CampagneResource::collection($campagnes));
    }

    /** Detail d'une campagne et suivi de chaque destinataire. */
    public function show($id)
    {
        $campagne = Campagne::with(["auteur", "destinataires" => fn($q) => $q->orderByRaw("ordre IS NULL, ordre")->orderBy("id"), "destinataires.client"])->find($id);
        if (!$campagne) {
            return $this->notFoundResponse("Campagne introuvable");
        }
        return $this->successResponse(new CampagneResource($campagne));
    }

    /** Segments disponibles, pour alimenter l'ecran de creation. */
    public function segments()
    {
        $segments = [];
        foreach (SelectionClients::SEGMENTS as $code => $libelle) {
            $segments[] = ["code" => $code, "name" => $libelle];
        }
        return $this->successResponse($segments);
    }

    /**
     * Nombre de clients vises par un segment, avant de creer la campagne.
     * Permet au gerant de verifier sa selection.
     */
    public function estimer(Request $request)
    {
        $clients = (new SelectionClients())->construire($request->input("segment", []));

        return $this->successResponse([
            "nombre"     => $clients->count(),
            "exemples"   => $clients->take(5)->map(fn($c) => [
                "id"        => $c->id,
                "nom"       => trim(($c->first_name ?? '') . ' ' . ($c->last_name ?? '')),
                "telephone" => $c->tel,
            ])->values(),
            "exclus"     => $this->nombreExclus(),
        ]);
    }

    /** Clients ayant refuse les messages promotionnels. */
    private function nombreExclus(): int
    {
        return User::whereHas("type", fn($q) => $q->where("code", "=", "client"))
            ->where("from_platform", "=", "0")
            ->where("accepte_promotions", "=", 0)
            ->count();
    }

    /**
     * Cree la campagne et fige la liste des destinataires.
     *
     * Le message est personnalise des maintenant : le suivi montre ainsi
     * exactement ce qui a ete envoye a chacun.
     */
    /**
     * Un lien saisi "www.godar.ma" est parfaitement clair pour un humain
     * mais invalide pour la validation : on complete le protocole plutot
     * que de renvoyer une erreur incomprehensible.
     */
    private function completerLien(Request $request): void
    {
        $lien = trim((string) $request->input("lien", ""));
        if ($lien === "" || str_starts_with($lien, "http://") || str_starts_with($lien, "https://")) {
            return;
        }
        $request->merge(["lien" => "https://" . $lien]);
    }

    public function store(Request $request)
    {
        $this->completerLien($request);

        $validator = Validator::make($request->all(), [
            "titre"       => ["required", "string", "max:160"],
            "message"     => ["required", "string", "max:4000"],
            "lien"        => ["nullable", "url:http,https", "max:500"],
            "image"       => ["nullable", "image", "mimes:png,jpg,jpeg"],
            "segment"     => ["nullable", "array"],
            "planifieeA"  => ["nullable", "date"],
            "envoyer"     => ["nullable", "boolean"],
        ]);

        if ($validator->fails()) {
            return $this->validationErrorResponse($validator->errors());
        }

        $segment = $request->input("segment", ["type" => "tous"]);
        $clients = (new SelectionClients())->construire($segment);

        if ($clients->isEmpty()) {
            return $this->validationErrorResponse([
                "segment" => ["Aucun client ne correspond à cette sélection."]
            ]);
        }

        DB::beginTransaction();
        try {
            $planifiee = $request->input("planifieeA");
            $immediat  = $request->boolean("envoyer");

            $campagne = Campagne::create([
                "titre"            => $request->input("titre"),
                "message"          => $request->input("message"),
                "lien"             => $request->input("lien"),
                "segment"          => $segment,
                "statut"           => $immediat
                    ? "en_cours"
                    : ($planifiee ? "programmee" : "brouillon"),
                "planifiee_a"      => $planifiee,
                "par_minute"       => 2,
                "demarree_a"       => $immediat ? now() : null,
                "nb_destinataires" => $clients->count(),
                "created_by"       => $request->user()?->id,
            ]);

            if ($request->hasFile("image")) {
                $campagne->addMediaFromRequest("image")->toMediaCollection("image");
            }

            $lien = $request->input("lien");
            $lignes = [];
            $ordre = 0;
            foreach ($clients as $client) {
                $lignes[] = [
                    "campagne_id"   => $campagne->id,
                    "client_id"     => $client->id,
                    "ordre"         => ++$ordre,
                    "telephone"     => SelectionClients::normaliserTelephone($client->tel),
                    "message_final" => Campagne::appliquerVariables(
                        $campagne->message, $client, $lien
                    ),
                    "statut"        => "en_attente",
                    "created_at"    => now(),
                    "updated_at"    => now(),
                ];
            }

            // insertOrIgnore : la contrainte d'unicite ecarte d'elle-meme
            // un client ou un numero deja present dans la campagne.
            foreach (array_chunk($lignes, 500) as $paquet) {
                CampagneDestinataire::insertOrIgnore($paquet);
            }

            $reel = CampagneDestinataire::where("campagne_id", $campagne->id)->count();
            $campagne->update(["nb_destinataires" => $reel]);

            DB::commit();

            return $this->createdResponse(
                new CampagneResource($campagne->fresh(["auteur"]))
            );
        } catch (Throwable $th) {
            DB::rollBack();
            Log::error("Creation de campagne echouee : " . $th->getMessage());
            return $this->serverErrorResponse(["msg" => $th->getMessage()]);
        }
    }

    /**
     * Envoi test vers un numero choisi, sans toucher aux clients.
     * Les variables sont remplacees par des valeurs d'exemple.
     */
    /**
     * Adresse publique de l'image a joindre a l'envoi test.
     *
     * Au moment du test la campagne n'existe pas encore : l'image
     * arrive avec la requete. WhatsApp la telecharge lui-meme, elle doit
     * donc etre accessible publiquement le temps de l'envoi. Le fichier
     * est depose dans un dossier temporaire, purge chaque jour.
     *
     * Si la campagne existe deja - test relance depuis son detail - on
     * reutilise son image sans rien recopier.
     */
    private function imageDeTest(Request $request): ?string
    {
        if ($request->filled("campagne")) {
            $existante = Campagne::find($request->input("campagne"))?->imageUrl();
            if ($existante) {
                return $existante;
            }
        }

        if (!$request->hasFile("image")) {
            return null;
        }

        try {
            $fichier = $request->file("image");
            $nom = "test-" . uniqid() . "." . $fichier->getClientOriginalExtension();

            // Le disque "public" explicitement : depuis Laravel 11 le disque
            // local pointe sur storage/app/private, hors de portee du web.
            $chemin = $fichier->storeAs("tests-campagnes", $nom, "public");

            return Storage::disk("public")->url($chemin);
        } catch (Throwable $th) {
            Log::error("Depot de l'image de test impossible : " . $th->getMessage());
            return null;
        }
    }

    public function test(Request $request)
    {
        $this->completerLien($request);

        $validator = Validator::make($request->all(), [
            "telephone" => ["required", "string", "max:30"],
            "message"   => ["required", "string", "max:4000"],
            "lien"      => ["nullable", "url:http,https"],
            "image"     => ["nullable", "image", "mimes:png,jpg,jpeg"],
            "campagne"  => ["nullable", "exists:campagnes,id"],
        ]);

        if ($validator->fails()) {
            return $this->validationErrorResponse($validator->errors());
        }

        $telephone = Telephone::international($request->input("telephone"));
        if ($telephone === "") {
            return $this->validationErrorResponse([
                "telephone" => ["Numéro invalide. Saisissez 0612345678 ou 212612345678."]
            ]);
        }

        // Un client fictif suffit a montrer le rendu des variables.
        $exemple = new User([
            "first_name" => "Mohamed",
            "last_name"  => "Alami",
        ]);

        $texte = "[TEST] " . Campagne::appliquerVariables(
            $request->input("message"),
            $exemple,
            $request->input("lien")
        );

        $image = $this->imageDeTest($request);

        try {
            $wa = new WasenderClient(config("services.whatsapp.wasender_key"));
            if ($image) {
                $wa->sendImage($telephone, $image, $texte);
            } else {
                $wa->sendText($telephone, $texte);
            }
            return $this->successResponse(["envoye" => true]);
        } catch (Throwable $th) {
            Log::error("Envoi test de campagne echoue : " . $th->getMessage());
            return $this->serverErrorResponse(["msg" => $th->getMessage()],
                "L'envoi test n'a pas abouti");
        }
    }

    /** Lance une campagne en brouillon ou programmee. */
    public function envoyer($id)
    {
        $campagne = Campagne::find($id);
        if (!$campagne) {
            return $this->notFoundResponse("Campagne introuvable");
        }
        if (!$campagne->estModifiable()) {
            return $this->validationErrorResponse([
                "statut" => ["Cette campagne a déjà été lancée."]
            ]);
        }

        $campagne->update([
            "statut"      => "en_cours",
            "demarree_a"  => now(),
            "planifiee_a" => null,
        ]);

        return $this->successResponse(new CampagneResource($campagne->fresh()));
    }

    /** Interrompt une campagne : les envois restants sont abandonnes. */
    public function annuler($id)
    {
        $campagne = Campagne::find($id);
        if (!$campagne) {
            return $this->notFoundResponse("Campagne introuvable");
        }
        if (in_array($campagne->statut, ["terminee", "annulee"])) {
            return $this->validationErrorResponse([
                "statut" => ["Cette campagne est déjà terminée."]
            ]);
        }

        DB::transaction(function () use ($campagne) {
            CampagneDestinataire::where("campagne_id", $campagne->id)
                ->where("statut", "en_attente")
                ->update(["statut" => "ignore", "erreur" => "Campagne annulée"]);
            $campagne->update(["statut" => "annulee", "terminee_a" => now()]);
        });

        return $this->successResponse(new CampagneResource($campagne->fresh()));
    }

    /**
     * Met la campagne en pause : aucun nouveau message ne part, la liste
     * garde son ordre et les messages restants restent en attente.
     */
    public function pause($id)
    {
        $campagne = Campagne::find($id);
        if (!$campagne) {
            return $this->notFoundResponse("Campagne introuvable");
        }
        if (!in_array($campagne->statut, ["en_cours", "programmee"])) {
            return $this->validationErrorResponse(["statut" => ["Seule une campagne en cours ou programmée peut être mise en pause."]]);
        }
        $campagne->update(["statut" => "en_pause", "pausee_a" => now()]);
        return $this->successResponse(new CampagneResource($campagne->fresh("auteur")));
    }

    /** Reprend une campagne en pause, la ou elle s'etait arretee. */
    public function reprendre($id)
    {
        $campagne = Campagne::find($id);
        if (!$campagne) {
            return $this->notFoundResponse("Campagne introuvable");
        }
        if ($campagne->statut !== "en_pause") {
            return $this->validationErrorResponse(["statut" => ["Cette campagne n'est pas en pause."]]);
        }
        $restants = CampagneDestinataire::where("campagne_id", $campagne->id)->where("statut", "en_attente")->count();
        $campagne->update([
            "statut"     => $restants > 0 ? "en_cours" : "terminee",
            "reprise_a"  => now(),
            "demarree_a" => $campagne->demarree_a ?? now(),
            "terminee_a" => $restants > 0 ? null : now(),
        ]);
        return $this->successResponse(new CampagneResource($campagne->fresh("auteur")));
    }

    /** Remet en attente les destinataires en echec, sans toucher aux autres. */
    public function relancerEchecs($id)
    {
        $campagne = Campagne::find($id);
        if (!$campagne) {
            return $this->notFoundResponse("Campagne introuvable");
        }

        $nb = CampagneDestinataire::where("campagne_id", $campagne->id)
            ->where("statut", "echec")
            ->update(["statut" => "en_attente", "erreur" => null]);

        if ($nb === 0) {
            return $this->validationErrorResponse([
                "statut" => ["Aucun envoi en échec à relancer."]
            ]);
        }

        $campagne->update([
            "statut"     => "en_cours",
            "nb_echecs"  => 0,
            "terminee_a" => null,
        ]);

        return $this->successResponse(new CampagneResource($campagne->fresh()));
    }

    public function destroy($id)
    {
        // Supprimer une campagne revient a l'administrateur.
        if (!request()->attributes->get("droit_verifie") && !request()->user()?->hasRole("admin")) {
            return $this->jsonResponse(false, self::NO_ACCESS, 403, ["msg" => ["Seul un administrateur peut supprimer une campagne."]]);
        }
        $campagne = Campagne::find($id);
        if (!$campagne) {
            return $this->notFoundResponse("Campagne introuvable");
        }
        if (in_array($campagne->statut, ["en_cours", "en_pause"])) {
            return $this->validationErrorResponse([
                "statut" => ["Annulez la campagne avant de la supprimer."]
            ]);
        }
        $campagne->delete();
        return $this->successResponse(null);
    }

    /** Autorise ou refuse les messages promotionnels pour un client. */
    public function promotionsClient(Request $request, $id)
    {
        $validator = Validator::make($request->all(), [
            "accepte" => ["required", "boolean"],
        ]);
        if ($validator->fails()) {
            return $this->validationErrorResponse($validator->errors());
        }

        $client = User::find($id);
        if (!$client) {
            return $this->notFoundResponse("Client introuvable");
        }

        $client->accepte_promotions = $request->boolean("accepte");
        $client->save();

        return $this->successResponse([
            "id"                => $client->id,
            "acceptePromotions" => (bool) $client->accepte_promotions,
        ]);
    }
}
