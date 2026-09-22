<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Facades\Storage;

/** Un contrat signe avec un proprietaire, pour l'un de ses appartements. */
class ContratProprietaire extends Model
{
    protected $table = "contrats_proprietaires";

    protected $fillable = [
        "owner_id", "realestate_id", "titre", "date_debut", "date_fin",
        "fichier", "nom_fichier", "type_mime", "taille", "created_by",
    ];

    protected $casts = ["date_debut" => "date", "date_fin" => "date"];

    public function bien()
    {
        return $this->belongsTo(Realstate::class, "realestate_id");
    }

    public function auteur()
    {
        return $this->belongsTo(Manager::class, "created_by");
    }

    public function versTableau(): array
    {
        return [
            "id"            => $this->id,
            "proprietaireId" => $this->owner_id,
            "bienId"        => $this->realestate_id,
            "bien"          => $this->bien?->title,
            "titre"         => $this->titre,
            "dateDebut"     => $this->date_debut?->toDateString(),
            "dateFin"       => $this->date_fin?->toDateString(),
            "url"           => Storage::disk("public")->url($this->fichier),
            "nomFichier"    => $this->nom_fichier,
            "typeMime"      => $this->type_mime,
            "taille"        => $this->taille,
            "creeLe"        => $this->created_at?->toISOString(),
            "par"           => $this->auteur
                ? trim(($this->auteur->first_name ?? "") . " " . ($this->auteur->last_name ?? ""))
                : null,
        ];
    }
}
