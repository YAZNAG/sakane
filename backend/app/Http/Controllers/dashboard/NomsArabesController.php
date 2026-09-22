<?php

namespace App\Http\Controllers\dashboard;

use App\Http\Controllers\Controller;
use App\Models\User;
use App\utils\JsonResponses;
use Illuminate\Http\Request;

/**
 * La memoire de l'agence pour l'ecriture arabe des noms.
 *
 * Pour un prenom ou un nom en lettres latines, l'ecriture arabe la plus
 * souvent enregistree parmi les clients de l'agence, et le nombre de
 * clients qui la portent. L'application la propose au scan de la CIN :
 * une correction faite une fois par un agent sert ensuite a tous.
 *
 * Seule une ecriture est renvoyee, jamais le client qui la porte.
 */
class NomsArabesController extends Controller
{
    use JsonResponses;

    public function show(Request $request)
    {
        return $this->successResponse([
            "prenom" => $this->memoire("first_name", "first_name_ar", $request->query("prenom")),
            "nom"    => $this->memoire("last_name", "last_name_ar", $request->query("nom")),
        ]);
    }

    private function memoire(string $colonne, string $colonneAr, $latin): ?array
    {
        $latin = trim(preg_replace('/\s+/u', ' ', (string) $latin));
        if ($latin === "" || mb_strlen($latin) > 60) {
            return null;
        }

        $ligne = User::query()
            ->whereRaw("UPPER(TRIM($colonne)) = ?", [mb_strtoupper($latin)])
            ->whereNotNull($colonneAr)
            ->where($colonneAr, "!=", "")
            ->selectRaw("$colonneAr as arabe, COUNT(*) as fois")
            ->groupBy($colonneAr)
            ->orderByDesc("fois")
            ->first();

        // Uniquement des lettres arabes et des espaces : une saisie
        // brouillee ne doit pas se propager.
        if (!$ligne || !preg_match('/^[\x{0621}-\x{064A}\s]+$/u', trim($ligne->arabe))) {
            return null;
        }

        return ["arabe" => trim($ligne->arabe), "fois" => (int) $ligne->fois];
    }
}
