<?php

namespace App\Http\Controllers\dashboard;

use App\Http\Controllers\Controller;
use App\Models\Bail;
use App\Models\FinancialTransaction;
use App\Models\Loyer;
use App\Models\LoyerPaiement;
use App\Models\MouvementCaisse;
use App\Models\Realstate;
use App\Models\User;
use App\Services\Baux;
use App\Services\Caisses;
use App\Services\SoldeInsuffisant;
use App\Services\Telephone;
use App\utils\JsonResponses;
use Carbon\Carbon;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Validator;
use Throwable;

/**
 * Location longue duree : baux, echeancier, paiements et quittances.
 *
 * Consultation : droit « view_contract » ; modifications : droit
 * « create_contract » ; l'administrateur a tout.
 */
class BailController extends Controller
{
    use JsonResponses;

    private function refuser(Request $request, string $droit)
    {
        // Deja valide par le controle central des droits.
        if ($request->attributes->get("droit_verifie")) return null;
        $m = $request->user();
        if (!$m || !($m->hasRole("admin") || $m->can($droit))) {
            return $this->jsonResponse(false, self::NO_ACCESS, 403,
                ["msg" => ["Vous n'avez pas l'autorisation de " . ($droit === "view_contract" ? "consulter" : "gérer") . " les locations longue durée."]]);
        }
        return null;
    }

    /** Les personnes qui habitent avec le locataire, nettoyees. */
    private function colocataires(Request $request): ?array
    {
        $liste = collect((array) $request->input("colocataires", []))
            ->map(fn($x) => [
                "nom"  => trim((string) ($x["nom"] ?? "")),
                "cin"  => strtoupper(trim((string) ($x["cin"] ?? ""))),
                "tel"  => trim((string) ($x["tel"] ?? "")),
                "lien" => trim((string) ($x["lien"] ?? "")),
            ])
            ->filter(fn($x) => $x["nom"] !== "")
            ->values()
            ->all();
        return $liste ?: null;
    }

    private function erreur(string $message)
    {
        return $this->validationErrorResponse(["msg" => [$message]]);
    }

    private function resume(Bail $bail): array
    {
        $aujourdhui = today()->toDateString();
        $loyers = $bail->relationLoaded("loyers") ? $bail->loyers : $bail->loyers()->get();
        $dus = $loyers->filter(fn($l) => $l->echeance->toDateString() <= $aujourdhui);
        $prochain = $loyers->first(fn($l) => $l->reste() > 0.009);
        return [
            "totalDu"     => round($dus->sum(fn($l) => (float) $l->montant), 2),
            "totalPaye"   => round($loyers->sum(fn($l) => (float) $l->paye), 2),
            "resteDu"     => round($dus->sum(fn($l) => $l->reste()), 2),
            "enRetard"    => $loyers->filter(fn($l) => $l->statut() === "en_retard")->count(),
            "echeances"   => $loyers->count(),
            "prochainLoyer" => $prochain ? $this->loyerTableau($prochain, false) : null,
        ];
    }

    private function bailTableau(Bail $bail, bool $complet = false): array
    {
        $bien = $bail->bien;
        $loc = $bail->locataire;
        $proprio = $bien?->owner;
        $donnees = [
            "id"          => $bail->id,
            "statut"      => $bail->statut,
            "bien"        => $bien ? [
                "id"      => $bien->id,
                "titre"   => $bien->title,
                "adresse" => trim(($bien->address ?? "") . " " . ($bien->city->name ?? "")),
                "photo"   => $bien->getFirstMediaUrl("images") ?: null,
            ] : null,
            "locataire"   => $loc ? [
                "id"        => $loc->id,
                "nom"       => Baux::nom($loc),
                "tel"       => $loc->tel,
                "cin"       => $loc->identity_number,
                "listeNoire" => $loc->liste_noire_le !== null,
            ] : null,
            "proprietaire" => $proprio ? ["id" => $proprio->id, "nom" => $proprio->name, "tel" => $proprio->tel] : null,
            "dateDebut"   => $bail->date_debut->toDateString(),
            "dateFin"     => $bail->date_fin->toDateString(),
            "dureeMois"   => (int) $bail->duree_mois,
            "loyer"       => (float) $bail->loyer,
            "charges"     => (float) $bail->charges,
            "montantMensuel" => $bail->montantMensuel(),
            "depot"       => (float) $bail->depot,
            "depotStatut" => $bail->depot_statut,
            "depotRendu"  => $bail->depot_rendu !== null ? (float) $bail->depot_rendu : null,
            "relancesActives" => (bool) $bail->relances_actives,
            "termineLe"   => $bail->termine_le?->toDateString(),
            "motifFin"    => $bail->motif_fin,
            "joursRestants" => $bail->statut === "actif" ? (int) round(today()->diffInDays($bail->date_fin, false)) : null,
            "resume"      => $this->resume($bail),
        ];
        if ($complet) {
            $donnees += [
                "compteurEauEntree"   => $bail->compteur_eau_entree,
                "compteurElecEntree"  => $bail->compteur_elec_entree,
                "compteurEauSortie"   => $bail->compteur_eau_sortie,
                "compteurElecSortie"  => $bail->compteur_elec_sortie,
                "remarques"   => $bail->remarques,
                "colocataires" => array_values((array) ($bail->colocataires ?? [])),
                "cinPhotos"   => $bail->getMedia("cin")->map(fn($x) => $x->getUrl())->values(),
                "etatLieuxPhotos" => $bail->getMedia("etat_lieux")->map(fn($x) => $x->getUrl())->values(),
                "contratUrl"  => $bail->getFirstMediaUrl("contrat") ?: null,
                "creePar"     => Baux::nom($bail->auteur),
                "creeLe"      => $bail->created_at?->toDateTimeString(),
                "loyers"      => $bail->loyers->map(fn($l) => $this->loyerTableau($l, true))->values(),
            ];
        }
        return $donnees;
    }

