<?php

namespace App\Http\Controllers\dashboard;

use App\Http\Controllers\Controller;
use App\Models\Booking;
use App\Models\Realstate;
use App\Models\User;
use App\utils\JsonResponses;
use Carbon\Carbon;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Validator;
use Mpdf\Mpdf;
use Throwable;

/**
 * Genere un apercu du bulletin d'hebergement avant signature.
 *
 * Rien n'est enregistre : la reservation n'existe pas encore. On
 * construit une instance en memoire, uniquement pour le rendu, afin que
 * le client lise exactement le document qu'il va signer.
 */
class ApercuContratController extends Controller
{
    use JsonResponses;

    public function apercu(Request $request)
    {
        $validator = Validator::make($request->all(), [
            "checkin"    => ["required", "date_format:Y-m-d"],
            "checkout"   => ["required", "date_format:Y-m-d", "after:checkin"],
            "guest"      => ["required", "integer", "gt:0"],
            "realestate" => ["required", "exists:realstates,id"],
            "client"     => ["required", "exists:users,id"],
            "nightPrice" => ["required", "numeric"],
            "typeGuest"  => ["required"],
            "avance"     => ["nullable", "numeric", "min:0"],
            "caution"    => ["nullable", "numeric", "min:0"],
            // Heures convenues avec le client ; a defaut, celles d'usage.
            "heureArrivee" => ["nullable", "date_format:H:i"],
            "heureDepart"  => ["nullable", "date_format:H:i"],
        ]);

        if ($validator->fails()) {
            return $this->validationErrorResponse($validator->errors());
        }

        try {
            $checkin  = Carbon::createFromFormat("Y-m-d", $request->input("checkin"));
            $checkout = Carbon::createFromFormat("Y-m-d", $request->input("checkout"));
            $nuits    = max(1, $checkin->diffInDays($checkout));
            $prix     = (float) $request->input("nightPrice");

            // Instance non enregistree : elle sert uniquement au rendu.
            $booking = new Booking([
                "checkin"     => $checkin,
                "checkout"    => $checkout,
                "nb_days"     => $nuits,
                "nb_guest"    => $request->input("guest"),
                "night_price" => $prix,
                "amount"      => $prix * $nuits,
                "type_guest"  => $request->input("typeGuest"),
                "avance"      => $request->input("avance", 0),
                "caution"     => $request->input("caution", 0),
                // Sans elles, l'apercu affichait les heures d'usage
                // quoi que l'agent ait saisi.
                "heure_arrivee" => $request->input("heureArrivee"),
                "heure_depart"  => $request->input("heureDepart"),
            ]);
            $booking->id = 0;

            $booking->setRelation("client",
                User::find($request->input("client")));
            $booking->setRelation("realestate",
                Realstate::with("city")->find($request->input("realestate")));

            $agence  = User::where("agence", "1")->first();
            $manager = $request->user();

            $html = view("pdf.contract", [
                "signature"  => null,
                "logo"       => $this->logo($agence),
                "booking"    => $booking,
                "agence"     => $agence,
                "manager"    => $manager,
                "isPrivate"  => true,
                "cachet"     => $this->cachet(),
                "qrContenu"  => "APERCU",
                "apercu"     => true,
                "nomAgence" => trim(($agence->first_name ?? '') . ' ' . ($agence->last_name ?? '')),
                "telAgence" => trim((string) ($agence->tel ?? '')),
                "adresseAgence" => trim((string) ($agence->address ?? '')),
                "emailAgence" => trim((string) ($agence->email ?? '')),
                "teinte" => "#2A8C94",
            ])->render();

            $mpdf = new Mpdf([
                // Les polices du projet, Amiri compris.
                ...config("pdf.polices"),
                "mode" => "utf-8", "format" => "A4", "orientation" => "P",
                "margin_left" => 15, "margin_right" => 15,
                "margin_top" => 20, "margin_bottom" => 20,
                "autoScriptToLang" => true, "autoLangToFont" => true,
            ]);
            $mpdf->WriteHTML($html);

            return $this->successResponse([
                "pdf" => base64_encode($mpdf->Output("", "S")),
                "nom" => "apercu-contrat.pdf",
            ]);
        } catch (Throwable $th) {
            return $this->serverErrorResponse(["msg" => $th->getMessage()],
                "L'aperçu n'a pas pu être généré");
        }
    }

    private function cachet(): ?string
    {
        $fichier = storage_path("app/public/cachet-agence.png");
        if (!is_readable($fichier)) {
            return null;
        }
        return "data:image/png;base64," . base64_encode(file_get_contents($fichier));
    }

    private function logo($agence): ?string
    {
        try {
            $url = $agence?->getFirstMediaPath("profile_photo");
            if ($url && is_readable($url)) {
                return "data:image/png;base64," . base64_encode(file_get_contents($url));
            }
        } catch (Throwable $th) {
            // Sans logo, le document reste lisible.
        }
        return null;
    }
}
