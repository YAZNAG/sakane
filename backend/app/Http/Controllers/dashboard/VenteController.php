<?php

namespace App\Http\Controllers\dashboard;

use App\Http\Controllers\Controller;
use App\Models\Realstate;
use App\Models\User;
use App\Services\DocumentsVente;
use App\Services\Telephone;
use App\utils\JsonResponses;
use Carbon\Carbon;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Facades\Validator;
use Throwable;
use WasenderApi\WasenderClient;

/**
 * Module Vente : biens a vendre, mandats du proprietaire, visites des
 * acheteurs avec leur recu. Consultation : view_contract ; modifications :
 * create_contract ; l'administrateur a tout.
 */
class VenteController extends Controller
{
    use JsonResponses;

    public static bool $envoisActifs = true;

    public const STATUTS = ["a_vendre" => "À vendre", "compromis" => "Sous compromis", "vendu" => "Vendu"];
    public const SUITES = ["interesse" => "Intéressé", "a_relancer" => "À relancer", "offre" => "Offre faite", "pas_interesse" => "Pas intéressé"];

    private function refuser(Request $request, string $droit)
    {
        // Deja valide par le controle central des droits.
        if ($request->attributes->get("droit_verifie")) return null;
        $m = $request->user();
        if (!$m || !($m->hasRole("admin") || $m->can($droit))) {
            return $this->jsonResponse(false, self::NO_ACCESS, 403,
                ["msg" => ["Vous n'avez pas l'autorisation de " . ($droit === "view_contract" ? "consulter" : "gérer") . " les ventes."]]);
        }
        return null;
    }

    private function biensVente()
    {
        return Realstate::with(["city", "owner", "category"])->whereNull("desactive_le")->whereHas("type", fn($t) => $t->where("code", "selle"));
    }

    private function mandatTableau(object $m): array
    {
        $fin = Carbon::parse($m->date_signature)->addMonthsNoOverflow((int) $m->duree_mois)->subDay();
        return [
            "id" => $m->id, "bienId" => $m->realestate_id,
            "proprietaireNom" => $m->proprietaire_nom, "proprietaireCin" => $m->proprietaire_cin,
            "proprietaireNationalite" => $m->proprietaire_nationalite, "proprietaireAdresse" => $m->proprietaire_adresse,
            "proprietaireTel" => $m->proprietaire_tel, "typeBien" => $m->type_bien, "ville" => $m->ville,
            "surface" => $m->surface !== null ? (float) $m->surface : null, "titreFoncier" => $m->titre_foncier,
            "adresseBien" => $m->adresse_bien, "prixDemande" => $m->prix_demande !== null ? (float) $m->prix_demande : null,
            "commission" => (float) $m->commission, "dureeMois" => (int) $m->duree_mois,
            "dateSignature" => Carbon::parse($m->date_signature)->toDateString(), "dateFin" => $fin->toDateString(),
            "actif" => $fin->gte(today()), "joursRestants" => (int) round(today()->diffInDays($fin, false)),
            "remarques" => $m->remarques, "creeLe" => Carbon::parse($m->created_at)->toISOString(),
            // Signe a la creation du mandat : le dossier n'a plus a proposer de le faire signer.
            "signe" => !empty($m->signature),
            "signeLe" => !empty($m->signe_le) ? Carbon::parse($m->signe_le)->toISOString() : null,
        ];
    }

    private function visiteTableau(object $v, $agents = null): array
    {
        return [
            "id" => $v->id, "bienId" => $v->realestate_id, "clientId" => $v->client_id,
            "visiteurNom" => $v->visiteur_nom, "visiteurCin" => $v->visiteur_cin, "visiteurNationalite" => $v->visiteur_nationalite,
            "visiteurAdresse" => $v->visiteur_adresse, "visiteurTel" => $v->visiteur_tel,
            "dateVisite" => Carbon::parse($v->date_visite)->toDateString(), "commission" => (float) $v->commission,
            "suite" => $v->suite, "suiteLibelle" => $v->suite ? (self::SUITES[$v->suite] ?? $v->suite) : null,
            "remarques" => $v->remarques,
            "signe" => !empty($v->signature ?? null),
            "signeLe" => !empty($v->signe_le ?? null) ? Carbon::parse($v->signe_le)->toISOString() : null,
            "agent" => $agents && $v->agent_id && isset($agents[$v->agent_id]) ? trim($agents[$v->agent_id]->first_name . " " . $agents[$v->agent_id]->last_name) : null,
            "creeLe" => Carbon::parse($v->created_at)->toISOString(),
        ];
    }

