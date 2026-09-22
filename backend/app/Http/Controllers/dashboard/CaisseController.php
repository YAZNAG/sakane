<?php

namespace App\Http\Controllers\dashboard;

use App\Http\Controllers\Controller;
use App\Models\Caisse;
use App\Models\CloturageCaisse;
use App\Models\MouvementCaisse;
use App\Models\RemiseCaisse;
use App\Services\Caisses;
use App\Services\SoldeInsuffisant;
use App\utils\JsonResponses;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Validator;

/**
 * Les caisses : celle de chaque agent, celle de l'agence.
 *
 * Un agent ne voit que la sienne. L'administrateur voit tout et confirme
 * les remises.
 */
class CaisseController extends Controller
{
    use JsonResponses;

    private function estAdmin(Request $request): bool
    {
        return ($request->user()?->hasRole("admin") ?? false)
            || \App\Services\CataloguePermissions::peut($request->user(), "view_all_cashboxes");
    }

    /**
     * Le detenteur de la caisse principale.
     *
     * Il tient la caisse de l'agence et suit toutes les autres : c'est
     * la seule exception a la regle qui veut que chacun ne voie que la
     * sienne.
     */
    private function estGerant(Request $request): bool
    {
        $gerant = config("agence.caisse_principale_manager");

        return $gerant && (int) $request->user()?->id === (int) $gerant;
    }

    /**
     * La caisse que le demandeur peut consulter : la sienne, ou celle
     * qu'il designe s'il est le gerant.
     */
    private function caisseConsultable(Request $request, $id = null): ?Caisse
    {
        $sienne = Caisses::pour($request->user());

        if ($id === null || $id === "" || (int) $id === (int) $sienne?->id) {
            return $sienne;
        }

        return $this->estGerant($request) ? Caisse::find($id) : null;
    }

    // ── Cote agent ───────────────────────────────────────────────

    /** Ma caisse : solde, etat, mouvements recents. */
    public function maCaisse(Request $request)
    {
        $caisse = Caisses::pour($request->user());

        $session = $caisse->sessionCourante();

        return $this->successResponse([
            "id"         => $caisse->id,
            "nom"        => $caisse->nom,
            // La caisse principale ne se transfere pas a elle-meme :
            // l'application masque alors le transfert.
            "principale" => $caisse->type === "agence",
            "ouverte"    => $session !== null,
            "solde"      => $caisse->solde(),
            // Ce qu'il reste de la caisse precedente : l'agent peut le
            // reporter d'un geste plutot que de le ressaisir.
            "aReporter"  => $caisse->dernierMontantCompte(),
            "session"    => $session === null ? null : [
                "id"        => $session->id,
                "numero"    => $session->numero,
                "ouverture" => (float) $session->montant_ouverture,
                "reporte"   => (bool) $session->reporte,
                "ouverteLe" => $session->ouverte_le?->toISOString(),
            ],
            "mouvements" => static::mouvements($caisse, $request->input("depuis")),
            "remises"    => static::remises($caisse),
            // Les transferts qu'il reste a confirmer, piece jointe comprise.
            "aConfirmer" => static::transfertsAConfirmer($caisse),
        ]);
    }

    /** Ouverture de caisse : le fond de depart, une seule fois. */
    public function ouvrir(Request $request)
    {
        $validator = Validator::make($request->all(), [
            // Sans montant, on reporte ce qui restait a la cloture
            // precedente : c'est le cas courant.
            "montant"  => ["nullable", "numeric", "min:0"],
            "reporter" => ["nullable", "boolean"],
        ]);

        if ($validator->fails()) {
            return $this->validationErrorResponse($validator->errors());
        }

        $caisse = Caisses::pour($request->user());

        if ($caisse->ouverte()) {
            return $this->jsonResponse(false,
                "Une caisse est deja ouverte. Cloturez-la d'abord.", 422, null);
        }

        $reporter = $request->boolean("reporter") || !$request->filled("montant");
        $montant  = $reporter
            ? $caisse->dernierMontantCompte()
            : (float) $request->input("montant");

        $session = Caisses::ouvrir($caisse, $montant, $request->user()->id, $reporter);

        return $this->createdResponse([
            "session" => $session->id,
            "numero"  => $session->numero,
            "reporte" => $reporter,
            "solde"   => $caisse->fresh()->solde(),
        ]);
    }

