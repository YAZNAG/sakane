<?php

namespace App\Http\Resources\DashboardResource;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class ChargeResource extends JsonResource
{
    /**
     * Transform the resource into an array.
     *
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        return [
            "id" => $this->id,
            "nom" => $this->nom,
            "description" => $this->description,
            "type" => $this->type,
            "status" => $this->status,
            "amount" => $this->amount,
            "createdAt" => $this->created_at,
            // Qui a saisi la charge : sans ce nom, une depense
            // contestee n'a personne a qui se rapporter.
            "creePar" => $this->manager
                ? trim(($this->manager->first_name ?? "") . " " . ($this->manager->last_name ?? ""))
                : null,
            "annuleeLe"  => $this->cancelled_at?->toISOString(),
            "rembourse"  => $this->montant_rembourse === null ? null : (float) $this->montant_rembourse,
            "motifAnnulation" => $this->motif_annulation,
            "realestate" => new RealestateResource($this->realestate),
            // piece jointe : recu, facture ou photo du justificatif
            "document" => $this->getFirstMedia('document') ? [
                "id"        => $this->getFirstMedia('document')->id,
                "url"       => $this->getFirstMediaUrl('document'),
                "name"      => $this->getFirstMedia('document')->file_name,
                "mimeType"  => $this->getFirstMedia('document')->mime_type,
                "size"      => $this->getFirstMedia('document')->size,
                "isImage"   => str_starts_with($this->getFirstMedia('document')->mime_type ?? '', 'image/'),
                "isPdf"     => ($this->getFirstMedia('document')->mime_type ?? '') === 'application/pdf',
            ] : null,
        ];
    }
}
