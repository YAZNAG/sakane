<?php

namespace App\Http\Controllers\dashboard;

use App\Http\Controllers\Controller;
use App\Models\Booking;
use App\Models\FinancialTransaction;
use App\Models\MouvementCaisse;
use App\Services\Caisses;
use App\Services\FactureAgence;
use App\Services\HistoriqueReservation;
use App\Services\SoldeInsuffisant;
use App\utils\JsonResponses;
use Carbon\Carbon;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Validator;
use Throwable;

/**
 * Le detail d'une reservation, la modification de son prix, sa facture
 * (payee ou non) et les heures d'arrivee et de depart par defaut.
 */
class DetailReservationController extends Controller
{
    use JsonResponses;

    /** Les essais le coupent pour ne pas laisser de PDF sur le disque. */
    public static bool $genererContrats = true;

    private const TYPES = ["prolongation" => "Prolongation", "raccourcissement" => "Raccourcissement", "prix" => "Modification du prix"];

    private static function nom($m): ?string
    {
        return $m ? (trim(($m->first_name ?? "") . " " . ($m->last_name ?? "")) ?: null) : null;
    }

    private static function encaisseNet(int $bookingId): float
    {
        return round((float) MouvementCaisse::where("booking_id", $bookingId)
            ->selectRaw("COALESCE(SUM(CASE WHEN sens = 'entree' THEN montant ELSE -montant END), 0) AS net")->value("net"), 2);
    }

    private function modifications(int $bookingId): array
    {
        $lignes = DB::table("booking_modifications")->where("booking_id", $bookingId)->orderBy("created_at")->get();
        $noms = DB::table("managers")->whereIn("id", $lignes->pluck("manager_id")->filter())->get()->keyBy("id");
        return $lignes->map(fn($l) => [
            "id" => $l->id, "type" => $l->type, "typeLibelle" => self::TYPES[$l->type] ?? $l->type,
            "date" => Carbon::parse($l->created_at)->toISOString(),
            "ancienCheckout" => $l->ancien_checkout, "nouveauCheckout" => $l->nouveau_checkout, "nuitsDelta" => (int) $l->nuits_delta,
            "ancienPrixNuit" => $l->ancien_prix_nuit !== null ? (float) $l->ancien_prix_nuit : null,
            "nouveauPrixNuit" => $l->nouveau_prix_nuit !== null ? (float) $l->nouveau_prix_nuit : null,
            "ancienTotal" => $l->ancien_total !== null ? (float) $l->ancien_total : null,
            "nouveauTotal" => $l->nouveau_total !== null ? (float) $l->nouveau_total : null,
            "ecart" => (float) $l->ecart, "encaisse" => (float) $l->encaisse, "rembourse" => (float) $l->rembourse,
            "par" => static::nom($noms[$l->manager_id] ?? null),
        ])->values()->all();
    }

    private function resumeFacture(Booking $b): array
    {
        $f = DB::table("factures")->where("booking_id", $b->id)->first();
        $appliquee = $f && !empty($f->appliquee_le);
        $m = FactureAgence::montants($b, $f);
        return [
            "appliquee" => $appliquee,
            "numero" => $appliquee ? FactureAgence::numero($f) : null,
            "appliqueeLe" => $appliquee ? Carbon::parse($f->appliquee_le)->toISOString() : null,
            "appliqueePar" => $appliquee && $f->appliquee_par ? static::nom(DB::table("managers")->find($f->appliquee_par)) : null,
            // Le total de la reservation est le H.T ; la T.V.A s'y ajoute.
            "ht" => $m["ht"], "taux" => $m["taux"], "tva" => $m["tva"], "ttc" => $m["ttc"],
            "tvaEncaissee" => $appliquee ? (float) ($f->montant_encaisse ?? 0) : 0.0,
            // Appliquee a la creation : la T.V.A est comprise dans le total de la reservation.
            "tvaIncluse" => $appliquee && !empty($f->tva_incluse),
            "clientNom" => $f->client_nom ?? trim(($b->client->first_name ?? "") . " " . ($b->client->last_name ?? "")),
            "clientIce" => $f->client_ice ?? null, "clientAdresse" => $f->client_adresse ?? null,
        ];
    }

