<?php

namespace App\Http\Controllers\dashboard;

use App\Http\Controllers\Controller;
use App\Models\Booking;
use App\Models\Manager;
use App\Models\MouvementCaisse;
use App\Models\Realstate;
use App\utils\JsonResponses;
use Carbon\Carbon;
use Carbon\CarbonPeriod;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Validator;

/**
 * Le calendrier de gestion d'un bien : prix de chaque nuit, dates bloquees
 * et reservations (y compris passees, pour l'historique).
 *
 * Les dates sont des nuits : un sejour du 10 au 13 occupe les nuits du
 * 10, 11 et 12 ; un blocage du 10 au 13 bloque les nuits du 10 au 13 inclus.
 */
class CalendrierController extends Controller
{
    use JsonResponses;

    private function refuserSansDroit(Request $request)
    {
        // Deja valide par le controle central des droits.
        if ($request->attributes->get("droit_verifie")) return null;
        $manager = $request->user();
        if (!$manager || !($manager->hasRole("admin") || $manager->can("update_property"))) {
            return $this->jsonResponse(false, self::NO_ACCESS, 403,
                ["msg" => ["Vous n'avez pas l'autorisation de modifier le calendrier de ce bien."]]);
        }
        return null;
    }

    /** Valide du/au ; renvoie [du, au] ou une reponse d'erreur. */
    private function periode(Request $request, int $maxJours, bool $finExclue = false)
    {
        $validator = Validator::make($request->all(), [
            "du" => ["required", "date_format:Y-m-d"],
            "au" => ["required", "date_format:Y-m-d", $finExclue ? "after:du" : "after_or_equal:du"],
        ], [
            "du.required"          => "Indiquez la date de début.",
            "au.required"          => "Indiquez la date de fin.",
            "au.after"             => "La date de départ doit suivre la date d'arrivée.",
            "au.after_or_equal"    => "La date de fin doit suivre la date de début.",
        ]);
        if ($validator->fails()) {
            return $this->validationErrorResponse($validator->errors());
        }

        $du = Carbon::parse($request->input("du"))->startOfDay();
        $au = Carbon::parse($request->input("au"))->startOfDay();
        if ((int) round($du->diffInDays($au)) > $maxJours) {
            return $this->validationErrorResponse(["msg" => ["La période ne peut pas dépasser {$maxJours} jours."]]);
        }

        return [$du, $au];
    }

    private static function nom($manager): ?string
    {
        return $manager ? (trim(($manager->first_name ?? "") . " " . ($manager->last_name ?? "")) ?: null) : null;
    }

