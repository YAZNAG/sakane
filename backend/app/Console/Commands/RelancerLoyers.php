<?php

namespace App\Console\Commands;

use App\Models\Loyer;
use App\Services\Baux;
use App\Services\ModelesMessages;
use App\Services\Telephone;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;
use Throwable;

/**
 * Relances des loyers : trois jours avant l'echeance, le jour meme,
 * puis cinq jours apres si le loyer n'est toujours pas regle.
 * Chaque relance ne part qu'une fois par echeance.
 */
class RelancerLoyers extends Command
{
    protected $signature = 'loyers:relances {--simuler : affiche ce qui partirait, sans rien envoyer ni noter}';

    protected $description = 'Envoie les relances de loyer par WhatsApp';

    private const TYPES = [
        "avant"  => [3, "loyer-rappel-avant"],
        "jour"   => [0, "loyer-rappel-jour"],
        "retard" => [-5, "loyer-retard"],
    ];

    public function handle(): int
    {
        $simuler = (bool) $this->option("simuler");
        $total = 0;

        foreach (self::TYPES as $type => [$jours, $modele]) {
            $date = today()->addDays($jours)->toDateString();
            $loyers = Loyer::with("bail.locataire", "bail.bien.city")
                ->whereDate("echeance", $date)
                ->whereColumn("paye", "<", "montant")
                ->whereHas("bail", fn($b) => $b->where("statut", "actif")->where("relances_actives", true))
                ->get();

            foreach ($loyers as $loyer) {
                if (DB::table("loyer_relances")->where("loyer_id", $loyer->id)->where("type", $type)->exists()) {
                    continue;
                }
                $bail = $loyer->bail;
                $numero = Telephone::international($bail->locataire->tel ?? "");
                $texte = ModelesMessages::rendu($modele, Baux::variables($bail, $loyer));

                if ($simuler) {
                    $this->line("[$type] " . Baux::nom($bail->locataire) . " ($numero) - " . $loyer->libelle() . " : " . str_replace("\n", " | ", mb_substr($texte, 0, 90)));
                    $total++;
                    continue;
                }

                $statut = "envoye";
                $erreur = null;
                if ($numero === "") {
                    $statut = "ignore";
                    $erreur = "Numéro du locataire invalide.";
                } elseif (trim($texte) === "") {
                    $statut = "ignore";
                    $erreur = "Modèle de message vide.";
                } else {
                    try {
                        Baux::envoyerTexte($numero, $texte);
                    } catch (Throwable $th) {
                        $statut = "echec";
                        $erreur = mb_substr($th->getMessage(), 0, 500);
                    }
                }

                DB::table("loyer_relances")->insert([
                    "loyer_id" => $loyer->id, "type" => $type, "telephone" => $numero,
                    "statut" => $statut, "erreur" => $erreur,
                    "created_at" => now(), "updated_at" => now(),
                ]);
                $total++;
                // WhatsApp n'aime pas les rafales.
                if ($statut === "envoye") {
                    sleep(3);
                }
            }
        }

        $this->info("Relances de loyer traitées : $total");
        return self::SUCCESS;
    }
}
