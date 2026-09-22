<?php

namespace App\Http\Controllers\dashboard;

use App\Http\Controllers\Controller;
use App\Http\Resources\DashboardResource\BookingResource;
use App\Models\Booking;
use App\Models\BookingStatus;
use App\Models\FinancialTransaction;
use App\Models\Manager;
use App\Models\Realstate;
use App\Models\TypeBooking;
use App\Models\User;
use App\Models\WhatsappMessage;
use App\utils\JsonResponses;
use Carbon\Carbon;
use App\Services\DonneesReservation;
use App\Services\ModelesMessages;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Validator;
use Mpdf\Mpdf;
use Throwable;
use WasenderApi\WasenderClient;
use App\Services\Caisses;
use App\Models\MouvementCaisse;


class BookingController extends Controller
{
    use JsonResponses;

    public function store(Request $request)
    {
        // Un client sur liste noire ne peut plus reserver.
        $clientBloque = User::whereKey($request->input("client"))->whereNotNull("liste_noire_le")->first();
        if ($clientBloque) {
            return $this->validationErrorResponse(["msg" => [
                "Ce client est sur la liste noire"
                . ($clientBloque->liste_noire_motif ? " : " . $clientBloque->liste_noire_motif : "")
                . ". Impossible de créer une réservation."
            ]]);
        }

        // Un bien desactive ne recoit plus de reservation.
        if (\App\Models\Realstate::whereKey($request->input("realestate"))->whereNotNull("desactive_le")->exists()) {
            return $this->validationErrorResponse(["msg" => ["Ce bien est désactivé : réactivez-le pour y créer une réservation."]]);
        }

        $validator = Validator::make($request->all(), [
            "checkin" => ["required", "date", "date_format:Y-m-d"],
            "checkout" => ["required", "date", "after:checkin", "date_format:Y-m-d"],
            "guest" => ["required", "integer", "gt:0"],
            // Heures convenues avec le client ; a defaut, celles d'usage.
            "heureArrivee" => ["nullable", "date_format:H:i"],
            "heureDepart" => ["nullable", "date_format:H:i"],
            "realestate" => ["required", "exists:realstates,id"],
            "client" => ["required", "exists:users,id"],
            "nightPrice" => ["required"],
            // Depuis une reservation Airbnb, le client peut ne pas etre la pour signer.
            "signature" => [$request->filled("airbnbSejour") ? "nullable" : "required", "image", "mimes:png"],
            "airbnbSejour" => ["nullable", "integer", "exists:airbnb_sejours,id"],
            // Facture appliquee des la creation : le total saisi est alors le T.T.C.
            "appliquerFacture" => ["nullable", "boolean"],
            "tvaFacture" => ["nullable", "numeric", "min:0", "max:30"],
            "typeGuest" => ["required"],
            "avance"    => ["nullable", "numeric", "min:0"],
            "caution"   => ["nullable", "numeric", "min:0"],
            "remarques" => ["nullable", "string", "max:1000"],
        ]);

        if ($validator->fails()) {
            return $this->validationErrorResponse($validator->errors());
        }

        //=============check the transaction type
        $isShort = Realstate::where("id", $request->input("realestate"))
            ->whereHas("type", function ($query) {
                $query->where("code", "=", "rent-short");
            })->exists();

        if (!$isShort) {
            return $this->validationErrorResponse([
                "msg" => ["Seuls les biens immobiliers de type location vacances peuvent être loués."]
            ]);
        }

        //=============check if the realestate is available at the given dates
        $checkin = Carbon::createFromFormat("Y-m-d", $request->input("checkin"));
        $checkout = Carbon::createFromFormat("Y-m-d", $request->input("checkout"));

        $busy = Booking::where("realestate_id", "=", $request->input("realestate"))
            ->where(function ($query) use ($checkin, $checkout) {
                $query->where("checkin", "<", $checkout->format("Y-m-d"))
                    ->where("checkout", ">", $checkin->format("Y-m-d"));
            })->whereHas("status", function ($query) {
                $query->where("code", "=", "payed");
            })->exists();


        if ($busy) {
            return $this->validationErrorResponse([
                "msg" => ["Ce bien est déjà réservé à ces dates."]
            ]);
        }

        // Des dates bloquees rendent le bien indisponible, meme sans reservation.
        $bloque = DB::table("blocages_biens")
            ->where("realestate_id", $request->input("realestate"))
            ->where("date_debut", "<", $checkout->format("Y-m-d"))
            ->where("date_fin", ">=", $checkin->format("Y-m-d"))
            ->orderBy("date_debut")
            ->first();

        if ($bloque) {
            return $this->validationErrorResponse([
                "msg" => ["Ce bien est bloqué du " . Carbon::parse($bloque->date_debut)->format("d/m/Y")
                    . " au " . Carbon::parse($bloque->date_fin)->format("d/m/Y")
                    . ($bloque->motif ? " (" . $bloque->motif . ")" : "") . "."]
            ]);
        }

        // Les dates prises sur Airbnb rendent le bien indisponible.
        if ($airbnb = \App\Services\SyncAirbnb::conflit((int) $request->input("realestate"), $checkin->format("Y-m-d"), $checkout->format("Y-m-d"), $request->filled("airbnbSejour") ? (int) $request->input("airbnbSejour") : null)) {
            return $this->validationErrorResponse(["msg" => [\App\Services\SyncAirbnb::messageConflit($airbnb)]]);
        }

        //==============add booking
        $data = $validator->validate();
        $nbdays = $checkin->diffInDays($checkout);
        $data["nb_days"] = $nbdays;
        $data["nb_guest"] = $request->input("guest");
        $data["heure_arrivee"] = $request->input("heureArrivee");
        $data["heure_depart"] = $request->input("heureDepart");
        $data["realestate_id"] = $request->input("realestate");
        $data["checkin"] = $checkin;
        $data["checkout"] = $checkout;
        $data["client_id"] = $data["client"];
        $data["status_id"] = BookingStatus::where("code", "=", "payed")->first()->id;
        $price = $data["nightPrice"];
        $data["amount"] = $price * $nbdays;
        $data["night_price"] = $price;
        $type = TypeBooking::where("code", "=", "realworld")->first();
        $data["type_id"] = $type->id;
        $manager = $request->user();
        $data["created_by"] = $manager->id;
        $data["type_guest"] = $data["typeGuest"];
        $data["avance"]    = $request->input("avance", 0);
        $data["caution"]   = $request->input("caution", 0);
        $data["remarques"] = $request->input("remarques");

        DB::beginTransaction();
        try {

            $booking = Booking::create($data);


            if ((now()->isAfter($checkin) && (now()->isBefore($checkout) || now()->isSameDay($checkout))) || now()->isSameDay($checkin)) {
                $realestate = $booking->realestate;
                $realestate->booking_id = $booking->id;
                $realestate->save();
            }

            // Load relationships
            $booking->load(['client', 'realestate.city', 'manager']);

            // La signature est facultative pour un contrat cree depuis Airbnb.
            $signatureFile = $request->file("signature");
            $signatureBase64 = null;
            if ($signatureFile) {
                $signatureData = base64_encode(file_get_contents($signatureFile->getRealPath()));
                $signatureMimeType = $signatureFile->getMimeType();
                $signatureBase64 = "data:{$signatureMimeType};base64,{$signatureData}";
                $booking->addMedia($signatureFile)->toMediaCollection("signature");
            }

            // Get agency info and logo
            $agence = User::where("agence", "1")->first();
            $logoUrl = $agence->getFirstMediaUrl("profile_photo");

            // Convert logo to base64 if it exists
            $logoBase64 = null;
            if ($logoUrl) {
                try {
                    // If logo is stored locally
                    $logoPath = $agence->getFirstMedia("profile_photo")->getPath();
                    $logoData = base64_encode(file_get_contents($logoPath));
                    $logoMimeType = mime_content_type($logoPath);
                    $logoBase64 = "data:{$logoMimeType};base64,{$logoData}";
                } catch (\Exception $e) {
                    // If logo is external URL, you might need to fetch it
                    $logoBase64 = null;
                }
            }


            // Cachet numerise de l'agence, s'il a ete depose.
            $cachetBase64 = null;
            $fichierCachet = storage_path('app/public/cachet-agence.png');
            if (is_readable($fichierCachet)) {
                $cachetBase64 = 'data:image/png;base64,'
                    . base64_encode(file_get_contents($fichierCachet));
            }

            // Contenu du code QR : adresse de verification de la reservation.
            $qrContenu = rtrim(config('app.url'), '/') . '/reservation/' . $booking->id;

            $htmlPdfPrivate = view("pdf.contract", [
                'signature' => $signatureBase64,
                'logo' => $logoBase64,
                'booking' => $booking,
                'agence' => $agence,
                'cachet' => $cachetBase64,
                'qrContenu' => $qrContenu,
                'apercu' => false,
                // Coordonnees de l'agence, telles qu'elles figurent en
                // pied de la fiche.
                'nomAgence' => trim(($agence->first_name ?? '') . ' ' . ($agence->last_name ?? '')),
                'telAgence' => trim((string) ($agence->tel ?? '')),
                'adresseAgence' => trim((string) ($agence->address ?? '')),
                'emailAgence' => trim((string) ($agence->email ?? '')),
                'teinte' => '#2A8C94',
                'manager' => $manager,
                "isPrivate" => true,
            ])->render();

            $mpdfPrivate = new Mpdf([
                // Les polices du projet, Amiri compris.
                ...config("pdf.polices"),
                'mode' => 'utf-8',
                'format' => 'A4',
                'orientation' => 'P',
                'margin_left' => 15,
                'margin_right' => 15,
                'margin_top' => 20,
                'margin_bottom' => 20,
                'autoScriptToLang' => true,
                'autoLangToFont' => true,
            ]);

            $mpdfPrivate->WriteHTML($htmlPdfPrivate);
            $privateContract = $mpdfPrivate->Output('', 'S');

            // Generate Public PDF (create new instance - don't clone)
            $htmlPdfPublic = view("pdf.contract", [
                'signature' => $signatureBase64,
                'logo' => $logoBase64,
                'booking' => $booking,
                'agence' => $agence,
                'cachet' => $cachetBase64,
                'qrContenu' => $qrContenu,
                'apercu' => false,
                // Coordonnees de l'agence, telles qu'elles figurent en
                // pied de la fiche.
                'nomAgence' => trim(($agence->first_name ?? '') . ' ' . ($agence->last_name ?? '')),
                'telAgence' => trim((string) ($agence->tel ?? '')),
                'adresseAgence' => trim((string) ($agence->address ?? '')),
                'emailAgence' => trim((string) ($agence->email ?? '')),
                'teinte' => '#2A8C94',
                'manager' => $manager,
                "isPrivate" => false,
            ])->render();

            $mpdfPublic = new Mpdf([
                // Les polices du projet, Amiri compris.
                ...config("pdf.polices"),
                'mode' => 'utf-8',
                'format' => 'A4',
                'orientation' => 'P',
                'margin_left' => 15,
                'margin_right' => 15,
                'margin_top' => 20,
                'margin_bottom' => 20,
                'autoScriptToLang' => true,
                'autoLangToFont' => true,
            ]);

            $mpdfPublic->WriteHTML($htmlPdfPublic);
            $publicContract = $mpdfPublic->Output('', 'S');

            // Save PDFs to media library
            $booking->addMediaFromString($privateContract)
                ->usingFileName('contract-pr-' . time() . '.pdf')
                ->toMediaCollection("contract-private");

            $booking->addMediaFromString($publicContract)
                ->usingFileName('contract-pb-' . time() . '.pdf')
                ->toMediaCollection("contract-public");


            $booking->refresh();
            //send whatsapp message
            $clientPhone = $booking->client->tel;
            $clientPhone = str_replace("+", "", $clientPhone);

            $adminPhones = Manager::role("admin")->where("id", "!=", $manager->id)->get()->map(function ($admin) {
                return str_replace("+", "", $admin->phone);
            });

            // Copie du message au createur de la reservation (agent ou admin).
            // Il ne recoit une copie que pour les reservations qu'il a lui-meme creees.
            $creatorPhone = str_replace("+", "", $manager->phone ?? "");
            if (!empty($creatorPhone) && !$adminPhones->contains($creatorPhone)) {
                $adminPhones = $adminPhones->push($creatorPhone);
            }

            $document = $booking->getFirstMediaUrl("contract-private");
            // Les modeles sont modifiables depuis l'application : leurs
            // variables doivent etre remplacees avant l'envoi.
            $variables = DonneesReservation::variables($booking);
            $texteClient  = ModelesMessages::rendu("new-booking-client", $variables);
            $texteManager = ModelesMessages::rendu("new-booking-admin", $variables);


            $wa = new WasenderClient(config("services.whatsapp.wasender_key"));

            //send to client

            if (!empty($clientPhone)) {
                try {
                    $wa->sendDocument(
                        $clientPhone,
                        $document,
                        $texteClient,
                        "bulletin_hebergement.pdf"
                    );
                } catch (Throwable $th) {
                    Log::error($th);
                }
            }

            //send to managers
            // L'adresse etait ajoutee par le code ; on ne la repete pas si
            // le modele contient deja la variable correspondante.
            $adresse = (string) $booking->realestate->address;
            $messageAdmin = ($adresse !== "" && !str_contains($texteManager, $adresse))
                ? $texteManager . " (" . $adresse . ")"
                : $texteManager;
            $adminPhones = \App\Services\ReceptionWhatsapp::filtrer($adminPhones, "reservation-ajoutee");
            foreach ($adminPhones as $phone) {
                if (!empty($phone)) {
                    try {
                        $wa->sendDocument(
                            $phone,
                            $document,
                            $messageAdmin,
                            "bulletin_hebergement.pdf"
                        );
                    } catch (Throwable $th) {
                        Log::error($th);
                    }
                }
            }

            FinancialTransaction::record(
                'income',
                $booking->amount,
                'Nouvelle réservation - ' . $booking->realestate->title,
                $booking->realestate_id,
                $booking->id
            );

            // Le sejour se regle a la reservation : l'application ne
            // demande plus de montant verse, c'est donc le total qui
            // entre en caisse. Un montant transmis, lui, prime : il
            // correspond alors a ce qui a ete physiquement remis.
            if (!$request->filled("airbnbSejour")) Caisses::automatique(function () use ($booking, $request) {
                $remis = (float) ($booking->avance ?? 0);
                if ($remis <= 0) {
                    $remis = (float) ($booking->amount ?? 0);
                }

                Caisses::encaisser(
                    Caisses::pour($request->user()),
                    $remis,
                    MouvementCaisse::RESERVATION,
                    [
                        "booking_id" => $booking->id,
                        "manager_id" => $request->user()?->id,
                        "libelle"    => "Paiement - " . ($booking->realestate->title ?? "bien"),
                    ]
                );
            });

            DB::commit();
            // Le syndic de l'immeuble recoit le contrat public, s'il en a un.
            if ($request->boolean("appliquerFacture")) {
                try {
                    \App\Services\FactureAgence::appliquerIncluse($booking, $request->filled("tvaFacture") ? (float) $request->input("tvaFacture") : 20.0, $request->user()?->id);
                } catch (Throwable $th) {
                    Log::error("Facture a la creation de la reservation " . $booking->id . " : " . $th->getMessage());
                }
            }
            // Le contrat cree depuis Airbnb est relie a son sejour : les dates restent bloquees.
            if ($request->filled("airbnbSejour")) {
                $sejour = DB::table("airbnb_sejours")->find((int) $request->input("airbnbSejour"));
                if ($sejour) {
                    DB::table("airbnb_sejours")->where("id", $sejour->id)->update(["booking_id" => $booking->id, "updated_at" => now()]);
                    DB::table("bookings")->where("id", $booking->id)->update(["airbnb_uid" => $sejour->uid]);
                    // Le client a deja paye Airbnb : le montant entre dans la caisse Airbnb.
                    Caisses::automatique(fn() => Caisses::encaisser(Caisses::airbnb(), (float) $booking->amount, MouvementCaisse::RESERVATION, [
                        "booking_id" => $booking->id, "manager_id" => $request->user()?->id,
                        "libelle" => trim("Airbnb " . (\App\Services\SyncAirbnb::details($sejour)["code"] ?? "")) . " - " . ($booking->realestate->title ?? "bien"),
                    ]));
                }
            }
            \App\Services\EnvoiSyndic::apresReservation($booking);
            $response = new BookingResource($booking);

            return $this->createdResponse($response);
        } catch (Throwable $th) {
            DB::rollBack();
            //return $this->serverErrorResponse($th->getMessage());
            throw $th;
        }
    }