    private function bienTableau($b, $mandats, $visites): array
    {
        $mActif = collect($mandats[$b->id] ?? [])->map(fn($m) => $this->mandatTableau($m))->first(fn($m) => $m["actif"]);
        $vis = collect($visites[$b->id] ?? []);
        return [
            "id" => $b->id, "titre" => $b->title,
            "adresse" => trim(($b->address ?? "") . " " . ($b->city->name ?? "")),
            "photo" => $b->getFirstMediaUrl("images") ?: null,
            "prix" => (float) ($b->price ?? 0), "surface" => $b->surface !== null ? (float) $b->surface : null,
            "statutVente" => $b->vente_statut ?: "a_vendre",
            "statutVenteLibelle" => self::STATUTS[$b->vente_statut ?: "a_vendre"] ?? $b->vente_statut,
            "dossier" => $b->dossier_id,
            "proprietaire" => $b->owner ? ["id" => $b->owner->id, "nom" => $b->owner->name, "tel" => $b->owner->tel] : null,
            "mandat" => $mActif, "nbMandats" => count($mandats[$b->id] ?? []),
            "nbVisites" => $vis->count(),
            "derniereVisite" => $vis->max("date_visite") ? Carbon::parse($vis->max("date_visite"))->toDateString() : null,
        ];
    }

    private function donnees($biens): array
    {
        $ids = $biens->pluck("id")->all() ?: [0];
        return [
            DB::table("mandats_vente")->whereNull("deleted_at")->whereIn("realestate_id", $ids)->orderByDesc("date_signature")->get()->groupBy("realestate_id"),
            DB::table("visites_vente")->whereNull("deleted_at")->whereIn("realestate_id", $ids)->orderByDesc("date_visite")->get()->groupBy("realestate_id"),
        ];
    }

    public function tableau(Request $request)
    {
        if ($refus = $this->refuser($request, "view_contract")) return $refus;
        $biens = $this->biensVente()->get();
        [$mandats, $visites] = $this->donnees($biens);
        $liste = $biens->map(fn($b) => $this->bienTableau($b, $mandats, $visites));
        $finMois = today()->addDays(30)->toDateString();
        $agents = DB::table("managers")->get()->keyBy("id");
        $recentes = DB::table("visites_vente")->whereNull("deleted_at")->whereIn("realestate_id", $biens->pluck("id")->all() ?: [0])
            ->orderByDesc("date_visite")->orderByDesc("id")->limit(10)->get();
        $titres = $biens->pluck("title", "id");
        return $this->successResponse([
            "biens"        => $liste->count(),
            "aVendre"      => $liste->where("statutVente", "a_vendre")->count(),
            "compromis"    => $liste->where("statutVente", "compromis")->count(),
            "vendus"       => $liste->where("statutVente", "vendu")->count(),
            "sansMandat"   => $liste->where("statutVente", "<>", "vendu")->whereNull("mandat")->count(),
            "mandatsActifs" => $liste->whereNotNull("mandat")->count(),
            "mandatsQuiExpirent" => $liste->filter(fn($b) => $b["mandat"] && $b["mandat"]["dateFin"] <= $finMois)->values(),
            "visitesCeMois" => DB::table("visites_vente")->whereNull("deleted_at")->where("date_visite", ">=", today()->startOfMonth()->toDateString())->count(),
            "visitesRecentes" => $recentes->map(fn($v) => $this->visiteTableau($v, $agents) + ["bien" => $titres[$v->realestate_id] ?? null])->values(),
        ]);
    }

    public function biens(Request $request)
    {
        if ($refus = $this->refuser($request, "view_contract")) return $refus;
        $q = $this->biensVente()->orderBy("title");
        if ($request->filled("dossier")) $q->where("dossier_id", $request->input("dossier"));
        $biens = $q->get();
        [$mandats, $visites] = $this->donnees($biens);
        $liste = $biens->map(fn($b) => $this->bienTableau($b, $mandats, $visites));
        $filtre = $request->input("filtre", "tous");
        if (isset(self::STATUTS[$filtre])) $liste = $liste->where("statutVente", $filtre);
        if ($filtre === "sans_mandat") $liste = $liste->where("statutVente", "<>", "vendu")->whereNull("mandat");
        if ($request->filled("q")) {
            $mot = mb_strtolower(trim($request->input("q")));
            $liste = $liste->filter(fn($b) => str_contains(mb_strtolower($b["titre"] . " " . $b["adresse"] . " " . ($b["proprietaire"]["nom"] ?? "")), $mot));
        }
        return $this->successResponse($liste->values());
    }