    private function loyerTableau(Loyer $l, bool $avecPaiements): array
    {
        $d = [
            "id"           => $l->id,
            "bailId"       => $l->bail_id,
            "libelle"      => $l->libelle(),
            "periodeDebut" => $l->periode_debut->toDateString(),
            "periodeFin"   => $l->periode_fin->toDateString(),
            "echeance"     => $l->echeance->toDateString(),
            "montant"      => (float) $l->montant,
            "paye"         => (float) $l->paye,
            "reste"        => $l->reste(),
            "statut"       => $l->statut(),
        ];
        if ($avecPaiements) {
            $d["paiements"] = $l->paiements->map(fn($p) => $this->paiementTableau($p))->values();
        }
        return $d;
    }

    private function paiementTableau(LoyerPaiement $p): array
    {
        return [
            "id"           => $p->id,
            "montant"      => (float) $p->montant,
            "payeLe"       => $p->paye_le->toDateString(),
            "mode"         => $p->mode,
            "modeLibelle"  => LoyerPaiement::MODES[$p->mode] ?? $p->mode,
            "reference"    => $p->reference,
            "remarque"     => $p->remarque,
            "par"          => Baux::nom($p->manager),
            "quittanceUrl" => $p->getFirstMediaUrl("quittance") ?: null,
            "quittanceEnvoyeeLe" => $p->quittance_envoyee_le?->toDateTimeString(),
            "annule"       => $p->annule_le !== null,
            "annuleLe"     => $p->annule_le?->toDateTimeString(),
            "motifAnnulation" => $p->motif_annulation,
        ];
    }

    private function charger(int $id): ?Bail
    {
        return Bail::with(["bien.city", "bien.owner", "locataire", "auteur", "loyers.paiements.manager"])->find($id);
    }

    // ------------------------------------------------------------------

    public function index(Request $request)
    {
        if ($refus = $this->refuser($request, "view_contract")) return $refus;

        $q = Bail::with(["bien.city", "bien.owner", "locataire", "loyers"])
            ->orderByRaw("statut = 'actif' desc")
            ->orderBy("date_fin");
        $statut = $request->input("statut", "actif");
        if (in_array($statut, ["actif", "termine"], true)) {
            $q->where("statut", $statut);
        }
        if ($request->filled("realestate")) {
            $q->where("realestate_id", $request->input("realestate"));
        }
        if ($request->filled("client")) {
            $q->where("client_id", $request->input("client"));
        }
        if ($request->filled("q")) {
            $mot = "%" . trim($request->input("q")) . "%";
            $q->where(fn($w) => $w
                ->whereHas("bien", fn($b) => $b->where("title", "like", $mot)->orWhere("address", "like", $mot))
                ->orWhereHas("locataire", fn($l) => $l->withTrashed()->where("first_name", "like", $mot)
                    ->orWhere("last_name", "like", $mot)->orWhere("tel", "like", $mot)->orWhere("identity_number", "like", $mot)));
        }

        $baux = $q->get()->map(fn($b) => $this->bailTableau($b))->values();
        if ($request->boolean("impayes")) {
            $baux = $baux->filter(fn($b) => $b["resume"]["resteDu"] > 0)->values();
        }
        return $this->successResponse($baux);
    }

