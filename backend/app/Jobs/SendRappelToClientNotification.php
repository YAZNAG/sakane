<?php

namespace App\Jobs;

use App\Models\Booking;
use App\Models\WhatsappMessage;
use App\Services\ModelesMessages;
use Illuminate\Support\Facades\Log;
use WasenderApi\WasenderClient;

class SendRappelToClientNotification
{


    public function __invoke()
    {
        Log::info("cron job (" . static::class . ") executed successfully at- " . now());
        $phones = Booking::with('client')
            ->whereDate('checkout', today()->addDay())
            ->get()
            ->pluck('client.tel')
            ->filter()
            ->map(fn($phone) => str_replace('+', '', $phone))
            ->values();

        $whatsapMesage = WhatsappMessage::where("code", "client-leaving-reminder")->first();
        // Le texte provient du modele modifiable par l'administrateur ;
        // le modele d'origine prend le relais s'il a ete vide.
        $message = ModelesMessages::rendu('client-leaving-reminder');

        $wa = new WasenderClient(config("services.whatsapp.wasender_key"));
        foreach ($phones as $phone) {
            if (!empty($phone)) {
                $wa->sendText($phone, $message);
            }
        }
    }
}