    /** Le dossier de vente d'un bien : mandats et visites. */
    public function dossier(Request $request, $id)
    {
        if ($refus = $this->refuser($request, "view_contract")) return $refus;
        $bien = $this->biensVente()->find($id);
        if (!$bien) return $this->notFoundResponse("Bien à vendre introuvable");
        [$mandats, $visites] = $this->donnees(collect([$bien]));
        $agents = DB::table("managers")->get()->keyBy("id");
        return $this->successResponse($this->bienTableau($bien, $mandats, $visites) + [
            "typeBienPropose" => DocumentsVente::typeArabe($bien),
            "mandats" => collect($mandats[$bien->id] ?? [])->map(fn($m) => $this->mandatTableau($m))->values(),
            "visites" => collect($visites[$bien->id] ?? [])->map(fn($v) => $this->visiteTableau($v, $agents))->values(),
            "types"   => DocumentsVente::TYPES,
            "statuts" => self::STATUTS,
            "suites"  => self::SUITES,
        ]);
    }

    public function statut(Request $request, $id)
    {
        if ($refus = $this->refuser($request, "create_contract")) return $refus;
        $v = Validator::make($request->all(), ["statut" => ["required", "in:" . implode(",", array_keys(self::STATUTS))]]);
        if ($v->fails()) return $this->validationErrorResponse($v->errors());
        $bien = $this->biensVente()->find($id);
        if (!$bien) return $this->notFoundResponse("Bien à vendre introuvable");
        $bien->vente_statut = $request->input("statut");
        $bien->save();
        return $this->dossier($request, $id);
    }

    /** Ce que le mandat d'un bien reprend deja : proprietaire et bien, saisis a la creation du bien. */
    public function preremplirMandat(Request $request, $id)
    {
        if ($refus = $this->refuser($request, "create_contract")) return $refus;
        $bien = $this->biensVente()->find($id);
        if (!$bien) return $this->notFoundResponse("Bien à vendre introuvable");
        $o = $bien->owner_id ? DB::table("owners")->find($bien->owner_id) : null;
        $dernier = DB::table("mandats_vente")->where("realestate_id", $bien->id)->whereNull("deleted_at")->orderByDesc("id")->first();
        return $this->successResponse([
            "ownerId" => $o->id ?? null,
            "proprietaireNom" => $o->name ?? ($dernier->proprietaire_nom ?? null),
            "proprietaireCin" => $o->cin ?? ($dernier->proprietaire_cin ?? null),
            "proprietaireNationalite" => $o->nationalite ?? ($dernier->proprietaire_nationalite ?? null),
            "proprietaireAdresse" => $o->address ?? ($dernier->proprietaire_adresse ?? null),
            "proprietaireTel" => $o->tel ?? ($dernier->proprietaire_tel ?? null),
            "typeBien" => DocumentsVente::typeArabe($bien),
            "ville" => $bien->city->name ?? null,
            "surface" => $bien->surface !== null ? (float) $bien->surface : null,
            "titreFoncier" => $dernier->titre_foncier ?? null,
            "adresseBien" => trim(($bien->address ?? "") . " " . ($bien->city->name ?? "")) ?: null,
            "prixDemande" => $bien->price ? (float) $bien->price : null,
            "commission" => 2.5, "dureeMois" => 12, "dateSignature" => today()->toDateString(),
            "types" => DocumentsVente::TYPES,
            "mandatsExistants" => DB::table("mandats_vente")->where("realestate_id", $bien->id)->whereNull("deleted_at")->count(),
        ]);
    }

