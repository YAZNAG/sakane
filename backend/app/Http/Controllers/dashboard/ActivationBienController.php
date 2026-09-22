<?php

namespace App\Http\Controllers\dashboard;

use App\Http\Controllers\Controller;
use App\Models\Realstate;
use App\utils\JsonResponses;
use Carbon\Carbon;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Facades\Validator;

/**
 * Desactiver un bien : il n'apparait plus dans les listes (reservation,
 * calendrier, Airbnb, syndics...) ni dans les statistiques a partir de ce
 * jour. Son historique est garde ; il peut etre reactive.
 */
class ActivationBienController extends Controller
{
    use JsonResponses;

    private function refuser(Request $request)
    {
        // Deja valide par le controle central des droits.
        if ($request->attributes->get("droit_verifie")) return null;
        $m = $request->user();
        if (!$m || !($m->hasRole("admin") || $m->can("update_property"))) {
            return $this->jsonResponse(false, self::NO_ACCESS, 403, ["msg" => ["Vous n'avez pas l'autorisation de désactiver un bien."]]);
        }
        return null;
    }

    private static function etat(Realstate $bien): array
    {
        $par = $bien->desactive_par ? DB::table("managers")->find($bien->desactive_par) : null;
        return [
            "id" => $bien->id, "titre" => $bien->title,
            "desactive" => $bien->desactive_le !== null,
            "desactiveLe" => $bien->desactive_le ? Carbon::parse($bien->desactive_le)->toISOString() : null,
            "desactivePar" => $par ? trim(($par->first_name ?? "") . " " . ($par->last_name ?? "")) : null,
            "motif" => $bien->desactive_motif,
        ];
    }

    public function desactiver(Request $request, $id)
    {
        if ($refus = $this->refuser($request)) return $refus;
        $v = Validator::make($request->all(), ["motif" => ["nullable", "string", "max:255"]]);
        if ($v->fails()) return $this->validationErrorResponse($v->errors());
        $bien = Realstate::find($id);
        if (!$bien) return $this->notFoundResponse("Bien introuvable");
        if ($bien->desactive_le !== null) {
            return $this->validationErrorResponse(["msg" => ["Ce bien est déjà désactivé."]]);
        }
        // Un bien encore occupe ou reserve ne se desactive pas.
        $prochaine = DB::table("bookings")->join("booking_statuses", "booking_statuses.id", "=", "bookings.status_id")
            ->where("bookings.realestate_id", $bien->id)->whereNull("bookings.deleted_at")
            ->where("booking_statuses.code", "<>", "rejected")->where("bookings.checkout", ">", today()->toDateString())
            ->orderBy("bookings.checkin");
        $nombre = (clone $prochaine)->count();
        if ($nombre > 0) {
            $premiere = $prochaine->first(["bookings.checkin"]);
            return $this->validationErrorResponse(["msg" => ["Ce bien a " . $nombre . " réservation(s) en cours ou à venir (la prochaine le "
                . Carbon::parse($premiere->checkin)->format("d/m/Y") . ") : terminez-les ou supprimez-les avant de le désactiver."]]);
        }
        if (Schema::hasTable("baux") && DB::table("baux")->where("realestate_id", $bien->id)->whereNull("deleted_at")
                ->where("statut", "actif")->where("date_fin", ">=", today()->toDateString())->exists()) {
            return $this->validationErrorResponse(["msg" => ["Ce bien a un bail en cours : terminez-le avant de le désactiver."]]);
        }
        DB::table("realstates")->where("id", $bien->id)->update([
            "desactive_le" => now(), "desactive_par" => $request->user()?->id,
            "desactive_motif" => trim((string) $request->input("motif", "")) ?: null, "updated_at" => now(),
        ]);
        return $this->successResponse(static::etat($bien->fresh()));
    }

    public function reactiver(Request $request, $id)
    {
        if ($refus = $this->refuser($request)) return $refus;
        $bien = Realstate::find($id);
        if (!$bien) return $this->notFoundResponse("Bien introuvable");
        DB::table("realstates")->where("id", $bien->id)->update([
            "desactive_le" => null, "desactive_par" => null, "desactive_motif" => null, "updated_at" => now(),
        ]);
        return $this->successResponse(static::etat($bien->fresh()));
    }

    /** Les biens desactives, pour les retrouver et les reactiver. */
    public function liste(Request $request)
    {
        return $this->successResponse(Realstate::whereNotNull("desactive_le")->orderByDesc("desactive_le")->get()
            ->map(fn($b) => static::etat($b))->values());
    }
}
