<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Spatie\MediaLibrary\HasMedia;
use Spatie\MediaLibrary\InteractsWithMedia;

class WhatsappMessage extends Model implements HasMedia
{
    use InteractsWithMedia;

    protected $fillable = [
        "message_name",
        "message",
        "code",
        "defaut",
        "description",
        "categorie",
        "variables",
        "langue",
        "actif",
        "updated_by",
    ];

    protected $casts = [
        "variables" => "array",
        "actif"     => "boolean",
    ];

    public function registerMediaCollections(): void
    {
        // Une seule image par modele : elle accompagne le texte envoye.
        $this->addMediaCollection("image")->singleFile();
    }

    /** Adresse publique de l'image, indispensable a l'envoi WhatsApp. */
    public function imageUrl(): ?string
    {
        $url = $this->getFirstMediaUrl("image");
        return $url !== "" ? $url : null;
    }

    public function historique()
    {
        return $this->hasMany(WhatsappMessageHistorique::class, "whatsapp_message_id")
            ->orderByDesc("created_at");
    }

    /** Le modele a-t-il ete modifie par rapport a celui d'origine ? */
    public function estPersonnalise(): bool
    {
        return $this->defaut !== null && trim((string) $this->message) !== trim((string) $this->defaut);
    }
}