    public function ajouterMandat(Request $request, $id)
    {
        if ($refus = $this->refuser($request, "create_contract")) return $refus;
        $bien = $this->biensVente()->find($id);
        if (!$bien) return $this->notFoundResponse("Bien à vendre introuvable");
        $v = Validator::make($request->all(), [
            "proprietaireNom" => ["required", "string", "max:190"], "proprietaireCin" => ["nullable", "string", "max:40"],
            "proprietaireNationalite" => ["nullable", "string", "max:60"], "proprietaireAdresse" => ["nullable", "string", "max:255"],
            "proprietaireTel" => ["nullable", "string", "max:40"], "typeBien" => ["nullable", "string", "max:60"],
            "ville" => ["nullable", "string", "max:80"], "surface" => ["nullable", "numeric", "min:0"],
            "titreFoncier" => ["nullable", "string", "max:80"], "adresseBien" => ["nullable", "string", "max:255"],
            "prixDemande" => ["nullable", "numeric", "min:0"], "commission" => ["nullable", "numeric", "min:0", "max:20"],
            "dureeMois" => ["nullable", "integer", "min:1", "max:60"], "dateSignature" => ["nullable", "date_format:Y-m-d"],
            "remarques" => ["nullable", "string", "max:2000"],
            "signature" => ["nullable", "image", "max:4096"],
        ], ["proprietaireNom.required" => "Indiquez le nom du propriétaire."]);
        if ($v->fails()) return $this->validationErrorResponse($v->errors());

        $id2 = DB::table("mandats_vente")->insertGetId([
            "realestate_id" => $bien->id,
            "proprietaire_nom" => $request->input("proprietaireNom"), "proprietaire_cin" => strtoupper((string) $request->input("proprietaireCin")) ?: null,
            "proprietaire_nationalite" => $request->input("proprietaireNationalite"), "proprietaire_adresse" => $request->input("proprietaireAdresse"),
            "proprietaire_tel" => $request->input("proprietaireTel"), "type_bien" => $request->input("typeBien") ?: DocumentsVente::typeArabe($bien),
            "ville" => $request->input("ville") ?: ($bien->city->name ?? null), "surface" => $request->input("surface") ?? $bien->surface,
            "titre_foncier" => $request->input("titreFoncier"), "adresse_bien" => $request->input("adresseBien") ?: trim(($bien->address ?? "") . " " . ($bien->city->name ?? "")),
            "prix_demande" => $request->input("prixDemande") ?? ($bien->price ?: null), "commission" => $request->input("commission", 2.5),
            "duree_mois" => $request->input("dureeMois", 12), "date_signature" => $request->input("dateSignature", today()->toDateString()),
            "remarques" => $request->input("remarques"), "created_by" => $request->user()?->id,
            "owner_id" => $bien->owner_id ?: null,
            "created_at" => now(), "updated_at" => now(),
        ]);
        if ($request->hasFile("signature")) {
            $chemin = $request->file("signature")->storeAs("signatures-mandats", "mandat-" . $id2 . "-" . time() . ".png", "local");
            DB::table("mandats_vente")->where("id", $id2)->update(["signature" => $chemin, "signe_le" => now()]);
        }
        // Ce qui manquait sur la fiche du proprietaire y est reporte.
        if ($bien->owner_id && ($o = DB::table("owners")->find($bien->owner_id))) {
            $maj = array_filter(["cin" => $o->cin ?: strtoupper((string) $request->input("proprietaireCin")), "nationalite" => $o->nationalite ?: $request->input("proprietaireNationalite"),
                "address" => $o->address ?: $request->input("proprietaireAdresse"), "tel" => $o->tel ?: $request->input("proprietaireTel")]);
            if ($maj) DB::table("owners")->where("id", $o->id)->update($maj + ["updated_at" => now()]);
        }
        if (!$bien->vente_statut) {
            $bien->vente_statut = "a_vendre";
            $bien->save();
        }
        return $this->successResponse($this->mandatComplet(DB::table("mandats_vente")->find($id2)));
    }

    public function supprimerMandat(Request $request, $id)
    {
        if ($refus = $this->refuser($request, "create_contract")) return $refus;
        if (!DB::table("mandats_vente")->whereNull("deleted_at")->where("id", $id)->update(["deleted_at" => now()])) {
            return $this->notFoundResponse("Mandat introuvable");
        }
        return $this->successResponse(null);
    }

