<?php

namespace App\Http\Controllers\dashboard;

use App\Http\Controllers\Controller;
use App\Models\Booking;
use App\Services\FactureAgence;
use App\Services\Telephone;
use App\utils\JsonResponses;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Log;
use Throwable;
use WasenderApi\WasenderClient;

/**
 * La facture d'une reservation : la consulter, puis l'envoyer au client.
 *
 * Parametres facultatifs : clientNom, clientIce, clientAdresse (une
 * societe), tva (taux : 20 par defaut, 0 pour une facture sans T.V.A).
 */
class FactureController extends Controller
{
    use JsonResponses;

    private function client(Request $request): array
    {
        // Un champ absent ne change rien ; un champ envoye vide efface la valeur.
        $champ = fn($cle) => $request->has($cle) ? trim((string) $request->input($cle, "")) : null;
        return ["nom" => $champ("clientNom"), "ice" => $champ("clientIce"), "adresse" => $champ("clientAdresse"), "tva" => $request->input("tva", "")];
    }

    /** Renvoie la facture, encodee, pour affichage dans l'application. */
    public function voir(Request $request, $id)
    {
        $booking = Booking::with(["client", "realestate.city"])->find($id);
        if ($booking === null) {
            return $this->notFoundResponse("Réservation introuvable");
        }
        try {
            // Consultation seulement : le client, l'ICE et la T.V.A se reglent en appliquant la facture.
            $f = FactureAgence::apercu($booking);
            $m = FactureAgence::montants($booking, $f);
            return $this->successResponse([
                "pdf"         => base64_encode(FactureAgence::pdf($booking, $f)),
                "nom"         => empty($f->numero) ? "facture-apercu-" . $booking->id . ".pdf" : "facture-" . FactureAgence::numero($f) . ".pdf",
                "numero"      => empty($f->numero) ? null : FactureAgence::numero($f),
                "appliquee"   => !empty($f->appliquee_le),
                "ht"          => $m["ht"], "montantTva" => $m["tva"], "ttc" => $m["ttc"],
                "clientNom"   => $f->client_nom,
                "clientIce"   => $f->client_ice,
                "clientAdresse" => $f->client_adresse,
                "tva"         => (float) $f->taux_tva,
            ]);
        } catch (Throwable $th) {
            Log::error("Facture " . $booking->id . " : " . $th->getMessage());
            return $this->serverErrorResponse(["msg" => $th->getMessage()], "La facture n'a pas pu être générée");
        }
    }

    /** Envoie la facture au client, par WhatsApp. */
    public function envoyer(Request $request, $id)
    {
        $booking = Booking::with(["client", "realestate.city"])->find($id);
        if ($booking === null) {
            return $this->notFoundResponse("Réservation introuvable");
        }
        $numero = Telephone::international($booking->client->tel ?? "");
        if ($numero === "") {
            return $this->jsonResponse(false, "Ce client n'a pas de numéro de téléphone valide.", 422, null);
        }
        $f = \Illuminate\Support\Facades\DB::table("factures")->where("booking_id", $booking->id)->whereNotNull("appliquee_le")->first();
        if (!$f) {
            return $this->jsonResponse(false, "Appliquez d'abord la facture avant de l'envoyer.", 422, null);
        }
        try {
            $nom = "facture-" . FactureAgence::numero($f) . ".pdf";
            $dossier = storage_path("app/public/factures");
            if (!is_dir($dossier)) {
                mkdir($dossier, 0755, true);
            }
            file_put_contents($dossier . "/" . $nom, FactureAgence::pdf($booking, $f));
            $adresse = rtrim(config("app.url"), "/") . "/storage/factures/" . $nom;

            $wa = new WasenderClient(config("services.whatsapp.wasender_key"));
            $wa->sendDocument($numero, $adresse,
                "Bonjour " . trim((string) $booking->client->first_name) . ", voici votre facture n° " . FactureAgence::numero($f) . ".", $nom);

            return $this->successResponse(["envoyeA" => $numero, "numero" => FactureAgence::numero($f)]);
        } catch (Throwable $th) {
            Log::error("Envoi de la facture " . $booking->id . " : " . $th->getMessage());
            return $this->serverErrorResponse(["msg" => $th->getMessage()], "La facture n'a pas pu être envoyée");
        }
    }
}
