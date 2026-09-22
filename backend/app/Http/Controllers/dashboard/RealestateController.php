<?php

namespace App\Http\Controllers\dashboard;

use App\Http\Controllers\Controller;
use Carbon\Carbon;
use App\Http\Resources\DashboardResource\RealestateResource;
use App\Models\Booking;
use App\Models\Realstate;
use App\Models\Secteur;
use App\Models\RealstateCategory;
use App\Models\RealstateEtat;
use App\Models\RealstateReviewStatus;
use App\Models\RealstateStatus;
use App\Models\TypeTransaction;
use App\Models\User;
use App\Models\UserType;
use App\utils\JsonResponses;
use App\Services\EnvoiRappel;
use App\Services\ModelesMessages;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Validator;
use App\Models\Manager;
use Illuminate\Support\Facades\Log;
use WasenderApi\WasenderClient;
use Throwable;

use function Symfony\Component\Clock\now;

class RealestateController extends Controller
{


    use JsonResponses;

    /**
     * Vide les champs laisses vides par l'application.
     *
     * Un formulaire envoye par le telephone transporte ses champs vides
     * sous la forme du mot « null » : la date de construction, l'etage
     * ou le proprietaire arrivaient donc comme un texte, que la
     * validation rejetait. On les ramene ici a un champ vide, avant
     * toute verification.
     */
    private function nettoyerChampsVides(Request $request): void
    {
        $vides = ["null", "undefined", "NaN", ""];
        $propres = [];

        foreach ($request->all() as $cle => $valeur) {
            if (is_string($valeur) && in_array(trim($valeur), $vides, true)) {
                $propres[$cle] = null;
            }
        }

        if ($propres) {
            $request->merge($propres);
        }
    }

    /**
     * Determine le secteur d'un bien : soit un secteur existant choisi
     * dans la liste, soit un nouveau secteur saisi par l'utilisateur.
     */
    private function resoudreSecteur(Request $request, $cityId)
    {
        $nom = trim((string) $request->input("secteurNom", ""));
        if ($nom !== "") {
            return optional(Secteur::trouverOuCreer($nom, $cityId))->id;
        }

        return $request->input("secteur") ?: null;
    }

