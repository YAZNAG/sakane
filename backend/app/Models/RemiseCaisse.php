<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Spatie\MediaLibrary\HasMedia;
use Spatie\MediaLibrary\InteractsWithMedia;

/**
 * Une remise d'especes d'une caisse a une autre.
 *
 * Elle se fait en deux temps : l'agent declare, l'admin confirme.
 * Entre les deux, l'argent est en transit - il a quitte la caisse de
 * l'agent sans etre entre dans celle de l'agence. C'est ce qui permet
 * de dater un ecart au lieu de le voir apparaitre entre deux soldes
 * justes.
 */
class RemiseCaisse extends Model implements HasMedia
{
    use InteractsWithMedia;

    protected $table = "remises_caisse";

    protected $fillable = [
        "caisse_source_id", "caisse_destination_id",
        "montant_declare", "montant_recu", "statut",
        "declare_par", "confirme_par", "declare_le", "confirme_le",
        "commentaire",
        "commentaire_reception",
    ];

    protected $casts = [
        "montant_declare" => "decimal:2",
        "montant_recu"    => "decimal:2",
        "declare_le"      => "datetime",
        "confirme_le"     => "datetime",
    ];

    public const EN_ATTENTE = "en_attente";
    public const CONFIRMEE  = "confirmee";
    public const REFUSEE    = "refusee";

    /** Le commentaire de l expediteur, suivi de celui du receveur s il en a laisse un. */
    public function commentaireComplet(): ?string
    {
        $parts = array_filter([
            trim((string) $this->commentaire) ?: null,
            trim((string) ($this->commentaire_reception ?? "")) ? "R\u{E9}ception : " . trim($this->commentaire_reception) : null,
        ]);
        return $parts ? implode(" \u{B7} ", $parts) : null;
    }

    public function source()
    {
        return $this->belongsTo(Caisse::class, "caisse_source_id");
    }

    public function destination()
    {
        return $this->belongsTo(Caisse::class, "caisse_destination_id");
    }

    /**
     * La photo jointe au transfert : un recu, une enveloppe comptee.
     *
     * Le destinataire la voit avant de confirmer, et elle reste
     * attachee au transfert ensuite.
     */
    public function piece(): ?string
    {
        $url = $this->getFirstMediaUrl("piece");

        return $url === "" ? null : $url;
    }

    /** Difference entre ce qui a ete annonce et ce qui a ete compte. */
    public function ecart(): float
    {
        if ($this->montant_recu === null) {
            return 0.0;
        }

        return round((float) $this->montant_recu - (float) $this->montant_declare, 2);
    }
}