    /** Le tableau de bord du module. */
    public function tableau(Request $request)
    {
        if ($refus = $this->refuser($request, "view_contract")) return $refus;

        $aujourdhui = today();
        $debutMois = $aujourdhui->copy()->startOfMonth()->toDateString();
        $finMois = $aujourdhui->copy()->endOfMonth()->toDateString();

        $actifs = Bail::where("statut", "actif")->pluck("id");
        $loyers = Loyer::with("bail.locataire", "bail.bien")->whereIn("bail_id", $actifs)->get();

        $impayes = $loyers->filter(fn($l) => $l->echeance->lte($aujourdhui) && $l->reste() > 0.009);
        $duMois = $loyers->filter(fn($l) => $l->echeance->toDateString() >= $debutMois && $l->echeance->toDateString() <= $finMois);
        $encaisseMois = LoyerPaiement::whereNull("annule_le")->whereBetween("paye_le", [$debutMois, $finMois])->sum("montant");

        $parBail = $impayes->groupBy("bail_id")->map(function ($liste) {
            $bail = $liste->first()->bail;
            return [
                "bailId"    => $bail->id,
                "locataire" => Baux::nom($bail->locataire),
                "tel"       => $bail->locataire->tel ?? null,
                "bien"      => $bail->bien->title ?? "",
                "mois"      => $liste->count(),
                "reste"     => round($liste->sum(fn($l) => $l->reste()), 2),
                "plusAncien" => $liste->min(fn($l) => $l->echeance->toDateString()),
            ];
        })->sortByDesc("reste")->values();

        $finissants = Bail::with("bien", "locataire")->where("statut", "actif")
            ->whereDate("date_fin", "<=", $aujourdhui->copy()->addDays(60)->toDateString())
            ->orderBy("date_fin")->get()
            ->map(fn($b) => [
                "bailId" => $b->id, "locataire" => Baux::nom($b->locataire), "bien" => $b->bien->title ?? "",
                "dateFin" => $b->date_fin->toDateString(), "joursRestants" => (int) round($aujourdhui->diffInDays($b->date_fin, false)),
            ])->values();

        $prochains = $loyers->filter(fn($l) => $l->echeance->gt($aujourdhui) && $l->echeance->lte($aujourdhui->copy()->addDays(7)) && $l->reste() > 0.009)
            ->sortBy(fn($l) => $l->echeance->toDateString())
            ->map(fn($l) => $this->loyerTableau($l, false) + ["locataire" => Baux::nom($l->bail->locataire), "bien" => $l->bail->bien->title ?? ""])
            ->values();

        $biensLongue = Realstate::whereHas("type", fn($t) => $t->where("code", "rent-long"))->pluck("id");
        $occupes = Bail::where("statut", "actif")->whereDate("date_debut", "<=", $aujourdhui)->whereDate("date_fin", ">=", $aujourdhui)->pluck("realestate_id")->unique();

        return $this->successResponse([
            "bauxActifs"     => $actifs->count(),
            "biens"          => $biensLongue->count(),
            "biensLibres"    => $biensLongue->diff($occupes)->count(),
            "impayesTotal"   => round($impayes->sum(fn($l) => $l->reste()), 2),
            "impayesLocataires" => $parBail->count(),
            "attenduMois"    => round($duMois->sum(fn($l) => (float) $l->montant), 2),
            "encaisseMois"   => round((float) $encaisseMois, 2),
            "tauxRecouvrementMois" => $duMois->sum(fn($l) => (float) $l->montant) > 0
                ? round($duMois->sum(fn($l) => min((float) $l->paye, (float) $l->montant)) / $duMois->sum(fn($l) => (float) $l->montant) * 100, 1) : null,
            "impayes"        => $parBail,
            "finissants"     => $finissants,
            "prochainesEcheances" => $prochains,
        ]);
    }

    /** Les biens de location longue duree, avec le bail en cours s'il y en a un. */
    public function biens(Request $request)
    {
        if ($refus = $this->refuser($request, "view_contract")) return $refus;

        $aujourdhui = today()->toDateString();
        $baux = Bail::with("locataire")->where("statut", "actif")->get()->groupBy("realestate_id");
        $biens = Realstate::with("city")->whereNull("desactive_le")->whereHas("type", fn($t) => $t->where("code", "rent-long"))
            ->orderBy("title")->get()
            ->map(function ($b) use ($baux, $aujourdhui) {
                $bail = ($baux[$b->id] ?? collect())->sortBy("date_debut")->first();
                return [
                    "id"      => $b->id,
                    "titre"   => $b->title,
                    "adresse" => trim(($b->address ?? "") . " " . ($b->city->name ?? "")),
                    "photo"   => $b->getFirstMediaUrl("images") ?: null,
                    "loyerPropose" => (float) ($b->price ?? 0),
                    "bail"    => $bail ? [
                        "id" => $bail->id, "locataire" => Baux::nom($bail->locataire),
                        "dateDebut" => $bail->date_debut->toDateString(), "dateFin" => $bail->date_fin->toDateString(),
                        "enCours" => $bail->date_debut->toDateString() <= $aujourdhui,
                        "loyer" => (float) $bail->loyer,
                        "montantMensuel" => $bail->montantMensuel(),
                    ] : null,
                ];
            })->values();
        return $this->successResponse($biens);
    }

