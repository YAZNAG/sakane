<?php

namespace App\Http\Controllers\dashboard;

use App\Http\Controllers\Controller;
use App\Http\Resources\DashboardResource\ChargeResource;
use App\Models\Charge;
use App\Models\FinancialTransaction;
use App\utils\JsonResponses;
use Carbon\Carbon;
use App\Services\ModelesMessages;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Validator;
use App\Models\Manager;
use Illuminate\Support\Facades\Log;
use WasenderApi\WasenderClient;
use Throwable;
use App\Services\Caisses;
use App\Models\MouvementCaisse;

class ChargeController extends Controller
{
    use JsonResponses;

    public function index(Request $request)
    {
        $realestate = $request->input("realestate");
        $type       = $request->input("type");
        $status     = $request->input("status");
        $from       = $request->input("from");
        $to         = $request->input("to");

        $charges = Charge::with("realestate")
            ->when(true, function ($query) use ($realestate) {
                // always apply realestate filter
                // if null → return only charges with null realestate_id
                if ($realestate === "all" || (string) $realestate === "-1") {
                    // Toutes les charges : agence et appartements.
                } elseif (is_null($realestate)) {
                    $query->whereNull("realestate_id");
                } else {
                    $query->where("realestate_id", $realestate);
                }
            })
            ->when($type, function ($query) use ($type) {
                $query->where("type", $type);
            })
            ->when($status, function ($query) use ($status) {
                $query->where("status", $status);
            })
            // Une charge annulee a son propre historique : elle
            // n'encombre pas la liste courante.
            ->when(!$status, fn($query) => $query->where("status", "!=", "cancelled"))
            ->when($from && $to, function ($query) use ($from, $to) {
                $dtFrom = Carbon::parse($from)->startOfDay();
                $dtTo   = Carbon::parse($to)->endOfDay();
                $query->whereBetween("created_at", [$dtFrom, $dtTo]);
            })
            ->orderBy("created_at", "desc")
            ->get();

        return $this->successResponse(ChargeResource::collection($charges));
    }

    public function store(Request $request)
    {
        // Une charge reglee en especes sort de la caisse : si celle-ci
        // ne peut pas la couvrir, mieux vaut le dire que d'enregistrer
        // une depense dont la caisse ne porte la trace.
        if ($request->input("status", "payed") === "payed") {
            $montant = (float) $request->input("amount", 0);
            $caisse  = \App\Services\Caisses::pour($request->user());
            $solde   = $caisse === null ? 0 : round($caisse->solde(), 2);

            if ($montant > $solde + 0.001) {
                return $this->jsonResponse(false,
                    "Votre caisse contient " . number_format($solde, 2, ",", " ")
                    . " MAD et cette depense en demande "
                    . number_format($montant, 2, ",", " ")
                    . ". Enregistrez un apport ou faites-vous transferer la somme,"
                    . " ou saisissez la charge comme non reglee.", 422, null);
            }
        }

        $validator = Validator::make($request->all(), [
            "nom"         => ["required", "string"],
            "description" => ["required", "string"],
            "amount"      => ["required", "numeric"],
            "document"    => ["nullable", "file", "mimes:pdf,jpg,jpeg,png"],
            "realestate" => ["nullable", "exists:realstates,id"],
            "status"     => ["nullable", "in:payed,pending"],
        ]);

        if ($validator->fails()) {
            return $this->validationErrorResponse($validator->errors());
        }

        $data = $validator->validated();
        $data["type"]   = "variable";
        // Statut choisi par l'utilisateur ; payee par defaut.
        $data["status"] = $request->input("status", "payed");
        $data["realestate_id"] = isset($data["realestate"]) ? $data["realestate"] : null;
        // Celui dont la caisse sera debitee : sans cette trace, une
        // depense reglee ne peut plus etre imputee apres coup.
        $data["manager_id"] = $request->user()?->id;

        $charge = Charge::create($data);

        if ($request->hasFile("document")) {
            $charge->addMediaFromRequest("document")
                ->toMediaCollection("document");
        }

        $realestate = $charge->realestate;
        // Une charge en attente n'est pas encore une depense :
        // l'ecriture comptable est passee lors de la validation.
        if ($charge->status === "payed") {
            FinancialTransaction::record(
                'expense',
                $charge->amount,
                $charge->nom . ($realestate ? ' - ' . $realestate->title : ''),
                $charge->realestate_id,
                null,
                $charge->id
            );

            // Une charge reglee en especes sort de la caisse de l'agent.
            Caisses::automatique(function () use ($charge, $request) {
                Caisses::decaisser(
                    Caisses::pour($request->user()),
                    (float) $charge->amount,
                    MouvementCaisse::CHARGE,
                    [
                        "charge_id"  => $charge->id,
                        "manager_id" => $request->user()?->id,
                        "libelle"    => "Charge - " . ($charge->nom ?? "depense"),
                    ]
                );
            });
        }

        $charge->load('realestate');
        $this->notifierAdministration($charge, 'creation', $request->user());

        return $this->createdResponse(new ChargeResource($charge));
    }