    /** Tout sur une reservation, pour sa page de detail. */
    public function detail(Request $request, $id)
    {
        $b = Booking::withTrashed()->with(["client", "realestate.city", "status", "manager"])->find($id);
        if (!$b) return $this->notFoundResponse("Réservation introuvable");
        $mouvements = MouvementCaisse::where("booking_id", $b->id)->orderBy("effectue_le")->get();
        $noms = DB::table("managers")->whereIn("id", $mouvements->pluck("manager_id")->filter())->get()->keyBy("id");
        $modifs = $this->modifications($b->id);
        return $this->successResponse([
            "id" => $b->id,
            "statut" => ["code" => $b->status?->code, "nom" => $b->status?->status],
            "supprimee" => $b->deleted_at !== null,
            "client" => $b->client ? ["id" => $b->client->id, "nom" => trim(($b->client->first_name ?? "") . " " . ($b->client->last_name ?? "")),
                "tel" => $b->client->tel, "cin" => $b->client->identity_number, "listeNoire" => $b->client->liste_noire_le !== null] : null,
            "bien" => $b->realestate ? ["id" => $b->realestate->id, "titre" => $b->realestate->title,
                "adresse" => trim(($b->realestate->address ?? "") . " " . ($b->realestate->city->name ?? ""))] : null,
            "checkin" => Carbon::parse($b->checkin)->toDateString(), "checkout" => Carbon::parse($b->checkout)->toDateString(),
            "heureArrivee" => \App\Services\HeuresSejour::arrivee($b), "heureDepart" => \App\Services\HeuresSejour::depart($b),
            "nuits" => (int) $b->nb_days, "personnes" => (int) $b->nb_guest, "typeInvite" => $b->type_guest,
            "prixNuit" => (float) $b->night_price, "montant" => (float) $b->amount, "avance" => (float) $b->avance, "caution" => (float) $b->caution,
            "encaisse" => static::encaisseNet($b->id), "reste" => round(max(0, (float) $b->amount - static::encaisseNet($b->id)), 2),
            "remarques" => $b->remarques, "creePar" => static::nom($b->manager), "creeLe" => $b->created_at?->toISOString(),
            "contratPublic" => $b->getFirstMediaUrl("contract-public") ?: null, "contratPrive" => $b->getFirstMediaUrl("contract-private") ?: null,
            "modifiee" => count($modifs) > 0, "modifications" => $modifs,
            "airbnb" => !empty($b->airbnb_uid),
            "paiements" => $mouvements->map(fn($m) => [
                "id" => $m->id, "date" => $m->effectue_le?->toISOString(), "sens" => $m->sens, "montant" => (float) $m->montant,
                "libelle" => $m->libelleLisible(), "par" => static::nom($noms[$m->manager_id] ?? null),
            ])->values(),
            "facture" => $this->resumeFacture($b),
        ]);
    }