    public function show(Request $request, $id)
    {
        if ($refus = $this->refuser($request, "view_contract")) return $refus;
        $bail = $this->charger((int) $id);
        if (!$bail) return $this->notFoundResponse("Bail introuvable");
        return $this->successResponse($this->bailTableau($bail, true));
    }

    public function store(Request $request)
    {
        if ($refus = $this->refuser($request, "create_contract")) return $refus;

        $v = Validator::make($request->all(), [
            "realestate"  => ["required", "integer", "exists:realstates,id"],
            "client"      => ["required", "integer", "exists:users,id"],
            "dateDebut"   => ["required", "date_format:Y-m-d"],
            "dureeMois"   => ["required_without:dateFin", "nullable", "integer", "min:1", "max:120"],
            "dateFin"     => ["nullable", "date_format:Y-m-d", "after:dateDebut"],
            "colocataires"         => ["nullable", "array", "max:10"],
            "colocataires.*.nom"   => ["required_with:colocataires", "string", "max:120"],
            "colocataires.*.cin"   => ["nullable", "string", "max:30"],
            "colocataires.*.tel"   => ["nullable", "string", "max:30"],
            "colocataires.*.lien"  => ["nullable", "string", "max:60"],
            "cinPhotos"   => ["nullable", "array", "max:12"],
            "cinPhotos.*" => ["image", "max:10240"],
            "loyer"       => ["required", "numeric", "min:1", "max:10000000"],
            "charges"     => ["nullable", "numeric", "min:0", "max:10000000"],
            "depot"       => ["nullable", "numeric", "min:0", "max:10000000"],
            "depotRecu"   => ["nullable", "boolean"],
            "compteurEauEntree"  => ["nullable", "string", "max:40"],
            "compteurElecEntree" => ["nullable", "string", "max:40"],
            "remarques"   => ["nullable", "string", "max:3000"],
            "relancesActives" => ["nullable", "boolean"],
            "envoyerContrat"  => ["nullable", "boolean"],
            "photos"      => ["nullable", "array", "max:20"],
            "photos.*"    => ["image", "max:10240"],
        ], [
            "realestate.required" => "Choisissez le logement.",
            "client.required"     => "Choisissez le locataire.",
            "dateDebut.required"  => "Indiquez la date d'entrée.",
            "dureeMois.required_without" => "Indiquez la date de fin ou la durée du bail.",
            "dateFin.after"       => "La date de fin doit suivre la date d'entrée.",
            "colocataires.*.nom.required_with" => "Indiquez le nom de chaque personne qui habite avec le locataire.",
            "dureeMois.max"       => "La durée ne peut pas dépasser 120 mois.",
            "loyer.required"      => "Indiquez le loyer mensuel.",
            "loyer.min"           => "Le loyer doit être supérieur à zéro.",
        ]);
        if ($v->fails()) return $this->validationErrorResponse($v->errors());

        $bien = Realstate::with("type")->find($request->input("realestate"));
        if (($bien->type->code ?? null) !== "rent-long") {
            return $this->erreur("Ce logement n'est pas en location longue durée. Changez d'abord sa catégorie.");
        }

        $locataire = User::find($request->input("client"));
        if ($locataire->liste_noire_le) {
            return $this->erreur("Ce client est sur la liste noire"
                . ($locataire->liste_noire_motif ? " : " . $locataire->liste_noire_motif : "") . ". Impossible de lui louer un logement.");
        }

        $debut = Carbon::parse($request->input("dateDebut"))->startOfDay();
        if ($request->filled("dateFin")) {
            // La duree se deduit des dates : un mois entame compte.
            $fin = Carbon::parse($request->input("dateFin"))->startOfDay();
            $duree = 1;
            while (Baux::debutPeriode($debut, $duree)->subDay()->lt($fin)) {
                $duree++;
            }
            if ($duree > 120) {
                return $this->erreur("Un bail ne peut pas dépasser 120 mois.");
            }
        } else {
            $duree = (int) $request->input("dureeMois");
            $fin = Baux::debutPeriode($debut, $duree)->subDay();
        }

        if ($conflit = Baux::bailEnConflit($bien->id, $debut->toDateString(), $fin->toDateString())) {
            return $this->erreur("Ce logement est déjà loué à " . Baux::nom($conflit->locataire)
                . " du " . Baux::date($conflit->date_debut) . " au " . Baux::date($conflit->date_fin) . ".");
        }
        $sejour = \App\Models\Booking::with("client")->where("realestate_id", $bien->id)
            ->whereHas("status", fn($s) => $s->whereNotIn("code", ["rejected", "completed"]))
            ->whereDate("checkin", "<=", $fin->toDateString())
            ->whereDate("checkout", ">", $debut->toDateString())
            ->first();
        if ($sejour) {
            return $this->erreur("Une réservation de " . Baux::nom($sejour->client) . " occupe ce logement du "
                . Baux::date($sejour->checkin) . " au " . Baux::date($sejour->checkout) . ".");
        }

        $manager = $request->user();
        $depot = round((float) $request->input("depot", 0), 2);

        try {
            $bail = DB::transaction(function () use ($request, $bien, $locataire, $debut, $fin, $duree, $depot, $manager) {
                $bail = Bail::create([
                    "realestate_id" => $bien->id,
                    "client_id"     => $locataire->id,
                    "date_debut"    => $debut->toDateString(),
                    "date_fin"      => $fin->toDateString(),
                    "duree_mois"    => $duree,
                    "loyer"         => round((float) $request->input("loyer"), 2),
                    "charges"       => round((float) $request->input("charges", 0), 2),
                    "depot"         => $depot,
                    "depot_statut"  => $depot > 0 && $request->boolean("depotRecu") ? "recu" : "non_recu",
                    "compteur_eau_entree"  => $request->input("compteurEauEntree"),
                    "compteur_elec_entree" => $request->input("compteurElecEntree"),
                    "remarques"     => $request->input("remarques"),
                    "colocataires"  => $this->colocataires($request),
                    "relances_actives" => $request->has("relancesActives") ? $request->boolean("relancesActives") : true,
                    "created_by"    => $manager?->id,
                ]);
                Baux::genererEcheancier($bail);

                if ($depot > 0 && $request->boolean("depotRecu")) {
                    Caisses::encaisser(Caisses::pour($manager), $depot, MouvementCaisse::CAUTION_RECUE, [
                        "bail_id"    => $bail->id,
                        "manager_id" => $manager?->id,
                        "libelle"    => "Dépôt de garantie - " . ($bien->title ?? "bien"),
                    ]);
                }

                foreach ((array) $request->file("photos", []) as $photo) {
                    $bail->addMedia($photo)->toMediaCollection("etat_lieux");
                }
                foreach ((array) $request->file("cinPhotos", []) as $photo) {
                    $bail->addMedia($photo)->toMediaCollection("cin");
                }
                return $bail;
            });
        } catch (Throwable $th) {
            Log::error($th);
            return $this->serverErrorResponse("Le bail n'a pas pu être enregistré : " . $th->getMessage());
        }

        $avertissement = null;
        try {
            $url = Baux::enregistrerContrat($bail);
            if ($request->boolean("envoyerContrat")) {
                $avertissement = Baux::envoyerDocument($bail, $url, "bail-contrat-locataire", Baux::variables($bail), "contrat_bail.pdf");
            }
        } catch (Throwable $th) {
            Log::error($th);
            $avertissement = "Le bail est enregistré, mais son contrat PDF n'a pas pu être créé.";
        }

        return $this->successResponse($this->bailTableau($this->charger($bail->id), true) + ["avertissement" => $avertissement]);
    }