    public function validate(Request $request, $id)
    {
        $charge = Charge::find($id);

        if (!$charge) {
            return $this->notFoundResponse();
        }

        $validator = Validator::make($request->all(), [
            "document" => ["nullable", "file", "mimes:pdf,jpg,jpeg,png",],
        ]);

        if ($validator->fails()) {
            return $this->validationErrorResponse($validator->errors());
        }

        // La validation vaut reglement : c'est la caisse de celui qui
        // valide qui est debitee, donc c'est lui que l'on consigne.
        $charge->update([
            "status"     => "payed",
            "manager_id" => $request->user()?->id,
        ]);

        $charge->load('realestate');
        FinancialTransaction::record(
            'expense',
            $charge->amount,
            $charge->nom . ($charge->realestate ? ' - ' . $charge->realestate->title : ''),
            $charge->realestate_id,
            null,
            $charge->id
        );

        // Une charge reglee en especes sort de la caisse de l'agent.
        Caisses::automatique(function () use ($charge, $request) {
            Caisses::decaisser(
                Caisses::pour($request->user()),
                (float) $charge->amount,
                MouvementCaisse::CHARGE,
                [
                    "charge_id"  => $charge->id,
                    "manager_id" => $request->user()?->id,
                    "libelle"    => "Charge - " . ($charge->nom ?? "depense"),
                ]
            );
        });

        if ($request->hasFile("document")) {
            $charge->addMediaFromRequest("document")
                ->toMediaCollection("document");
        }

        $charge->refresh()->load('realestate');
        $this->notifierAdministration($charge, 'validation', $request->user());

        return $this->successResponse(new ChargeResource($charge));
    }

    /**
     * Previent les administrateurs qu'une charge vient d'etre creee
     * ou validee. Si une piece jointe existe (recu, facture), elle est
     * envoyee avec le message.
     */
    private function notifierAdministration(Charge $charge, string $motif, $auteur = null): void
    {
        try {
            // Seuls les gestionnaires disposant de la permission
            // receive_charge_notifications sont prevenus.
            $telephones = Manager::permission('receive_charge_notifications')->whereNotIn("id", \App\Services\CataloguePermissions::retires("receive_charge_notifications"))
                ->when($auteur, fn($q) => $q->where('id', '!=', $auteur->id))
                ->get()
                ->map(fn($m) => str_replace('+', '', $m->phone ?? ''))
                ->filter()
                ->unique()
                ->values();

            $telephones = \App\Services\ReceptionWhatsapp::filtrer($telephones, $motif === "validation" ? "charge-traitee" : "charge-ajoutee");
            if ($telephones->isEmpty()) {
                return;
            }

            $bien    = $charge->realestate?->title ?? 'Bien non precise';
            $montant = number_format((float) $charge->amount, 2, ',', ' ');
            $par     = $auteur
                ? trim(($auteur->first_name ?? '') . ' ' . ($auteur->last_name ?? ''))
                : 'Non precise';
            $quand   = now()->format('d/m/Y H:i');
            $piece   = $charge->getFirstMediaUrl('document');

            if ($motif === 'validation') {
                $entete = '✅ Charge validée';
                $etat   = 'Payée';
            } else {
                $entete = '🧾 Nouvelle charge';
                $etat   = $charge->status === 'payed' ? 'Payée' : 'En attente';
            }

            $ligneDescription = $charge->description
                ? "\n📝 Détail      : {$charge->description}"
                : '';

            // Le texte vient du modele modifiable par l'administrateur.
            $message = ModelesMessages::rendu(
                $motif === 'validation' ? 'charge-validated' : 'charge-created',
                [
                    "{apartment_name}" => $bien,
                    "{amount}"         => $montant,
                    "{label}"          => $charge->nom,
                    "{status}"         => $etat,
                    "{agent_name}"     => $par,
                    "{time}"           => $quand,
                    "{note}"           => $charge->description ?: '',
                ]
            );

            $wa = new WasenderClient(config('services.whatsapp.wasender_key'));

            foreach ($telephones as $phone) {
                try {
                    if (!empty($piece)) {
                        // le justificatif accompagne le message
                        $estImage = str_starts_with(
                            $charge->getFirstMedia('document')?->mime_type ?? '',
                            'image/'
                        );
                        if ($estImage) {
                            $wa->sendImage($phone, $piece, $message);
                        } else {
                            $wa->sendDocument($phone, $piece, $message, 'justificatif.pdf');
                        }
                    } else {
                        $wa->sendText($phone, $message);
                    }
                } catch (Throwable $th) {
                    Log::error('WhatsApp charge notification failed: ' . $th->getMessage());
                }
            }
        } catch (Throwable $th) {
            Log::error('notifierAdministration failed: ' . $th->getMessage());
        }
    }


