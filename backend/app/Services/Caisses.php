<?php

namespace App\Services;

use App\Models\Caisse;
use App\Models\Manager;
use App\Models\MouvementCaisse;
use App\Models\SessionCaisse;
use Illuminate\Support\Facades\Log;

/**
 * Le point de passage unique pour tout mouvement de caisse.
 *
 * Les encaissements et les depenses passent par ici plutot que
 * d'ecrire directement en base : c'est ce qui garantit qu'un
 * mouvement automatique et un mouvement saisi a la main obeissent aux
 * memes regles.
 */
class Caisses
{
    /** La caisse d'un agent, creee a la volee si elle n'existe pas. */
    public static function pour(?Manager $manager): ?Caisse
    {
        if ($manager === null) {
            return null;
        }

        // Le gerant tient la caisse principale : c'est la sienne, et il
        // n'en a pas d'autre.
        $gerant = config("agence.caisse_principale_manager");
        if ($gerant && (int) $manager->id === (int) $gerant) {
            return static::agence();
        }

        return Caisse::firstOrCreate(
            ["manager_id" => $manager->id, "type" => "agent"],
            [
                "nom"   => trim(($manager->first_name ?? "") . " " . ($manager->last_name ?? ""))
                    ?: ("Agent #" . $manager->id),
                "actif" => true,
            ]
        );
    }

    /**
     * La caisse principale : celle ou convergent tous les transferts.
     *
     * Son nom et son detenteur viennent de la configuration, et sont
     * realignes ici : changer de gerant ne demande pas de toucher a la
     * base.
     */
    public static function agence(): Caisse
    {
        $caisse = Caisse::firstOrCreate(
            ["type" => "agence"],
            ["nom" => config("agence.caisse_principale_nom", "Caisse de l'agence"), "actif" => true]
        );

        $nom    = config("agence.caisse_principale_nom");
        $gerant = config("agence.caisse_principale_manager");

        $maj = [];
        if ($nom && $caisse->nom !== $nom) {
            $maj["nom"] = $nom;
        }
        if ($gerant && (int) $caisse->manager_id !== (int) $gerant) {
            $maj["manager_id"] = (int) $gerant;
        }
        if ($maj) {
            $caisse->update($maj);
        }

        return $caisse;
    }

    /**
     * La caisse Airbnb : les sejours payes a Airbnb y entrent. Sans
     * detenteur, elle n'apparait que pour l'administrateur.
     */
    public static function airbnb(): Caisse
    {
        return Caisse::firstOrCreate(["type" => "airbnb"], ["nom" => "Caisse Airbnb", "actif" => true]);
    }

    /**
     * Enregistre un mouvement.
     *
     * Un montant nul ou negatif ne produit rien : encaisser zero
     * dirham n'est pas un evenement, et une reservation sans avance ne
     * doit pas encombrer le journal.
     */
    public static function enregistrer(
        ?Caisse $caisse,
        string  $sens,
        float   $montant,
        string  $motif,
        array   $options = []
    ): ?MouvementCaisse {
        if ($caisse === null || $montant <= 0) {
            return null;
        }

        // Le solde ne peut jamais passer sous zero : une caisse ne
        // rend pas plus que ce qu'elle contient. On refuse plutot que
        // d'inscrire une dette silencieuse.
        if ($sens === "sortie" && round($montant, 2) > round($caisse->solde(), 2) + 0.001) {
            throw new SoldeInsuffisant(round($caisse->solde(), 2), round($montant, 2));
        }

        return MouvementCaisse::create([
            "caisse_id"   => $caisse->id,
            "session_id"  => static::sessionPourEcriture($caisse, $options["manager_id"] ?? null)->id,
            "sens"        => $sens,
            "montant"     => round($montant, 2),
            "motif"       => $motif,
            "libelle"     => $options["libelle"] ?? null,
            "booking_id"  => $options["booking_id"] ?? null,
            "charge_id"   => $options["charge_id"] ?? null,
            "remise_id"   => $options["remise_id"] ?? null,
            "bail_id"     => $options["bail_id"] ?? null,
            "manager_id"  => $options["manager_id"] ?? null,
            "effectue_le" => $options["effectue_le"] ?? now(),
            "commentaire" => $options["commentaire"] ?? null,
        ]);
    }