    public function ajouterVisite(Request $request, $id)
    {
        if ($refus = $this->refuser($request, "create_contract")) return $refus;
        $bien = $this->biensVente()->find($id);
        if (!$bien) return $this->notFoundResponse("Bien à vendre introuvable");
        $client = $request->filled("client") ? User::find($request->input("client")) : null;
        if ($client) {
            $request->merge([
                "visiteurNom" => $request->input("visiteurNom") ?: trim(($client->first_name ?? "") . " " . ($client->last_name ?? "")),
                "visiteurCin" => $request->input("visiteurCin") ?: $client->identity_number,
                "visiteurAdresse" => $request->input("visiteurAdresse") ?: $client->address,
                "visiteurTel" => $request->input("visiteurTel") ?: $client->tel,
                "visiteurNationalite" => $request->input("visiteurNationalite") ?: ($client->nationalite ?? null),
            ]);
        }
        $v = Validator::make($request->all(), [
            "visiteurNom" => ["required", "string", "max:190"], "visiteurCin" => ["nullable", "string", "max:40"],
            "visiteurNationalite" => ["nullable", "string", "max:60"], "visiteurAdresse" => ["nullable", "string", "max:255"],
            "visiteurTel" => ["nullable", "string", "max:40"], "dateVisite" => ["nullable", "date_format:Y-m-d"],
            "commission" => ["nullable", "numeric", "min:0", "max:20"],
            "suite" => ["nullable", "in:" . implode(",", array_keys(self::SUITES))], "remarques" => ["nullable", "string", "max:2000"],
            "signature" => ["nullable", "image", "max:4096"],
        ], ["visiteurNom.required" => "Indiquez le nom du visiteur (ou choisissez un client)."]);
        // La commission du recu est celle du mandat en cours du bien.
        $mandatBien = DB::table("mandats_vente")->where("realestate_id", $bien->id)->whereNull("deleted_at")->orderByDesc("date_signature")->first();
        if ($v->fails()) return $this->validationErrorResponse($v->errors());
        $id2 = DB::table("visites_vente")->insertGetId([
            "realestate_id" => $bien->id, "client_id" => $client?->id,
            "visiteur_nom" => $request->input("visiteurNom"), "visiteur_cin" => strtoupper((string) $request->input("visiteurCin")) ?: null,
            "visiteur_nationalite" => $request->input("visiteurNationalite"), "visiteur_adresse" => $request->input("visiteurAdresse"),
            "visiteur_tel" => $request->input("visiteurTel"), "date_visite" => $request->input("dateVisite", today()->toDateString()),
            "commission" => $request->input("commission", $mandatBien->commission ?? 2.5), "suite" => $request->input("suite"), "remarques" => $request->input("remarques"),
            "agent_id" => $request->user()?->id, "created_at" => now(), "updated_at" => now(),
        ]);
        if ($request->hasFile("signature")) {
            $chemin = $request->file("signature")->storeAs("signatures-visites", "visite-" . $id2 . "-" . time() . ".png", "local");
            DB::table("visites_vente")->where("id", $id2)->update(["signature" => $chemin, "signe_le" => now()]);
        }
        return $this->successResponse($this->visiteTableau(DB::table("visites_vente")->find($id2), DB::table("managers")->get()->keyBy("id")));
    }

    /** Le visiteur signe son recu, juste apres sa creation. */
    public function signerVisite(Request $request, $id)
    {
        if ($refus = $this->refuser($request, "create_contract")) return $refus;
        $v = DB::table("visites_vente")->find($id);
        if (!$v) return $this->notFoundResponse("Visite introuvable");
        $val = Validator::make($request->all(), ["signature" => ["required", "image", "max:4096"]], ["signature.required" => "La signature du client est vide."]);
        if ($val->fails()) return $this->validationErrorResponse($val->errors());
        $chemin = $request->file("signature")->storeAs("signatures-visites", "visite-" . $v->id . "-" . time() . ".png", "local");
        DB::table("visites_vente")->where("id", $id)->update(["signature" => $chemin, "signe_le" => now(), "updated_at" => now()]);
        return $this->successResponse($this->visiteTableau(DB::table("visites_vente")->find($id), DB::table("managers")->get()->keyBy("id")));
    }

    public function modifierVisite(Request $request, $id)
    {
        if ($refus = $this->refuser($request, "create_contract")) return $refus;
        $v = Validator::make($request->all(), [
            "suite" => ["nullable", "in:" . implode(",", array_keys(self::SUITES))], "remarques" => ["nullable", "string", "max:2000"],
        ]);
        if ($v->fails()) return $this->validationErrorResponse($v->errors());
        $maj = [];
        if ($request->has("suite")) $maj["suite"] = $request->input("suite");
        if ($request->has("remarques")) $maj["remarques"] = $request->input("remarques");
        DB::table("visites_vente")->where("id", $id)->update($maj + ["updated_at" => now()]);
        $visite = DB::table("visites_vente")->find($id);
        return $visite ? $this->successResponse($this->visiteTableau($visite, DB::table("managers")->get()->keyBy("id"))) : $this->notFoundResponse("Visite introuvable");
    }

    public function supprimerVisite(Request $request, $id)
    {
        if ($refus = $this->refuser($request, "create_contract")) return $refus;
        if (!DB::table("visites_vente")->whereNull("deleted_at")->where("id", $id)->update(["deleted_at" => now()])) {
            return $this->notFoundResponse("Visite introuvable");
        }
        return $this->successResponse(null);
    }