    public function store(Request $request)
    {
        $this->nettoyerChampsVides($request);

        $validator = Validator::make(
            $request->all(),
            [
                "title" => ["required", "string"],
                "description" => ["required", "string"],
                "price" => ["required", "numeric", "gt:0"],
                "surface" => ["required", "integer", "gt:0"],
                "address" => ["required", "string"],
                "dateConstruction" => ["nullable", "date_format:Y-m-d"],
                "nbEtages" => ["nullable", "integer"],
                "nbRooms" => ["nullable", "integer"],
                "etage" => ["nullable", "integer"],
                "nbBathrooms" => ["nullable", "integer"],
                "latitude" => ["required", "numeric"],
                "longitude" => ["required", "numeric"],
                "tour360Url" => ["nullable", "url:http,https"],
                "category" => ["required", "exists:realstate_categories,code"],
                "typeTransaction" => ["required", "exists:type_transactions,code"],
                "etat" => ["required", "exists:realstate_etats,code"],
                "city" => ["required", "exists:cities,id"],
                // Secteur existant, ou nom d'un nouveau secteur a creer.
                "secteur" => ["nullable", "exists:secteurs,id"],
                "secteurNom" => ["nullable", "string", "max:120"],
                "features" => ["nullable", "array"],
                "features.*" => ["exists:features,id"],
                "images" => ["required", "array", "min:2"],
                "owner" => ["nullable", "exists:owners,id"],
                "images.*" => ["image", "mimes:png,jpg,jpeg",]
            ]
        );

        if ($validator->fails()) {
            return $this->jsonResponse(false, self::VALIDATION_ERROR, 422, $validator->errors());
        }

        $data = $validator->validated();

        try {
            DB::beginTransaction();

            // Map data
            $data["date_construction"] = $data["dateConstruction"] ?? null;
            $data["nb_etage"] = $data["nbEtages"] ?? null;
            $data["nb_rooms"] = $data["nbRooms"] ?? null;
            $data["nb_bathroom"] = $data["nbBathrooms"] ?? null;
            $data["tour_360_url"] = $data["tour360Url"] ?? null;
            $data["category_id"] = RealstateCategory::where("code", $data["category"])->first()->id;
            $data["transaction_id"] = TypeTransaction::where("code", $data["typeTransaction"])->first()->id;
            $data["etat_id"] = RealstateEtat::where("code", $data["etat"])->first()->id;
            $data["city_id"] = $data["city"];
            $data["secteur_id"] = $this->resoudreSecteur($request, $data["city"]);
            $data["review_status_id"] = RealstateReviewStatus::where("code", "legal")->first()->id;
            $data["status_id"] = RealstateStatus::where("code", "active")->first()->id;
            $data["owner_id"] = $data["owner"] ?? null;
            $data["cleaning_status"] = "cleaned";

            // Host (agence) user
            $agence = User::where("agence", "1")->first();
            $data["host_id"] = $agence->id;

            // Create realestate
            $realstate = Realstate::create($data);

            // Attach features if provided
            if (!empty($data["features"])) {
                $realstate->features()->attach($data["features"]);
            }

            // Add images
            $images = $request->file("images");
            foreach ($images as $i => $image) {
                $ext = $image->getClientOriginalExtension();
                $fileName = ($i + 1) . "." . $ext;
                $realstate
                    ->addMedia($image)
                    ->usingFileName($fileName)
                    ->toMediaCollection("images");
            }

            DB::commit();

            $response = new RealestateResource($realstate);
            return $this->jsonResponse(true, self::SUCCESS, 201, $response);
        } catch (\Throwable $e) {
            DB::rollBack();
            // Sans trace, la cause reste invisible : un echec de creation
            // se diagnostiquait a l'aveugle.
            \Illuminate\Support\Facades\Log::error(
                "Echec de creation du bien : " . $e->getMessage(),
                ["fichier" => $e->getFile() . ":" . $e->getLine(), "trace" => $e->getTraceAsString()]
            );
            return $this->jsonResponse(false, "Erreur lors de la création du bien immobilier", 500, [
                "error" => $e->getMessage()
            ]);
        }
    }


    public function index(Request $request)
    {
        $status = $request->input("status");
        $realestatesQuery = Realstate::with(["owner", "booking.client", "bookings", "city", "secteur", "dossier", "category", "type", "reviewStatus", "status", "etat", "features", "host"])->whereHas("host", function ($query) {
            $query->where("agence", "=", "1");
        })->with([
            'bookings' => function ($q) {
                $q->whereDate('checkin', '>', today())
                    ->orderBy('checkin', 'asc');
            }
        ]);

        // Un bien desactive n'apparait plus ; « desactives=1 » ne montre qu'eux, pour les reactiver.
        $request->boolean("desactives") ? $realestatesQuery->whereNotNull("desactive_le") : $realestatesQuery->whereNull("desactive_le");

        // Un agent affecte a des dossiers ne voit que leurs biens.
        // Sans affectation, l'acces reste complet : personne ne perd son
        // outil de travail du seul fait du deploiement.
        $dossiersAutorises = $request->user()?->dossiersAutorises();
        if ($dossiersAutorises !== null) {
            $realestatesQuery->whereIn("dossier_id", $dossiersAutorises);
        }

        // Famille de biens : location vacances, location longue duree
        // ou vente. Permet de parcourir un etat au sein d'une famille.
        if ($type = $request->input("type")) {
            $realestatesQuery->whereHas("type", function ($query) use ($type) {
                $query->where("code", "=", $type);
            });
        }

        // Dossier de rangement. La valeur "aucun" vise les biens qui
        // n'ont ete ranges nulle part : ils doivent rester atteignables.
        if ($dossier = $request->input("dossier")) {
            if ($dossier === "aucun") {
                $realestatesQuery->whereNull("dossier_id");
            } else {
                $realestatesQuery->where("dossier_id", "=", $dossier);
            }
        }


        if ($status == "available") {
            $realestates = $realestatesQuery
                ->whereDoesntHave("booking")
                ->where("cleaning_status", "cleaned")
                ->withCount([
                    "bookings as todayBookings" => function ($query) {
                        $query->whereDate("checkin", today());
                    }
                ])
                ->orderBy("created_at", "desc")
                ->get();
        } else if ($status == "reserved") {
            $realestates = $realestatesQuery
                ->whereHas('booking')
                ->join('bookings', 'bookings.id', '=', 'realstates.booking_id')
                ->orderBy('bookings.checkout', 'asc')
                ->select('realstates.*')
                ->get();
        } else if ($status == "cleaning") {
            $realestates = $realestatesQuery
                ->whereDoesntHave("booking")
                ->whereIn("cleaning_status", ["to_clean", "cleaning"])
                ->get();
        } else {
            $realestates = $realestatesQuery->get();
        }
        //get next checkin
        foreach ($realestates as $r) {
            // La prochaine arrivee, ou le debut du prochain blocage s'il vient avant.
            $prochaineArrivee = $r->bookings->first()?->checkin;
            $prochainBlocage = DB::table("blocages_biens")->where("realestate_id", $r->id)
                ->where("date_fin", ">=", today()->toDateString())->orderBy("date_debut")->value("date_debut");
            $r->nextCheckin = ($prochainBlocage && (!$prochaineArrivee
                || $prochainBlocage < Carbon::parse($prochaineArrivee)->toDateString()))
                ? $prochainBlocage : $prochaineArrivee;
        }

        $response = RealestateResource::collection($realestates);
        return $this->jsonResponse(true, self::SUCCESS, 200, $response);
    }

