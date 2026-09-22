<?php

namespace App\Console\Commands;

use App\Models\WhatsappMessage;
use App\Services\CatalogueModeles;
use Illuminate\Console\Command;

/**
 * Met la base en accord avec le catalogue fourni.
 *
 * Les textes personnalises par le gerant ne sont jamais ecrases :
 * seule la valeur d'origine ("defaut") est rafraichie, ainsi que les
 * libelles et la liste des variables.
 */
class InstallerModelesMessages extends Command
{
    protected $signature = 'messages:installer {--reinitialiser : remet aussi les textes a leur valeur d\'origine}';

    protected $description = "Installe ou met a jour les modeles de messages";

    public function handle(): int
    {
        $reinitialiser = (bool) $this->option('reinitialiser');
        $crees = 0;
        $majs  = 0;

        foreach (CatalogueModeles::tous() as $modele) {
            $existant = WhatsappMessage::where("code", $modele["code"])
                ->where("langue", "fr")
                ->first();

            if (!$existant) {
                WhatsappMessage::create([
                    "code"         => $modele["code"],
                    "message_name" => $modele["message_name"],
                    "message"      => $modele["defaut"],
                    "defaut"       => $modele["defaut"],
                    "description"  => $modele["description"],
                    "categorie"    => $modele["categorie"],
                    "variables"    => $modele["variables"],
                    "langue"       => "fr",
                    "actif"        => true,
                ]);
                $crees++;
                continue;
            }

            $existant->message_name = $modele["message_name"];
            $existant->description  = $modele["description"];
            $existant->categorie    = $modele["categorie"];
            $existant->variables    = $modele["variables"];
            $existant->defaut       = $modele["defaut"];
            if ($reinitialiser) {
                $existant->message = $modele["defaut"];
            }
            $existant->save();
            $majs++;
        }

        $this->info("Modeles : {$crees} cree(s), {$majs} mis a jour.");
        return self::SUCCESS;
    }
}