    public function index(Request $request)
    {
        $from = $request->input("from");
        $to = $request->input("to");

        $from = Carbon::parse($from)->startOfDay();
        $to = Carbon::parse($to)->endOfDay();

        $type = $request->input("type", "realworld");
        $realestate = $request->input("realestate");

        $bookings = Booking::with(["client", "type", "clientReview", "paymentMethod", "hostReview", "client", "realestate"])
            // Une reservation d'un bien supprime ne s'affiche plus.
            ->whereHas("realestate")
            ->whereHas("type", function ($query) use ($type) {
                $query->where("code", "=", $type);
            })->when($request->filled("realestate"), function ($query) use ($realestate) {
                $query->where("realestate_id", "=", $realestate);
            })
            ->when(isset($from) && isset($to), function ($query) use ($from, $to) {
                $query->where("created_at", ">=", $from)
                    ->where("created_at", "<=", $to);
            })->orderBy("created_at", "desc")
            ->get();
        $response = BookingResource::collection($bookings);
        return $this->successResponse($response);
    }


    public function extendBooking(Request $request, $id)
    {
        $manager = $request->user();
        $newCheckout = Carbon::createFromFormat("Y-m-d", $request->input("checkout"));

        $booking = Booking::find($id);
        // Sans prix transmis, la prolongation garde celui du sejour :
        // sans quoi le supplement vaudrait zero et la caisse ne
        // recevrait rien.
        $newNightPrice = $request->input("price") ?: $booking->night_price;
        $nbDays = Carbon::createFromFormat("Y-m-d", $booking->checkout)->diffInDays($newCheckout);
        $total = $nbDays * $newNightPrice;

        // Les nuits ajoutees ne peuvent pas tomber sur des dates bloquees.
        $bloque = DB::table("blocages_biens")
            ->where("realestate_id", $booking->realestate_id)
            ->where("date_debut", "<", $newCheckout->format("Y-m-d"))
            ->where("date_fin", ">=", Carbon::parse($booking->checkout)->format("Y-m-d"))
            ->orderBy("date_debut")
            ->first();

        if ($airbnb = \App\Services\SyncAirbnb::conflit((int) $booking->realestate_id, \Carbon\Carbon::parse($booking->checkout)->format("Y-m-d"), $newCheckout->format("Y-m-d"))) {
            return $this->validationErrorResponse(["msg" => ["Impossible de prolonger : " . lcfirst(\App\Services\SyncAirbnb::messageConflit($airbnb))]]);
        }

        if ($bloque) {
            return $this->validationErrorResponse([
                "msg" => ["Impossible de prolonger : le bien est bloqué du "
                    . Carbon::parse($bloque->date_debut)->format("d/m/Y") . " au "
                    . Carbon::parse($bloque->date_fin)->format("d/m/Y") . "."]
            ]);
        }

        //generate signature
        $signaturePath = $booking->getFirstMedia("signature")?->getPath();
        $signatureBase64 = null;
        if (!empty($signaturePath)) {
            try {
                $signatureData = base64_encode(file_get_contents($signaturePath));
                $signatureMimeType = mime_content_type($signaturePath);
                $signatureBase64 = "data:{$signatureMimeType};base64,{$signatureData}";
            } catch (Throwable $th) {
                $signatureBase64 = null;
            }
        }
        //generate logo
        $agence = User::where("agence", "1")->first();
        $logoPath = $agence->getFirstMedia("profile_photo")?->getPath();
        $logoBase64 = null;
        if (!empty($logoPath)) {
            try {
                $logoData = base64_encode(file_get_contents($logoPath));
                $logoMimeType = mime_content_type($logoPath);
                $logoBase64 = "data:{$logoMimeType};base64,{$logoData}";
            } catch (Throwable $th) {
                $logoBase64 = null;
            }
        }

        try {
            $oldCheckout = $booking->checkout;
            $oldTotal = $booking->amount;

            $booking->checkout = $newCheckout;
            $booking->night_price = ($newNightPrice + $booking->night_price) / 2;
            $booking->amount = $booking->amount + $total;
            $booking->nb_days = $booking->nb_days + $nbDays;
            $booking->save();

            //generate private contract
            $mpdfPrivate = new Mpdf([
                // Les polices du projet, Amiri compris.
                ...config("pdf.polices"),
                'mode' => 'utf-8',
                'format' => 'A4',
                'orientation' => 'P',
                'margin_left' => 15,
                'margin_right' => 15,
                'margin_top' => 20,
                'margin_bottom' => 20,
                'autoScriptToLang' => true,
                'autoLangToFont' => true,
            ]);

            // Cachet numerise de l'agence, s'il a ete depose.
            $cachetBase64 = null;
            $fichierCachet = storage_path('app/public/cachet-agence.png');
            if (is_readable($fichierCachet)) {
                $cachetBase64 = 'data:image/png;base64,'
                    . base64_encode(file_get_contents($fichierCachet));
            }
            $qrContenu = rtrim(config('app.url'), '/') . '/reservation/' . $booking->id;

            $htmlPrivatePdf = view("pdf.contract", [
                'signature' => $signatureBase64,
                'logo' => $logoBase64,
                'booking' => $booking,
                'agence' => $agence,
                'cachet' => $cachetBase64,
                'qrContenu' => $qrContenu,
                'apercu' => false,
                // Coordonnees de l'agence, telles qu'elles figurent en
                // pied de la fiche.
                'nomAgence' => trim(($agence->first_name ?? '') . ' ' . ($agence->last_name ?? '')),
                'telAgence' => trim((string) ($agence->tel ?? '')),
                'adresseAgence' => trim((string) ($agence->address ?? '')),
                'emailAgence' => trim((string) ($agence->email ?? '')),
                'teinte' => '#2A8C94',
                'manager' => $manager,
                "isPrivate" => true,
                "type" => "extend",
                "oldCheckout" => $oldCheckout,
                "oldTotal" => $oldTotal
            ])->render();

            $mpdfPrivate->WriteHTML($htmlPrivatePdf);
            $privateContract = $mpdfPrivate->Output("", "S");


            //generate public contract


            $mpdfPublic = new Mpdf([
                // Les polices du projet, Amiri compris.
                ...config("pdf.polices"),
                'mode' => 'utf-8',
                'format' => 'A4',
                'orientation' => 'P',
                'margin_left' => 15,
                'margin_right' => 15,
                'margin_top' => 20,
                'margin_bottom' => 20,
                'autoScriptToLang' => true,
                'autoLangToFont' => true,
            ]);

            $htmlPublicPdf = view("pdf.contract", [
                'signature' => $signatureBase64,
                'logo' => $logoBase64,
                'booking' => $booking,
                'agence' => $agence,
                'cachet' => $cachetBase64,
                'qrContenu' => $qrContenu,
                'apercu' => false,
                // Coordonnees de l'agence, telles qu'elles figurent en
                // pied de la fiche.
                'nomAgence' => trim(($agence->first_name ?? '') . ' ' . ($agence->last_name ?? '')),
                'telAgence' => trim((string) ($agence->tel ?? '')),
                'adresseAgence' => trim((string) ($agence->address ?? '')),
                'emailAgence' => trim((string) ($agence->email ?? '')),
                'teinte' => '#2A8C94',
                'manager' => $manager,
                "isPrivate" => false,
                "type" => "extend",
                "oldCheckout" => $oldCheckout,
                "oldTotal" => $oldTotal
            ])->render();

            $mpdfPublic->WriteHTML($htmlPublicPdf);
            $publicContract = $mpdfPublic->Output("", "S");

            $booking->addMediaFromString($privateContract)
                ->usingFileName('contract-pr-' . time() . '.pdf')
                ->toMediaCollection("contract-private");

            $booking->addMediaFromString($publicContract)
                ->usingFileName('contract-pb-' . time() . '.pdf')
                ->toMediaCollection("contract-public");


            $wa = new WasenderClient(config("services.whatsapp.wasender_key"));

            ///send message to client
            $client = $booking->client;
            $clientPhone = str_replace("+", "", $client->tel);
            if (!empty($clientPhone)) {
                try {
                    // Le texte vient du modele "Message de prolongement" :
                    // il se modifie depuis le module des messages. Les
                    // nuits et le montant sont ceux de la prolongation,
                    // non ceux du sejour entier.
                    $variables = DonneesReservation::variables($booking);
                    $variables["{nights}"] = (string) static::nuitsEntre($oldCheckout, $booking->checkout);
                    $variables["{amount}"] = number_format((float) $total, 0, ',', ' ');

                    $wa->sendDocument(
                        $clientPhone,
                        $booking->getFirstMediaUrl("contract-private"),
                        ModelesMessages::rendu("booking-extended-client", $variables),
                        "bulletin_hebergement.pdf"
                    );
                } catch (Throwable $th) {
                    Log::error($th);
                }
            }




            $adminPhones = Manager::role("admin")->where("id", "!=", $manager->id)->get()->map(function ($admin) {
                return str_replace("+", "", $admin->phone);
            });

            // Celui qui fait l'operation et le createur de la reservation
            // recoivent aussi le message, meme s'ils sont administrateurs.
            foreach ([$manager, $booking->manager] as $destinataire) {
                $tel = str_replace("+", "", (string) ($destinataire->phone ?? ""));
                if ($tel !== "" && !$adminPhones->contains($tel)) {
                    $adminPhones = $adminPhones->push($tel);
                }
            }

            $booking->refresh();




            $messageAdmin = ModelesMessages::rendu("booking-extended-admin", \App\Services\MessagesModification::variables($booking, ["checkout" => $oldCheckout, "total" => $oldTotal, "difference" => $total]));

            $adminPhones = \App\Services\ReceptionWhatsapp::filtrer($adminPhones, "reservation-prolongee");
            foreach ($adminPhones as $phone) {
                if (!empty($phone)) {
                    try {
                        $wa->sendDocument(
                            $phone,
                            $booking->getFirstMediaUrl("contract-private"),
                            $messageAdmin,
                            "bulletin_hebergement.pdf"
                        );
                    } catch (Throwable $th) {
                        Log::error($th);
                    }
                }
            }


            FinancialTransaction::record(
                'income',
                $total,
                'Prolongation - ' . $booking->realestate->title . ($manager ? ' (par ' . trim($manager->first_name . ' ' . $manager->last_name) . ')' : ''),
                $booking->realestate_id,
                $booking->id,
                null,
                null,
                $manager?->id
            );
            \App\Services\HistoriqueReservation::noter([
                "booking_id" => $booking->id, "type" => "prolongation",
                "ancien_checkout" => \Carbon\Carbon::parse($oldCheckout)->toDateString(), "nouveau_checkout" => \Carbon\Carbon::parse($booking->checkout)->toDateString(),
                "nuits_delta" => (int) $nbDays, "ancien_prix_nuit" => null, "nouveau_prix_nuit" => (float) $newNightPrice,
                "ancien_total" => (float) $oldTotal, "nouveau_total" => (float) $booking->amount, "ecart" => (float) $total,
                "encaisse" => (float) ($request->input("encaisse", 0) ?: $total), "manager_id" => $manager?->id,
            ]);
            // Les syndics de l'immeuble recoivent le contrat mis a jour.
            \App\Services\EnvoiSyndic::apresModification($booking, "prolongation", ["checkout" => $oldCheckout, "total" => $oldTotal, "difference" => $total]);

            // La prolongation se regle sur le moment : le montant saisi
            // entre en caisse et, a defaut, le supplement du sejour.
            Caisses::automatique(function () use ($booking, $request, $total) {
                $remis = (float) $request->input("encaisse", 0);
                if ($remis <= 0) {
                    $remis = (float) $total;
                }

                Caisses::encaisser(
                    Caisses::pour($request->user()),
                    $remis,
                    MouvementCaisse::PROLONGATION,
                    [
                        "booking_id" => $booking->id,
                        "manager_id" => $request->user()?->id,
                        "libelle"    => "Prolongation - " . ($booking->realestate->title ?? "bien"),
                    ]
                );
            });

            DB::commit();
            return $this->successResponse(null);
        } catch (Throwable $th) {
            DB::rollBack();
            Log::error($th);
            return $this->serverErrorResponse($th->getMessage());
        }
    }

