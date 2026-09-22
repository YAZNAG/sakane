<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Spatie\MediaLibrary\HasMedia;
use Spatie\MediaLibrary\InteractsWithMedia;
use Spatie\MediaLibrary\MediaCollections\Models\Media;

class Campagne extends Model implements HasMedia
{
    use InteractsWithMedia;

    protected $table = "campagnes";

    protected $fillable = [
        "titre",
        "message",
        "lien",
        "segment",
        "statut",
        "planifiee_a",
        "demarree_a",
        "terminee_a",
        "nb_destinataires",
        "nb_envoyes",
        "nb_echecs",
        "par_minute",
        "pausee_a",
        "reprise_a",
        "dernier_envoi_a",
        "created_by",
    ];

    protected $casts = [
        "segment"     => "array",
        "planifiee_a" => "datetime",
        "demarree_a"  => "datetime",
        "terminee_a"  => "datetime",
        "pausee_a"    => "datetime",
        "reprise_a"   => "datetime",
        "dernier_envoi_a" => "datetime",
    ];

    /** Compteurs par statut, precharges par la liste des campagnes. */
    public $comptes = null;

    public function destinataires()
    {
        return $this->hasMany(CampagneDestinataire::class, "campagne_id");
    }

    public function auteur()
    {
        return $this->belongsTo(Manager::class, "created_by");
    }

    public function registerMediaCollections(): void
    {
        $this->addMediaCollection("image")->singleFile();
    }

    /** Adresse publique de l'image, indispensable a l'envoi WhatsApp. */
    public function imageUrl(): ?string
    {
        $url = $this->getFirstMediaUrl("image");
        return $url !== "" ? $url : null;
    }

    /** Une campagne deja lancee ne peut plus etre relancee en entier. */
    public function estModifiable(): bool
    {
        return in_array($this->statut, ["brouillon", "programmee"]);
    }

    /**
     * Remplace les variables dynamiques par les donnees du client.
     * Les variables inconnues sont laissees telles quelles pour que
     * l'erreur soit visible a la relecture plutot que silencieuse.
     */
    public static function appliquerVariables(string $message, ?User $client, ?string $lien = null): string
    {
        $prenom = trim((string) ($client->first_name ?? ""));
        $nom    = trim((string) ($client->last_name ?? ""));
        $entier = trim($prenom . " " . $nom);

        $texte = strtr($message, [
            "{client_name}"       => $entier !== "" ? $entier : "cher client",
            "{client_first_name}" => $prenom !== "" ? $prenom : "cher client",
            "{client_last_name}"  => $nom,
        ]);

        if ($lien) {
            $texte .= "\n\n" . $lien;
        }

        return $texte;
    }
}