    public function update(Request $request, $id)
    {
        $charge = Charge::find($id);

        if (!$charge) {
            return $this->notFoundResponse();
        }

        $validator = Validator::make($request->all(), [
            "nom"         => ["sometimes", "string"],
            "description" => ["sometimes", "string"],
            "amount"      => ["sometimes", "numeric"],
            "type"        => ["sometimes", "in:fix,variable"],
            "status"      => ["sometimes", "in:pending,payed,cancelled"],
            "document"    => ["nullable", "file", "mimes:pdf,jpg,jpeg,png"],
            "realestate"  => ["nullable", "exists:realstates,id"]
        ]);

        if ($validator->fails()) {
            return $this->validationErrorResponse($validator->errors());
        }

        $data = $validator->validated();

        if (isset($data["realestate"])) {
            $data["realestate_id"] = $data["realestate"];
        }

        $charge->update($data);

        // Add new document if exists
        if ($request->hasFile("document")) {
            // Optional: delete old document
            $charge->clearMediaCollection("document");

            $charge->addMediaFromRequest("document")
                ->toMediaCollection("document");
        }

        return $this->successResponse(new ChargeResource($charge));
    }

    public function destroy(Request $request, $id)
    {
        $charge = Charge::find($id);

        if (!$charge) {
            return $this->notFoundResponse();
        }

        if ($charge->status === 'payed') {
            $charge->loadMissing('realestate');
            FinancialTransaction::record(
                'expense_reversal',
                $charge->amount,
                'Annulation charge - ' . ($charge->nom ?? 'Charge')
                    . ($charge->realestate ? ' - ' . $charge->realestate->title : ''),
                $charge->realestate_id,
                null,
                $charge->id
            );

            // Annuler une charge deja payee rend l'argent : il rentre
            // dans la caisse de celui qui la supprime.
            Caisses::automatique(function () use ($charge, $request) {
                Caisses::encaisser(
                    Caisses::pour($request->user()),
                    (float) $charge->amount,
                    MouvementCaisse::CHARGE_ANNULEE,
                    [
                        "charge_id"  => $charge->id,
                        "manager_id" => $request->user()?->id,
                        "libelle"    => "Annulation - " . ($charge->nom ?? "charge"),
                    ]
                );
            });
        }

        $charge->delete();

        return $this->successResponse(null);
    }