    public function shrink(Request $request, $id)
    {
        $manager = $request->user();
        $booking = Booking::findOrFail($id);
        $newCheckout = Carbon::parse($request->input("checkout"));
        $checkin = Carbon::parse($booking->checkin);
        $refundedPrice = $request->input("refundPrice");

        //generate signature
        $signaturePath = $booking->getFirstMedia("signature")?->getPath();
        $signatureBase64 = null;
        if (!empty($signaturePath)) {
            try {
                $signatureData = base64_encode(file_get_contents($signaturePath));
                $signatureMimeType = mime_content_type($signaturePath);
                $signatureBase64 = "data:{$signatureMimeType};base64,{$signatureData}";
            } catch (Throwable $th) {
                $signatureBase64 = null;
            }
        }
        //generate logo
        $agence = User::where("agence", "1")->first();
        $logoPath = $agence->getFirstMedia("profile_photo")?->getPath();
        $logoBase64 = null;
        if (!empty($logoPath)) {
            try {
                $logoData = base64_encode(file_get_contents($logoPath));
                $logoMimeType = mime_content_type($logoPath);
                $logoBase64 = "data:{$logoMimeType};base64,{$logoData}";
            } catch (Throwable $th) {
                $logoBase64 = null;
            }
        }


        DB::beginTransaction();
        try {
            $oldTotal = $booking->amount;
            $oldCheckout = $booking->checkout;

            $booking->update([
                "checkout" => $newCheckout,
                "amount" => $oldTotal - $refundedPrice,
                "nb_days" => $checkin->diffInDays($newCheckout)
            ]);


            //generate private contract
            $mpdfPrivate = new Mpdf([
                // Les polices du projet, Amiri compris.
                ...config("pdf.polices"),
                'mode' => 'utf-8',
                'format' => 'A4',
                'orientation' => 'P',
                'margin_left' => 15,
                'margin_right' => 15,
                'margin_top' => 20,
                'margin_bottom' => 20,
                'autoScriptToLang' => true,
                'autoLangToFont' => true,
            ]);

            // Cachet numerise de l'agence, s'il a ete depose.
            $cachetBase64 = null;
            $fichierCachet = storage_path('app/public/cachet-agence.png');
            if (is_readable($fichierCachet)) {
                $cachetBase64 = 'data:image/png;base64,'
                    . base64_encode(file_get_contents($fichierCachet));
            }
            $qrContenu = rtrim(config('app.url'), '/') . '/reservation/' . $booking->id;

            $htmlPrivatePdf = view("pdf.contract", [
                'signature' => $signatureBase64,
                'logo' => $logoBase64,
                'booking' => $booking,
                'agence' => $agence,
                'cachet' => $cachetBase64,
                'qrContenu' => $qrContenu,
                'apercu' => false,
                // Coordonnees de l'agence, telles qu'elles figurent en
                // pied de la fiche.
                'nomAgence' => trim(($agence->first_name ?? '') . ' ' . ($agence->last_name ?? '')),
                'telAgence' => trim((string) ($agence->tel ?? '')),
                'adresseAgence' => trim((string) ($agence->address ?? '')),
                'emailAgence' => trim((string) ($agence->email ?? '')),
                'teinte' => '#2A8C94',
                'manager' => $manager,
                "isPrivate" => true,
                "type" => "shrink",
                "oldCheckout" => $oldCheckout,
                "oldTotal" => $oldTotal
            ])->render();

            $mpdfPrivate->WriteHTML($htmlPrivatePdf);
            $privateContract = $mpdfPrivate->Output("", "S");


            //generate public contract

            $mpdfPublic = new Mpdf([
                // Les polices du projet, Amiri compris.
                ...config("pdf.polices"),
                'mode' => 'utf-8',
                'format' => 'A4',
                'orientation' => 'P',
                'margin_left' => 15,
                'margin_right' => 15,
                'margin_top' => 20,
                'margin_bottom' => 20,
                'autoScriptToLang' => true,
                'autoLangToFont' => true,
            ]);

            $htmlPublicPdf = view("pdf.contract", [
                'signature' => $signatureBase64,
                'logo' => $logoBase64,
                'booking' => $booking,
                'agence' => $agence,
                'cachet' => $cachetBase64,
                'qrContenu' => $qrContenu,
                'apercu' => false,
                // Coordonnees de l'agence, telles qu'elles figurent en
                // pied de la fiche.
                'nomAgence' => trim(($agence->first_name ?? '') . ' ' . ($agence->last_name ?? '')),
                'telAgence' => trim((string) ($agence->tel ?? '')),
                'adresseAgence' => trim((string) ($agence->address ?? '')),
                'emailAgence' => trim((string) ($agence->email ?? '')),
                'teinte' => '#2A8C94',
                'manager' => $manager,
                "isPrivate" => false,
                "type" => "shrink",
                "oldCheckout" => $oldCheckout,
                "oldTotal" => $oldTotal
            ])->render();

            $mpdfPublic->WriteHTML($htmlPublicPdf);
            $publicContract = $mpdfPublic->Output("", "S");

            $booking->addMediaFromString($privateContract)
                ->usingFileName('contract-pr-' . time() . '.pdf')
                ->toMediaCollection("contract-private");

            $booking->addMediaFromString($publicContract)
                ->usingFileName('contract-pb-' . time() . '.pdf')
                ->toMediaCollection("contract-public");



            $client = $booking->client;
            $clientPhone = str_replace("+", "", $client->tel);

            $adminPhones = Manager::role("admin")->where("id", "!=", $manager->id)->get()->map(function ($admin) {
                return str_replace("+", "", $admin->phone);
            });

            // Celui qui fait l'operation et le createur de la reservation
            // recoivent aussi le message, meme s'ils sont administrateurs.
            foreach ([$manager, $booking->manager] as $destinataire) {
                $tel = str_replace("+", "", (string) ($destinataire->phone ?? ""));
                if ($tel !== "" && !$adminPhones->contains($tel)) {
                    $adminPhones = $adminPhones->push($tel);
                }
            }

            $booking->refresh();

            $wa = new WasenderClient(config("services.whatsapp.wasender_key"));
            if (!empty($clientPhone)) {
                try {
                    // Le texte vient du modele "Message de raccourcis" :
                    // les nuits retirees et le montant rendu, plutot
                    // qu'une phrase figee dans le code.
                    $variables = DonneesReservation::variables($booking);
                    $variables["{nights}"] = (string) static::nuitsEntre($booking->checkout, $oldCheckout);
                    $variables["{amount}"] = number_format((float) $refundedPrice, 0, ',', ' ');

                    $wa->sendDocument(
                        $clientPhone,
                        $booking->getFirstMediaUrl("contract-private"),
                        ModelesMessages::rendu("booking-shortened-client", $variables),
                        "bulletin_hebergement.pdf"
                    );
                } catch (Throwable $th) {
                    Log::error($th);
                }
            }

            $messageAdmin = ModelesMessages::rendu("booking-shortened-admin", \App\Services\MessagesModification::variables($booking, ["checkout" => $oldCheckout, "total" => $oldTotal, "difference" => $refundedPrice]));

            $adminPhones = \App\Services\ReceptionWhatsapp::filtrer($adminPhones, "reservation-raccourcie");
            foreach ($adminPhones as $phone) {
                if (!empty($phone)) {
                    try {
                        $wa->sendDocument(
                            $phone,
                            $booking->getFirstMediaUrl("contract-private"),
                            $messageAdmin,
                            "bulletin_hebergement.pdf"
                        );
                    } catch (Throwable $th) {
                        Log::error($th);
                    }
                }
            }


            FinancialTransaction::record(
                'refund',
                $refundedPrice,
                'Remboursement - ' . $booking->realestate->title . ($manager ? ' (par ' . trim($manager->first_name . ' ' . $manager->last_name) . ')' : ''),
                $booking->realestate_id,
                $booking->id,
                null,
                null,
                $manager?->id
            );
            \App\Services\HistoriqueReservation::noter([
                "booking_id" => $booking->id, "type" => "raccourcissement",
                "ancien_checkout" => \Carbon\Carbon::parse($oldCheckout)->toDateString(), "nouveau_checkout" => \Carbon\Carbon::parse($booking->checkout)->toDateString(),
                "nuits_delta" => -1 * (int) round(\Carbon\Carbon::parse($booking->checkout)->startOfDay()->diffInDays(\Carbon\Carbon::parse($oldCheckout)->startOfDay())),
                "ancien_total" => (float) $oldTotal, "nouveau_total" => (float) $booking->amount, "ecart" => -1 * (float) $refundedPrice,
                "rembourse" => (float) $refundedPrice, "manager_id" => $manager?->id,
            ]);
            // Les syndics de l'immeuble recoivent le contrat mis a jour.
            \App\Services\EnvoiSyndic::apresModification($booking, "raccourcissement", ["checkout" => $oldCheckout, "total" => $oldTotal, "difference" => $refundedPrice]);

            // Ce que l'agent rend au client sort de sa poche.
            Caisses::automatique(function () use ($booking, $request, $refundedPrice) {
                Caisses::decaisser(
                    Caisses::pour($request->user()),
                    (float) $refundedPrice,
                    MouvementCaisse::REMBOURSEMENT,
                    [
                        "booking_id" => $booking->id,
                        "manager_id" => $request->user()?->id,
                        "libelle"    => "Remboursement - " . ($booking->realestate->title ?? "bien"),
                    ]
                );
            });

            DB::commit();
            return $this->successResponse(null);
        } catch (Throwable $th) {
            DB::rollBack();
            Log::error($th);
            return $this->serverErrorResponse($th->getMessage());
        }
    }