    private function pdf(string $contenu, string $nom)
    {
        return response($contenu, 200, ["Content-Type" => "application/pdf", "Content-Disposition" => 'attachment; filename="' . $nom . '"']);
    }

    public function pdfMandat(Request $request, $id)
    {
        if ($refus = $this->refuser($request, "view_contract")) return $refus;
        $m = DB::table("mandats_vente")->whereNull("deleted_at")->find($id);
        return $m ? $this->pdf(DocumentsVente::pdfMandat($m), "mandat_vente_" . $m->id . ".pdf") : $this->notFoundResponse("Mandat introuvable");
    }

    public function pdfVisite(Request $request, $id)
    {
        if ($refus = $this->refuser($request, "view_contract")) return $refus;
        $v = DB::table("visites_vente")->whereNull("deleted_at")->find($id);
        if (!$v) return $this->notFoundResponse("Visite introuvable");
        $bien = Realstate::with(["city", "category"])->find($v->realestate_id);
        $mandat = DB::table("mandats_vente")->whereNull("deleted_at")->where("realestate_id", $v->realestate_id)->orderByDesc("date_signature")->first();
        return $this->pdf(DocumentsVente::pdfVisite($v, $bien, $mandat), "recu_visite_" . $v->id . ".pdf");
    }

    /** Envoie le document par WhatsApp : le mandat au proprietaire, le recu au visiteur. */
    private function envoyer(string $tel, string $contenu, string $nom, string $texte)
    {
        $numero = Telephone::international($tel);
        if ($numero === "") {
            return $this->validationErrorResponse(["msg" => ["Numéro de téléphone manquant ou invalide."]]);
        }
        try {
            $chemin = "ventes/" . uniqid() . "-" . $nom;
            Storage::disk("public")->put($chemin, $contenu);
            if (static::$envoisActifs) {
                (new WasenderClient(config("services.whatsapp.wasender_key")))->sendDocument($numero, Storage::disk("public")->url($chemin), $texte, $nom);
            }
            return $this->successResponse(["envoyeA" => $numero]);
        } catch (Throwable $th) {
            Log::error("Envoi document vente : " . $th->getMessage());
            return $this->jsonResponse(false, "L'envoi WhatsApp a échoué. Réessayez plus tard.", 502, null);
        }
    }

    public function envoyerMandat(Request $request, $id)
    {
        if ($refus = $this->refuser($request, "create_contract")) return $refus;
        $m = DB::table("mandats_vente")->whereNull("deleted_at")->find($id);
        if (!$m) return $this->notFoundResponse("Mandat introuvable");
        return $this->envoyer((string) $m->proprietaire_tel, DocumentsVente::pdfMandat($m), "mandat_vente.pdf",
            "Bonjour " . $m->proprietaire_nom . ", veuillez trouver ci-joint le mandat de vente de votre bien.");
    }

    public function envoyerVisite(Request $request, $id)
    {
        if ($refus = $this->refuser($request, "create_contract")) return $refus;
        $v = DB::table("visites_vente")->whereNull("deleted_at")->find($id);
        if (!$v) return $this->notFoundResponse("Visite introuvable");
        $bien = Realstate::with(["city", "category"])->find($v->realestate_id);
        $mandat = DB::table("mandats_vente")->whereNull("deleted_at")->where("realestate_id", $v->realestate_id)->orderByDesc("date_signature")->first();
        return $this->envoyer((string) $v->visiteur_tel, DocumentsVente::pdfVisite($v, $bien, $mandat), "recu_visite.pdf",
            "Bonjour " . $v->visiteur_nom . ", voici le reçu de votre visite du " . Carbon::parse($v->date_visite)->format("d/m/Y") . ".");
    }

    // ------------------------------------------------------------------
    // Mandats crees avant le bien (formulaire d'ajout d'un bien a vendre)
    // ------------------------------------------------------------------

    private function champsMandat(Request $request, $bien = null): array
    {
        return [
            "proprietaire_nom" => $request->input("proprietaireNom"),
            "proprietaire_cin" => strtoupper((string) $request->input("proprietaireCin")) ?: null,
            "proprietaire_nationalite" => $request->input("proprietaireNationalite"),
            "proprietaire_adresse" => $request->input("proprietaireAdresse"),
            "proprietaire_tel" => $request->input("proprietaireTel"),
            "type_bien" => $request->input("typeBien") ?: ($bien ? DocumentsVente::typeArabe($bien) : null),
            "ville" => $request->input("ville") ?: ($bien->city->name ?? "أكادير"),
            "surface" => $request->input("surface") ?? $bien?->surface,
            "titre_foncier" => $request->input("titreFoncier"),
            "adresse_bien" => $request->input("adresseBien") ?: ($bien ? trim(($bien->address ?? "") . " " . ($bien->city->name ?? "")) : null),
            "prix_demande" => $request->input("prixDemande") ?? ($bien?->price ?: null),
            "commission" => $request->input("commission", 2.5),
            "duree_mois" => $request->input("dureeMois", 12),
            "date_signature" => $request->input("dateSignature", today()->toDateString()),
            "remarques" => $request->input("remarques"),
        ];
    }

