<?php

namespace App\Http\Controllers\app;

use App\Http\Controllers\Controller;
use App\Http\Resources\AppResources\UserResource;
use App\Mail\OtpMail;
use App\Models\User;
use App\Models\UserType;
use App\utils\JsonResponses;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Mail;
use Illuminate\Support\Facades\Validator;
use Illuminate\Auth\Events\Registered;
use Illuminate\Foundation\Auth\EmailVerificationRequest;
use Illuminate\Support\Facades\URL;

class AuthController extends Controller
{
    use JsonResponses;


    public function register(Request $request)
    {
        $validator = Validator::make(
            $request->all(),
            [
                "email" => ["required", "email", "unique:users"],
                "password" => ["required", "min:8"],
                "firstName" => ["required", "string"],
                "lastName" => ["required", "string"],
            ]
        );
        if ($validator->fails()) {
            return $this->jsonResponse(false, self::VALIDATION_ERROR, 422, $validator->errors());
        }

        $user = new User();
        $user->first_name = $request->input("firstName");
        $user->last_name = $request->input("lastName");
        $user->email = $request->input("email");
        $user->password = Hash::make($request->input("password"));
        $clientType = UserType::where("code", "=", "client")->first();
        $user->type_id = $clientType->id;
        $user->save();

        $user->sendEmailVerificationNotification();

        $token = $user->createToken("access-token");
        $response = new UserResource($user, $token->plainTextToken);
        return $this->jsonResponse(true, "User has been registered successfully", 201, $response);
    }

    public function login(Request $request)
    {
        // Le client se connecte avec son adresse ou avec son numero :
        // beaucoup n'ont qu'un telephone, l'adresse ayant ete generee
        // pour eux a la creation de leur fiche.
        $identifiant = trim((string) ($request->input("email") ?? $request->input("tel") ?? ""));

        $validator = Validator::make(
            array_merge($request->all(), ["identifiant" => $identifiant]),
            [
                "identifiant" => ["required", "string"],
                "password" => ["required"]
            ]
        );
        if ($validator->fails()) {
            return $this->jsonResponse(false, self::VALIDATION_ERROR, 422, $validator->errors());
        }

        $user = str_contains($identifiant, "@")
            ? User::where("email", "=", $identifiant)->first()
            : User::whereIn("tel", \App\Services\Telephone::variantes($identifiant))->first();

        if ($user == null || !Hash::check($request->input("password"), $user->password)) {
            return $this->jsonResponse(false, "invalid-credentials", 401, null);
        }

        $token = $user->createToken("access-token")->plainTextToken;
        $response = new UserResource($user, $token);
        return $this->jsonResponse(true, "Success Login", 200, $response);
    }


    public function me(Request $request)
    {
        $user = $request->user();
        $response = new UserResource($user, null);
        return $this->jsonResponse(true, self::SUCCESS, 200, $response);
    }


    public function forgetPassword(Request $request)
    {
        $validator = Validator::make(
            $request->all(),
            [
                "email" => ["required", "email", "exists:users,email"]
            ]
        );
        if ($validator->fails()) {
            return $this->jsonResponse(false, self::VALIDATION_ERROR, 422, $validator->errors());
        }
        $otp = mt_rand(10000, 99999);
        $expire_at = now()->addMinutes(30);
        $user = User::where("email", "=", $request->input("email"))->first();
        $user->otp = $otp;
        $user->otp_expire_at = $expire_at;
        $user->save();
        Mail::to($user)->send(new OtpMail($otp, $user->fullName()));
        return $this->jsonResponse(true, "OTP sent to your email.", 200, null);
    }
    public function checkOtp(Request $request)
    {
        $validator = Validator::make($request->all(), [
            "email" => ["required", "email", "exists:users,email"],
            "otp" => "required"
        ]);
        if ($validator->fails()) {
            return $this->jsonResponse(false, self::VALIDATION_ERROR, 422, $validator->errors());
        }
        $user = User::where("email", "=", $request->input("email"))->first();
        if ($user->otp != $request->input("otp") || now()->gt($user->otp_expire_at)) {
            return $this->jsonResponse(false, "Invalid or expired OTP.", 400, null);
        }
        $user->otp_expire_at = now()->addMinutes(-30);
        $user->save();
        $token = $user->createToken("access-token")->plainTextToken;
        return $this->jsonResponse(true, self::SUCCESS, 200, [
            "accessToken" => $token
        ]);
    }


    public function resetPassword(Request $request)
    {
        $validator = Validator::make($request->all(), [
            "password" => ["required", "min:8"]
        ]);
        if ($validator->fails()) {
            return $this->jsonResponse(false, self::VALIDATION_ERROR, 422, $validator->errors());
        }
        $user = $request->user();
        $user->password = Hash::make($request->input("password"));
        $user->otp_expire_at = now()->addMinutes(-30);
        $user->save();
        return $this->jsonResponse(true, self::SUCCESS, 200, null);
    }

    public function verifyEmail(Request $request, $id, $hash)
    {
        $user = User::find($id);
        if (!$user) {
            return $this->jsonResponse(false, 403, "in-valid", null);
        }
        $hashedEmail = sha1($user->getEmailForVerification());
        if (!hash_equals($hash, $hashedEmail)) {
            return $this->jsonResponse(false, "in-valid", 403, null);
        }
        if (!$user->hasVerifiedEmail()) {
            $user->markEmailAsVerified();
        }
        return $this->jsonResponse(true, self::SUCCESS, 200, null);
    }


    public function resendEmailVerification(Request $request)
    {
        $user = $request->user();
        if ($user->hasVerifiedEmail()) {
            return $this->jsonResponse(true, "Email-already-verified", 200, null);
        }
        $user->sendEmailVerificationNotification();
        return $this->jsonResponse(true, self::SUCCESS, 200, null);
    }



}
