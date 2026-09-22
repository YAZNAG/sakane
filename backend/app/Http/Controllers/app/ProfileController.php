<?php

namespace App\Http\Controllers\app;

use App\Http\Controllers\Controller;
use App\Http\Resources\AppResources\ClientProfileResource;
use App\Http\Resources\AppResources\HostProfileResource;
use App\Http\Resources\AppResources\UserResource;
use App\Models\User;
use App\utils\JsonResponses;
use Illuminate\Auth\Events\Validated;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Validator;

class ProfileController extends Controller
{
    use JsonResponses;
    public function clientProfile(Request $request, $id)
    {
        $client = User::find($id);
        if (!$client) {
            return $this->jsonResponse(false, self::NOT_FOUND, 404, null);
        }
        $response = new ClientProfileResource($client);
        return $this->jsonResponse(true, self::SUCCESS, 200, $response);
    }

    public function hostProfile(Request $request, $id)
    {
        $host = User::where("id", "=", $id)
            ->whereHas("type", function ($query) {
                $query->where("code", "=", "host");
            })->first();
        if (!$host) {
            return $this->jsonResponse(false, self::NOT_FOUND, 404, null);
        }
        $response = new HostProfileResource($host);
        return $this->jsonResponse(true, self::SUCCESS, 200, $response);
    }


    public function updateProfile(Request $request)
    {
        $user = $request->user();
        $validator = Validator::make($request->all(), [
            "city" => ["sometimes", "exists:cities,id"],
            "address" => ["sometimes", "string", "min:4", "max:200"],
            "firstName" => ["sometimes", "string"],
            "lastName" => ["sometimes", "string"],
            "rib" => ["sometimes", "string", "size:24"],
            "identityFront" => ["sometimes", "image", 'mimes:jpeg,png,jpg', 'max:2048'],
            "identityBack" => ["sometimes", "image", 'mimes:jpeg,png,jpg', 'max:2048'],
            "profile" => ["sometimes", "image", 'mimes:jpeg,png,jpg', 'max:2048'],
            "tel" => ["sometimes", "regex:/^\d{10,}$/"],
            "oldPassword" => ["sometimes", "string"],
            "newPassword" => ["sometimes", "string", "min:8"]
        ]);
        if ($validator->fails()) {
            return $this->jsonResponse(false, self::VALIDATION_ERROR, 422, $validator->errors());
        }
        $data = $validator->validated();
        if (isset($data["city"])) {
            $data["city_id"] = $data["city"];
        }
        if (isset($data["firstName"])) {
            $data["first_name"] = $data["firstName"];
        }
        if (isset($data["lastName"])) {
            $data["last_name"] = $data["lastName"];
        }
        $user->update($data);
        if ($request->has("identityFront") && $user->identity_status != "valid") {
            $ext = $request->file("identityFront")->getClientOriginalExtension();
            $user->addMedia($request->file("identityFront"))
                ->usingFileName("identity-front." . $ext)
                ->toMediaCollection("identity_front");
        }
        if ($request->has("identityBack") && $user->identity_status != "valid") {
            $ext = $request->file("identityBack")->getClientOriginalExtension();
            $user->addMedia($request->file("identityBack"))
                ->usingFileName("identity-back." . $ext)
                ->toMediaCollection("identity_back");
        }
        if ($request->has("profile")) {
            $ext = $request->file("profile")->getClientOriginalExtension();
            $user->addMedia($request->file("profile"))
                ->usingFileName("profile." . $ext)
                ->toMediaCollection("profile_photo");
        }

        if (isset($data["newPassword"])) {
            if (!isset($data["oldPassword"])) {
                return $this->jsonResponse(false, "old-password-required", 422, null);
            }
            if (!Hash::check($data["oldPassword"], $user->password)) {
                return $this->jsonResponse(false, "incorrect-password", 422, null);
            }
            $user->password = Hash::make($data["newPassword"]);
            $user->save();
        }
        $user->unsetRelation("media");
        $user->loadMedia("identity_front");
        $user->loadMedia("identity_back");
        $user->loadMedia("profile_photo");
        $response = new UserResource($user, null);
        return $this->jsonResponse(true, self::SUCCESS, 200, $response);
    }
}