    /**
     * Les reservations supprimees depuis moins d'une semaine.
     *
     * Passe sept jours, une reservation ne figure plus dans la
     * corbeille : elle en sort d'elle-meme, sans que personne ait a
     * faire le menage. Son ecriture comptable, elle, demeure.
     */
    /**
     * Le nombre de nuits entre deux dates.
     *
     * Une prolongation ne concerne pas tout le sejour : le message doit
     * parler des nuits ajoutees ou retirees, pas du total.
     */
    protected static function nuitsEntre($depuis, $jusqua): int
    {
        try {
            $a = \Carbon\Carbon::parse((string) $depuis)->startOfDay();
            $b = \Carbon\Carbon::parse((string) $jusqua)->startOfDay();
            return (int) abs($a->diffInDays($b));
        } catch (\Throwable $th) {
            return 0;
        }
    }

    /**
     * Les arrivees : les reservations qui entrent aujourd'hui, ou les
     * prochaines. Classees par date d'arrivee, et non par date de saisie.
     *
     * Memes restrictions que la liste des biens : dossiers de l'agent,
     * famille de biens, dossier de rangement.
     */
    public function arrivees(Request $request)
    {
        $quand = $request->input("quand", "today");

        $query = Booking::with(["client", "status", "realestate", "manager"])
            ->whereHas("status", fn($q) => $q->whereIn("code", ["pending", "confirmed", "payed"]))
            ->whereHas("realestate");

        if ($quand === "upcoming") {
            $query->whereDate("checkin", ">", today())->orderBy("checkin")->orderBy("id");
        } else {
            $query->whereDate("checkin", today())->orderBy("id");
        }

        $dossiersAutorises = $request->user()?->dossiersAutorises();
        if ($dossiersAutorises !== null) {
            $query->whereHas("realestate", fn($q) => $q->whereIn("dossier_id", $dossiersAutorises));
        }

        if ($type = $request->input("type")) {
            $query->whereHas("realestate.type", fn($q) => $q->where("code", "=", $type));
        }

        if ($dossier = $request->input("dossier")) {
            $query->whereHas("realestate", function ($q) use ($dossier) {
                $dossier === "aucun" ? $q->whereNull("dossier_id") : $q->where("dossier_id", "=", $dossier);
            });
        }

        return $this->successResponse(BookingResource::collection($query->limit(500)->get()));
    }

