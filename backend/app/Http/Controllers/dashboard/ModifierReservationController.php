<?php

namespace App\Http\Controllers\dashboard;

use App\Http\Controllers\Controller;
use App\Models\Booking;
use App\Models\FinancialTransaction;
use App\Models\User;
use App\utils\JsonResponses;
use Carbon\Carbon;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Validator;
use Mpdf\Mpdf;
use Throwable;

/**
 * Change les dates et le prix par nuit d'une reservation, depuis le
 * calendrier du bien.
 *
 * Le montant du sejour devient nuits x prix. L'ecart avec l'ancien montant
 * est inscrit en recette (hausse) ou en remboursement (baisse), comme une
 * prolongation ou un raccourcissement. Aucun mouvement de caisse n'est
 * fait ici : l'argent recu ou rendu passe par la caisse, comme d'habitude.
 */
class ModifierReservationController extends Controller
{
    use JsonResponses;

    /** Les essais le coupent pour ne pas laisser de PDF sur le disque. */
    protected bool $genererContrats = true;

    public function modifier(Request $request, $id)
    {
        $manager = $request->user();
        if (!$request->attributes->get("droit_verifie") && (!$manager || !($manager->hasRole("admin") || $manager->can("extend_reservation") || $manager->can("reduce_reservation")))) {
            return $this->jsonResponse(false, self::NO_ACCESS, 403,
                ["msg" => ["Vous n'avez pas l'autorisation de modifier cette réservation."]]);
        }

        $validator = Validator::make($request->all(), [
            "checkin"  => ["required", "date_format:Y-m-d"],
            "checkout" => ["required", "date_format:Y-m-d", "after:checkin"],
            "prixNuit" => ["required", "numeric", "min:0", "max:1000000"],
        ], [
            "checkin.required"  => "Indiquez la date d'arrivée.",
            "checkout.required" => "Indiquez la date de départ.",
            "checkout.after"    => "La date de départ doit suivre la date d'arrivée.",
            "prixNuit.required" => "Indiquez le prix par nuit.",
            "prixNuit.numeric"  => "Le prix par nuit doit être un nombre.",
        ]);
        if ($validator->fails()) {
            return $this->validationErrorResponse($validator->errors());
        }

        $booking = Booking::with(["status", "realestate"])->find($id);
        if (!$booking) {
            return $this->notFoundResponse("Réservation introuvable");
        }
        if (in_array($booking->status?->code, ["rejected", "completed"], true)) {
            return $this->validationErrorResponse(["msg" => ["Une réservation terminée ou refusée ne peut plus être modifiée."]]);
        }

        $arrivee = Carbon::parse($request->input("checkin"))->startOfDay();
        $depart = Carbon::parse($request->input("checkout"))->startOfDay();
        $arriveeTexte = $arrivee->toDateString();
        $departTexte = $depart->toDateString();

        $autre = Booking::with("client")
            ->where("realestate_id", $booking->realestate_id)
            ->where("id", "<>", $booking->id)
            ->whereHas("status", fn($q) => $q->where("code", "<>", "rejected"))
            ->where("checkin", "<", $departTexte)
            ->where("checkout", ">", $arriveeTexte)
            ->orderBy("checkin")
            ->first();
        if ($autre) {
            $nom = trim(($autre->client->first_name ?? "") . " " . ($autre->client->last_name ?? ""));
            return $this->validationErrorResponse(["msg" => ["Ces dates chevauchent la réservation de "
                . ($nom ?: "un autre client") . " du " . Carbon::parse($autre->checkin)->format("d/m/Y")
                . " au " . Carbon::parse($autre->checkout)->format("d/m/Y") . "."]]);
        }

        $bloque = DB::table("blocages_biens")
            ->where("realestate_id", $booking->realestate_id)
            ->where("date_debut", "<", $departTexte)
            ->where("date_fin", ">=", $arriveeTexte)
            ->orderBy("date_debut")
            ->first();
        if ($airbnb = \App\Services\SyncAirbnb::conflit((int) $booking->realestate_id, $arriveeTexte, $departTexte)) {
            return $this->validationErrorResponse(["msg" => [\App\Services\SyncAirbnb::messageConflit($airbnb)]]);
        }

        if ($bloque) {
            return $this->validationErrorResponse(["msg" => ["Le bien est bloqué du "
                . Carbon::parse($bloque->date_debut)->format("d/m/Y") . " au "
                . Carbon::parse($bloque->date_fin)->format("d/m/Y") . "."]]);
        }

        $nuits = (int) round($arrivee->diffInDays($depart));
        $prixNuit = round((float) $request->input("prixNuit"), 2);
        $ancienMontant = round((float) $booking->amount, 2);
        $nouveauMontant = round($nuits * $prixNuit, 2);
        $ecart = round($nouveauMontant - $ancienMontant, 2);
        $ancienDepart = $booking->checkout;
        $titre = $booking->realestate->title ?? "bien";

        DB::beginTransaction();
        try {
            $booking->checkin = $arriveeTexte;
            $booking->checkout = $departTexte;
            $booking->nb_days = $nuits;
            $booking->night_price = $prixNuit;
            $booking->amount = $nouveauMontant;
            $booking->save();

            if ($ecart > 0) {
                FinancialTransaction::record("income", $ecart, "Modification reservation - " . $titre,
                    $booking->realestate_id, $booking->id);
            } elseif ($ecart < 0) {
                FinancialTransaction::record("refund", abs($ecart), "Modification reservation - " . $titre,
                    $booking->realestate_id, $booking->id);
            }

            if ($this->genererContrats) {
                $this->regenererContrats($booking->fresh(), $request->user(), $ancienDepart, $ancienMontant);
            }

            DB::commit();
        } catch (Throwable $th) {
            DB::rollBack();
            Log::error($th);
            return $this->serverErrorResponse("La réservation n'a pas pu être modifiée : " . $th->getMessage());
        }

        return $this->successResponse([
            "id"            => $booking->id,
            "checkin"       => $arriveeTexte,
            "checkout"      => $departTexte,
            "nuits"         => $nuits,
            "prixNuit"      => $prixNuit,
            "montant"       => $nouveauMontant,
            "ancienMontant" => $ancienMontant,
            "ecart"         => $ecart,
        ]);
    }