    public function realestatesOverview(Request $request)
    {
        $realestatesQuery = Realstate::with(["owner", "booking.client", "bookings", "city", "secteur", "dossier", "category", "type", "reviewStatus", "status", "status", "etat", "features", "host"])
            ->whereHas("host", function ($query) {
                $query->where("agence", "=", "1");
            })->orderBy("created_at", "desc");

        // Un bien desactive n'apparait plus ; « desactives=1 » ne montre qu'eux, pour les reactiver.
        $request->boolean("desactives") ? $realestatesQuery->whereNotNull("desactive_le") : $realestatesQuery->whereNull("desactive_le");

        // Un agent affecte a des dossiers ne voit que leurs biens.
        // Sans affectation, l'acces reste complet : personne ne perd son
        // outil de travail du seul fait du deploiement.
        $dossiersAutorises = $request->user()?->dossiersAutorises();
        if ($dossiersAutorises !== null) {
            $realestatesQuery->whereIn("dossier_id", $dossiersAutorises);
        }

        // Famille de biens : location vacances, location longue duree
        // ou vente. Permet de parcourir un etat au sein d'une famille.
        if ($type = $request->input("type")) {
            $realestatesQuery->whereHas("type", function ($query) use ($type) {
                $query->where("code", "=", $type);
            });
        }

        // Dossier de rangement. La valeur "aucun" vise les biens qui
        // n'ont ete ranges nulle part : ils doivent rester atteignables.
        if ($dossier = $request->input("dossier")) {
            if ($dossier === "aucun") {
                $realestatesQuery->whereNull("dossier_id");
            } else {
                $realestatesQuery->where("dossier_id", "=", $dossier);
            }
        }



        $allRealetstate = (clone $realestatesQuery)->count();

        $nbAvailable = (clone $realestatesQuery)
            ->whereDoesntHave("booking")
            ->where("cleaning_status", "cleaned")
            ->count();

        $nbReserved = (clone $realestatesQuery)->whereNotNull("booking_id")->count();

        $nbCleaning = (clone $realestatesQuery)
            ->whereDoesntHave("booking")
            ->whereIn("cleaning_status", ["to_clean", "cleaning"])
            ->count();

        $todayCheckout = (clone $realestatesQuery)->whereHas("booking", function ($query) {
            $query->where("checkout", "<=", now()->format("Y-m-d"));
        })->with([
            'bookings' => function ($q) {
                $q->whereDate('checkin', '>', today())
                    ->orderBy('checkin', 'asc');
            }
        ])->get();
        foreach ($todayCheckout as $r) {
            // La prochaine arrivee, ou le debut du prochain blocage s'il vient avant.
            $prochaineArrivee = $r->bookings->first()?->checkin;
            $prochainBlocage = DB::table("blocages_biens")->where("realestate_id", $r->id)
                ->where("date_fin", ">=", today()->toDateString())->orderBy("date_debut")->value("date_debut");
            $r->nextCheckin = ($prochainBlocage && (!$prochaineArrivee
                || $prochainBlocage < Carbon::parse($prochaineArrivee)->toDateString()))
                ? $prochainBlocage : $prochaineArrivee;
        }

        $realestateResponse = RealestateResource::collection($todayCheckout);

        $response = [
            "reserved" => $nbReserved,
            "available" => $nbAvailable,
            "cleaning" => $nbCleaning,
            "all" => $allRealetstate,
            "todayCheckout" => $realestateResponse
        ];

        return $this->successResponse($response);
    }