    private function reglesMandat(): array
    {
        return [
            "owner" => ["nullable", "integer", "exists:owners,id"],
            "proprietaireNom" => ["required_without:owner", "nullable", "string", "max:190"], "proprietaireCin" => ["nullable", "string", "max:40"],
            "proprietaireNationalite" => ["nullable", "string", "max:60"], "proprietaireAdresse" => ["nullable", "string", "max:255"],
            "proprietaireTel" => ["nullable", "string", "max:40"], "typeBien" => ["nullable", "string", "max:60"],
            "ville" => ["nullable", "string", "max:80"], "surface" => ["nullable", "numeric", "min:0"],
            "titreFoncier" => ["nullable", "string", "max:80"], "adresseBien" => ["nullable", "string", "max:255"],
            "prixDemande" => ["nullable", "numeric", "min:0"], "commission" => ["nullable", "numeric", "min:0", "max:20"],
            "dureeMois" => ["nullable", "integer", "min:1", "max:60"], "dateSignature" => ["nullable", "date_format:Y-m-d"],
            "remarques" => ["nullable", "string", "max:2000"],
        ];
    }

    /** Le proprietaire du mandat : choisi, ou cree a partir des champs saisis. */
    private function proprietaire(Request $request): ?\App\Models\Owner
    {
        if ($request->filled("owner")) {
            $o = \App\Models\Owner::find($request->input("owner"));
            $request->merge([
                "proprietaireNom" => $request->input("proprietaireNom") ?: $o->name,
                "proprietaireTel" => $request->input("proprietaireTel") ?: $o->tel,
                "proprietaireAdresse" => $request->input("proprietaireAdresse") ?: $o->address,
                "proprietaireCin" => $request->input("proprietaireCin") ?: $o->cin,
                "proprietaireNationalite" => $request->input("proprietaireNationalite") ?: $o->nationalite,
            ]);
            // Ce qui manquait sur la fiche du proprietaire y est reporte.
            $maj = array_filter(["cin" => $o->cin ?: strtoupper((string) $request->input("proprietaireCin")), "nationalite" => $o->nationalite ?: $request->input("proprietaireNationalite"),
                "address" => $o->address ?: $request->input("proprietaireAdresse"), "tel" => $o->tel ?: $request->input("proprietaireTel")]);
            if ($maj) DB::table("owners")->where("id", $o->id)->update($maj + ["updated_at" => now()]);
            return $o;
        }
        if ($request->boolean("creerProprietaire", true) && trim((string) $request->input("proprietaireNom")) !== "") {
            $id = DB::table("owners")->insertGetId([
                "name" => $request->input("proprietaireNom"), "tel" => $request->input("proprietaireTel"),
                "address" => $request->input("proprietaireAdresse"), "cin" => strtoupper((string) $request->input("proprietaireCin")) ?: null,
                "nationalite" => $request->input("proprietaireNationalite"), "created_at" => now(), "updated_at" => now(),
            ]);
            return \App\Models\Owner::find($id);
        }
        return null;
    }

    private function mandatComplet(object $m): array
    {
        return $this->mandatTableau($m) + [
            "ownerId" => $m->owner_id ?? null,
            "signe" => !empty($m->signature),
            "signeLe" => !empty($m->signe_le) ? Carbon::parse($m->signe_le)->toISOString() : null,
            "bien" => $m->realestate_id ? DB::table("realstates")->where("id", $m->realestate_id)->value("title") : null,
        ];
    }

    /** Les mandats, pour choisir celui d'un nouveau bien (?libres=1 : pas encore lies). */
    public function mandats(Request $request)
    {
        if ($refus = $this->refuser($request, "view_contract")) return $refus;
        $q = DB::table("mandats_vente")->whereNull("deleted_at")->orderByDesc("created_at");
        if ($request->boolean("libres")) $q->whereNull("realestate_id");
        if ($request->filled("q")) {
            $mot = "%" . trim($request->input("q")) . "%";
            $q->where(fn($w) => $w->where("proprietaire_nom", "like", $mot)->orWhere("adresse_bien", "like", $mot)->orWhere("titre_foncier", "like", $mot));
        }
        return $this->successResponse($q->limit(200)->get()->map(fn($m) => $this->mandatComplet($m))->values());
    }