    /**
     * Les caisses vers lesquelles on peut envoyer des especes.
     *
     * Celle de l'agence et celles des collaborateurs en service, sauf
     * la sienne : on ne se transfere pas a soi-meme.
     */
    public function destinataires(Request $request)
    {
        $mienne = Caisses::pour($request->user());

        $liste = Caisse::with("manager")->where("actif", true)->get()
            ->filter(fn($c) => (int) $c->id !== (int) ($mienne->id ?? 0))
            ->filter(fn($c) => $c->type === "agence" || $c->manager !== null)
            // Le gerant tient la caisse agence : son ancienne caisse personnelle
            // ne doit jamais recevoir de transfert (personne ne la verrait).
            ->filter(fn($c) => !($c->type === "agent" && config("agence.caisse_principale_manager")
                && (int) $c->manager_id === (int) config("agence.caisse_principale_manager")))
            ->sortBy(fn($c) => [$c->type === "agence" ? 0 : 1, $c->nom])
            ->values();

        return $this->successResponse([
            "caisses" => $liste->map(fn($c) => [
                "id"         => $c->id,
                "nom"        => $c->nom,
                "principale" => $c->type === "agence",
            ])->all(),
        ]);
    }

    /** Un mouvement saisi a la main : caution recue ou rendue, apport. */
    public function ajouterMouvement(Request $request)
    {
        $validator = Validator::make($request->all(), [
            "sens"        => ["required", "in:entree,sortie"],
            "montant"     => ["required", "numeric", "gt:0"],
            "motif"       => ["required", "string", "max:40"],
            "commentaire" => ["nullable", "string", "max:500"],
        ]);

        if ($validator->fails()) {
            return $this->validationErrorResponse($validator->errors());
        }

        $motif = $request->input("motif");

        // Un agent ne saisit que les motifs prevus pour lui : les
        // encaissements de reservation viennent de l'application, pas
        // d'une saisie libre qui pourrait les doubler.
        // Chaque type d operation a son droit ; les autres motifs demandent
        // le droit de saisir tout type d operation.
        $droitMotif = [
            MouvementCaisse::ENCAISSEMENT_SOLDE => "cash_in",
            MouvementCaisse::APPORT             => "cash_contribution",
            MouvementCaisse::DEPENSE_DIVERSE    => "cash_expense",
        ][$motif] ?? "free_cash_movement";
        if (!\App\Services\CataloguePermissions::peut($request->user(), $droitMotif)) {
            return $this->jsonResponse(false,
                "Ce motif n'est pas a votre main.", 403, null);
        }

        // Chacun ne voit que sa propre caisse, gerant compris.
        $caisse = Caisses::pour($request->user());

        if ($caisse === null) {
            return $this->notFoundResponse();
        }

        try {
            Caisses::enregistrer(
                $caisse,
                $request->input("sens"),
                (float) $request->input("montant"),
                $motif,
                [
                    "manager_id"  => $request->user()->id,
                    "commentaire" => $request->input("commentaire"),
                ]
            );
        } catch (SoldeInsuffisant $e) {
            // L'agent doit lire ce qui manque, pas une trace technique.
            return $this->jsonResponse(false, $e->getMessage(), 422, null);
        }

        return $this->successResponse(["solde" => $caisse->fresh()->solde()]);
    }

