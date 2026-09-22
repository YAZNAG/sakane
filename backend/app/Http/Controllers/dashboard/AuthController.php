<?php

namespace App\Http\Controllers\dashboard;

use App\Http\Controllers\Controller;
use App\Http\Resources\DashboardResource\ManagerResource;
use App\Models\Manager;
use App\utils\JsonResponses;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Validator;

class AuthController extends Controller
{
    use JsonResponses;
    public function login(Request $request)
    {
        $validator = Validator::make($request->all(), [
            "fcmToken" => ["nullable"],
            "password" => ["required"],
            "email" => ["required"]
        ]);
        if ($validator->fails()) {
            return $this->jsonResponse(false, self::VALIDATION_ERROR, 422, $validator->errors());
        }

        $manager = Manager::where("email", "=", $request->input("email"))->first();
        if ($manager == null || !Hash::check($request->input("password"), $manager->password)) {
            return $this->jsonResponse(false, "invalid-credential", "401", null);
        }


        //check if user has the same fcm token
        if ($request->has("fcmToken")) {
            $managerWithToken = Manager::where("fcm_token", "=", $request->input("fcmToken"))
                ->where("email", "!=", $request->input("email"))->first();
            if ($managerWithToken) {
                $managerWithToken->fcm_token = null;
                $managerWithToken->save();
            }
        }


        $token = $manager->createToken("manager-token")->plainTextToken;

        $manager->fcm_token = $request->input("fcmToken");
        $manager->save();
        $response = (new ManagerResource($manager))->withToken($token);
        return $this->jsonResponse(true, self::SUCCESS, 200, $response);
    }
    public function me(Request $request)
    {
        $manager = auth('managers')->user();
        $response = new ManagerResource($manager);
        return $this->successResponse($response);
    }
}