    public function confirmCheckin($id)
    {
        $realestate = Realstate::find($id);
        $booking = $realestate->bookings()->whereDate("checkin", today())->first();
        $realestate->booking_id = $booking->id;
        $realestate->save();
        return $this->successResponse(null);
    }

    public function confirmDepart($id)
    {
        $realestate = Realstate::find($id);
        if (!$realestate) {
            return $this->notFoundResponse("Realestate not found");
        }

        // La reservation qui s'acheve, saisie avant que le bien ne soit
        // libere : c'est elle qui recevra le message post-sejour.
        $booking = $realestate->booking_id
            ? Booking::find($realestate->booking_id)
            : $realestate->bookings()
                ->whereDate("checkout", today())->latest("id")->first();

        $realestate->booking_id = null;
        // L'appartement attend le menage. Le chronometre ne demarre que
        // lorsque la femme de menage declare commencer.
        $realestate->cleaning_status = "to_clean";
        $realestate->checkout_at = now();
        $realestate->cleaning_started_at = null;
        $realestate->cleaning_finished_at = null;
        $realestate->cleaned_by = null;
        $realestate->last_cleaning_minutes = null;
        $realestate->save();

        // prevenir les femmes de menage que l appartement est libre
        $this->notifierFemmesDeMenage($realestate, "checkout");

        // Le client vient de partir : on le remercie maintenant, plutot
        // qu'a une heure calculee qui tombait au milieu de la nuit.
        EnvoiRappel::postSejour($booking);

        return $this->successResponse(null);
    }

    /**
     * Remet un appartement en nettoyage (menage juge insuffisant, par exemple).
     */
    public function returnToCleaning(Request $request, $id)
    {
        $realestate = Realstate::find($id);
        if (!$realestate) {
            return $this->notFoundResponse("Realestate not found");
        }

        $realestate->cleaning_status = "to_clean";
        $realestate->checkout_at = now();
        $realestate->cleaning_started_at = null;
        $realestate->cleaning_finished_at = null;
        $realestate->cleaned_by = null;
        $realestate->last_cleaning_minutes = null;
        $realestate->save();

        $motif = trim((string) $request->input('motif', ''));
        $this->notifierFemmesDeMenage($realestate, "retour", $motif);

        return $this->successResponse(null);
    }

    /**
     * La femme de menage declare qu'elle commence le nettoyage.
     * C'est ici que demarre le chronometre du temps de travail.
     */
    public function startCleaning($id)
    {
        $realestate = Realstate::find($id);
        if (!$realestate) {
            return $this->notFoundResponse("Realestate not found");
        }

        $realestate->cleaning_status = "cleaning";
        $realestate->cleaning_started_at = now();
        $realestate->cleaning_finished_at = null;
        $realestate->cleaned_by = request()->user()?->id;
        $realestate->save();

        $this->notifierSuiviNettoyage($realestate, "debut", request()->user());

        return $this->successResponse(null);
    }

