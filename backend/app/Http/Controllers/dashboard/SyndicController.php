<?php

namespace App\Http\Controllers\dashboard;

use App\Http\Controllers\Controller;
use App\Models\Realstate;
use App\Models\Syndic;
use App\Services\EnvoiSyndic;
use App\utils\JsonResponses;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Validator;

/**
 * Les syndics : un compte par immeuble (nom, telephone) et les biens qui en
 * dependent. A chaque nouvelle reservation dans l'un de ces biens, le syndic
 * recoit le contrat public par WhatsApp.
 *
 * La consultation est ouverte ; la creation et la modification sont
 * reservees aux administrateurs.
 */
class SyndicController extends Controller
{
    use JsonResponses;

    private function refuserSiNonAdmin(Request $request)
    {
        // Deja valide par le controle central des droits.
        if ($request->attributes->get("droit_verifie")) return null;
        $manager = $request->user();
        if (!$manager || !$manager->hasRole("admin")) {
            return $this->jsonResponse(false, self::NO_ACCESS, 403,
                ["msg" => ["Seuls les administrateurs peuvent gérer les syndics."]]);
        }
        return null;
    }

    private static function ligne(Syndic $syndic): array
    {
        $dernier = DB::table("syndic_envois")
            ->where("syndic_id", $syndic->id)
            ->orderByDesc("updated_at")
            ->first();

        return [
            "id"          => $syndic->id,
            "nom"         => $syndic->nom,
            "telephone"   => $syndic->telephone,
            "actif"       => (bool) $syndic->actif,
            "notes"       => $syndic->notes,
            "nombreBiens" => $syndic->biens->count(),
            "biens"       => $syndic->biens->map(fn($b) => ["id" => $b->id, "titre" => $b->title])->values(),
            "dernierEnvoi" => $dernier ? [
                "bookingId" => $dernier->booking_id,
                "statut"    => $dernier->statut,
                "erreur"    => $dernier->erreur,
                "le"        => \Carbon\Carbon::parse($dernier->updated_at)->toISOString(),
            ] : null,
            "creeLe"      => $syndic->created_at?->toISOString(),
        ];
    }

    private function valider(Request $request, bool $creation)
    {
        $obligatoire = $creation ? "required" : "sometimes";
        $validator = Validator::make($request->all(), [
            "nom"       => [$obligatoire, "string", "min:2", "max:150"],
            "telephone" => [$obligatoire, "string", "max:30"],
            "actif"     => ["sometimes", "boolean"],
            "notes"     => ["nullable", "string", "max:1000"],
            "biens"     => ["sometimes", "array"],
            "biens.*"   => ["integer", "exists:realstates,id"],
        ], [
            "nom.required"       => "Indiquez le nom du syndic.",
            "telephone.required" => "Indiquez le numéro WhatsApp du syndic.",
        ]);

        if ($validator->fails()) {
            return $this->validationErrorResponse($validator->errors());
        }

        if ($request->has("telephone") && EnvoiSyndic::numero($request->input("telephone")) === null) {
            return $this->validationErrorResponse(["telephone" => [
                "Numéro invalide : écrivez-le au format international, par exemple 212612345678.",
            ]]);
        }

        return null;
    }

    /** L'ancienne colonne garde le premier syndic du bien, pour les ecrans qui la lisent encore. */
    private static function colonneSyndic(array $biens): void
    {
        foreach (array_unique(array_map("intval", $biens)) as $id) {
            $premier = DB::table("realestate_syndic")->join("syndics", "syndics.id", "=", "realestate_syndic.syndic_id")
                ->whereNull("syndics.deleted_at")->where("realestate_id", $id)->orderBy("realestate_syndic.id")->value("syndic_id");
            Realstate::where("id", $id)->update(["syndic_id" => $premier]);
        }
    }

    public function index()
    {
        $syndics = Syndic::with("biens")->orderBy("nom")->get();
        return $this->successResponse($syndics->map(fn($s) => static::ligne($s))->values());
    }