    public function corbeille(Request $request)
    {
        if (!$request->attributes->get("droit_verifie") && !$request->user()->can("delete_reservation")) {
            return $this->jsonResponse(false, "forbidden", 403, null);
        }

        $depuis = now()->subDays(7);

        $reservations = Booking::onlyTrashed()
            ->with(["client", "realestate", "status"])
            ->where("deleted_at", ">=", $depuis)
            ->orderByDesc("deleted_at")
            ->get()
            ->map(fn($b) => [
                "id"          => $b->id,
                "client"      => trim(($b->client->first_name ?? "") . " " . ($b->client->last_name ?? "")),
                "telephone"   => $b->client->tel ?? null,
                "bien"        => $b->realestate->title ?? null,
                "checkin"     => $b->checkin,
                "checkout"    => $b->checkout,
                "nuits"       => (int) ($b->nb_days ?? 0),
                "montant"     => (float) ($b->amount ?? 0),
                "supprimeePar" => ($auteur = $b->supprimee_par ? \App\Models\Manager::find($b->supprimee_par) : null)
                    ? trim(($auteur->first_name ?? "") . " " . ($auteur->last_name ?? "")) : null,
                "rembourse"    => $b->rembourse_suppression === null ? null : (bool) $b->rembourse_suppression,
                "montantRembourse" => $b->montant_rembourse_suppression === null ? null : (float) $b->montant_rembourse_suppression,
                "supprimeeLe" => $b->deleted_at?->toISOString(),
                // Ce qu'il restera dans la corbeille, en jours.
                "joursRestants" => max(0, 7 - (int) $b->deleted_at?->diffInDays(now())),
            ])->all();

        return $this->successResponse(["reservations" => $reservations]);
    }

