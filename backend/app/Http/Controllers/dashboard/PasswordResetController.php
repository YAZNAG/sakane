<?php

namespace App\Http\Controllers\dashboard;

use App\Http\Controllers\Controller;
use App\Models\Manager;
use App\utils\JsonResponses;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Validator;
use Throwable;
use WasenderApi\WasenderClient;

class PasswordResetController extends Controller
{
    use JsonResponses;

    /** Etape 1 : envoi d'un code a usage unique par WhatsApp. */
    public function forgetPassword(Request $request)
    {
        $validator = Validator::make($request->all(), [
            "email" => ["required", "email"],
        ]);
        if ($validator->fails()) {
            return $this->jsonResponse(false, self::VALIDATION_ERROR, 422, $validator->errors());
        }

        $manager = Manager::where("email", $request->input("email"))->first();

        // Reponse volontairement identique si le compte n'existe pas :
        // on evite de reveler quels e-mails sont enregistres.
        if (!$manager) {
            return $this->jsonResponse(true, "code-envoye", 200, null);
        }

        $phone = preg_replace('/\D/', '', $manager->phone ?? '');
        if (str_starts_with($phone, '0')) {
            $phone = '212' . substr($phone, 1);
        }
        if (empty($phone)) {
            return $this->jsonResponse(false, "aucun-telephone", 422, [
                "email" => ["Aucun numero de telephone n'est associe a ce compte. Contactez un administrateur."]
            ]);
        }

        $otp = (string) mt_rand(10000, 99999);
        $manager->otp = $otp;
        $manager->otp_expire_at = now()->addMinutes(15);
        $manager->save();

        $message = "Bonjour {$manager->first_name},\n\n"
            . "Votre code de reinitialisation est : {$otp}\n"
            . "Il est valable 15 minutes.\n\n"
            . "Si vous n'etes pas a l'origine de cette demande, ignorez ce message.";

        try {
            $wa = new WasenderClient(config("services.whatsapp.wasender_key"));
            $wa->sendText($phone, $message);
        } catch (Throwable $th) {
            Log::error("otp-manager-whatsapp: " . $th->getMessage());
            return $this->jsonResponse(false, "envoi-impossible", 500, null);
        }

        return $this->jsonResponse(true, "code-envoye", 200, [
            "phone" => substr($phone, 0, 5) . "****" . substr($phone, -2),
        ]);
    }

    /** Etape 2 : verification du code. */
    public function checkOtp(Request $request)
    {
        $validator = Validator::make($request->all(), [
            "email" => ["required", "email"],
            "otp"   => ["required"],
        ]);
        if ($validator->fails()) {
            return $this->jsonResponse(false, self::VALIDATION_ERROR, 422, $validator->errors());
        }

        $manager = Manager::where("email", $request->input("email"))->first();

        if (!$manager || $manager->otp === null
            || $manager->otp != $request->input("otp")
            || now()->gt($manager->otp_expire_at)) {
            return $this->jsonResponse(false, "code-invalide", 422, [
                "otp" => ["Code invalide ou expire."]
            ]);
        }

        return $this->jsonResponse(true, "code-valide", 200, null);
    }

    /** Etape 3 : definition du nouveau mot de passe. */
    public function resetPassword(Request $request)
    {
        $validator = Validator::make($request->all(), [
            "email"    => ["required", "email"],
            "otp"      => ["required"],
            "password" => ["required", "string", "min:6", "confirmed"],
        ]);
        if ($validator->fails()) {
            return $this->jsonResponse(false, self::VALIDATION_ERROR, 422, $validator->errors());
        }

        $manager = Manager::where("email", $request->input("email"))->first();

        if (!$manager || $manager->otp === null
            || $manager->otp != $request->input("otp")
            || now()->gt($manager->otp_expire_at)) {
            return $this->jsonResponse(false, "code-invalide", 422, [
                "otp" => ["Code invalide ou expire."]
            ]);
        }

        $manager->password = Hash::make($request->input("password"));
        $manager->otp = null;
        $manager->otp_expire_at = null;
        $manager->save();

        // Toutes les sessions ouvertes sont invalidees.
        $manager->tokens()->delete();

        return $this->jsonResponse(true, self::SUCCESS, 200, null);
    }
}
