<?php

namespace App\Http\Controllers\dashboard;

use App\Http\Controllers\Controller;
use App\Http\Resources\DashboardResource\RappelResource;
use App\Models\Rappel;
use App\Models\RappelEnvoye;
use App\utils\JsonResponses;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Validator;

/**
 * Reglage des rappels de reservation et du message post-sejour.
 * Reserve aux administrateurs : ces messages partent aux clients.
 */
class RappelController extends Controller
{
    use JsonResponses;

    private function refuserSiNonAdmin(Request $request)
    {
        // Deja valide par le controle central des droits.
        if ($request->attributes->get("droit_verifie")) return null;
        $manager = $request->user();
        if (!$manager || !$manager->hasRole('admin')) {
            return $this->jsonResponse(false, self::NO_ACCESS, 403,
                ["msg" => ["Seuls les administrateurs peuvent régler les rappels."]]);
        }
        return null;
    }

    public function index(Request $request)
    {
        if ($refus = $this->refuserSiNonAdmin($request)) return $refus;

        $rappels = Rappel::orderBy("ordre")->orderBy("id")->get();
        return $this->successResponse(RappelResource::collection($rappels));
    }

    /**
     * Modifie un rappel : delai, destinataires, modeles, activation.
     * Le moment de reference n'est pas modifiable : un rappel d'arrivee
     * ne devient pas un message post-sejour.
     */
    public function update(Request $request, $id)
    {
        if ($refus = $this->refuserSiNonAdmin($request)) return $refus;

        $validator = Validator::make($request->all(), [
            "libelle"        => ["sometimes", "string", "max:120"],
            "decalageHeures" => ["sometimes", "integer", "between:-720,720"],
            "versClient"     => ["sometimes", "boolean"],
            "versAgent"      => ["sometimes", "boolean"],
            "modeleClient"   => ["nullable", "string", "max:60"],
            "modeleAgent"    => ["nullable", "string", "max:60"],
            "actif"          => ["sometimes", "boolean"],
        ]);
        if ($validator->fails()) {
            return $this->validationErrorResponse($validator->errors());
        }

        $rappel = Rappel::find($id);
        if (!$rappel) {
            return $this->notFoundResponse("Rappel introuvable");
        }

        // Le signe du decalage doit rester coherent avec le moment choisi :
        // un rappel d'arrivee se declenche avant, un message post-sejour apres.
        // Un rappel declenche par le constat du depart n'a pas de delai
        // a regler : le message part au clic.
        if ($request->has("decalageHeures") && $rappel->moment !== Rappel::MOMENT_CLIC) {
            $valeur = (int) $request->input("decalageHeures");
            $rappel->decalage_heures = $rappel->moment === Rappel::MOMENT_ARRIVEE
                ? -abs($valeur)
                : abs($valeur);
        }

        foreach ([
            "libelle"      => "libelle",
            "versClient"   => "vers_client",
            "versAgent"    => "vers_agent",
            "modeleClient" => "modele_client",
            "modeleAgent"  => "modele_agent",
            "actif"        => "actif",
        ] as $entree => $colonne) {
            if ($request->has($entree)) {
                $rappel->{$colonne} = in_array($entree, ["versClient", "versAgent", "actif"])
                    ? $request->boolean($entree)
                    : $request->input($entree);
            }
        }

        $rappel->save();

        return $this->successResponse(new RappelResource($rappel));
    }

    /** Suivi des envois d'un rappel : envoyes, en attente, en echec. */
    public function suivi(Request $request, $id)
    {
        if ($refus = $this->refuserSiNonAdmin($request)) return $refus;

        $rappel = Rappel::find($id);
        if (!$rappel) {
            return $this->notFoundResponse("Rappel introuvable");
        }

        $envois = RappelEnvoye::with("booking.client")
            ->where("rappel_id", $id)
            ->orderByDesc("id")
            ->limit(100)
            ->get()
            ->map(fn($e) => [
                "id"           => $e->id,
                "reservation"  => $e->booking_id,
                "client"       => $e->booking?->client
                    ? trim(($e->booking->client->first_name ?? '') . ' ' .
                           ($e->booking->client->last_name ?? ''))
                    : null,
                "destinataire" => $e->destinataire,
                "telephone"    => $e->telephone,
                "statut"       => $e->statut,
                "erreur"       => $e->erreur,
                "envoyeA"      => $e->envoye_a?->toISOString(),
            ]);

        return $this->successResponse([
            "envoyes"   => RappelEnvoye::where("rappel_id", $id)->where("statut", "envoye")->count(),
            "echecs"    => RappelEnvoye::where("rappel_id", $id)->where("statut", "echec")->count(),
            "aEnvoyer"  => RappelEnvoye::where("rappel_id", $id)->where("statut", "a_envoyer")->count(),
            "derniers"  => $envois,
        ]);
    }

    /** Remet en attente les envois en echec d'un rappel. */
    public function relancerEchecs(Request $request, $id)
    {
        if ($refus = $this->refuserSiNonAdmin($request)) return $refus;

        $nb = RappelEnvoye::where("rappel_id", $id)
            ->where("statut", "echec")
            ->update(["statut" => "a_envoyer", "erreur" => null]);

        return $this->successResponse(["relances" => $nb]);
    }
}
