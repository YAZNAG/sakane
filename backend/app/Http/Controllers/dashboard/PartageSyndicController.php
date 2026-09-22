<?php

namespace App\Http\Controllers\dashboard;

use App\Http\Controllers\Controller;
use App\Models\Booking;
use App\Services\DonneesReservation;
use App\utils\JsonResponses;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Validator;
use Throwable;
use WasenderApi\WasenderClient;

/**
 * Partage du contrat de location avec le syndic (union des proprietaires).
 *
 * Le contrat public part par WhatsApp au numero du syndic, avec un message
 * modifiable. Le numero et le message par defaut sont des reglages de
 * l'agence, que l'on peut changer au moment de l'envoi.
 */
class PartageSyndicController extends Controller
{
    use JsonResponses;

    private const MESSAGE_DEFAUT = "Bonjour,\n\n"
        . "Veuillez trouver ci-joint le contrat de location de {apartment_name}"
        . " pour le séjour de {client_name}, du {check_in_date} au {check_out_date}.\n\n"
        . "Cordialement.";

    private static function lire(string $cle, string $defaut): string
    {
        $valeur = DB::table("reglages_agence")->where("cle", $cle)->value("valeur");
        return $valeur === null ? $defaut : (string) $valeur;
    }

    private static function ecrire(string $cle, ?string $valeur): void
    {
        $existe = DB::table("reglages_agence")->where("cle", $cle)->exists();
        if ($existe) {
            DB::table("reglages_agence")->where("cle", $cle)->update(["valeur" => $valeur, "updated_at" => now()]);
        } else {
            DB::table("reglages_agence")->insert(["cle" => $cle, "valeur" => $valeur, "created_at" => now(), "updated_at" => now()]);
        }
    }

    /**
     * Un numero au format international, chiffres seuls : 212612345678.
     * On ne complete pas un numero incomplet ou local : on le signale.
     */
    private static function numero(?string $brut): ?string
    {
        $chiffres = preg_replace('/\D/', '', (string) $brut);
        if (strlen($chiffres) < 10 || strlen($chiffres) > 15 || str_starts_with($chiffres, "0")) {
            return null;
        }
        return $chiffres;
    }

    /** Le texte du modele « Contrat envoye au syndic ». */
    private static function modele(): string
    {
        $texte = \App\Models\WhatsappMessage::where("code", "syndic-contrat")->where("langue", "fr")->value("message");
        if (is_string($texte) && trim($texte) !== "") {
            return $texte;
        }
        return \App\Services\CatalogueModeles::defaut("syndic-contrat") ?? self::MESSAGE_DEFAUT;
    }

    /** Le message enregistre au partage devient celui du module des messages. */
    private static function enregistrerModele(string $texte, ?int $par): void
    {
        \App\Models\WhatsappMessage::where("code", "syndic-contrat")->where("langue", "fr")
            ->update(["message" => $texte, "updated_by" => $par, "updated_at" => now()]);
    }

    public function reglages(Request $request)
    {
        // Le syndic rattache au bien de la reservation, s'il y en a un.
        $telephone = self::lire("syndic_telephone", "");
        $syndic = null;
        if ($request->filled("booking")) {
            $reservation = Booking::with("realestate")->find($request->input("booking"));
            $compte = $reservation?->realestate?->syndic_id
                ? \App\Models\Syndic::find($reservation->realestate->syndic_id) : null;
            if ($compte && $compte->telephone) {
                $telephone = $compte->telephone;
                $syndic = $compte->nom;
            }
        }

        return $this->successResponse([
            "syndic"     => $syndic,
            "telephone"  => $telephone,
            "message"    => self::modele(),
            "variables"  => ["{syndic_name}", "{client_name}", "{client_phone}", "{client_cin}", "{apartment_name}", "{address}", "{residence}", "{booking_id}", "{check_in_date}", "{check_in_time}", "{check_out_date}", "{check_out_time}", "{nights}", "{guests}", "{amount}", "{advance}", "{balance}", "{deposit}", "{notes}", "{agent_name}", "{contact}"],
        ]);
    }

    public function enregistrer(Request $request)
    {
        $validation = Validator::make($request->all(), [
            "telephone" => ["nullable", "string", "max:30"],
            "message"   => ["nullable", "string", "max:2000"],
        ]);
        if ($validation->fails()) {
            return $this->validationErrorResponse($validation->errors());
        }

        $telephone = trim((string) $request->input("telephone", ""));
        if ($telephone !== "" && self::numero($telephone) === null) {
            return $this->validationErrorResponse(["msg" => ["Numéro invalide : écrivez-le au format international, par exemple 212612345678."]]);
        }

        self::ecrire("syndic_telephone", $telephone === "" ? "" : self::numero($telephone));
        if ($request->filled("message")) {
            self::enregistrerModele((string) $request->input("message"), $request->user()?->id);
        }

        return $this->reglages($request);
    }

    public function partager(Request $request, $id)
    {
        $validation = Validator::make($request->all(), [
            "telephone"   => ["required", "string", "max:30"],
            "message"     => ["required", "string", "max:2000"],
            "enregistrer" => ["nullable", "boolean"],
        ], [
            "telephone.required" => "Indiquez le numéro du syndic.",
            "message.required"   => "Écrivez le message qui accompagne le contrat.",
        ]);
        if ($validation->fails()) {
            return $this->validationErrorResponse($validation->errors());
        }

        $telephone = self::numero($request->input("telephone"));
        if ($telephone === null) {
            return $this->validationErrorResponse(["msg" => ["Numéro invalide : écrivez-le au format international, par exemple 212612345678."]]);
        }

        $booking = Booking::with(["client", "realestate"])->find($id);
        if (!$booking) {
            return $this->notFoundResponse();
        }

        $contrat = $booking->getFirstMediaUrl("contract-public");
        if (empty($contrat)) {
            return $this->validationErrorResponse(["msg" => ["Le contrat de cette réservation n'est pas encore disponible."]]);
        }

        $compte = $booking->realestate?->syndic_id ? \App\Models\Syndic::find($booking->realestate->syndic_id) : null;
        $texte = \App\Services\EnvoiSyndic::message($booking, $compte, (string) $request->input("message"));

        $journal = fn(string $statut, ?string $erreur) => DB::table("syndic_envois")->insert([
            "syndic_id" => $compte?->id, "booking_id" => $booking->id, "telephone" => $telephone, "statut" => $statut,
            "erreur" => $erreur, "message" => $texte, "source" => "manuel", "envoye_par" => $request->user()?->id,
            "created_at" => now(), "updated_at" => now(),
        ]);
        try {
            $wa = new WasenderClient(config("services.whatsapp.wasender_key"));
            $wa->sendDocument($telephone, $contrat, $texte, "contrat_location.pdf");
            $journal("envoye", null);
        } catch (Throwable $th) {
            Log::error("Partage du contrat au syndic : " . $th->getMessage());
            $journal("echec", mb_substr($th->getMessage(), 0, 500));
            return $this->jsonResponse(false, "L'envoi WhatsApp a échoué. Vérifiez le numéro puis réessayez.", 502, null);
        }

        if ($request->boolean("enregistrer")) {
            self::ecrire("syndic_telephone", $telephone);
            self::enregistrerModele((string) $request->input("message"), $request->user()?->id);
        }

        return $this->successResponse(["envoyeA" => $telephone]);
    }
}