    public function mandat(Request $request, $id)
    {
        if ($refus = $this->refuser($request, "view_contract")) return $refus;
        $m = DB::table("mandats_vente")->whereNull("deleted_at")->find($id);
        return $m ? $this->successResponse($this->mandatComplet($m) + ["types" => DocumentsVente::TYPES]) : $this->notFoundResponse("Mandat introuvable");
    }

    /** Un mandat sans bien : le bien sera cree ensuite et lie a lui. */
    public function creerMandat(Request $request)
    {
        if ($refus = $this->refuser($request, "create_contract")) return $refus;
        $v = Validator::make($request->all(), $this->reglesMandat(), ["proprietaireNom.required_without" => "Choisissez ou saisissez le propriétaire."]);
        if ($v->fails()) return $this->validationErrorResponse($v->errors());
        $owner = $this->proprietaire($request);
        $id = DB::table("mandats_vente")->insertGetId($this->champsMandat($request) + [
            "realestate_id" => null, "owner_id" => $owner?->id, "created_by" => $request->user()?->id, "created_at" => now(), "updated_at" => now(),
        ]);
        return $this->successResponse($this->mandatComplet(DB::table("mandats_vente")->find($id)));
    }

    public function modifierMandat(Request $request, $id)
    {
        if ($refus = $this->refuser($request, "create_contract")) return $refus;
        $m = DB::table("mandats_vente")->whereNull("deleted_at")->find($id);
        if (!$m) return $this->notFoundResponse("Mandat introuvable");
        if ($m->signature) {
            return $this->validationErrorResponse(["msg" => ["Ce mandat est déjà signé : créez un nouveau mandat pour le modifier."]]);
        }
        $v = Validator::make($request->all(), $this->reglesMandat());
        if ($v->fails()) return $this->validationErrorResponse($v->errors());
        $owner = $request->filled("owner") ? $this->proprietaire($request) : null;
        $champs = array_filter($this->champsMandat($request), fn($x) => $x !== null && $x !== "");
        DB::table("mandats_vente")->where("id", $id)->update($champs + ($owner ? ["owner_id" => $owner->id] : []) + ["updated_at" => now()]);
        return $this->successResponse($this->mandatComplet(DB::table("mandats_vente")->find($id)));
    }

    /** La signature du proprietaire, dessinee dans l'application (image PNG). */
    public function signerMandat(Request $request, $id)
    {
        if ($refus = $this->refuser($request, "create_contract")) return $refus;
        $m = DB::table("mandats_vente")->whereNull("deleted_at")->find($id);
        if (!$m) return $this->notFoundResponse("Mandat introuvable");
        $v = Validator::make($request->all(), ["signature" => ["required", "image", "max:4096"]], ["signature.required" => "La signature du propriétaire est vide."]);
        if ($v->fails()) return $this->validationErrorResponse($v->errors());
        $chemin = $request->file("signature")->storeAs("signatures-mandats", "mandat-" . $m->id . "-" . time() . ".png", "local");
        DB::table("mandats_vente")->where("id", $id)->update(["signature" => $chemin, "signe_le" => now(), "updated_at" => now()]);
        return $this->successResponse($this->mandatComplet(DB::table("mandats_vente")->find($id)));
    }

    /** Relie le mandat au bien cree juste apres lui ; le proprietaire du mandat devient celui du bien. */
    public function lierMandat(Request $request, $id)
    {
        if ($refus = $this->refuser($request, "create_contract")) return $refus;
        $m = DB::table("mandats_vente")->whereNull("deleted_at")->find($id);
        if (!$m) return $this->notFoundResponse("Mandat introuvable");
        $bien = $this->biensVente()->find($request->input("bien"));
        if (!$bien) return $this->validationErrorResponse(["bien" => ["Ce bien n'est pas un bien à vendre."]]);
        DB::table("mandats_vente")->where("id", $id)->update(["realestate_id" => $bien->id, "updated_at" => now()]);
        $maj = ["vente_statut" => $bien->vente_statut ?: "a_vendre"];
        if ($m->owner_id && !$bien->owner_id) $maj["owner_id"] = $m->owner_id;
        DB::table("realstates")->where("id", $bien->id)->update($maj);
        return $this->dossier($request, $bien->id);
    }
}