    /**
     * Un transfert d'especes vers une autre caisse.
     *
     * Annoncer un transfert ne retire rien : la somme reste dans la
     * caisse de l'expediteur, marquee en attente. Les deux caisses ne
     * bougent qu'a la confirmation du destinataire, qui dispose du
     * detail et de la piece jointe pour verifier ce qu'il a recu.
     */
    public function declarerRemise(Request $request)
    {
        $validator = Validator::make($request->all(), [
            "montant"     => ["required", "numeric", "gt:0"],
            // Sans destinataire, l'argent va a la caisse de l'agence.
            "caisse"      => ["nullable", "integer"],
            "commentaire" => ["nullable", "string", "max:500"],
            "piece"       => ["nullable", "image", "mimes:png,jpg,jpeg", "max:8192"],
        ]);

        if ($validator->fails()) {
            return $this->validationErrorResponse($validator->errors());
        }

        $source  = Caisses::pour($request->user());
        $montant = (float) $request->input("montant");

        $destination = $request->filled("caisse")
            ? Caisse::find($request->input("caisse"))
            : Caisses::agence();

        if ($source === null) {
            return $this->notFoundResponse();
        }

        if ($destination === null || !$destination->actif) {
            return $this->jsonResponse(false, "Caisse introuvable.", 404, null);
        }

        if ((int) $destination->id === (int) $source->id) {
            return $this->jsonResponse(false,
                "Choisissez la caisse d'un collegue ou celle de l'agence.", 422, null);
        }

        // Les transferts deja annonces ne sont plus disponibles, meme
        // s'ils sont encore dans la caisse : sans cela, la meme somme
        // pourrait etre promise deux fois.
        $dejaPromis = (float) RemiseCaisse::where("caisse_source_id", $source->id)
            ->where("statut", RemiseCaisse::EN_ATTENTE)
            ->sum("montant_declare");
        $disponible = round($source->solde() - $dejaPromis, 2);

        if ($montant > $disponible + 0.001) {
            return $this->jsonResponse(false,
                $dejaPromis > 0.005
                    ? "Vous disposez de " . number_format($disponible, 2, ",", " ")
                        . " MAD : " . number_format($dejaPromis, 2, ",", " ")
                        . " MAD sont deja annonces et attendent confirmation."
                    : "Vous ne pouvez pas transferer plus que votre solde.",
                422, null);
        }

        // Rien ne bouge encore : la somme reste dans la caisse de
        // l'expediteur, annoncee comme en attente. Les deux ecritures
        // se font a la confirmation, d'un seul geste.
        $remise = RemiseCaisse::create([
            "caisse_source_id"      => $source->id,
            "caisse_destination_id" => $destination->id,
            "montant_declare"       => $montant,
            "montant_recu"          => null,
            "statut"                => RemiseCaisse::EN_ATTENTE,
            "declare_par"           => $request->user()->id,
            "declare_le"            => now(),
            "commentaire"           => $request->input("commentaire"),
        ]);

        // La photo est attachee apres coup : son echec ne doit pas
        // annuler un transfert deja enregistre.
        if ($request->hasFile("piece")) {
            try {
                $remise->addMediaFromRequest("piece")->toMediaCollection("piece");
            } catch (\Throwable $e) {
                \Illuminate\Support\Facades\Log::warning(
                    "Piece jointe du transfert non enregistree : " . $e->getMessage());
            }
        }

        return $this->createdResponse([
            "id"          => $remise->id,
            "solde"       => $source->fresh()->solde(),
            "statut"      => $remise->statut,
            "destinataire" => $destination->nom,
            "piece"       => $remise->fresh()->piece(),
        ]);
    }