    /**
     * Change le prix par nuit. Nouveau bulletin avec l'ancien et le nouveau
     * prix ; l'ecart passe par la caisse de l'agent qui fait l'operation.
     */
    public function modifierPrix(Request $request, $id)
    {
        $v = Validator::make($request->all(), [
            "prixNuit"  => ["required", "numeric", "min:0", "max:1000000"],
            "encaisse"  => ["nullable", "numeric", "min:0"],
            "rembourser" => ["nullable", "boolean"],
        ], ["prixNuit.required" => "Indiquez le nouveau prix par nuit."]);
        if ($v->fails()) return $this->validationErrorResponse($v->errors());

        $b = Booking::with(["status", "realestate", "client"])->find($id);
        if (!$b) return $this->notFoundResponse("Réservation introuvable");
        if (($b->status?->code) === "rejected") {
            return $this->validationErrorResponse(["msg" => ["Une réservation refusée ne peut pas être modifiée."]]);
        }
        $manager = $request->user();
        $nuits = max(1, (int) ($b->nb_days ?: round(Carbon::parse($b->checkin)->diffInDays(Carbon::parse($b->checkout)))));
        $ancienPrix = round((float) $b->night_price, 2);
        $ancienTotal = round((float) $b->amount, 2);
        $prix = round((float) $request->input("prixNuit"), 2);
        $total = round($nuits * $prix, 2);
        $ecart = round($total - $ancienTotal, 2);
        if (abs($ecart) < 0.01 && abs($prix - $ancienPrix) < 0.01) {
            return $this->validationErrorResponse(["msg" => ["Le prix n'a pas changé."]]);
        }
        $titre = $b->realestate->title ?? "bien";
        $par = static::nom($manager);
        $encaisse = 0.0;
        $rembourse = 0.0;

        DB::beginTransaction();
        try {
            $b->night_price = $prix;
            $b->amount = $total;
            $b->save();

            if ($ecart > 0) {
                FinancialTransaction::record("income", $ecart, "Modification du prix - " . $titre . ($par ? " (par " . $par . ")" : ""), $b->realestate_id, $b->id, null, null, $manager?->id);
                $encaisse = round((float) ($request->has("encaisse") ? $request->input("encaisse") : $ecart), 2);
                if ($encaisse > 0) {
                    Caisses::encaisser(Caisses::pour($manager), $encaisse, MouvementCaisse::ENCAISSEMENT_SOLDE, [
                        "booking_id" => $b->id, "manager_id" => $manager?->id, "libelle" => "Modification du prix - " . $titre,
                    ]);
                }
            } elseif ($ecart < 0) {
                FinancialTransaction::record("refund", abs($ecart), "Modification du prix - " . $titre . ($par ? " (par " . $par . ")" : ""), $b->realestate_id, $b->id, null, null, $manager?->id);
                // On ne rend que ce qui a ete encaisse au-dela du nouveau total.
                $trop = round(max(0, static::encaisseNet($b->id) - $total), 2);
                if ($request->boolean("rembourser", true) && $trop > 0) {
                    $rembourse = min($trop, abs($ecart));
                    Caisses::decaisser(Caisses::pour($manager), $rembourse, MouvementCaisse::REMBOURSEMENT, [
                        "booking_id" => $b->id, "manager_id" => $manager?->id, "libelle" => "Remboursement modification du prix - " . $titre,
                    ]);
                }
            }

            if (static::$genererContrats) {
                $ctl = app(ModifierReservationController::class);
                $frais = $b->fresh(["client", "realestate", "manager"]);
                foreach (["contract-private" => ["pr", true], "contract-public" => ["pb", false]] as $collection => [$prefixe, $prive]) {
                    $frais->addMediaFromString($ctl->pdfContrat($frais, $manager, $b->checkout, $ancienTotal, $prive, [
                        "type" => "modification", "oldPrixNuit" => $ancienPrix, "oldTotal" => $ancienTotal, "oldCheckout" => null,
                    ]))->usingFileName("contract-" . $prefixe . "-" . time() . ".pdf")->toMediaCollection($collection);
                }
            }

            HistoriqueReservation::noter([
                "booking_id" => $b->id, "type" => "prix", "ancien_prix_nuit" => $ancienPrix, "nouveau_prix_nuit" => $prix,
                "ancien_total" => $ancienTotal, "nouveau_total" => $total, "ecart" => $ecart,
                "encaisse" => $encaisse, "rembourse" => $rembourse, "manager_id" => $manager?->id,
            ]);
            DB::commit();
            // Le client et les gestionnaires recoivent le nouveau contrat (pas le syndic).
            \App\Services\MessagesModification::apresPrix($b->fresh(["client", "realestate", "manager"]), $manager, ["prixNuit" => $ancienPrix, "total" => $ancienTotal, "difference" => $ecart]);
        } catch (SoldeInsuffisant $e) {
            DB::rollBack();
            return $this->validationErrorResponse(["msg" => [$e->getMessage()]]);
        } catch (Throwable $th) {
            DB::rollBack();
            Log::error($th);
            return $this->serverErrorResponse("Le prix n'a pas pu être modifié : " . $th->getMessage());
        }
        return $this->detail($request, $b->id);
    }

    /** Les montants de la facture, pour le formulaire « Appliquer la facture ». */
    public function facture(Request $request, $id)
    {
        $b = Booking::with("client")->find($id);
        return $b ? $this->successResponse($this->resumeFacture($b)) : $this->notFoundResponse("Réservation introuvable");
    }

