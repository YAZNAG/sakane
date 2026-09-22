<?php

namespace App\Http\Controllers\dashboard;

use App\Http\Controllers\Controller;
use App\Models\Realstate;
use App\Services\SyncAirbnb;
use App\utils\JsonResponses;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Validator;
use Illuminate\Support\Str;

/** Liaison d'un bien avec son annonce Airbnb (calendrier iCal). */
class AirbnbController extends Controller
{
    use JsonResponses;

    private function refuser(Request $request)
    {
        // Deja valide par le controle central des droits.
        if ($request->attributes->get("droit_verifie")) return null;
        $m = $request->user();
        if (!$m || !($m->hasRole("admin") || $m->can("update_property"))) {
            return $this->jsonResponse(false, self::NO_ACCESS, 403,
                ["msg" => ["Vous n'avez pas l'autorisation de relier ce bien à Airbnb."]]);
        }
        return null;
    }

    public function afficher(Request $request, $id)
    {
        if (!Realstate::find($id)) return $this->notFoundResponse("Bien introuvable");
        return $this->successResponse(SyncAirbnb::etat((int) $id));
    }

    public function modifier(Request $request, $id)
    {
        if ($refus = $this->refuser($request)) return $refus;
        if (!Realstate::find($id)) return $this->notFoundResponse("Bien introuvable");

        $url = trim((string) $request->input("urlImport", ""));
        if ($url !== "" && !preg_match('~^https://~i', $url)) {
            return $this->validationErrorResponse(["urlImport" => ["Collez le lien complet donné par Airbnb (il commence par https://)."]]);
        }
        $v = Validator::make(["urlImport" => $url], ["urlImport" => ["nullable", "max:1000"]]);
        if ($v->fails()) return $this->validationErrorResponse($v->errors());

        $cal = SyncAirbnb::pour((int) $id);
        DB::table("airbnb_calendriers")->where("id", $cal->id)->update([
            "url_import" => $url !== "" ? $url : null, "updated_at" => now(),
            "dernier_statut" => null, "derniere_erreur" => null,
        ]);
        if ($url === "") {
            // Plus de lien : les sejours importes ne bloquent plus rien.
            DB::table("airbnb_sejours")->where("realestate_id", $id)->delete();
        } else {
            SyncAirbnb::importer(DB::table("airbnb_calendriers")->find($cal->id));
        }
        return $this->successResponse(SyncAirbnb::etat((int) $id));
    }

    public function synchroniser(Request $request, $id)
    {
        if (!Realstate::find($id)) return $this->notFoundResponse("Bien introuvable");
        $cal = SyncAirbnb::pour((int) $id);
        if (empty($cal->url_import)) {
            return $this->validationErrorResponse(["msg" => ["Ajoutez d'abord le lien du calendrier Airbnb de ce bien."]]);
        }
        SyncAirbnb::importer($cal);
        return $this->successResponse(SyncAirbnb::etat((int) $id));
    }

    /** Nouveau lien d'export : l'ancien cesse de fonctionner. */
    public function nouveauLien(Request $request, $id)
    {
        if ($refus = $this->refuser($request)) return $refus;
        $cal = SyncAirbnb::pour((int) $id);
        DB::table("airbnb_calendriers")->where("id", $cal->id)->update(["jeton_export" => Str::random(48), "updated_at" => now()]);
        return $this->successResponse(SyncAirbnb::etat((int) $id));
    }

    /** Le calendrier qu'Airbnb importe. Public : la cle secrete du lien suffit. */
    public function export(string $jeton)
    {
        $cal = DB::table("airbnb_calendriers")->where("jeton_export", $jeton)->first();
        if (!$cal) {
            abort(404);
        }
        return response(SyncAirbnb::exporter($cal), 200, [
            "Content-Type"        => "text/calendar; charset=utf-8",
            "Content-Disposition" => 'inline; filename="calendrier.ics"',
            "Cache-Control"       => "no-cache, must-revalidate",
        ]);
    }

    /**
     * Les reservations Airbnb a venir (et des 30 derniers jours), tous biens,
     * avec le contrat deja cree s'il existe.
     */
    public function sejours(Request $request)
    {
        $lignes = DB::table("airbnb_sejours")
            ->join("realstates", "realstates.id", "=", "airbnb_sejours.realestate_id")
            ->whereNull("realstates.deleted_at")
            ->whereNull("realstates.desactive_le")
            ->where("airbnb_sejours.type", "reservation")
            ->where("airbnb_sejours.au", ">=", today()->subDays(30)->toDateString())
            ->when($request->filled("bien"), fn($q) => $q->where("airbnb_sejours.realestate_id", (int) $request->input("bien")))
            ->orderBy("airbnb_sejours.du")
            ->get(["airbnb_sejours.*", "realstates.title as bien_titre", "realstates.price as bien_prix"]);
        return $this->successResponse($lignes->map(fn($s) => SyncAirbnb::details($s) + [
            "bienTitre" => $s->bien_titre, "prixNuit" => $s->bien_prix !== null ? (float) $s->bien_prix : null,
        ])->values());
    }

    /** Vue d'ensemble : l'etat de chaque bien relie. */
    public function liste(Request $request)
    {
        $lignes = DB::table("airbnb_calendriers")
            ->join("realstates", "realstates.id", "=", "airbnb_calendriers.realestate_id")
            ->whereNull("realstates.deleted_at")
            ->whereNull("realstates.desactive_le")
            // Le module n'affiche que les biens deja relies a Airbnb.
            ->whereNotNull("airbnb_calendriers.url_import")
            ->orderBy("realstates.title")
            ->get(["realstates.id", "realstates.title", "airbnb_calendriers.url_import", "airbnb_calendriers.derniere_sync_a",
                "airbnb_calendriers.dernier_statut", "airbnb_calendriers.derniere_erreur", "airbnb_calendriers.derniere_lecture_export_a"]);
        return $this->successResponse($lignes->map(fn($l) => [
            "bienId" => $l->id, "titre" => $l->title, "relie" => !empty($l->url_import),
            "derniereSyncA" => $l->derniere_sync_a, "statut" => $l->dernier_statut, "erreur" => $l->derniere_erreur,
            "derniereLectureAirbnbA" => $l->derniere_lecture_export_a,
        ])->values());
    }
}