    /**
     * Sort une reservation de la corbeille.
     *
     * Elle reprend sa place telle qu'elle etait. Aucun message ne part
     * au client : une suppression annulee ne le concerne pas. Le bien
     * ne lui est rendu que s'il n'a pas ete reattribue entre-temps.
     */
    public function restaurer(Request $request, $id)
    {
        if (!$request->attributes->get("droit_verifie") && !$request->user()->can("delete_reservation")) {
            return $this->jsonResponse(false, "forbidden", 403, null);
        }

        $booking = Booking::onlyTrashed()->find($id);

        if ($booking === null) {
            return $this->notFoundResponse();
        }

        DB::transaction(function () use ($booking) {
            $booking->restore();
            $booking->forceFill([
                "supprimee_par"                 => null,
                "rembourse_suppression"         => null,
                "montant_rembourse_suppression" => null,
            ])->save();

            // L'annulation n'a pas eu lieu : son ecriture comptable non
            // plus. Les autres ecritures du sejour restent.
            FinancialTransaction::where("booking_id", $booking->id)
                ->where("type", "cancellation")
                ->delete();

            // L'argent sorti de la caisse a la suppression y revient.
            $sorties = \App\Models\MouvementCaisse::where("booking_id", $booking->id)
                ->where("sens", "sortie")
                ->where(fn($q) => $q->where("libelle", "like", "Suppression reservation%")
                    ->orWhere("libelle", "like", "Remboursement suppression reservation%"))
                ->get();

            foreach ($sorties as $sortie) {
                if (\App\Models\MouvementCaisse::where("contrepasse_id", $sortie->id)->exists()) {
                    continue;
                }
                Caisses::enregistrerSansControle(
                    \App\Models\Caisse::find($sortie->caisse_id),
                    "entree",
                    (float) $sortie->montant,
                    \App\Models\MouvementCaisse::CORRECTION,
                    [
                        "booking_id"     => $booking->id,
                        "manager_id"     => request()->user()?->id,
                        "contrepasse_id" => $sortie->id,
                        "libelle"        => "Restauration reservation - "
                            . ($booking->realestate?->title ?? "bien"),
                    ]
                );
            }

            // Le bien retrouve son sejour en cours, sauf s'il en a
            // recu un autre depuis.
            $bien = Realstate::find($booking->realestate_id);
            if ($bien !== null && $bien->booking_id === null
                && $booking->checkout >= now()->toDateString()) {
                $bien->update(["booking_id" => $booking->id]);
            }
        });

        return $this->successResponse(["id" => $booking->id]);
    }