    /** Refait les contrats prive et public avec les nouvelles dates. */
    protected function regenererContrats(Booking $booking, $manager, $ancienDepart, $ancienMontant): void
    {
        foreach (["contract-private" => ["pr", true], "contract-public" => ["pb", false]] as $collection => [$prefixe, $prive]) {
            $booking->addMediaFromString($this->pdfContrat($booking, $manager, $ancienDepart, $ancienMontant, $prive))
                ->usingFileName("contract-" . $prefixe . "-" . time() . ".pdf")
                ->toMediaCollection($collection);
        }
    }

    /** Le contenu PDF d'un contrat, sans l'enregistrer. */
    public function pdfContrat(Booking $booking, $manager, $ancienDepart, $ancienMontant, bool $prive, array $extra = []): string
    {
        $image = function (?string $chemin) {
            if (empty($chemin)) return null;
            try {
                return "data:" . mime_content_type($chemin) . ";base64," . base64_encode(file_get_contents($chemin));
            } catch (Throwable $th) {
                return null;
            }
        };

        $agence = User::where("agence", "1")->first();
        $fichierCachet = storage_path("app/public/cachet-agence.png");
        $polices = config("pdf.polices");

        $options = [
            "mode" => "utf-8",
            "format" => "A4",
            "orientation" => "P",
            "autoScriptToLang" => true,
            "autoLangToFont" => true,
        ];
        if (is_array($polices)) {
            // Mise en page d'Alwed : polices arabes et marges larges.
            $options = array_merge($polices, $options, ["margin_left" => 15, "margin_right" => 15, "margin_top" => 20, "margin_bottom" => 20]);
        } else {
            $options += ["margin_left" => 12, "margin_right" => 12, "margin_top" => 12, "margin_bottom" => 12];
        }

        $donnees = [
            "signature"     => $image($booking->getFirstMedia("signature")?->getPath()),
            "logo"          => $image($agence?->getFirstMedia("profile_photo")?->getPath()),
            "booking"       => $booking,
            "agence"        => $agence,
            "cachet"        => is_readable($fichierCachet) ? "data:image/png;base64," . base64_encode(file_get_contents($fichierCachet)) : null,
            "qrContenu"     => rtrim(config("app.url"), "/") . "/reservation/" . $booking->id,
            "apercu"        => false,
            "nomAgence"     => trim(($agence->first_name ?? "") . " " . ($agence->last_name ?? "")),
            "telAgence"     => trim((string) ($agence->tel ?? "")),
            "adresseAgence" => trim((string) ($agence->address ?? "")),
            "emailAgence"   => trim((string) ($agence->email ?? "")),
            "teinte"        => "#2A8C94",
            "manager"       => $manager,
            "type"          => null,
            "oldCheckout"   => $ancienDepart,
            "oldTotal"      => $ancienMontant,
        ];

        $mpdf = new Mpdf($options);
        $mpdf->WriteHTML(view("pdf.contract", $extra + $donnees + ["isPrivate" => $prive])->render());
        return $mpdf->Output("", "S");
    }
}