    public function index(Request $request, $id)
    {
        $bien = Realstate::find($id);
        if (!$bien) {
            return $this->notFoundResponse("Bien introuvable");
        }

        $request->mergeIfMissing([
            "du" => now()->startOfMonth()->toDateString(),
            "au" => now()->addMonths(3)->endOfMonth()->toDateString(),
        ]);
        $periode = $this->periode($request, 800);
        if (!is_array($periode)) return $periode;
        [$du, $au] = $periode;
        $duTexte = $du->toDateString();
        $auTexte = $au->toDateString();

        $prix = DB::table("prix_nuits")
            ->where("realestate_id", $bien->id)
            ->whereBetween("date", [$duTexte, $auTexte])
            ->orderBy("date")
            ->get(["date", "prix"])
            ->map(fn($p) => ["date" => Carbon::parse($p->date)->toDateString(), "prix" => (float) $p->prix])
            ->values();

        $lignesBlocage = DB::table("blocages_biens")
            ->where("realestate_id", $bien->id)
            ->where("date_debut", "<=", $auTexte)
            ->where("date_fin", ">=", $duTexte)
            ->orderBy("date_debut")
            ->get();
        $auteurs = Manager::whereIn("id", $lignesBlocage->pluck("created_by")->filter()->unique())->get()->keyBy("id");
        $blocages = $lignesBlocage->map(fn($b) => [
            "id"    => $b->id,
            "du"    => Carbon::parse($b->date_debut)->toDateString(),
            "au"    => Carbon::parse($b->date_fin)->toDateString(),
            "nuits" => (int) round(Carbon::parse($b->date_debut)->diffInDays(Carbon::parse($b->date_fin)->addDay())),
            "motif" => $b->motif,
            "par"   => static::nom($auteurs[$b->created_by] ?? null),
        ])->values();

        $reservations = Booking::with(["client", "status", "manager"])
            ->where("realestate_id", $bien->id)
            ->where("checkin", "<=", $auTexte)
            ->where("checkout", ">=", $duTexte)
            ->whereHas("status", fn($q) => $q->where("code", "<>", "rejected"))
            ->orderBy("checkin")
            ->get();

        $encaisse = MouvementCaisse::whereIn("booking_id", $reservations->pluck("id")->all() ?: [0])
            ->selectRaw("booking_id, SUM(CASE WHEN sens = 'entree' THEN montant ELSE -montant END) AS net")
            ->groupBy("booking_id")
            ->pluck("net", "booking_id");

        $aujourdhui = today()->toDateString();
        $sejours = $reservations->map(function ($b) use ($encaisse, $aujourdhui) {
            $montant = round((float) $b->amount, 2);
            $recu = round(max(0, (float) ($encaisse[$b->id] ?? 0)), 2);
            $checkin = Carbon::parse($b->checkin)->toDateString();
            $checkout = Carbon::parse($b->checkout)->toDateString();
            return [
                "id"            => $b->id,
                "checkin"       => $checkin,
                "checkout"      => $checkout,
                "heureArrivee"  => $b->heure_arrivee,
                "heureDepart"   => $b->heure_depart,
                "nuits"         => (int) ($b->nb_days ?? round(Carbon::parse($checkin)->diffInDays(Carbon::parse($checkout)))),
                "client"        => $b->client ? [
                    "id"       => $b->client->id,
                    "nom"      => trim(($b->client->first_name ?? "") . " " . ($b->client->last_name ?? "")),
                    "tel"      => $b->client->tel,
                    "cin"      => $b->client->identity_number,
                ] : null,
                "montant"       => $montant,
                "prixNuit"      => $b->night_price !== null ? (float) $b->night_price : null,
                "avance"        => (float) ($b->avance ?? 0),
                "caution"       => (float) ($b->caution ?? 0),
                "remarques"     => $b->remarques,
                "statut"        => ["code" => $b->status?->code, "nom" => $b->status?->status],
                "encaisse"      => $recu,
                "reste"         => round(max(0, $montant - $recu), 2),
                // Hors charges, toute operation est reglee : pas de « non paye ».
                "paiement"      => "paye",
                "creePar"       => static::nom($b->manager),
                "contratPublic" => $b->getFirstMediaUrl("contract-public") ?: null,
                "contratPrive"  => $b->getFirstMediaUrl("contract-private") ?: null,
                "passee"        => $checkout < $aujourdhui,
            ];
        })->values();

        $baux = \App\Models\Bail::with("locataire")
            ->where("realestate_id", $bien->id)
            ->whereDate("date_debut", "<=", $auTexte)
            ->whereRaw("COALESCE(termine_le, date_fin) >= ?", [$duTexte])
            ->orderBy("date_debut")
            ->get()
            ->map(fn($b) => [
                "id"        => $b->id,
                "du"        => $b->date_debut->toDateString(),
                "au"        => ($b->termine_le ?? $b->date_fin)->toDateString(),
                "statut"    => $b->statut,
                "locataire" => \App\Services\Baux::nom($b->locataire),
                "tel"       => $b->locataire->tel ?? null,
                "loyer"     => $b->montantMensuel(),
            ])->values();

        return $this->successResponse([
            "bien" => [
                "id"       => $bien->id,
                "titre"    => $bien->title,
                "prixBase" => (float) ($bien->price ?? 0),
                // L'etat du jour, affiche en tete du calendrier.
                "statutJour" => \App\Services\EtatBien::pour($bien),
            ],
            "du"           => $duTexte,
            "au"           => $auTexte,
            "prix"         => $prix,
            "blocages"     => $blocages,
            "reservations" => $sejours,
            "airbnb"       => \Illuminate\Support\Facades\DB::table("airbnb_sejours")->where("realestate_id", $bien->id)
                ->where("du", "<=", $auTexte)->where("au", ">=", $duTexte)->orderBy("du")
                ->get()
                // Tout ce qu'il faut pour « Ajouter un contrat » ou « Voir le contrat » depuis le calendrier.
                ->map(fn($s) => \App\Services\SyncAirbnb::details($s) + ["bienTitre" => $bien->title, "prixNuit" => $bien->price !== null ? (float) $bien->price : null])->values(),
            "baux"         => $baux,
        ]);
    }

    /** Fixe le prix des nuits du..au (incluses). */
    public function definirPrix(Request $request, $id)
    {
        if ($refus = $this->refuserSansDroit($request)) return $refus;
        if (!Realstate::find($id)) {
            return $this->notFoundResponse("Bien introuvable");
        }

        $periode = $this->periode($request, 366);
        if (!is_array($periode)) return $periode;
        [$du, $au] = $periode;

        $validator = Validator::make($request->all(), [
            "prix" => ["required", "numeric", "min:0", "max:1000000"],
        ], [
            "prix.required" => "Indiquez le prix par nuit.",
            "prix.numeric"  => "Le prix doit être un nombre.",
        ]);
        if ($validator->fails()) {
            return $this->validationErrorResponse($validator->errors());
        }

        $prix = round((float) $request->input("prix"), 2);
        $jours = 0;
        DB::transaction(function () use ($id, $du, $au, $prix, $request, &$jours) {
            foreach (CarbonPeriod::create($du, $au) as $jour) {
                DB::table("prix_nuits")->updateOrInsert(
                    ["realestate_id" => $id, "date" => $jour->toDateString()],
                    ["prix" => $prix, "created_by" => $request->user()?->id, "updated_at" => now(), "created_at" => now()]
                );
                $jours++;
            }
        });

        return $this->successResponse(["jours" => $jours, "prix" => $prix]);
    }