    /**
     * Ce qu'implique la suppression, avant de la confirmer : ce que la
     * reservation a rapporte, ce qui a ete encaisse, et la caisse de celui
     * qui supprime (d'ou sortirait un remboursement).
     */
    public function apercuSuppression(Request $request, $id)
    {
        if (!$request->attributes->get("droit_verifie") && !$request->user()->can('delete_reservation')) {
            return response()->json([
                "success" => false,
                "statusCode" => 403,
                "message" => "forbidden",
                "error" => ["msg" => ["Vous n'avez pas l'autorisation de supprimer une reservation."]],
            ], 403);
        }

        $booking = Booking::with('realestate')->find($id);
        if (!$booking) {
            return $this->notFoundResponse();
        }

        $chiffres = static::chiffresSuppression($booking);
        $caisse = Caisses::pour($request->user());

        return $this->successResponse([
            "id"       => $booking->id,
            "bien"     => $booking->realestate?->title,
            "montant"  => round((float) $booking->amount, 2),
            "revenu"   => $chiffres["revenu"],
            "encaisse" => $chiffres["encaisse"],
            "caisse"   => $caisse ? [
                "id"    => $caisse->id,
                "nom"   => $caisse->nom,
                "solde" => round((float) $caisse->solde(), 2),
            ] : null,
        ]);
    }