    /**
     * Cloture : l'agent compte ses especes et declare le montant.
     *
     * Un excedent entre en caisse, puisqu'il correspond a de l'argent
     * reellement present. Un manquant reste inscrit sur la cloture :
     * l'en faire sortir ferait passer le solde sous zero, ce que la
     * regle interdit.
     */
    public function cloturer(Request $request)
    {
        $validator = Validator::make($request->all(), [
            "montantCompte" => ["required", "numeric", "min:0"],
            "commentaire"   => ["nullable", "string", "max:500"],
        ]);

        if ($validator->fails()) {
            return $this->validationErrorResponse($validator->errors());
        }

        $caisse  = Caisses::pour($request->user());
        $session = $caisse->sessionCourante();

        if ($session === null) {
            return $this->jsonResponse(false,
                "Ouvrez d'abord votre caisse.", 422, null);
        }

        $theorique = round($caisse->solde(), 2);

        // Une caisse ne se cloture qu'une fois vide : ce qu'elle
        // contenait doit avoir ete remis a l'agence. Sans cette regle,
        // elle se fermait sur un reliquat que plus personne ne suivait.
        if (abs($theorique) > 0.005) {
            return $this->jsonResponse(false,
                "Votre caisse contient encore "
                . number_format($theorique, 2, ",", " ")
                . " MAD. Transferez-les vers la caisse principale avant de cloturer.",
                422, null);
        }

        $compte = round((float) $request->input("montantCompte"), 2);

        // La caisse est vide en theorie. Declarer de l'argent en main la
        // fermerait en le contenant, puisque l'ecart entrerait comme
        // excedent : cet argent doit d'abord etre enregistre, puis
        // transfere vers la caisse principale.
        if ($compte > 0.005) {
            return $this->jsonResponse(false,
                "Vous declarez " . number_format($compte, 2, ",", " ")
                . " MAD en main alors que la caisse est vide. Enregistrez-les"
                . " comme apport, transferez-les vers la caisse principale,"
                . " puis cloturez.", 422, null);
        }

        $ecart  = round($compte - $theorique, 2);

        // La periode, c'est la caisse elle-meme : de son ouverture a
        // maintenant. Plus besoin de remonter la cloture precedente.
        $debut   = $session->ouverte_le;
        $periode = $session->mouvements()->get();

        $entrees = round($periode->where("sens", "entree")->sum("montant"), 2);
        $sorties = round($periode->where("sens", "sortie")->sum("montant"), 2);
        $remis   = round($periode->where("motif", MouvementCaisse::REMISE_DECLAREE)
            ->sum("montant"), 2);

        // Le fond avec lequel cette caisse a ete ouverte.
        $depart = round((float) $session->montant_ouverture, 2);

        $cloture = DB::transaction(function () use ($caisse, $session, $theorique, $compte, $ecart, $request, $debut, $depart, $entrees, $sorties, $remis) {
            $cloture = CloturageCaisse::create([
                "caisse_id"       => $caisse->id,
                "session_id"      => $session->id,
                "debut_periode"   => $debut,
                "montant_depart"  => $depart,
                "total_entrees"   => $entrees,
                "total_sorties"   => $sorties,
                "total_remis"     => $remis,
                "solde_theorique" => $theorique,
                "montant_compte"  => $compte,
                "ecart"           => $ecart,
                "cloture_par"     => $request->user()->id,
                "cloture_le"      => now(),
                "commentaire"     => $request->input("commentaire"),
            ]);

            // L'excedent est de l'argent qui existe : il entre.
            if ($ecart > 0.005) {
                Caisses::encaisser($caisse, $ecart, MouvementCaisse::EXCEDENT, [
                    "manager_id"  => $request->user()->id,
                    "commentaire" => "Cloture du " . now()->format("d/m/Y H:i"),
                ]);
            }

            // La caisse se ferme : aucune autre ne s'ouvre d'office.
            // C'est a l'agent de decider s'il reporte le montant compte
            // ou s'il repart d'un autre fond.
            $session->update([
                "close_le"     => now(),
                "cloturage_id" => $cloture->id,
            ]);

            return $cloture;
        });

        return $this->createdResponse([
            "id"             => $cloture->id,
            "montantDepart"  => $depart,
            "totalEntrees"   => $entrees,
            "totalSorties"   => $sorties,
            "totalRemis"     => $remis,
            "soldeTheorique" => $theorique,
            "montantCompte"  => $compte,
            "ecart"          => $ecart,
            "solde"          => $caisse->fresh()->solde(),
        ]);
    }

    /** Les cloturages : les siens, ou tous pour l'administrateur. */
    public function cloturages(Request $request)
    {
        $query = CloturageCaisse::with(["caisse", "auteur"])
            ->orderByDesc("cloture_le")
            ->limit(100);

        // Chacun voit les clotures de sa propre caisse ; le gerant,
        // celles de la caisse qu'il designe.
        $caisse = $this->caisseConsultable($request, $request->input("caisse"));
        if ($caisse === null) {
            return $this->jsonResponse(false, self::NO_ACCESS, 403, null);
        }
        $query->where("caisse_id", $caisse->id);

        return $this->successResponse($query->get()->map(fn($c) => [
            "id"             => $c->id,
            "caisse"         => $c->caisse->nom ?? "-",
            "caisseId"       => $c->caisse_id,
            "montantDepart"  => (float) $c->montant_depart,
            "totalEntrees"   => (float) $c->total_entrees,
            "totalSorties"   => (float) $c->total_sorties,
            "totalRemis"     => (float) $c->total_remis,
            "debutPeriode"   => $c->debut_periode?->toISOString(),
            "soldeTheorique" => (float) $c->solde_theorique,
            "montantCompte"  => (float) $c->montant_compte,
            "ecart"          => (float) $c->ecart,
            "juste"          => $c->juste(),
            "auteur"         => trim(($c->auteur->first_name ?? "") . " " . ($c->auteur->last_name ?? "")),
            "clotureLe"      => $c->cloture_le?->toISOString(),
            "commentaire"    => $c->commentaire,
        ])->all());
    }

