<?php

namespace App\Http\Controllers\dashboard;

use App\Http\Controllers\Controller;
use App\Models\Booking;
use App\Models\Manager;
use App\Models\Realstate;
use App\utils\JsonResponses;
use Carbon\Carbon;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Validator;

/**
 * Les dates bloquees d'un bien.
 *
 * Pendant une periode bloquee (travaux, usage du proprietaire...), le
 * bien ne peut pas etre reserve : la reservation est refusee et le
 * calendrier montre ces jours comme indisponibles. Le debut et la fin
 * sont des nuits comprises : bloque du 15 au 18, le bien est libre la
 * nuit du 19.
 */
class BlocageController extends Controller
{
    use JsonResponses;

    public function index(Request $request, $id)
    {
        if (!Realstate::find($id)) {
            return $this->notFoundResponse();
        }

        $lignes = DB::table("blocages_biens")
            ->where("realestate_id", $id)
            ->where("date_fin", ">=", today()->toDateString())
            ->orderBy("date_debut")
            ->get();

        $auteurs = Manager::whereIn("id", $lignes->pluck("created_by")->filter()->unique())->get()->keyBy("id");

        return $this->successResponse([
            "blocages" => $lignes->map(fn($b) => [
                "id"     => $b->id,
                "du"     => $b->date_debut,
                "au"     => $b->date_fin,
                "nuits"  => (int) round(Carbon::parse($b->date_debut)->diffInDays(Carbon::parse($b->date_fin)->addDay())),
                "motif"  => $b->motif,
                "par"    => ($a = $auteurs[$b->created_by] ?? null) ? trim(($a->first_name ?? "") . " " . ($a->last_name ?? "")) : null,
                "creeLe" => $b->created_at,
            ])->values(),
        ]);
    }

    public function store(Request $request, $id)
    {
        if (!Realstate::find($id)) {
            return $this->notFoundResponse();
        }

        $validation = Validator::make($request->all(), [
            "du"    => ["required", "date_format:Y-m-d"],
            "au"    => ["required", "date_format:Y-m-d", "after_or_equal:du"],
            "motif" => ["nullable", "string", "max:200"],
        ], [
            "au.after_or_equal" => "La date de fin doit suivre la date de début.",
        ]);

        if ($validation->fails()) {
            return $this->validationErrorResponse($validation->errors());
        }

        $du = $request->input("du");
        $au = $request->input("au");
        $lendemain = Carbon::parse($au)->addDay()->toDateString();

        // On ne bloque pas des nuits deja vendues : la reservation passe d'abord.
        $reservation = Booking::with("client")
            ->where("realestate_id", $id)
            ->whereHas("status", fn($q) => $q->whereIn("code", ["pending", "confirmed", "payed"]))
            ->where("checkin", "<", $lendemain)
            ->where("checkout", ">", $du)
            ->orderBy("checkin")
            ->first();

        if ($reservation) {
            $client = trim(($reservation->client->first_name ?? "") . " " . ($reservation->client->last_name ?? ""));
            return $this->validationErrorResponse(["msg" => [
                "Une réservation occupe déjà ces dates : " . ($client !== "" ? $client . ", " : "")
                . "du " . Carbon::parse($reservation->checkin)->format("d/m/Y")
                . " au " . Carbon::parse($reservation->checkout)->format("d/m/Y") . ".",
            ]]);
        }

        $id_blocage = DB::table("blocages_biens")->insertGetId([
            "realestate_id" => $id,
            "date_debut"    => $du,
            "date_fin"      => $au,
            "motif"         => $request->input("motif"),
            "created_by"    => $request->user()?->id,
            "created_at"    => now(),
            "updated_at"    => now(),
        ]);

        return $this->successResponse(["id" => $id_blocage]);
    }

    public function destroy(Request $request, $id)
    {
        $supprimees = DB::table("blocages_biens")->where("id", $id)->delete();

        return $supprimees ? $this->successResponse(null) : $this->notFoundResponse();
    }
}