    /**
     * Annule une charge, sans l'effacer.
     *
     * Celui qui l'a creee peut l'annuler, comme un administrateur. La
     * charge reste dans l'historique, marquee annulee : on sait ce qui
     * a ete depense, puis repris. Si de l'argent revient, le montant
     * rendu entre dans la caisse de celui qui annule.
     */
    public function cancel(Request $request, $id)
    {
        $charge = Charge::with("realestate")->find($id);

        if (!$charge) {
            return $this->notFoundResponse();
        }

        $utilisateur = $request->user();
        $sienne = (int) $charge->manager_id === (int) $utilisateur?->id;

        if (!$sienne && !($utilisateur?->hasRole("admin") ?? false)) {
            return $this->jsonResponse(false,
                "Seul celui qui a saisi cette charge, ou un administrateur,"
                . " peut l'annuler.", 403, null);
        }

        if ($charge->status === "cancelled") {
            return $this->jsonResponse(false, "Cette charge est deja annulee.", 422, null);
        }

        $validator = Validator::make($request->all(), [
            // Ce que l'on recupere reellement : souvent tout, parfois
            // rien, parfois une partie.
            "montant" => ["nullable", "numeric", "min:0"],
            "motif"   => ["nullable", "string", "max:500"],
        ]);

        if ($validator->fails()) {
            return $this->validationErrorResponse($validator->errors());
        }

        $etaitPayee = $charge->status === "payed";
        $rembourse  = $request->filled("montant")
            ? round((float) $request->input("montant"), 2)
            : ($etaitPayee ? round((float) $charge->amount, 2) : 0.0);

        if ($rembourse > round((float) $charge->amount, 2) + 0.001) {
            return $this->jsonResponse(false,
                "Le montant rendu ne peut pas depasser celui de la charge.", 422, null);
        }

        DB::transaction(function () use ($charge, $request, $rembourse, $etaitPayee) {
            $charge->update([
                "status"            => "cancelled",
                "cancelled_at"      => now(),
                "cancelled_by"      => $request->user()?->id,
                "montant_rembourse" => $rembourse,
                "motif_annulation"  => $request->input("motif"),
            ]);

            if ($etaitPayee) {
                FinancialTransaction::record(
                    "expense_reversal",
                    $rembourse,
                    "Annulation charge - " . ($charge->nom ?? "Charge")
                        . ($charge->realestate ? " - " . $charge->realestate->title : ""),
                    $charge->realestate_id,
                    null,
                    $charge->id
                );
            }

            // L'argent rendu revient dans la caisse de celui qui annule.
            if ($rembourse > 0.005) {
                Caisses::automatique(function () use ($charge, $request, $rembourse) {
                    Caisses::encaisser(
                        Caisses::pour($request->user()),
                        $rembourse,
                        MouvementCaisse::CHARGE_ANNULEE,
                        [
                            "charge_id"  => $charge->id,
                            "manager_id" => $request->user()?->id,
                            "libelle"    => "Annulation - " . ($charge->nom ?? "charge"),
                        ]
                    );
                });
            }
        });

        return $this->successResponse(new ChargeResource($charge->fresh()));
    }

    /**
     * L'historique des charges annulees.
     *
     * Tous biens confondus, la plus recente en tete : de quoi retrouver
     * ce qui a ete repris, par qui, et quand.
     */
    public function annulees(Request $request)
    {
        $charges = Charge::with(["realestate", "manager"])
            ->where("status", "cancelled")
            ->orderByDesc("cancelled_at")
            ->orderByDesc("id")
            ->limit(200)
            ->get();

        $auteurs = \App\Models\Manager::whereIn("id",
            $charges->pluck("cancelled_by")->filter()->unique())->get()->keyBy("id");

        return $this->successResponse([
            "charges" => $charges->map(fn($ch) => [
                "id"          => $ch->id,
                "nom"         => $ch->nom,
                "description" => $ch->description,
                "montant"     => (float) $ch->amount,
                "rembourse"   => $ch->montant_rembourse === null ? null : (float) $ch->montant_rembourse,
                "bien"        => $ch->realestate->title ?? null,
                "creeePar"    => trim(($ch->manager->first_name ?? "") . " " . ($ch->manager->last_name ?? "")) ?: null,
                "annuleePar"  => trim((($auteurs[$ch->cancelled_by] ?? null)->first_name ?? "") . " "
                    . (($auteurs[$ch->cancelled_by] ?? null)->last_name ?? "")) ?: null,
                "annuleeLe"   => $ch->cancelled_at?->toISOString(),
                "creeeLe"     => $ch->created_at?->toISOString(),
                "motif"       => $ch->motif_annulation,
            ])->all(),
        ]);
    }
}