    public function finishCleaning($id)
    {
        $realestate = Realstate::find($id);
        if (!$realestate) {
            return $this->notFoundResponse("Realestate not found");
        }

        // Si le debut n'a pas ete declare, on le considere comme immediat.
        if (!$realestate->cleaning_started_at) {
            $realestate->cleaning_started_at = now();
        }

        $realestate->cleaning_status = "cleaned";
        $realestate->cleaning_finished_at = now();
        $realestate->cleaned_by = request()->user()?->id;
        $realestate->last_cleaning_minutes =
            $realestate->cleaning_started_at->diffInMinutes(now());
        $realestate->save();

        $this->notifierSuiviNettoyage($realestate, "fin", request()->user());

        return $this->successResponse(null);
    }

    /**
     * Informe les gestionnaires designes de l'avancement du nettoyage.
     * Destinataires : permission receive_charge_notifications.
     */
    private function notifierSuiviNettoyage(Realstate $realestate, string $etape, $auteur = null): void
    {
        try {
            $telephones = Manager::permission('receive_charge_notifications')->whereNotIn("id", \App\Services\CataloguePermissions::retires("receive_charge_notifications"))
                ->get()
                ->map(fn($m) => str_replace('+', '', $m->phone ?? ''))
                ->filter()
                ->unique()
                ->values();

            $telephones = \App\Services\ReceptionWhatsapp::filtrer($telephones, $etape === "debut" ? "nettoyage-commence" : "nettoyage-termine");
            if ($telephones->isEmpty()) {
                return;
            }

            $bien = $realestate->title ?? "Bien #{$realestate->id}";
            $par  = $auteur
                ? trim(($auteur->first_name ?? '') . ' ' . ($auteur->last_name ?? ''))
                : 'Non precise';
            $heure = now()->format('d/m/Y H:i');

            if ($etape === "debut") {
                // delai entre le depart du client et le debut du menage
                $attente = $realestate->checkout_at
                    ? $this->dureeLisible($realestate->checkout_at->diffInMinutes(now()))
                    : '';

                $message = ModelesMessages::rendu("cleaning-started", [
                    "{apartment_name}" => $bien,
                    "{agent_name}"     => $par,
                    "{time}"           => $heure,
                    "{waiting_time}"   => $attente,
                ]);
            } else {
                $message = ModelesMessages::rendu("cleaning-finished", [
                    "{apartment_name}" => $bien,
                    "{agent_name}"     => $par,
                    "{time}"           => $heure,
                    "{duration}"       => $this->dureeLisible($realestate->last_cleaning_minutes),
                ]);
            }

            $wa = new WasenderClient(config('services.whatsapp.wasender_key'));
            foreach ($telephones as $phone) {
                try {
                    $wa->sendText($phone, $message);
                } catch (Throwable $th) {
                    Log::error('WhatsApp suivi nettoyage failed: ' . $th->getMessage());
                }
            }
        } catch (Throwable $th) {
            Log::error('notifierSuiviNettoyage failed: ' . $th->getMessage());
        }
    }

    /** "45 min" ou "1 h 20" */
    private function dureeLisible(?int $minutes): string
    {
        if (!$minutes || $minutes <= 0) return "moins d'une minute";
        if ($minutes < 60) return "{$minutes} min";
        $h = intdiv($minutes, 60);
        $r = $minutes % 60;
        return $r === 0 ? "{$h} h" : "{$h} h {$r}";
    }

    /**
     * Previent par WhatsApp toutes les femmes de menage qu un appartement
     * est a nettoyer. Le message precise de quel appartement il s agit.
     */
    private function notifierFemmesDeMenage(Realstate $realestate, string $motif = "checkout", string $commentaire = ""): void
    {
        try {
            $telephones = Manager::role('nettoyeuse')
                ->get()
                ->map(fn($m) => str_replace('+', '', $m->phone ?? ''))
                ->filter()
                ->unique()
                ->values();

            $telephones = \App\Services\ReceptionWhatsapp::filtrer($telephones, "nettoyage-a-faire");
            if ($telephones->isEmpty()) {
                return;
            }

            $bien    = $realestate->title ?? "Bien #{$realestate->id}";
            $adresse = $realestate->address ?? '-';
            $heure   = now()->format('d/m/Y H:i');

            if ($motif === "retour") {
                $entete = "🔄 Appartement à renettoyer";
                $ligne  = $commentaire !== '' ? "\n📝 Motif        : {$commentaire}" : "";
            } else {
                $entete = "🧹 Appartement à nettoyer";
                $ligne  = "";
            }

            $message = ModelesMessages::rendu("cleaning-to-do", [
                "{apartment_name}"  => $bien,
                "{address}"         => $adresse,
                "{check_out_date}"  => $heure,
                "{time}"            => $heure,
                "{note}"            => $commentaire ?? '',
            ]);

            $wa = new WasenderClient(config('services.whatsapp.wasender_key'));
            foreach ($telephones as $phone) {
                try {
                    $wa->sendText($phone, $message);
                } catch (Throwable $th) {
                    Log::error('WhatsApp menage notification failed: ' . $th->getMessage());
                }
            }
        } catch (Throwable $th) {
            Log::error('notifierFemmesDeMenage failed: ' . $th->getMessage());
        }
    }



