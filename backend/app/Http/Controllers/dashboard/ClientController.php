<?php

namespace App\Http\Controllers\dashboard;

use App\Http\Controllers\Controller;
use App\Http\Resources\AppResources\ClientProfileResource;
use App\Http\Resources\DashboardResource\ClientResource;
use App\Models\User;
use App\Models\UserType;
use App\utils\JsonResponses;

use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Validator;
use Throwable;

class ClientController extends Controller
{
    use JsonResponses;
    public function index(Request $request)
    {
        // Recherche sur nom, prenom, telephone ou CIN.
        // Le terme est decoupe en mots : "ahmed benali" trouve aussi "Benali Ahmed".
        $search = trim((string) $request->input("search", ""));

        $clients = User::whereHas("type", function ($query) {
            $query->where("code", "=", "client")
                ->where("from_platform", "=", "0");
        })->when($search !== "", function ($query) use ($search) {
            $mots = preg_split('/\s+/', $search, -1, PREG_SPLIT_NO_EMPTY);
            foreach ($mots as $mot) {
                $like = "%{$mot}%";
                $query->where(function ($q) use ($like) {
                    $q->where("first_name", "like", $like)
                        ->orWhere("last_name", "like", $like)
                        ->orWhere("tel", "like", $like)
                        ->orWhere("identity_number", "like", $like)
                        ->orWhere("email", "like", $like)
                        ->orWhereRaw("CONCAT(first_name, ' ', last_name) like ?", [$like]);
                });
            }
        })->when($request->boolean("listeNoire"), fn($q) => $q->whereNotNull("liste_noire_le"))
            ->orderBy("created_at", "desc")
            ->get();
        $response = ClientResource::collection($clients);
        return $this->successResponse($response);
    }
    /**
     * Les clients deja enregistres qui ressemblent a celui qu'on va creer :
     * meme telephone (les 9 derniers chiffres), meme CIN, ou meme nom et
     * prenom. Chaque resultat dit ce qui correspond.
     */
    public function doublons(Request $request)
    {
        $tel    = preg_replace('/\D/', '', (string) $request->input("tel", ""));
        $cin    = strtoupper(str_replace(" ", "", trim((string) $request->input("cin", ""))));
        $prenom = mb_strtolower(trim((string) $request->input("prenom", "")));
        $nom    = mb_strtolower(trim((string) $request->input("nom", "")));

        $parTel = strlen($tel) >= 9 ? substr($tel, -9) : null;
        $parCin = $cin !== "" ? $cin : null;
        $parNom = ($prenom !== "" && $nom !== "");

        if (!$parTel && !$parCin && !$parNom) {
            return $this->successResponse([]);
        }

        $clients = User::whereHas("type", fn($q) => $q->where("code", "client"))
            ->where(function ($q) use ($parTel, $parCin, $parNom, $prenom, $nom) {
                if ($parTel) {
                    $q->orWhereRaw("REPLACE(REPLACE(REPLACE(REPLACE(tel, '+', ''), ' ', ''), '-', ''), '.', '') LIKE ?", ["%" . $parTel]);
                }
                if ($parCin) {
                    $q->orWhereRaw("UPPER(REPLACE(identity_number, ' ', '')) = ?", [$parCin]);
                }
                if ($parNom) {
                    $q->orWhere(fn($w) => $w->whereRaw("LOWER(TRIM(first_name)) = ?", [$prenom])->whereRaw("LOWER(TRIM(last_name)) = ?", [$nom]))
                      ->orWhere(fn($w) => $w->whereRaw("LOWER(TRIM(first_name)) = ?", [$nom])->whereRaw("LOWER(TRIM(last_name)) = ?", [$prenom]));
                }
            })
            ->orderByDesc("created_at")
            ->limit(10)
            ->get();

        return $this->successResponse($clients->map(function ($client) use ($request, $parTel, $parCin, $parNom, $prenom, $nom) {
            $raisons = [];
            $telClient = preg_replace('/\D/', '', (string) $client->tel);
            if ($parTel && str_ends_with($telClient, $parTel)) {
                $raisons[] = "telephone";
            }
            if ($parCin && strtoupper(str_replace(" ", "", (string) $client->identity_number)) === $parCin) {
                $raisons[] = "cin";
            }
            $p = mb_strtolower(trim((string) $client->first_name));
            $n = mb_strtolower(trim((string) $client->last_name));
            if ($parNom && (($p === $prenom && $n === $nom) || ($p === $nom && $n === $prenom))) {
                $raisons[] = "nom";
            }

            $reservations = \App\Models\Booking::where("client_id", $client->id);
            $derniere = (clone $reservations)->with("realestate")->orderByDesc("checkin")->first();

            // Les champs du dossier, sans les relations : la fiche d'alerte
            // n'en a pas besoin et elles ne se serialisent pas hors requete.
            return [
                "id"                => $client->id,
                "firstName"         => $client->first_name,
                "lastName"          => $client->last_name,
                "firstNameAr"       => $client->first_name_ar,
                "lastNameAr"        => $client->last_name_ar,
                "email"             => $client->email,
                "tel"               => $client->tel,
                "identityNumber"    => $client->identity_number,
                "listeNoire"        => $client->liste_noire_le ? ["motif" => $client->liste_noire_motif] : null,
            ] + [
                "raisons"             => $raisons,
                "nbReservations"      => $reservations->count(),
                "derniereReservation" => $derniere ? [
                    "bien"     => $derniere->realestate->title ?? null,
                    "checkin"  => $derniere->checkin,
                    "checkout" => $derniere->checkout,
                ] : null,
                "creeLe"              => $client->created_at?->toDateString(),
            ];
        })->values());
    }