    /** Revenu net d'une reservation et argent net encaisse en caisse. */
    private static function chiffresSuppression(Booking $booking): array
    {
        $revenus = FinancialTransaction::where("booking_id", $booking->id)->where("type", "income");
        $revenu = $revenus->exists()
            ? (float) $revenus->sum("amount")
                - (float) FinancialTransaction::where("booking_id", $booking->id)->where("type", "refund")->sum("amount")
            : (float) $booking->amount;

        $encaisse = (float) (MouvementCaisse::where("booking_id", $booking->id)
            ->selectRaw("COALESCE(SUM(CASE WHEN sens = 'entree' THEN montant ELSE -montant END), 0) AS net")
            ->value("net") ?? 0);

        return [
            "revenu"   => round(max(0, $revenu), 2),
            "encaisse" => round(max(0, $encaisse), 2),
        ];
    }

    /**
     * Supprime une reservation.
     *
     * L'application demande si le client est rembourse :
     * - oui : le montant rendu sort de la caisse de celui qui supprime
     *   (refuse si elle ne le contient pas) ;
     * - non : rien ne sort de caisse, l'argent encaisse reste acquis.
     * Dans les deux cas, les statistiques retirent ce que l'agence ne
     * garde pas, et la suppression porte le nom de son auteur.
     * Une ancienne version de l'application, qui ne pose pas la question,
     * garde le comportement d'origine.
     */
    public function destroy(Request $request, $id)
    {
        // [PERMISSION] seuls les gestionnaires disposant de delete_reservation
        // peuvent supprimer une reservation (exclut le role agent).
        if (!$request->attributes->get("droit_verifie") && !$request->user()->can('delete_reservation')) {
            return response()->json([
                "success" => false,
                "statusCode" => 403,
                "message" => "forbidden",
                "error" => ["msg" => ["Vous n'avez pas l'autorisation de supprimer une reservation."]],
            ], 403);
        }

        $booking = Booking::with('realestate')->find($id);

        if (!$booking) {
            Realstate::where("booking_id", $id)->update(["booking_id" => null]);
            return $this->successResponse(null);
        }

        $manager = $request->user();
        $bien = $booking->realestate?->title ?? "Bien #{$booking->realestate_id}";
        $questionPosee = $request->has("rembourse");
        $rembourse = $questionPosee && $request->boolean("rembourse");
        $chiffres = static::chiffresSuppression($booking);
        $montant = 0.0;

        if ($rembourse) {
            $validator = Validator::make($request->all(), [
                "montantRembourse" => ["required", "numeric", "gt:0"],
            ], [
                "montantRembourse.required" => "Indiquez le montant rendu au client.",
                "montantRembourse.gt"       => "Le montant rendu doit être supérieur à zéro.",
            ]);
            if ($validator->fails()) {
                return $this->validationErrorResponse($validator->errors());
            }

            $montant = round((float) $request->input("montantRembourse"), 2);
            $plafond = max($chiffres["revenu"], $chiffres["encaisse"]);
            if ($montant > $plafond + 0.001) {
                return $this->validationErrorResponse(["msg" => [
                    "Le remboursement ne peut pas dépasser " . number_format($plafond, 2, ",", " ") . " MAD.",
                ]]);
            }

            $caisse = Caisses::pour($manager);
            $solde = $caisse ? round((float) $caisse->solde(), 2) : 0.0;
            if ($caisse === null || $montant > $solde + 0.001) {
                return $this->validationErrorResponse(["msg" => [
                    "Votre caisse contient " . number_format($solde, 2, ",", " ")
                    . " MAD : impossible de rembourser " . number_format($montant, 2, ",", " ") . " MAD.",
                ]]);
            }
        }

        try {
            DB::transaction(function () use ($booking, $manager, $bien, $questionPosee, $rembourse, $montant, $chiffres, $request) {
                if ($questionPosee) {
                    // Ce que l'agence garde : l'argent encaisse, moins ce qu'elle rend.
                    // Le reste du revenu de la reservation disparait des statistiques.
                    $garde = max(0, $chiffres["encaisse"] - $montant);
                    $annule = round(max(0, $chiffres["revenu"] - $garde), 2);

                    FinancialTransaction::record(
                        'cancellation',
                        $annule,
                        'Annulation - ' . $bien . ($rembourse
                            ? ' (remboursé ' . number_format($montant, 2, ',', ' ') . ' MAD)'
                            : ' (non remboursé)'),
                        $booking->realestate_id,
                        $booking->id
                    );

                    if ($rembourse && $montant > 0) {
                        Caisses::decaisser(
                            Caisses::pour($manager),
                            $montant,
                            MouvementCaisse::REMBOURSEMENT,
                            [
                                "booking_id" => $booking->id,
                                "manager_id" => $manager?->id,
                                "libelle"    => "Remboursement suppression reservation - " . $bien,
                            ]
                        );
                    }
                } else {
                    FinancialTransaction::record(
                        'cancellation',
                        $booking->amount,
                        'Annulation - ' . $bien,
                        $booking->realestate_id,
                        $booking->id
                    );

                    // Comportement d'origine : l'argent ressort de la caisse ou il etait entre.
                    Caisses::automatique(function () use ($booking, $request, $bien) {
                        $parCaisse = MouvementCaisse::where("booking_id", $booking->id)
                            ->selectRaw("caisse_id, SUM(CASE WHEN sens = 'entree' THEN montant ELSE -montant END) AS net")
                            ->groupBy("caisse_id")
                            ->get();

                        foreach ($parCaisse as $ligne) {
                            if ((float) $ligne->net > 0.005) {
                                Caisses::enregistrerSansControle(
                                    \App\Models\Caisse::find($ligne->caisse_id),
                                    "sortie",
                                    (float) $ligne->net,
                                    MouvementCaisse::REMBOURSEMENT,
                                    [
                                        "booking_id" => $booking->id,
                                        "manager_id" => $request->user()?->id,
                                        "libelle"    => "Suppression reservation - " . $bien,
                                    ]
                                );
                            }
                        }
                    });
                }

                $booking->forceFill([
                    "supprimee_par"                 => $manager?->id,
                    "rembourse_suppression"         => $questionPosee ? $rembourse : null,
                    "montant_rembourse_suppression" => $questionPosee ? $montant : null,
                ])->save();

                Realstate::where("booking_id", $booking->id)->update(["booking_id" => null]);
                $booking->delete();
            });
        } catch (\App\Services\SoldeInsuffisant $e) {
            return $this->validationErrorResponse(["msg" => [$e->getMessage()]]);
        }

        return $this->successResponse(null);
    }
}