    /** Revient au prix habituel pour les nuits du..au (incluses). */
    public function effacerPrix(Request $request, $id)
    {
        if ($refus = $this->refuserSansDroit($request)) return $refus;

        $periode = $this->periode($request, 800);
        if (!is_array($periode)) return $periode;
        [$du, $au] = $periode;

        $jours = DB::table("prix_nuits")
            ->where("realestate_id", $id)
            ->whereBetween("date", [$du->toDateString(), $au->toDateString()])
            ->delete();

        return $this->successResponse(["jours" => $jours]);
    }

    /** Prix d'un sejour : arrivee (du) et depart (au, nuit non comprise). */
    public function tarif(Request $request, $id)
    {
        $bien = Realstate::find($id);
        if (!$bien) {
            return $this->notFoundResponse("Bien introuvable");
        }

        $periode = $this->periode($request, 400, true);
        if (!is_array($periode)) return $periode;
        [$du, $au] = $periode;

        $base = (float) ($bien->price ?? 0);
        $speciaux = DB::table("prix_nuits")
            ->where("realestate_id", $bien->id)
            ->where("date", ">=", $du->toDateString())
            ->where("date", "<", $au->toDateString())
            ->get(["date", "prix"])
            ->mapWithKeys(fn($p) => [Carbon::parse($p->date)->toDateString() => (float) $p->prix]);

        $detail = [];
        $total = 0.0;
        foreach (CarbonPeriod::create($du, $au->copy()->subDay()) as $nuit) {
            $cle = $nuit->toDateString();
            $prix = $speciaux[$cle] ?? $base;
            $total += $prix;
            $detail[] = ["date" => $cle, "prix" => $prix, "special" => isset($speciaux[$cle])];
        }
        $nuits = count($detail);

        return $this->successResponse([
            "nuits"     => $nuits,
            "total"     => round($total, 2),
            "prixMoyen" => $nuits ? round($total / $nuits, 2) : $base,
            "prixBase"  => $base,
            "detail"    => $detail,
        ]);
    }

    /** Rend reservables les nuits du..au, en raccourcissant ou coupant les blocages. */
    public function debloquer(Request $request, $id)
    {
        if ($refus = $this->refuserSansDroit($request)) return $refus;

        $periode = $this->periode($request, 800);
        if (!is_array($periode)) return $periode;
        [$du, $au] = $periode;
        $duTexte = $du->toDateString();
        $auTexte = $au->toDateString();
        $veille = $du->copy()->subDay()->toDateString();
        $lendemain = $au->copy()->addDay()->toDateString();

        $modifies = 0;
        DB::transaction(function () use ($id, $duTexte, $auTexte, $veille, $lendemain, &$modifies) {
            $blocages = DB::table("blocages_biens")
                ->where("realestate_id", $id)
                ->where("date_debut", "<=", $auTexte)
                ->where("date_fin", ">=", $duTexte)
                ->lockForUpdate()
                ->get();

            foreach ($blocages as $b) {
                $debut = Carbon::parse($b->date_debut)->toDateString();
                $fin = Carbon::parse($b->date_fin)->toDateString();

                if ($debut >= $duTexte && $fin <= $auTexte) {
                    DB::table("blocages_biens")->where("id", $b->id)->delete();
                } elseif ($debut < $duTexte && $fin > $auTexte) {
                    // La periode debloquee est au milieu : le blocage est coupe en deux.
                    DB::table("blocages_biens")->where("id", $b->id)->update(["date_fin" => $veille, "updated_at" => now()]);
                    DB::table("blocages_biens")->insert([
                        "realestate_id" => $b->realestate_id,
                        "date_debut"    => $lendemain,
                        "date_fin"      => $fin,
                        "motif"         => $b->motif,
                        "created_by"    => $b->created_by,
                        "created_at"    => now(),
                        "updated_at"    => now(),
                    ]);
                } elseif ($debut < $duTexte) {
                    DB::table("blocages_biens")->where("id", $b->id)->update(["date_fin" => $veille, "updated_at" => now()]);
                } else {
                    DB::table("blocages_biens")->where("id", $b->id)->update(["date_debut" => $lendemain, "updated_at" => now()]);
                }
                $modifies++;
            }
        });

        return $this->successResponse(["blocagesModifies" => $modifies]);
    }
}