    // ── Cote administrateur ──────────────────────────────────────

    /**
     * La caisse du demandeur, et elle seule.
     *
     * Chacun ne voit que sa propre caisse. La forme de la reponse est
     * conservee : les applications deja installees continuent de
     * l'appeler. Plus rien n'est en transit, les transferts etant
     * immediats.
     */
    public function index(Request $request)
    {
        $caisse = Caisses::pour($request->user());

        if ($this->estGerant($request)) {
            $gerant = (int) config("agence.caisse_principale_manager");

            // Toutes les caisses en service : la principale, et celles
            // des collaborateurs encore presents. On ecarte l'ancienne
            // caisse personnelle du gerant, qui ferait doublon.
            $liste = Caisse::with("manager")->where("actif", true)->get()
                ->filter(fn($c) => $c->type === "agence"
                    || ($c->manager !== null && (int) $c->manager_id !== $gerant))
                ->sortBy(fn($c) => [$c->type === "agence" ? 0 : 1, $c->nom])
                ->values();
        } else {
            $liste = collect([$caisse]);
        }

        // Compter et confirmer les remises revient au gerant, ou a un
        // administrateur : les autres n'ont rien a confirmer.
        // Ce qui attend d'etre confirme par le detenteur de cette caisse.
        $aConfirmer = static::transfertsAConfirmer($caisse);

        return $this->successResponse([
            "caisses"    => $liste->map(fn($c) => [
                "id"      => $c->id,
                "nom"     => $c->nom,
                "type"    => $c->type,
                "solde"   => $c->solde(),
                "ouverte" => $c->ouverte(),
            ])->all(),
            // Les remises que le gerant doit compter et confirmer, et ce
            // qu'elles representent : cet argent a quitte l'agent sans
            // etre encore entre dans la caisse de l'agence.
            "enTransit"  => round(collect($aConfirmer)->sum("montantDeclare"), 2),
            "aConfirmer" => $aConfirmer,
        ]);
    }

    /**
     * Le destinataire compte ce qu'il a recu et confirme.
     *
     * Il voit le detail et la piece jointe avant d'accepter. Le gerant
     * et les administrateurs peuvent confirmer a sa place, comme
     * auparavant.
     */
    public function confirmerRemise(Request $request, $id)
    {
        $validator = Validator::make($request->all(), [
            "montantRecu" => ["required", "numeric", "min:0"],
            "commentaire" => ["nullable", "string", "max:500"],
        ]);

        if ($validator->fails()) {
            return $this->validationErrorResponse($validator->errors());
        }

        $remise = RemiseCaisse::with(["source", "destination"])->find($id);

        if ($remise === null) {
            return $this->notFoundResponse();
        }

        $mienne = Caisses::pour($request->user());
        $destinataire = $mienne !== null
            && (int) $remise->caisse_destination_id === (int) $mienne->id;

        if (!$destinataire && !$this->estGerant($request) && !$this->estAdmin($request)) {
            return $this->jsonResponse(false, self::NO_ACCESS, 403, null);
        }

        if ($remise->statut !== RemiseCaisse::EN_ATTENTE) {
            return $this->jsonResponse(false,
                "Ce transfert a deja ete traite.", 422, null);
        }

        $recu = (float) $request->input("montantRecu");

        DB::transaction(function () use ($remise, $recu, $request) {
            $remise->update([
                "montant_recu" => $recu,
                "statut"       => RemiseCaisse::CONFIRMEE,
                "confirme_par" => $request->user()->id,
                "confirme_le"  => now(),
                // Le commentaire de l expediteur reste ; le receveur a le sien.
                "commentaire_reception" => $request->input("commentaire") ?: null,
            ]);

            // Les deux ecritures, maintenant seulement : la somme quitte
            // l'expediteur et entre chez le destinataire. La sortie
            // constate un fait deja accompli - l'argent a change de
            // mains - et ne se heurte donc pas a la regle du solde, qui
            // bloquerait un transfert que plus personne ne pourrait
            // denouer.
            Caisses::enregistrerSansControle(
                $remise->source,
                "sortie",
                (float) $remise->montant_declare,
                MouvementCaisse::REMISE_DECLAREE,
                [
                    "remise_id"  => $remise->id,
                    "manager_id" => $remise->declare_par,
                    "libelle"    => "Transfert vers " . ($remise->destination->nom ?? "une caisse"),
                    // Le commentaire du transfert suit l argent dans les deux caisses.
                    "commentaire" => $remise->commentaireComplet(),
                ]
            );

            // La caisse qui recoit encaisse ce qui a ete compte, pas ce
            // qui avait ete annonce : c'est la realite qui fait foi.
            Caisses::encaisser($remise->destination, $recu, MouvementCaisse::REMISE_RECUE, [
                "remise_id"  => $remise->id,
                "manager_id" => $request->user()->id,
                "libelle"    => "Transfert de " . ($remise->source->nom ?? "une caisse"),
                "commentaire" => $remise->commentaireComplet(),
            ]);

            // L'ecart entre l'annonce et le compte reste inscrit sur le
            // transfert : il demeure opposable sans deformer les caisses.
        });

        return $this->successResponse([
            "statut" => $remise->fresh()->statut,
            "ecart"  => $remise->fresh()->ecart(),
        ]);
    }