    public function show($id)
    {
        $realestate = Realstate::with(["owner", "bookings", "city", "secteur", "dossier", "category", "type", "reviewStatus", "status", "status", "etat", "features", "host"])->find($id);

        $reservedDates = $realestate->bookings()
            ->where("checkout", ">=", now())
            ->whereHas("status", function ($query) {
                $query->where("code", "=", "payed");
            })->orderBy("checkout", "asc")
            ->get()->map(function ($item) {
                return [
                    "checkin" => $item->checkin,
                    "checkout" => $item->checkout,
                ];
            });



        // Les dates bloquees apparaissent comme reservees dans le calendrier.
        $blocages = DB::table("blocages_biens")
            ->where("realestate_id", $realestate->id)
            ->where("date_fin", ">=", Carbon::now()->toDateString())
            ->get()
            ->map(fn($b) => [
                "checkin"  => $b->date_debut,
                "checkout" => Carbon::parse($b->date_fin)->addDay()->toDateString(),
            ]);
        // Les reservations faites sur Airbnb (pas les simples blocages) : ces dates sont prises.
        $airbnb = \Illuminate\Support\Facades\Schema::hasTable("airbnb_sejours")
            ? DB::table("airbnb_sejours")->where("realestate_id", $realestate->id)->where("type", "reservation")
                ->whereNull("booking_id")->where("au", ">=", Carbon::now()->toDateString())->get()
                ->map(fn($s) => ["checkin" => $s->du, "checkout" => $s->au, "airbnb" => true, "airbnbSejour" => $s->id])
            : collect();
        $reservedDates = collect($reservedDates)->concat($blocages)->concat($airbnb)->values();

        $response = (new RealestateResource($realestate))
            ->setReservedDates($reservedDates);

        return $this->successResponse($response);
    }











