<?php

namespace App\Http\Controllers\dashboard;

use App\Http\Controllers\Controller;
use App\Models\Caisse;
use App\Models\MouvementCaisse;
use App\Services\Caisses;
use App\Services\SoldeInsuffisant;
use App\utils\JsonResponses;
use Carbon\Carbon;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Validator;
use Throwable;

/**
 * La caisse Airbnb, pour l'administrateur seul : son solde, son historique
 * et le transfert de son argent vers une autre caisse.
 */
class CaisseAirbnbController extends Controller
{
    use JsonResponses;

    private function refuser(Request $request)
    {
        // Deja valide par le controle central des droits.
        if ($request->attributes->get("droit_verifie")) return null;
        return $request->user()?->hasRole("admin") ? null
            : $this->jsonResponse(false, self::NO_ACCESS, 403, ["msg" => ["La caisse Airbnb est réservée aux administrateurs."]]);
    }

    private static function destinations(): array
    {
        return Caisse::with("manager")->where("actif", true)->where("type", "<>", "airbnb")->get()
            ->filter(fn($c) => $c->type === "agence" || $c->manager !== null)
            ->sortBy(fn($c) => [$c->type === "agence" ? 0 : 1, $c->nom])
            ->map(fn($c) => ["id" => $c->id, "nom" => $c->nom, "principale" => $c->type === "agence"])->values()->all();
    }

    public function afficher(Request $request)
    {
        if ($refus = $this->refuser($request)) return $refus;
        $caisse = Caisses::airbnb();
        $depuis = $request->filled("depuis") ? Carbon::parse($request->input("depuis"))->startOfDay() : now()->subMonths(3)->startOfDay();
        $mvts = MouvementCaisse::where("caisse_id", $caisse->id)->where("effectue_le", ">=", $depuis)
            ->where("motif", "<>", MouvementCaisse::OUVERTURE)->orderByDesc("effectue_le")->orderByDesc("id")->limit(500)->get();
        $noms = DB::table("managers")->whereIn("id", $mvts->pluck("manager_id")->filter())->get()->keyBy("id");
        $entrees = (float) MouvementCaisse::where("caisse_id", $caisse->id)->where("sens", "entree")->where("motif", "<>", MouvementCaisse::OUVERTURE)->sum("montant");
        $sorties = (float) MouvementCaisse::where("caisse_id", $caisse->id)->where("sens", "sortie")->sum("montant");
        return $this->successResponse([
            "id" => $caisse->id, "nom" => $caisse->nom, "solde" => round($caisse->solde(), 2),
            "totalEncaisse" => round($entrees, 2), "totalTransfere" => round($sorties, 2),
            "mouvements" => $mvts->map(fn($m) => [
                "id" => $m->id, "date" => $m->effectue_le?->toISOString(), "sens" => $m->sens, "montant" => (float) $m->montant,
                "libelle" => $m->libelleLisible(), "bookingId" => $m->booking_id, "commentaire" => $m->commentaire,
                "par" => ($p = $noms[$m->manager_id] ?? null) ? trim(($p->first_name ?? "") . " " . ($p->last_name ?? "")) : null,
            ])->values(),
            "destinations" => static::destinations(),
        ]);
    }

    /** Transfere une somme de la caisse Airbnb vers une autre caisse, immediatement. */
    public function transferer(Request $request)
    {
        if ($refus = $this->refuser($request)) return $refus;
        $v = Validator::make($request->all(), [
            "caisse" => ["required", "integer"], "montant" => ["required", "numeric", "gt:0"],
            "commentaire" => ["nullable", "string", "max:500"],
        ], ["caisse.required" => "Choisissez la caisse qui reçoit l'argent.", "montant.gt" => "Indiquez un montant."]);
        if ($v->fails()) return $this->validationErrorResponse($v->errors());
        $source = Caisses::airbnb();
        $destination = Caisse::where("actif", true)->where("type", "<>", "airbnb")->find($request->input("caisse"));
        if (!$destination) return $this->validationErrorResponse(["caisse" => ["Caisse introuvable."]]);
        $montant = round((float) $request->input("montant"), 2);
        $par = $request->user();
        try {
            DB::transaction(function () use ($source, $destination, $montant, $par, $request) {
                Caisses::decaisser($source, $montant, MouvementCaisse::REMISE_DECLAREE, [
                    "manager_id" => $par?->id, "libelle" => "Transfert vers " . $destination->nom, "commentaire" => $request->input("commentaire"),
                ]);
                Caisses::encaisser($destination, $montant, MouvementCaisse::REMISE_RECUE, [
                    "manager_id" => $par?->id, "libelle" => "Transfert depuis la caisse Airbnb", "commentaire" => $request->input("commentaire"),
                ]);
            });
        } catch (SoldeInsuffisant $e) {
            return $this->validationErrorResponse(["montant" => [$e->getMessage()]]);
        } catch (Throwable $th) {
            return $this->validationErrorResponse(["msg" => ["Le transfert n'a pas pu être fait : " . $th->getMessage()]]);
        }
        return $this->afficher($request);
    }
}