    /**
     * Ramene une caisse a zero.
     *
     * Le journal n'est pas efface : un mouvement inverse annule le
     * solde, et la trace de l'operation reste. Le motif est exige,
     * parce que vider la caisse d'un autre demande une raison.
     */
    public function vider(Request $request, $id)
    {
        if (!$this->estAdmin($request)) {
            return $this->jsonResponse(false, self::NO_ACCESS, 403, null);
        }

        $validator = Validator::make($request->all(), [
            "motif" => ["required", "string", "min:3", "max:500"],
        ]);

        if ($validator->fails()) {
            return $this->validationErrorResponse($validator->errors());
        }

        $caisse = Caisse::find($id);

        if ($caisse === null) {
            return $this->notFoundResponse();
        }

        $solde = round($caisse->solde(), 2);

        if (abs($solde) < 0.01) {
            return $this->jsonResponse(false,
                "Cette caisse est deja vide.", 422, null);
        }

        // Sans controle du solde : c'est precisement lui qu'on annule.
        Caisses::enregistrerSansControle(
            $caisse,
            $solde > 0 ? "sortie" : "entree",
            abs($solde),
            MouvementCaisse::VIDAGE,
            [
                "manager_id"  => $request->user()->id,
                "libelle"     => "Vidage par l'administrateur",
                "commentaire" => $request->input("motif"),
            ]
        );

        return $this->successResponse([
            "solde"  => $caisse->fresh()->solde(),
            "annule" => $solde,
        ]);
    }

    /** Le journal d'une caisse, pour l'administrateur. */
    public function mouvementsDe(Request $request, $id)
    {
        // Chacun consulte sa propre caisse ; le gerant, toutes.
        $caisse = $this->caisseConsultable($request, $id);

        if ($caisse === null) {
            return $this->jsonResponse(false, self::NO_ACCESS, 403, null);
        }

        return $this->successResponse([
            "id"         => $caisse->id,
            "nom"        => $caisse->nom,
            "solde"      => $caisse->solde(),
            "mouvements" => static::mouvements($caisse, $request->input("depuis")),
        ]);
    }

    /**
     * Les caisses successives d'un detenteur, chacune avec son journal.
     *
     * L'agent voit les siennes ; l'administrateur celles qu'il demande.
     */
    public function sessions(Request $request)
    {
        // Chacun voit sa propre caisse ; le gerant, celle qu'il designe.
        $caisse = $this->caisseConsultable($request, $request->input("caisse"));

        if ($caisse === null) {
            return $this->jsonResponse(false, self::NO_ACCESS, 403, null);
        }

        $sessions = $caisse->sessions()
            ->with(["mouvements" => fn($q) => $q->orderByDesc("effectue_le")->orderByDesc("id")])
            ->orderByDesc("id")->limit(40)->get();

        return $this->successResponse([
            "caisse"   => $caisse->nom,
            "sessions" => $sessions->map(fn($se) => [
                "id"         => $se->id,
                "numero"     => $se->numero,
                "ouverture"  => (float) $se->montant_ouverture,
                "reporte"    => (bool) $se->reporte,
                "ouverteLe"  => $se->ouverte_le?->toISOString(),
                "closeLe"    => $se->close_le?->toISOString(),
                "ouverte"    => $se->ouverte(),
                "solde"      => $se->solde(),
                "mouvements" => $se->mouvements->map(fn($m) => [
                    "id"          => $m->id,
                    "sens"        => $m->sens,
                    "montant"     => (float) $m->montant,
                    "motif"       => $m->motif,
                    "libelle"     => $m->libelleLisible(),
                    "commentaire" => $m->commentaire,
                    "par"         => static::auteur($m),
                    "effectueLe"  => $m->effectue_le?->toISOString(),
                ])->all(),
            ])->all(),
        ]);
    }