    public function store(Request $request)
    {
        $validator = Validator::make($request->all(), [
            "email" => ["nullable", "email", "unique:users,email"],
            "firstName" => ["required"],
            "lastName" => ["required"],
            "firstNameAr" => ["nullable", "string", "max:100"],
            "lastNameAr" => ["nullable", "string", "max:100"],
            "identityNumber" => ["nullable", "string"],
            "nationalite" => ["nullable", "string", "max:60"],
            "documents" => ["array"],
            "tel" => ["regex:/^\d{10,}$/"],
            "documentsProvided" => ["array"],
            "documents.*" => ["image", "mimes:png,jpg,jpeg"]
        ]);
        if ($validator->fails()) {
            return $this->validationErrorResponse($validator->errors());
        }

        // Un CIN n'appartient qu'a un seul client actif.
        $cinSaisi = strtoupper(str_replace(" ", "", trim((string) $request->input("identityNumber", ""))));
        if ($cinSaisi !== "") {
            $titulaire = User::whereHas("type", fn($q) => $q->where("code", "client"))
                ->whereRaw("UPPER(REPLACE(identity_number, ' ', '')) = ?", [$cinSaisi])
                ->first();
            if ($titulaire) {
                return $this->validationErrorResponse(["identityNumber" => [
                    "Ce CIN est déjà utilisé par le client "
                    . trim(($titulaire->first_name ?? "") . " " . ($titulaire->last_name ?? ""))
                    . " (n° " . $titulaire->id . ")."
                ]]);
            }
        }
        $data = $validator->validated();
        $data["first_name"] = $data["firstName"];
        $data["last_name"] = $data["lastName"];
        // Les noms arabes sont facultatifs : la CIN ne se lit pas toujours.
        if (isset($data["firstNameAr"])) {
            $data["first_name_ar"] = $data["firstNameAr"];
        }
        if (isset($data["lastNameAr"])) {
            $data["last_name_ar"] = $data["lastNameAr"];
        }
        if (isset($data["identityNumber"])) {
            $data["identity_number"] = $data["identityNumber"];
        }
        // Nationalite saisie, marocaine a defaut.
        $data["nationalite"] = trim((string) ($data["nationalite"] ?? "")) ?: "Marocain";
        $data["email"] = isset($data["email"]) ? $data["email"] : $data["firstName"] . $data["lastName"] . time() . "@gmail.com";
        $data["password"] = Hash::make($data["firstName"] . $data["lastName"]);

        $type = UserType::where("code", "=", "client")->first();
        $data["type_id"] = $type->id;
        $data["from_platform"] = 0;
        $data["documents"] = implode(";", $request->input("documentsProvided"));

        DB::beginTransaction();

        try {
            $client = User::create($data);
            $documents = $request->file("documents");
            if (isset($documents)) {
                for ($i = 0; $i < count($documents); $i++) {
                    $image = $documents[$i];
                    $ext = $image->getClientOriginalExtension();
                    $fileName = ($i + 1) . "." . $ext;
                    $client->addMedia($image)->usingFileName($fileName)->toMediaCollection("documents");
                }
            }
            DB::commit();
            return $this->successResponse(new ClientResource($client));
        } catch (Throwable $th) {
            DB::rollBack();
            Log::error($th);
            return $this->serverErrorResponse(null);
        }
    }

