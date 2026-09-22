<?php

namespace App\Http\Resources\DashboardResource;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class CampagneResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        $parStatut = $this->comptes ?? $this->destinataires()->selectRaw("statut, count(*) n")->groupBy("statut")->pluck("n", "statut");
        $total     = (int) collect($parStatut)->sum();
        $envoyes   = (int) ($parStatut["envoye"] ?? 0);
        $echecs    = (int) ($parStatut["echec"] ?? 0);
        $attente   = (int) ($parStatut["en_attente"] ?? 0);
        $ignores   = (int) ($parStatut["ignore"] ?? 0);
        $parMinute = max(1, (int) ($this->par_minute ?: 2));

        return [
            "id"              => $this->id,
            "titre"           => $this->titre,
            "message"         => $this->message,
            "lien"            => $this->lien,
            "image"           => $this->imageUrl(),
            "segment"         => $this->segment,
            "statut"          => $this->statut,
            "parMinute"       => $parMinute,
            "planifieeA"      => $this->planifiee_a?->toISOString(),
            "demarreeA"       => $this->demarree_a?->toISOString(),
            "termineeA"       => $this->terminee_a?->toISOString(),
            "pauseeA"         => $this->pausee_a?->toISOString(),
            "repriseA"        => $this->reprise_a?->toISOString(),
            "dernierEnvoiA"   => $this->dernier_envoi_a?->toISOString(),
            "nbDestinataires" => $total,
            "nbEnvoyes"       => $envoyes,
            "nbEchecs"        => $echecs,
            "nbRestants"      => $attente,
            "nbEnAttente"     => $attente,
            "nbIgnores"       => $ignores,
            "progression"     => $total > 0 ? round(($envoyes + $echecs + $ignores) / $total * 100, 1) : 0,
            "minutesRestantes" => (int) ceil($attente / $parMinute),
            "auteur"          => $this->auteur
                ? trim(($this->auteur->first_name ?? '') . ' ' . ($this->auteur->last_name ?? ''))
                : null,
            "creeLe"          => $this->created_at?->toISOString(),
            "destinataires"   => $this->whenLoaded("destinataires", function () {
                return $this->destinataires->values()->map(fn($d, $i) => [
                    "id"        => $d->id,
                    "ordre"     => $d->ordre ?? ($i + 1),
                    "clientId"  => $d->client_id,
                    "nom"       => $d->client
                        ? trim(($d->client->first_name ?? '') . ' ' . ($d->client->last_name ?? ''))
                        : null,
                    "telephone" => $d->telephone,
                    "statut"    => $d->statut,
                    "erreur"    => $d->erreur,
                    "envoyeA"   => $d->envoye_a?->toISOString(),
                ]);
            }),
        ];
    }
}