    /**
     * Ouvre une caisse, fond de depart compris - meme nul.
     *
     * Un mouvement de zero dirham est normalement ecarte : ce n'est pas
     * un evenement. L'ouverture fait exception, car elle marque le
     * debut du journal et non un encaissement. Sans elle, une caisse
     * ouverte a zero resterait fermee.
     */
    public static function ouvrir(
        ?Caisse $caisse,
        float   $montant,
        ?int    $parManager,
        bool    $reporte = false
    ): ?SessionCaisse {
        if ($caisse === null) {
            return null;
        }

        $montant = round(max(0, $montant), 2);

        $session = SessionCaisse::create([
            "caisse_id"         => $caisse->id,
            "numero"            => $caisse->sessions()->count() + 1,
            "montant_ouverture" => $montant,
            "reporte"           => $reporte,
            "ouverte_le"        => now(),
            "ouverte_par"       => $parManager,
        ]);

        // Le fond de depart est un mouvement comme un autre : il ouvre
        // le journal de cette caisse, meme a zero.
        MouvementCaisse::create([
            "caisse_id"   => $caisse->id,
            "session_id"  => $session->id,
            "sens"        => "entree",
            "montant"     => $montant,
            "motif"       => MouvementCaisse::OUVERTURE,
            "libelle"     => $reporte
                ? "Report de la caisse precedente"
                : "Ouverture de caisse",
            "manager_id"  => $parManager,
            "effectue_le" => now(),
        ]);

        return $session;
    }

    /**
     * La session ou ecrire, quitte a en ouvrir une.
     *
     * De l'argent peut arriver alors que la caisse vient d'etre
     * cloturee. Le refuser le ferait disparaitre : on ouvre donc une
     * nouvelle caisse en reportant le dernier montant compte, et
     * l'agent la trouvera ouverte a son retour.
     */
    public static function sessionPourEcriture(Caisse $caisse, ?int $parManager): SessionCaisse
    {
        $session = $caisse->sessionCourante();

        if ($session !== null) {
            return $session;
        }

        return static::ouvrir($caisse, $caisse->dernierMontantCompte(), $parManager, true);
    }

    public static function encaisser(?Caisse $c, float $m, string $motif, array $o = []): ?MouvementCaisse
    {
        return static::enregistrer($c, "entree", $m, $motif, $o);
    }

    public static function decaisser(?Caisse $c, float $m, string $motif, array $o = []): ?MouvementCaisse
    {
        return static::enregistrer($c, "sortie", $m, $motif, $o);
    }

    /**
     * Enregistre un mouvement declenche par l'application.
     *
     * Un echec ici ne doit jamais faire echouer l'operation qui l'a
     * provoque : une reservation reste valable meme si son ecriture de
     * caisse n'a pas pu se faire. L'incident est journalise pour etre
     * rattrape.
     */
    public static function automatique(callable $ecriture): void
    {
        try {
            $ecriture();
        } catch (\Throwable $e) {
            Log::warning("Mouvement de caisse non enregistre : " . $e->getMessage());
        }
    }

    /** Contre-passe un mouvement : l'inverse, sans effacer l'original. */
    public static function contrepasser(MouvementCaisse $mouvement, ?int $parManager, ?string $motif = null): MouvementCaisse
    {
        $inverse = $mouvement->sens === "entree" ? "sortie" : "entree";

        // Une contre-passation constate une correction : elle ne se
        // heurte pas a la regle du solde.
        return MouvementCaisse::create([
            "caisse_id"      => $mouvement->caisse_id,
            "sens"           => $inverse,
            "montant"        => $mouvement->montant,
            "motif"          => MouvementCaisse::CORRECTION,
            "libelle"        => "Annulation : " . $mouvement->libelleLisible(),
            "booking_id"     => $mouvement->booking_id,
            "charge_id"      => $mouvement->charge_id,
            "bail_id"        => $mouvement->bail_id,
            "manager_id"     => $parManager,
            "effectue_le"    => now(),
            "contrepasse_id" => $mouvement->id,
            "commentaire"    => $motif,
        ]);
    }

    /**
     * Enregistre sans verifier le solde.
     *
     * Reserve aux ecritures qui constatent un fait plutot qu'elles ne
     * decident d'un mouvement : une contre-passation, par exemple.
     */
    public static function enregistrerSansControle(
        ?Caisse $caisse,
        string  $sens,
        float   $montant,
        string  $motif,
        array   $options = []
    ): ?MouvementCaisse {
        if ($caisse === null || $montant <= 0) {
            return null;
        }

        return MouvementCaisse::create(array_merge([
            "caisse_id"   => $caisse->id,
            "session_id"  => static::sessionPourEcriture($caisse, $options["manager_id"] ?? null)->id,
            "sens"        => $sens,
            "montant"     => round($montant, 2),
            "motif"       => $motif,
            "effectue_le" => now(),
        ], array_intersect_key($options, array_flip([
            "libelle", "booking_id", "charge_id", "remise_id", "bail_id",
            "manager_id", "effectue_le", "commentaire", "contrepasse_id",
        ]))));
    }
}

/**
 * Une sortie qui ferait passer la caisse sous zero.
 *
 * Le message est destine a l'agent : il doit comprendre ce qui manque,
 * pas lire une trace technique.
 */
class SoldeInsuffisant extends \RuntimeException
{
    public function __construct(public readonly float $solde, public readonly float $demande)
    {
        parent::__construct(sprintf(
            "Solde insuffisant : la caisse contient %s MAD et il en faudrait %s.",
            number_format($solde, 2, ",", " "),
            number_format($demande, 2, ",", " ")
        ));
    }
}