    public function show($id)
    {
        $syndic = Syndic::with("biens")->find($id);
        if (!$syndic) {
            return $this->notFoundResponse("Syndic introuvable");
        }

        $envois = DB::table("syndic_envois")
            ->leftJoin("bookings", "bookings.id", "=", "syndic_envois.booking_id")
            ->leftJoin("realstates", "realstates.id", "=", "bookings.realestate_id")
            ->where("syndic_envois.syndic_id", $syndic->id)
            ->orderByDesc("syndic_envois.updated_at")
            ->limit(30)
            ->get([
                "syndic_envois.booking_id", "syndic_envois.statut", "syndic_envois.erreur",
                "syndic_envois.updated_at", "bookings.checkin", "bookings.checkout", "realstates.title",
            ])
            ->map(fn($e) => [
                "bookingId" => $e->booking_id,
                "bien"      => $e->title,
                "checkin"   => $e->checkin,
                "checkout"  => $e->checkout,
                "statut"    => $e->statut,
                "erreur"    => $e->erreur,
                "le"        => \Carbon\Carbon::parse($e->updated_at)->toISOString(),
            ]);

        return $this->successResponse(static::ligne($syndic) + ["envois" => $envois]);
    }

    /** Les biens de l'agence, avec le syndic auquel chacun est rattache. */
    public function biens()
    {
        $noms = Syndic::pluck("nom", "id");
        $liens = DB::table("realestate_syndic")->get()->groupBy("realestate_id");
        $biens = Realstate::whereHas("host", fn($q) => $q->where("agence", 1))
            ->whereNull("desactive_le")
            ->orderBy("title")
            ->get(["id", "title", "syndic_id", "transaction_id"])
            ->map(function ($b) use ($noms, $liens) {
                // Un bien peut dependre de plusieurs syndics.
                $syndics = collect($liens[$b->id] ?? [])->map(fn($l) => ["id" => $l->syndic_id, "nom" => $noms[$l->syndic_id] ?? null])
                    ->filter(fn($x) => $x["nom"] !== null)->values();
                return [
                    "id"       => $b->id,
                    "titre"    => $b->title,
                    "syndicId" => $syndics->first()["id"] ?? null,
                    "syndic"   => $syndics->isEmpty() ? null : $syndics->pluck("nom")->implode(", "),
                    "syndics"  => $syndics,
                ];
            });

        return $this->successResponse($biens->values());
    }

    public function store(Request $request)
    {
        if ($refus = $this->refuserSiNonAdmin($request)) return $refus;
        if ($refus = $this->valider($request, true)) return $refus;

        $syndic = DB::transaction(function () use ($request) {
            $syndic = Syndic::create([
                "nom"        => trim($request->input("nom")),
                "telephone"  => EnvoiSyndic::numero($request->input("telephone")),
                "actif"      => $request->boolean("actif", true),
                "notes"      => $request->input("notes"),
                "created_by" => $request->user()?->id,
            ]);

            // Un bien peut dependre de plusieurs syndics : il garde les autres.
            $biens = $request->input("biens", []);
            $syndic->biens()->sync($biens);
            static::colonneSyndic($biens);

            return $syndic;
        });

        return $this->createdResponse(static::ligne($syndic->fresh("biens")));
    }

    public function update(Request $request, $id)
    {
        if ($refus = $this->refuserSiNonAdmin($request)) return $refus;

        $syndic = Syndic::find($id);
        if (!$syndic) {
            return $this->notFoundResponse("Syndic introuvable");
        }
        if ($refus = $this->valider($request, false)) return $refus;

        DB::transaction(function () use ($request, $syndic) {
            if ($request->has("nom")) {
                $syndic->nom = trim($request->input("nom"));
            }
            if ($request->has("telephone")) {
                $syndic->telephone = EnvoiSyndic::numero($request->input("telephone"));
            }
            if ($request->has("actif")) {
                $syndic->actif = $request->boolean("actif");
            }
            if ($request->has("notes")) {
                $syndic->notes = $request->input("notes");
            }
            $syndic->save();

            if ($request->has("biens")) {
                $biens = $request->input("biens", []);
                $avant = $syndic->biens()->pluck("realstates.id")->all();
                $syndic->biens()->sync($biens);
                static::colonneSyndic(array_merge($avant, $biens));
            }
        });

        return $this->successResponse(static::ligne($syndic->fresh("biens")));
    }

    public function destroy(Request $request, $id)
    {
        if ($refus = $this->refuserSiNonAdmin($request)) return $refus;

        $syndic = Syndic::find($id);
        if (!$syndic) {
            return $this->notFoundResponse("Syndic introuvable");
        }

        DB::transaction(function () use ($syndic) {
            // Ses biens n'ont plus de syndic ; ils ne sont pas supprimes.
            $biens = $syndic->biens()->pluck("realstates.id")->all();
            $syndic->biens()->detach();
            $syndic->delete();
            static::colonneSyndic($biens);
        });

        return $this->successResponse(["supprime" => true]);
    }
}
