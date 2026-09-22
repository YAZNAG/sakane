<?php

namespace App\Http\Controllers\app;

use App\Http\Controllers\Controller;
use App\Http\Resources\AppResources\UserResource;
use App\Models\Adress;
use App\Models\UserType;
use App\utils\JsonResponses;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Validator;



class BecomeHostController extends Controller
{
    use JsonResponses;

    public function becomeHost(Request $request)
    {
        $currentUser = $request->user();
        $currentType = UserType::find($currentUser->type_id);


        if ($currentType->code == "host") {
            return $this->jsonResponse(false, "already-host", 422, null);
        }
        $validator = Validator::make($request->all(), [
            "tel" => ["required", "regex:/^\+\d{10,}$/"],
            "city" => ["required", "exists:cities,id"],
            "address" => ["required", "min:4", "max:200"],
            "rib" => ["sometimes", "string", "size:24"],
            "identityFront" => ["required", "image", 'mimes:jpeg,png,jpg,gif', 'max:2048'],
            "identityBack" => ["required", "image", 'mimes:jpeg,png,jpg,gif', 'max:2048'],
            "profile" => ["required", "image", 'mimes:jpeg,png,jpg', 'max:2048'],

        ]);
        if ($validator->fails()) {
            return $this->jsonResponse(false, self::VALIDATION_ERROR, 422, $validator->errors());
        }



        $hostType = UserType::where("code", "=", "host")->first();
        $currentUser->type_id = $hostType->id;
        $currentUser->address = $request->input("address");
        $currentUser->tel = $request->input("tel");
        $currentUser->city_id = $request->input("city");
        $currentUser->rib = $request->input("rib");
        $currentUser->save();

        if ($request->hasFile("profile")) {
            $ext = $request->file("profile")->getClientOriginalExtension();
            $currentUser->addMedia($request->file("profile"))->usingFileName("profile." . $ext)->toMediaCollection("profile_photo");
        }
        if ($request->hasFile("identityFront")) {
            $ext = $request->file("identityFront")->getClientOriginalExtension();
            $currentUser->addMedia($request->file("identityFront"))->usingFileName("identity-front." . $ext)->toMediaCollection("identity_front");
        }
        if ($request->hasFile("identityBack")) {
            $ext = $request->file("identityBack")->getClientOriginalExtension();
            $currentUser->addMedia($request->file("identityBack"))->usingFileName("identity-back." . $ext)->toMediaCollection("identity_back");
        }
        $response = new UserResource($currentUser, null);
        return $this->jsonResponse(true, self::SUCCESS, 200, $response);
    }
}