    // ── Mise en forme ────────────────────────────────────────────

    /**
     * Le journal de la caisse en cours.
     *
     * Pas tout l'historique du detenteur : chaque caisse a le sien, et
     * les meler ferait perdre le sens d'un solde.
     */
    private static function mouvements(Caisse $caisse, ?string $depuis): array
    {
        $session = $caisse->sessionCourante();

        $query = ($session !== null ? $session->mouvements() : $caisse->mouvements())
            ->orderByDesc("effectue_le")->orderByDesc("id");

        if ($session === null) {
            $query->whereRaw("1 = 0");
        }

        if ($depuis) {
            $query->whereDate("effectue_le", ">=", $depuis);
        }

        return $query->limit(200)->get()->map(fn($m) => [
            "id"          => $m->id,
            "sens"        => $m->sens,
            "montant"     => (float) $m->montant,
            "motif"       => $m->motif,
            "libelle"     => $m->libelleLisible(),
            "bookingId"   => $m->booking_id,
            "chargeId"    => $m->charge_id,
            "commentaire" => $m->commentaire,
            "par"         => static::auteur($m),
            "effectueLe"  => $m->effectue_le?->toISOString(),
        ])->all();
    }

    /**
     * Le nom de celui qui a passe l'ecriture.
     *
     * Un mouvement sans auteur reste possible (report automatique) :
     * on renvoie alors rien plutot qu'un nom trompeur.
     */
    private static function auteur($mouvement): ?string
    {
        $manager = $mouvement->manager_id
            ? \App\Models\Manager::find($mouvement->manager_id)
            : null;

        if ($manager === null) {
            return null;
        }

        return trim(($manager->first_name ?? "") . " " . ($manager->last_name ?? "")) ?: null;
    }

    private static function remises(Caisse $caisse): array
    {
        return RemiseCaisse::where("caisse_source_id", $caisse->id)
            ->orderByDesc("id")->limit(30)->get()
            ->map(fn($r) => [
                "id"             => $r->id,
                "montantDeclare" => (float) $r->montant_declare,
                "montantRecu"    => $r->montant_recu === null ? null : (float) $r->montant_recu,
                "statut"         => $r->statut,
                "ecart"          => $r->ecart(),
                "declareLe"      => $r->declare_le?->toISOString(),
                "confirmeLe"     => $r->confirme_le?->toISOString(),
                "destination"    => $r->destination->nom ?? null,
                "commentaire"    => $r->commentaire,
                "commentaireReception" => $r->commentaire_reception,
            ])->all();
    }

    /**
     * Les transferts qui attendent la confirmation de cette caisse.
     *
     * Le destinataire y trouve le detail et la piece jointe : il sait
     * ce qu'il accepte avant de l'accepter.
     */
    private static function transfertsAConfirmer(?Caisse $caisse): array
    {
        if ($caisse === null) {
            return [];
        }

        return RemiseCaisse::with("source")
            ->where("caisse_destination_id", $caisse->id)
            ->where("statut", RemiseCaisse::EN_ATTENTE)
            ->orderBy("declare_le")
            ->get()
            ->map(fn($r) => [
                "id"             => $r->id,
                "caisse"         => $r->source->nom ?? "-",
                "montantDeclare" => (float) $r->montant_declare,
                "declareLe"      => $r->declare_le?->toISOString(),
                "commentaire"    => $r->commentaire,
                "piece"          => $r->piece(),
            ])->all();
    }
}