    public function update(Request $request, $id)
    {
        $this->nettoyerChampsVides($request);

        $realestate = Realstate::where("id", "=", $id)->firstOrFail();

        $validator = Validator::make($request->all(), [
            "title" => ["sometimes", "string"],
            "description" => ["sometimes", "string"],
            "price" => ["sometimes", "numeric", "gt:0"],
            "surface" => ["sometimes", "integer", "gt:0"],
            "address" => ["sometimes", "string"],
            "dateConstruction" => ["nullable", "date_format:Y-m-d"],
            "nbEtages" => ["nullable", "integer"],
            "nbRooms" => ["nullable", "integer"],
            "etage" => ["nullable", "integer"],
            "nbBathrooms" => ["nullable", "integer"],
            "latitude" => ["sometimes", "numeric"],
            "longitude" => ["sometimes", "numeric"],
            "tour360Url" => ["nullable", "url:http,https"],
            "category" => ["sometimes", "exists:realstate_categories,code"],
            "typeTransaction" => ["sometimes", "exists:type_transactions,code"],
            "etat" => ["sometimes", "exists:realstate_etats,code"],
            "city" => ["sometimes", "exists:cities,id"],
            "secteur" => ["nullable", "exists:secteurs,id"],
            "secteurNom" => ["nullable", "string", "max:120"],
            "features" => ["nullable", "array"],
            "features.*" => ["exists:features,id"],
            "trashImages" => ["sometimes", "array"],
            "trashImages.*" => ["sometimes", "integer"],
            "owner" => ["nullable", "exists:owners,id"],
            "images" => ["sometimes", "array"],
            "images.*" => ["image", "mimes:png,jpg,jpeg"]
        ]);

        if ($validator->fails()) {
            return $this->jsonResponse(false, self::VALIDATION_ERROR, 422, $validator->errors());
        }

        $data = $validator->validated();

        try {
            DB::beginTransaction();

            // Map fields
            $data["date_construction"] = $data["dateConstruction"] ?? null;
            $data["nb_etage"] = $data["nbEtages"] ?? null;
            $data["nb_rooms"] = $data["nbRooms"] ?? null;
            $data["nb_bathroom"] = $data["nbBathrooms"] ?? null;
            $data["tour_360_url"] = $data["tour360Url"] ?? null;

            if (isset($data["category"])) {
                $data["category_id"] = RealstateCategory::where("code", $data["category"])->first()->id;
            }
            if (isset($data["typeTransaction"])) {
                $data["transaction_id"] = TypeTransaction::where("code", $data["typeTransaction"])->first()->id;
            }
            if (isset($data["etat"])) {
                $data["etat_id"] = RealstateEtat::where("code", $data["etat"])->first()->id;
            }
            if ($request->filled("secteur") || $request->filled("secteurNom")) {
                $data["secteur_id"] = $this->resoudreSecteur(
                    $request,
                    $data["city"] ?? $realestate->city_id
                );
            }
            if (isset($data["city"])) {
                $data["city_id"] = $data["city"];
            }

            if (isset($data["owner"])) {
                $data["owner_id"] = $data["owner"];
            }

            // Update base realestate
            $realestate->update($data);

            // Sync features if provided
            if (isset($data['features'])) {
                $realestate->features()->sync($data['features']);
            }

            // Add new images
            $newImages = $request->file("images");
            if ($newImages) {
                $start = $realestate->getMedia("images")->max("id") ?? 0;
                foreach ($newImages as $i => $image) {
                    $ext = $image->getClientOriginalExtension();
                    $fileName = (++$start) . "." . $ext;
                    $realestate
                        ->addMedia($image)
                        ->usingFileName($fileName)
                        ->toMediaCollection("images");
                }
            }

            // Delete images if requested
            if ($request->has("trashImages")) {
                foreach ($request->input("trashImages") as $imageId) {
                    $realestate->getMedia("images")->where("id", $imageId)->first()?->delete();
                }
            }

            DB::commit();

            // Reload relations
            $realestate->load([
                "city.region.country",
                "category",
                "type",
                "reviewStatus",
                "status",
                "etat",
                "features",
                "host"
            ]);
            $realestate->unsetRelation("media");
            $realestate->loadMedia("images");

            $data = new RealestateResource($realestate);
            return $this->jsonResponse(true, self::SUCCESS, 200, $data);
        } catch (\Throwable $e) {
            DB::rollBack();
            return $this->jsonResponse(false, "Erreur lors de la mise à jour du bien immobilier", 500, [
                "error" => $e->getMessage()
            ]);
        }
    }



    public function destroy($id)
    {
        // [PERMISSION] seuls les gestionnaires disposant de delete_property
        // peuvent supprimer un bien (controle serveur).
        if (!request()->attributes->get("droit_verifie") && !request()->user()->can('delete_property')) {
            return response()->json([
                "success" => false,
                "statusCode" => 403,
                "message" => "forbidden",
                "error" => ["msg" => ["Vous n'avez pas l'autorisation de supprimer un bien."]],
            ], 403);
        }

        $realestate = Realstate::find($id);
        if (!$realestate) {
            return $this->notFoundResponse("Realestate not found");
        }

        $realestate->delete();
        return $this->successResponse(null);
    }

    public function addRapport(Request $request, $id)
    {
        $validator = Validator::make($request->all(), [
            "rapoort" => ["required"]
        ]);
        if ($validator->fails()) {
            return $this->validationErrorResponse($validator->errors());
        }
        $realestate = Realstate::find($id);
        $images = $request->file("images");
        foreach ($images as $img) {
            $realestate->addMedia($img)->toMediaCollection("rapport");
        }
        return $this->successResponse(null);
    }
}
