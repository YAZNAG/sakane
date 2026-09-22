<?php

namespace App\Http\Controllers\dashboard;

use App\Http\Controllers\Controller;
use App\Http\Resources\DashboardResource\ReclamationResource;
use App\Models\Manager;
use App\Models\Reclamation;
use App\utils\JsonResponses;
use App\Services\ModelesMessages;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Validator;
use Throwable;
use WasenderApi\WasenderClient;

class ReclamationController extends Controller
{
    use JsonResponses;

    /**
     * List reclamations, optionally filtered by realestate.
     */
    public function index(Request $request)
    {
        $realestateId = $request->input('realestate');

        $reclamations = Reclamation::with(['realestate', 'manager'])
            ->when($realestateId, fn($q) => $q->where('realestate_id', $realestateId))
            ->orderBy('created_at', 'desc')
            ->get();

        return $this->successResponse(ReclamationResource::collection($reclamations));
    }

    /**
     * Create a new reclamation with optional note and multiple images.
     */
    public function store(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'note'       => ['nullable', 'string'],
            'realestate' => ['required', 'exists:realstates,id'],
            'images'     => ['required', 'array'],
            'images.*'   => ['image', 'mimes:png,jpg,jpeg'],
        ]);

        if ($validator->fails()) {
            return $this->validationErrorResponse($validator->errors());
        }

        DB::beginTransaction();
        try {
            $data = $validator->validated();
            $reclamation = Reclamation::create([
                'note'         => $data['note'] ?? null,
                'realestate_id'=> $data['realestate'],
                'manager_id'   => $request->user()?->id,
                'status'       => 'pending',
            ]);

            foreach ($request->file('images') as $image) {
                $reclamation->addMedia($image)->toMediaCollection('images');
            }

            DB::commit();

            $reclamation->load(['realestate', 'manager']);
            $this->notifyConcerned($reclamation);

            return $this->createdResponse(new ReclamationResource($reclamation));
        } catch (Throwable $th) {
            DB::rollBack();
            return $this->serverErrorResponse(null);
        }
    }

    /**
     * Notifie par WhatsApp tous les gestionnaires concernes par les reclamations,
     * c est-a-dire ceux disposant de la permission view_reclamations.
     * Le message precise le bien, la description, la date et le nom du signalant.
     * La premiere photo est jointe au message.
     */
    private function notifyConcerned(Reclamation $reclamation): void
    {
        try {
            $auteurId = $reclamation->manager_id;

            $destinataires = Manager::permission('view_reclamations')
                ->when($auteurId, fn($q) => $q->where('id', '!=', $auteurId))
                ->get()
                ->map(fn($m) => str_replace('+', '', $m->phone ?? ''))
                ->filter()
                ->unique()
                ->values();

            $realestateName = $reclamation->realestate?->title ?? "Bien #{$reclamation->realestate_id}";
            $note           = $reclamation->note ?? 'Aucune description fournie';
            $imageCount     = $reclamation->getMedia('images')->count();
            $createdAt      = now()->format('d/m/Y H:i');
            $signalant      = trim(($reclamation->manager?->first_name ?? '') . ' ' . ($reclamation->manager?->last_name ?? ''));
            $signalant      = $signalant !== '' ? $signalant : 'Non precise';

            $message = ModelesMessages::rendu("reclamation-created", [
                "{apartment_name}" => $realestateName,
                "{agent_name}"     => $signalant,
                "{note}"           => $note,
                "{time}"           => $createdAt,
            ]);

            $imageUrl = $reclamation->getFirstMediaUrl('images');
            $wa = new WasenderClient(config('services.whatsapp.wasender_key'));

            $destinataires = \App\Services\ReceptionWhatsapp::filtrer($destinataires, "reclamation-ajoutee");
            foreach ($destinataires as $phone) {
                try {
                    if (!empty($imageUrl)) {
                        $wa->sendImage($phone, $imageUrl, $message);
                    } else {
                        $wa->sendText($phone, $message);
                    }
                } catch (Throwable $th) {
                    Log::error('WhatsApp reclamation notification failed: ' . $th->getMessage());
                }
            }
        } catch (Throwable $th) {
            Log::error('ReclamationController@notifyConcerned failed: ' . $th->getMessage());
        }
    }

    /**
     * Mark a reclamation as resolved.
     */
    public function resolve(Request $request, $id)
    {
        $reclamation = Reclamation::find($id);

        if (!$reclamation) {
            return $this->notFoundResponse();
        }

        $reclamation->update(['status' => 'resolved']);
        $reclamation->load(['realestate', 'manager']);

        $this->notifierResolution($reclamation, $request->user());

        return $this->successResponse(new ReclamationResource($reclamation));
    }

    /**
     * Previent les gestionnaires concernes qu'une reclamation a ete traitee.
     * Le signalant est prevenu en priorite : c'est lui qui attend la reponse.
     */
    private function notifierResolution(Reclamation $reclamation, $auteur = null): void
    {
        try {
            $telephones = Manager::permission('view_reclamations')
                ->when($auteur, fn($q) => $q->where('id', '!=', $auteur->id))
                ->get()
                ->map(fn($m) => str_replace('+', '', $m->phone ?? ''))
                ->filter()
                ->unique()
                ->values();

            $telephones = \App\Services\ReceptionWhatsapp::filtrer($telephones, "reclamation-resolue");
            if ($telephones->isEmpty()) {
                return;
            }

            $bien      = $reclamation->realestate?->title ?? "Bien #{$reclamation->realestate_id}";
            $note      = $reclamation->note ?? 'Aucune description';
            $signalant = trim(($reclamation->manager?->first_name ?? '') . ' ' . ($reclamation->manager?->last_name ?? ''));
            $signalant = $signalant !== '' ? $signalant : 'Non precise';
            $par       = $auteur
                ? trim(($auteur->first_name ?? '') . ' ' . ($auteur->last_name ?? ''))
                : 'Non precise';
            $quand     = now()->format('d/m/Y H:i');

            $message = ModelesMessages::rendu("reclamation-resolved", [
                "{apartment_name}" => $realestateName ?? '',
                "{agent_name}"     => $par ?? '',
                "{note}"           => $note ?? '',
                "{time}"           => $quand ?? '',
            ]);

            $wa = new WasenderClient(config('services.whatsapp.wasender_key'));
            foreach ($telephones as $phone) {
                try {
                    $wa->sendText($phone, $message);
                } catch (Throwable $th) {
                    Log::error('WhatsApp resolution notification failed: ' . $th->getMessage());
                }
            }
        } catch (Throwable $th) {
            Log::error('notifierResolution failed: ' . $th->getMessage());
        }
    }
}