    /**
     * Applique la facture, une seule fois : le total de la reservation est
     * le H.T, la T.V.A s'y ajoute et entre dans la caisse de l'agent qui
     * fait l'operation ; elle apparait dans les statistiques. Le contrat
     * garde son montant.
     */
    public function appliquerFacture(Request $request, $id)
    {
        $v = Validator::make($request->all(), [
            "tva" => ["nullable", "numeric", "min:0", "max:30"],
            "clientNom" => ["nullable", "string", "max:190"], "clientIce" => ["nullable", "string", "max:40"],
            "clientAdresse" => ["nullable", "string", "max:255"],
        ], ["tva.max" => "Le taux de T.V.A ne dépasse pas 30 %."]);
        if ($v->fails()) return $this->validationErrorResponse($v->errors());
        $b = Booking::with(["client", "realestate"])->find($id);
        if (!$b) return $this->notFoundResponse("Réservation introuvable");
        $deja = DB::table("factures")->where("booking_id", $b->id)->whereNotNull("appliquee_le")->first();
        if ($deja) {
            return $this->validationErrorResponse(["msg" => ["Facture déjà appliquée (N° " . FactureAgence::numero($deja) . ", le "
                . Carbon::parse($deja->appliquee_le)->format("d/m/Y") . ") : vous pouvez seulement la voir ou la télécharger."]]);
        }
        $manager = $request->user();
        $champ = fn($cle) => $request->has($cle) ? trim((string) $request->input($cle, "")) : null;
        $taux = $request->filled("tva") ? round((float) $request->input("tva"), 2) : 20.0;

        try {
            DB::transaction(function () use ($b, $manager, $champ, $taux) {
                $f = FactureAgence::pour($b, ["nom" => $champ("clientNom"), "ice" => $champ("clientIce") ?? "", "adresse" => $champ("clientAdresse"), "tva" => $taux], $manager?->id);
                $ht = round((float) $b->amount, 2);
                $tva = round($ht * $taux / 100, 2);
                $numero = FactureAgence::numero($f);
                $titre = $b->realestate->title ?? "bien";
                $mvt = null;
                if ($tva > 0) {
                    $mvt = Caisses::encaisser(Caisses::pour($manager), $tva, MouvementCaisse::ENCAISSEMENT_SOLDE, [
                        "booking_id" => $b->id, "manager_id" => $manager?->id, "libelle" => "TVA facture N° " . $numero . " - " . $titre,
                    ]);
                    $par = static::nom($manager);
                    FinancialTransaction::record("income", $tva, "TVA - Facture N° " . $numero . " - " . $titre . ($par ? " (par " . $par . ")" : ""),
                        $b->realestate_id, $b->id, null, null, $manager?->id);
                }
                DB::table("factures")->where("id", $f->id)->update([
                    "taux_tva" => $taux, "montant_ht" => $ht, "montant_tva" => $tva, "montant_ttc" => round($ht + $tva, 2),
                    "date_facture" => today()->toDateString(), "appliquee_le" => now(), "appliquee_par" => $manager?->id,
                    "statut_paiement" => "paye", "paye_le" => now(), "montant_encaisse" => $tva, "encaisse_par" => $manager?->id,
                    "mouvement_caisse_id" => $mvt?->id, "updated_at" => now(),
                ]);
            });
        } catch (Throwable $th) {
            Log::error($th);
            return $this->validationErrorResponse(["msg" => ["La facture n'a pas pu être appliquée : " . $th->getMessage()]]);
        }
        return $this->successResponse($this->resumeFacture($b->fresh("client")));
    }

    /** Heures d'arrivee et de depart proposees par defaut. */
    public function heures(Request $request)
    {
        if ($request->isMethod("put")) {
            if (!$request->attributes->get("droit_verifie") && !$request->user()?->hasRole("admin")) {
                return $this->jsonResponse(false, self::NO_ACCESS, 403, ["msg" => ["Réservé aux administrateurs."]]);
            }
            $v = Validator::make($request->all(), ["arrivee" => ["nullable", "date_format:H:i"], "depart" => ["nullable", "date_format:H:i"]],
                ["arrivee.date_format" => "Heure d'arrivée au format 14:00.", "depart.date_format" => "Heure de départ au format 12:00."]);
            if ($v->fails()) return $this->validationErrorResponse($v->errors());
            foreach (["arrivee" => "heure_arrivee_defaut", "depart" => "heure_depart_defaut"] as $champ => $cle) {
                if ($request->filled($champ)) {
                    DB::table("reglages_agence")->updateOrInsert(["cle" => $cle], ["valeur" => $request->input($champ), "updated_at" => now(), "created_at" => now()]);
                }
            }
            \App\Services\HeuresSejour::oublier();
        }
        return $this->successResponse(["arrivee" => \App\Services\HeuresSejour::defautArrivee(), "depart" => \App\Services\HeuresSejour::defautDepart()]);
    }
}