    public function update(Request $request, $id)
    {
        if ($refus = $this->refuser($request, "create_contract")) return $refus;
        $bail = Bail::find($id);
        if (!$bail) return $this->notFoundResponse("Bail introuvable");

        $v = Validator::make($request->all(), [
            "remarques"          => ["nullable", "string", "max:3000"],
            "relancesActives"    => ["nullable", "boolean"],
            "compteurEauEntree"  => ["nullable", "string", "max:40"],
            "compteurElecEntree" => ["nullable", "string", "max:40"],
            "loyer"              => ["nullable", "numeric", "min:1", "max:10000000"],
            "charges"            => ["nullable", "numeric", "min:0", "max:10000000"],
            "depotRecu"          => ["nullable", "boolean"],
            "colocataires"       => ["nullable", "array", "max:10"],
            "colocataires.*.nom" => ["required_with:colocataires", "string", "max:120"],
            "cinPhotos"          => ["nullable", "array", "max:12"],
            "cinPhotos.*"        => ["image", "max:10240"],
        ]);
        if ($v->fails()) return $this->validationErrorResponse($v->errors());

        DB::transaction(function () use ($request, $bail) {
            foreach (["remarques" => "remarques", "compteurEauEntree" => "compteur_eau_entree", "compteurElecEntree" => "compteur_elec_entree"] as $cle => $col) {
                if ($request->has($cle)) $bail->$col = $request->input($cle);
            }
            if ($request->has("relancesActives")) $bail->relances_actives = $request->boolean("relancesActives");
            if ($request->has("colocataires")) $bail->colocataires = $this->colocataires($request);
            foreach ((array) $request->file("cinPhotos", []) as $photo) {
                $bail->addMedia($photo)->toMediaCollection("cin");
            }

            // Un nouveau loyer vaut pour les echeances a venir encore non payees.
            if ($request->filled("loyer") || $request->has("charges")) {
                if ($request->filled("loyer")) $bail->loyer = round((float) $request->input("loyer"), 2);
                if ($request->has("charges")) $bail->charges = round((float) $request->input("charges", 0), 2);
                $bail->save();
                Loyer::where("bail_id", $bail->id)->whereDate("echeance", ">", today())->where("paye", 0)
                    ->get()->each(function ($l) use ($bail) {
                        $l->montant = $bail->montantMensuel();
                        $l->save();
                    });
            }

            if ($request->boolean("depotRecu") && $bail->depot_statut === "non_recu" && (float) $bail->depot > 0) {
                Caisses::encaisser(Caisses::pour($request->user()), (float) $bail->depot, MouvementCaisse::CAUTION_RECUE, [
                    "bail_id"    => $bail->id,
                    "manager_id" => $request->user()?->id,
                    "libelle"    => "Dépôt de garantie - " . ($bail->bien->title ?? "bien"),
                ]);
                $bail->depot_statut = "recu";
            }
            $bail->save();
        });

        return $this->successResponse($this->bailTableau($this->charger($bail->id), true));
    }

