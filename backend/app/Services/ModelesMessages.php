<?php

namespace App\Services;

use App\Models\WhatsappMessage;
use Illuminate\Support\Facades\Log;
use Throwable;

/**
 * Fabrique le texte d'un message a partir du modele enregistre.
 *
 * Le modele d'origine sert de filet : si le modele modifie a ete vide,
 * desactive ou supprime, le message part quand meme avec le texte fourni
 * a l'installation. Une notification manquante serait bien plus genante
 * qu'un texte non personnalise.
 */
class ModelesMessages
{
    public static function rendu(string $code, array $donnees = [], string $langue = 'fr'): string
    {
        $contenu = null;

        try {
            $modele = WhatsappMessage::where("code", $code)
                ->where("langue", $langue)
                ->where("actif", true)
                ->first();

            // Repli sur le francais si la langue demandee n'existe pas.
            if (!$modele && $langue !== 'fr') {
                $modele = WhatsappMessage::where("code", $code)
                    ->where("langue", 'fr')
                    ->where("actif", true)
                    ->first();
            }

            $contenu = $modele?->message;
        } catch (Throwable $th) {
            Log::error("Lecture du modele {$code} impossible : " . $th->getMessage());
        }

        if (!is_string($contenu) || trim($contenu) === '') {
            $contenu = CatalogueModeles::defaut($code);
        }

        if (!is_string($contenu) || trim($contenu) === '') {
            Log::error("Aucun modele disponible pour le code {$code}");
            return '';
        }

        return static::remplacer($contenu, $donnees);
    }

    /**
     * Image associee a un modele, ou null. L'appelant choisit alors
     * entre un envoi texte et un envoi image legende.
     */
    public static function image(string $code, string $langue = 'fr'): ?string
    {
        try {
            $modele = WhatsappMessage::where("code", $code)
                ->where("langue", $langue)
                ->where("actif", true)
                ->first()
                ?? WhatsappMessage::where("code", $code)
                    ->where("langue", 'fr')
                    ->where("actif", true)
                    ->first();

            return $modele?->imageUrl();
        } catch (Throwable $th) {
            Log::error("Lecture de l'image du modele {$code} impossible : "
                . $th->getMessage());
            return null;
        }
    }

    /**
     * Remplace les variables. Les cles peuvent etre fournies avec ou sans
     * accolades : "client_name" comme "{client_name}".
     */
    public static function remplacer(string $contenu, array $donnees): string
    {
        $table = [];
        foreach ($donnees as $cle => $valeur) {
            $nom = str_starts_with($cle, '{') ? $cle : '{' . $cle . '}';
            $table[$nom] = (string) ($valeur ?? '');
        }

        return strtr($contenu, $table);
    }

    /** Variables laissees sans valeur, utile pour prevenir le gerant. */
    public static function variablesNonRemplies(string $texte): array
    {
        preg_match_all('/\{[a-z_]+\}/i', $texte, $trouvees);
        return array_values(array_unique($trouvees[0] ?? []));
    }
}