    public function update(Request $request, $id)
    {
        $client = User::find($id);

        if (!$client) {
            return $this->notFoundResponse();
        }

        $validator = Validator::make($request->all(), [
            "email" => ["nullable", "email", "unique:users,email," . $id],
            "firstName" => ["sometimes"],
            "lastName" => ["sometimes"],
            "firstNameAr" => ["sometimes", "nullable", "string", "max:100"],
            "lastNameAr" => ["sometimes", "nullable", "string", "max:100"],
            "identityNumber" => ["sometimes", "nullable", "string"],
            "nationalite" => ["sometimes", "nullable", "string", "max:60"],
            "tel" => ["sometimes", "regex:/^\d{10,}$/"],
            "documents" => ["sometimes", "array"],
            "documentsProvided" => ["sometimes", "array"],
            "documents.*" => ["image", "mimes:png,jpg,jpeg"]
        ]);

        if ($validator->fails()) {
            return $this->validationErrorResponse($validator->errors());
        }

        // Un CIN n'appartient qu'a un seul client actif.
        $cinSaisi = strtoupper(str_replace(" ", "", trim((string) $request->input("identityNumber", ""))));
        if ($cinSaisi !== "") {
            $titulaire = User::whereHas("type", fn($q) => $q->where("code", "client"))
                ->whereRaw("UPPER(REPLACE(identity_number, ' ', '')) = ?", [$cinSaisi])
                ->where("id", "<>", $id)->first();
            if ($titulaire) {
                return $this->validationErrorResponse(["identityNumber" => [
                    "Ce CIN est déjà utilisé par le client "
                    . trim(($titulaire->first_name ?? "") . " " . ($titulaire->last_name ?? ""))
                    . " (n° " . $titulaire->id . ")."
                ]]);
            }
        }

        $data = $validator->validated();

        // Mapping fields
        if (isset($data["firstName"])) {
            $data["first_name"] = $data["firstName"];
        }

        // array_key_exists et non isset : vider un nom arabe est une
        // intention legitime, et isset() confondrait null et absent.
        if (array_key_exists("firstNameAr", $data)) {
            $data["first_name_ar"] = $data["firstNameAr"];
        }
        if (array_key_exists("lastNameAr", $data)) {
            $data["last_name_ar"] = $data["lastNameAr"];
        }

        if (isset($data["lastName"])) {
            $data["last_name"] = $data["lastName"];
        }

        if (isset($data["identityNumber"])) {
            $data["identity_number"] = $data["identityNumber"];
        }

        if (isset($data["documentsProvided"])) {
            $data["documents"] = implode(";", $data["documentsProvided"]);
        }
        if (array_key_exists("nationalite", $data)) {
            // Tout client a une nationalite : vide, elle reste « Marocain ».
            $data["nationalite"] = trim((string) $data["nationalite"]) ?: "Marocain";
        }

        DB::beginTransaction();

        try {
            $client->update($data);

            // Append new documents
            if ($request->hasFile("documents")) {
                $existingCount = $client->getMedia("documents")->count();
                $documents = $request->file("documents");
                foreach ($documents as $i => $image) {
                    $ext = $image->getClientOriginalExtension();
                    $fileName = ($existingCount + $i + 1) . "." . $ext;
                    $client->addMedia($image)
                        ->usingFileName($fileName)
                        ->toMediaCollection("documents");
                }
            }

            DB::commit();

            return $this->successResponse(new ClientResource($client));
        } catch (Throwable $th) {
            DB::rollBack();
            Log::error($th);
            return $this->serverErrorResponse(null);
        }
    }

    public function destroy($id)
    {
        $client = User::find($id);

        if (!$client) {
            return $this->notFoundResponse();
        }

        $client->delete(); // works if SoftDeletes is enabled

        return $this->successResponse(null);
    }



    private function refuserListeNoire(Request $request)
    {
        // Deja valide par le controle central des droits.
        if ($request->attributes->get("droit_verifie")) return null;
        $manager = $request->user();
        if (!$manager || !($manager->hasRole("admin") || $manager->can("update_client"))) {
            return $this->jsonResponse(false, "forbidden", 403,
                ["msg" => ["Vous n'avez pas l'autorisation de modifier la liste noire."]]);
        }
        return null;
    }

    /** Met un client sur liste noire : il ne peut plus reserver. */
    public function ajouterListeNoire(Request $request, $id)
    {
        if ($refus = $this->refuserListeNoire($request)) return $refus;

        $validator = Validator::make($request->all(), [
            "motif" => ["required", "string", "min:3", "max:300"],
        ], [
            "motif.required" => "Indiquez pourquoi ce client est mis sur liste noire.",
            "motif.min"      => "Le motif est trop court.",
        ]);
        if ($validator->fails()) {
            return $this->validationErrorResponse($validator->errors());
        }

        $client = User::whereHas("type", fn($q) => $q->where("code", "client"))->find($id);
        if (!$client) {
            return $this->notFoundResponse();
        }

        $client->forceFill([
            "liste_noire_le"    => now(),
            "liste_noire_motif" => trim($request->input("motif")),
            "liste_noire_par"   => $request->user()?->id,
        ])->save();

        return $this->successResponse(new ClientResource($client->fresh()));
    }

    /** Retire un client de la liste noire. */
    public function retirerListeNoire(Request $request, $id)
    {
        if ($refus = $this->refuserListeNoire($request)) return $refus;

        $client = User::whereHas("type", fn($q) => $q->where("code", "client"))->find($id);
        if (!$client) {
            return $this->notFoundResponse();
        }

        $client->forceFill([
            "liste_noire_le"    => null,
            "liste_noire_motif" => null,
            "liste_noire_par"   => null,
        ])->save();

        return $this->successResponse(new ClientResource($client->fresh()));
    }

    public function show(Request $request, $id)
    {
        $client = User::with([
            "bookings" => fn($q) => $q->orderByDesc("checkin"),
            "bookings.realestate",
            "bookings.status",
            "bookings.manager",
        ])->find($id);
        if (!$client) {
            return $this->notFoundResponse();
        }
        $response = new ClientResource($client);
        return $this->successResponse($response);
    }
}