    /** Prolonge le bail de quelques mois, eventuellement a un nouveau loyer. */
    public function prolonger(Request $request, $id)
    {
        if ($refus = $this->refuser($request, "create_contract")) return $refus;
        $bail = Bail::with("locataire")->find($id);
        if (!$bail) return $this->notFoundResponse("Bail introuvable");
        if ($bail->statut !== "actif") return $this->erreur("Ce bail est terminé : créez un nouveau bail.");

        $v = Validator::make($request->all(), [
            "mois"  => ["required", "integer", "min:1", "max:120"],
            "loyer" => ["nullable", "numeric", "min:1", "max:10000000"],
            "envoyerContrat" => ["nullable", "boolean"],
        ], ["mois.required" => "Indiquez le nombre de mois à ajouter."]);
        if ($v->fails()) return $this->validationErrorResponse($v->errors());

        $debut = Carbon::parse($bail->date_debut);
        $nouvelleDuree = (int) $bail->duree_mois + (int) $request->input("mois");
        $nouvelleFin = Baux::debutPeriode($debut, $nouvelleDuree)->subDay();

        if ($conflit = Baux::bailEnConflit($bail->realestate_id, $bail->date_fin->copy()->addDay()->toDateString(), $nouvelleFin->toDateString(), $bail->id)) {
            return $this->erreur("Impossible : le logement est loué à " . Baux::nom($conflit->locataire) . " à partir du " . Baux::date($conflit->date_debut) . ".");
        }

        DB::transaction(function () use ($request, $bail, $nouvelleDuree, $nouvelleFin) {
            // Un dernier mois au prorata redevient un mois entier.
            Loyer::where("bail_id", $bail->id)->whereDate("periode_debut", ">", $bail->date_fin->copy()->subMonthNoOverflow()->toDateString())
                ->where("paye", 0)->delete();
            if ($request->filled("loyer")) {
                $bail->loyer = round((float) $request->input("loyer"), 2);
            }
            $bail->duree_mois = $nouvelleDuree;
            $bail->date_fin = $nouvelleFin->toDateString();
            $bail->save();
            Baux::genererEcheancier($bail);
        });

        $avertissement = null;
        try {
            $url = Baux::enregistrerContrat($bail->fresh());
            if ($request->boolean("envoyerContrat")) {
                $avertissement = Baux::envoyerDocument($bail, $url, "bail-contrat-locataire", Baux::variables($bail->fresh()), "contrat_bail.pdf");
            }
        } catch (Throwable $th) {
            Log::error($th);
        }

        return $this->successResponse($this->bailTableau($this->charger($bail->id), true) + ["avertissement" => $avertissement]);
    }

