<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

/**
 * Un mouvement d'argent dans une caisse.
 *
 * Immuable : une erreur se corrige par un mouvement inverse, jamais par
 * une modification. L'historique reste ainsi opposable.
 */
class MouvementCaisse extends Model
{
    protected $table = "mouvements_caisse";

    protected $fillable = [
        "caisse_id", "session_id", "sens", "montant", "motif", "libelle",
        "booking_id", "charge_id", "remise_id", "bail_id",
        "manager_id", "effectue_le", "contrepasse_id", "commentaire",
    ];

    protected $casts = [
        "montant"     => "decimal:2",
        "effectue_le" => "datetime",
    ];

    // Motifs d'entree.
    public const OUVERTURE   = "ouverture";
    public const RESERVATION = "encaissement_reservation";
    public const PROLONGATION = "encaissement_prolongation";
    public const CAUTION_RECUE = "caution_recue";
    public const REMISE_RECUE = "remise_recue";
    public const APPORT      = "apport";
    public const ENCAISSEMENT_SOLDE = "encaissement_solde";
    public const CHARGE_ANNULEE = "charge_annulee";
    public const LOYER       = "encaissement_loyer";

    // Motifs de sortie.
    public const CHARGE       = "charge";
    public const REMBOURSEMENT = "remboursement";
    public const CAUTION_RENDUE = "caution_rendue";
    public const REMISE_DECLAREE = "remise_declaree";
    public const VERSEMENT_PROPRIETAIRE = "versement_proprietaire";
    public const DEPOT_BANQUE = "depot_banque";
    public const DEPENSE_DIVERSE = "depense_diverse";
    public const VIDAGE = "vidage";
    public const EXCEDENT = "excedent_cloture";

    // Correction, dans un sens comme dans l'autre.
    public const CORRECTION = "correction";

    /** Libelles lisibles, pour l'application comme pour les exports. */
    public const LIBELLES = [
        self::OUVERTURE             => "Ouverture de caisse",
        self::RESERVATION           => "Encaissement r\u{E9}servation",
        self::PROLONGATION          => "Encaissement prolongation",
        self::CAUTION_RECUE         => "Caution re\u{E7}ue",
        self::REMISE_RECUE          => "Remise re\u{E7}ue",
        self::APPORT                => "Apport",
        self::ENCAISSEMENT_SOLDE    => "Encaissement du solde",
        self::CHARGE_ANNULEE        => "Charge annul\u{E9}e",
        self::LOYER                 => "Encaissement loyer",
        self::DEPENSE_DIVERSE       => "D\u{E9}pense diverse",
        self::VIDAGE                => "Vidage par l'administrateur",
        self::EXCEDENT              => "Exc\u{E9}dent constat\u{E9} \u{E0} la cl\u{F4}ture",
        self::CHARGE                => "Charge pay\u{E9}e",
        self::REMBOURSEMENT         => "Remboursement client",
        self::CAUTION_RENDUE        => "Caution rendue",
        self::REMISE_DECLAREE       => "Remise \u{E0} l'agence",
        self::VERSEMENT_PROPRIETAIRE => "Versement propri\u{E9}taire",
        self::DEPOT_BANQUE          => "D\u{E9}p\u{F4}t en banque",
        self::CORRECTION            => "Correction",
    ];

    /**
     * Motifs qu'un agent peut saisir lui-meme.
     *
     * L'apport seul : tout le reste vient de l'application. Une
     * reservation ne porte que son montant et son avance, il n'y a
     * donc pas de caution a enregistrer ici.
     */
    public const SAISIE_LIBRE = [
        self::ENCAISSEMENT_SOLDE, self::APPORT, self::DEPENSE_DIVERSE,
    ];

    public function caisse()
    {
        return $this->belongsTo(Caisse::class, "caisse_id");
    }

    public function libelleLisible(): string
    {
        return $this->libelle ?: (self::LIBELLES[$this->motif] ?? $this->motif);
    }
}