    /** Met fin au bail : echeances futures retirees, depot rendu, compteurs de sortie. */
    public function terminer(Request $request, $id)
    {
        if ($refus = $this->refuser($request, "create_contract")) return $refus;
        $bail = Bail::with("bien")->find($id);
        if (!$bail) return $this->notFoundResponse("Bail introuvable");
        if ($bail->statut !== "actif") return $this->erreur("Ce bail est déjà terminé.");

        $v = Validator::make($request->all(), [
            "dateSortie"  => ["required", "date_format:Y-m-d"],
            "motif"       => ["nullable", "string", "max:255"],
            "depotRendu"  => ["nullable", "numeric", "min:0"],
            "compteurEauSortie"  => ["nullable", "string", "max:40"],
            "compteurElecSortie" => ["nullable", "string", "max:40"],
        ], ["dateSortie.required" => "Indiquez la date de sortie du locataire."]);
        if ($v->fails()) return $this->validationErrorResponse($v->errors());

        $sortie = Carbon::parse($request->input("dateSortie"))->startOfDay();
        if ($sortie->lt($bail->date_debut)) {
            return $this->erreur("La date de sortie ne peut pas précéder l'entrée du " . Baux::date($bail->date_debut) . ".");
        }
        $rendu = $request->filled("depotRendu") ? round((float) $request->input("depotRendu"), 2) : null;
        if ($rendu !== null && $rendu > (float) $bail->depot + 0.001) {
            return $this->erreur("On ne peut pas rendre plus que le dépôt reçu (" . Baux::montant($bail->depot) . " MAD).");
        }
        if ($rendu !== null && $bail->depot_statut !== "recu") {
            return $this->erreur("Le dépôt de garantie n'a pas été enregistré comme reçu : il ne peut pas être rendu.");
        }

        $manager = $request->user();
        try {
            DB::transaction(function () use ($request, $bail, $sortie, $rendu, $manager) {
                $retires = Loyer::where("bail_id", $bail->id)->whereDate("periode_debut", ">", $sortie->toDateString())->get();
                foreach ($retires as $l) {
                    if ((float) $l->paye > 0) {
                        throw new \RuntimeException("Le loyer de " . $l->libelle() . " a déjà été payé : annulez d'abord ce paiement ou choisissez une date de sortie plus tardive.");
                    }
                    $l->delete();
                }

                if ($rendu !== null) {
                    $titre = $bail->bien->title ?? "bien";
                    if ($rendu > 0) {
                        Caisses::decaisser(Caisses::pour($manager), $rendu, MouvementCaisse::CAUTION_RENDUE, [
                            "bail_id"    => $bail->id,
                            "manager_id" => $manager?->id,
                            "libelle"    => "Dépôt de garantie rendu - " . $titre,
                        ]);
                    }
                    // Ce qui est garde du depot devient un revenu du bien.
                    $retenue = round((float) $bail->depot - $rendu, 2);
                    if ($retenue > 0) {
                        FinancialTransaction::record("income", $retenue, "Retenue sur dépôt de garantie - " . $titre, $bail->realestate_id);
                    }
                    $bail->depot_rendu = $rendu;
                    $bail->depot_statut = "restitue";
                }

                $bail->statut = "termine";
                $bail->termine_le = $sortie->toDateString();
                $bail->termine_par = $manager?->id;
                $bail->motif_fin = $request->input("motif");
                $bail->compteur_eau_sortie = $request->input("compteurEauSortie");
                $bail->compteur_elec_sortie = $request->input("compteurElecSortie");
                $bail->save();
            });
        } catch (SoldeInsuffisant $e) {
            return $this->erreur($e->getMessage());
        } catch (\RuntimeException $e) {
            return $this->erreur($e->getMessage());
        }

        return $this->successResponse($this->bailTableau($this->charger($bail->id), true));
    }

    public function destroy(Request $request, $id)
    {
        if ($refus = $this->refuser($request, "create_contract")) return $refus;
        $bail = Bail::find($id);
        if (!$bail) return $this->notFoundResponse("Bail introuvable");
        if ($bail->paiements()->exists()) {
            return $this->erreur("Des paiements ont été enregistrés sur ce bail : terminez-le au lieu de le supprimer.");
        }
        if ($bail->depot_statut === "recu") {
            return $this->erreur("Le dépôt de garantie a été encaissé : terminez le bail pour le rendre.");
        }
        DB::transaction(function () use ($bail) {
            Loyer::where("bail_id", $bail->id)->delete();
            $bail->delete();
        });
        return $this->successResponse(null);
    }

    public function contrat(Request $request, $id)
    {
        if ($refus = $this->refuser($request, "view_contract")) return $refus;
        $bail = Bail::find($id);
        if (!$bail) return $this->notFoundResponse("Bail introuvable");
        return response(Baux::pdfBail($bail), 200, [
            "Content-Type"        => "application/pdf",
            "Content-Disposition" => 'attachment; filename="bail_' . $bail->id . '.pdf"',
        ]);
    }

    public function envoyerContrat(Request $request, $id)
    {
        if ($refus = $this->refuser($request, "create_contract")) return $refus;
        $bail = Bail::with("locataire")->find($id);
        if (!$bail) return $this->notFoundResponse("Bail introuvable");
        $url = Baux::enregistrerContrat($bail);
        if ($echec = Baux::envoyerDocument($bail, $url, "bail-contrat-locataire", Baux::variables($bail), "contrat_bail.pdf")) {
            return $this->erreur($echec);
        }
        return $this->successResponse(["contratUrl" => $url]);
    }

    /** Ajuste le montant d'une echeance (remise, prorata). */
    public function modifierLoyer(Request $request, $id)
    {
        if ($refus = $this->refuser($request, "create_contract")) return $refus;
        $loyer = Loyer::find($id);
        if (!$loyer) return $this->notFoundResponse("Échéance introuvable");
        $v = Validator::make($request->all(), ["montant" => ["required", "numeric", "min:0", "max:10000000"]],
            ["montant.required" => "Indiquez le nouveau montant."]);
        if ($v->fails()) return $this->validationErrorResponse($v->errors());
        $montant = round((float) $request->input("montant"), 2);
        if ($montant + 0.001 < (float) $loyer->paye) {
            return $this->erreur("Le montant ne peut pas être inférieur à ce qui a déjà été payé (" . Baux::montant($loyer->paye) . " MAD).");
        }
        $loyer->montant = $montant;
        $loyer->save();
        return $this->successResponse($this->loyerTableau($loyer->fresh("paiements"), true));
    }

    public function payer(Request $request, $id)
    {
        if ($refus = $this->refuser($request, "create_contract")) return $refus;
        $loyer = Loyer::with("bail.bien", "bail.locataire")->find($id);
        if (!$loyer) return $this->notFoundResponse("Échéance introuvable");

        $v = Validator::make($request->all(), [
            "montant"   => ["required", "numeric", "min:1"],
            "payeLe"    => ["nullable", "date_format:Y-m-d", "before_or_equal:today"],
            "mode"      => ["nullable", "in:especes,virement,cheque"],
            "reference" => ["nullable", "string", "max:100"],
            "remarque"  => ["nullable", "string", "max:255"],
            "envoyerQuittance" => ["nullable", "boolean"],
        ], [
            "montant.required" => "Indiquez le montant reçu.",
            "payeLe.before_or_equal" => "La date de paiement ne peut pas être dans le futur.",
        ]);
        if ($v->fails()) return $this->validationErrorResponse($v->errors());

        $montant = round((float) $request->input("montant"), 2);
        if ($montant > $loyer->reste() + 0.001) {
            return $this->erreur("Le montant dépasse le reste à payer pour " . $loyer->libelle() . " (" . Baux::montant($loyer->reste()) . " MAD).");
        }

        try {
            $paiement = Baux::encaisser($loyer, $montant, $request->input("payeLe", today()->toDateString()),
                $request->input("mode", "especes"), $request->user(),
                ["reference" => $request->input("reference"), "remarque" => $request->input("remarque")]);
        } catch (Throwable $th) {
            Log::error($th);
            return $this->serverErrorResponse("Le paiement n'a pas pu être enregistré : " . $th->getMessage());
        }

        $avertissement = null;
        try {
            $url = Baux::enregistrerQuittance($paiement);
            if ($request->boolean("envoyerQuittance")) {
                $avertissement = Baux::envoyerDocument($loyer->bail, $url, "loyer-quittance",
                    Baux::variables($loyer->bail, $loyer->fresh(), $paiement), "quittance_loyer.pdf");
                if ($avertissement === null) {
                    $paiement->update(["quittance_envoyee_le" => now()]);
                }
            }
        } catch (Throwable $th) {
            Log::error($th);
            $avertissement = "Le paiement est enregistré, mais la quittance n'a pas pu être créée.";
        }

        return $this->successResponse([
            "loyer" => $this->loyerTableau($loyer->fresh("paiements.manager"), true),
            "paiement" => $this->paiementTableau($paiement->fresh("manager")),
            "avertissement" => $avertissement,
        ]);
    }

    public function annulerPaiement(Request $request, $id)
    {
        if ($refus = $this->refuser($request, "create_contract")) return $refus;
        $paiement = LoyerPaiement::with("loyer", "bail.bien")->find($id);
        if (!$paiement) return $this->notFoundResponse("Paiement introuvable");
        if ($paiement->annule_le) return $this->erreur("Ce paiement est déjà annulé.");

        Baux::annulerPaiement($paiement, $request->user(), $request->input("motif"));
        return $this->successResponse($this->loyerTableau($paiement->loyer->fresh("paiements.manager"), true));
    }

    public function quittance(Request $request, $id)
    {
        if ($refus = $this->refuser($request, "view_contract")) return $refus;
        $paiement = LoyerPaiement::find($id);
        if (!$paiement) return $this->notFoundResponse("Paiement introuvable");
        return response(Baux::pdfQuittance($paiement), 200, [
            "Content-Type"        => "application/pdf",
            "Content-Disposition" => 'attachment; filename="quittance_' . $paiement->id . '.pdf"',
        ]);
    }

    public function envoyerQuittance(Request $request, $id)
    {
        if ($refus = $this->refuser($request, "create_contract")) return $refus;
        $paiement = LoyerPaiement::with("loyer", "bail.locataire")->find($id);
        if (!$paiement) return $this->notFoundResponse("Paiement introuvable");
        if ($paiement->annule_le) return $this->erreur("Ce paiement a été annulé.");
        $url = Baux::enregistrerQuittance($paiement);
        if ($echec = Baux::envoyerDocument($paiement->bail, $url, "loyer-quittance",
            Baux::variables($paiement->bail, $paiement->loyer, $paiement), "quittance_loyer.pdf")) {
            return $this->erreur($echec);
        }
        $paiement->update(["quittance_envoyee_le" => now()]);
        return $this->successResponse(["quittanceUrl" => $url]);
    }
}
