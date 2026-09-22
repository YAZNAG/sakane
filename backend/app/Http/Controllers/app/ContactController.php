<?php

namespace App\Http\Controllers\app;

use App\Http\Controllers\Controller;
use App\Mail\ContactUs;
use App\Models\ContactMessage;
use App\Models\User;
use App\utils\JsonResponses;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Mail;
use Illuminate\Support\Facades\Validator;

class ContactController extends Controller
{
    use JsonResponses;
    public function contactUs(Request $request)
    {
        $validator = Validator::make($request->all(), [
            "email" => ["required", "email"],
            "subject" => ["required", "string"],
            "message" => ["required", "string"],
            "tel" => ["sometimes", "string"]
        ]);
        if ($validator->fails()) {
            return $this->jsonResponse(false, self::VALIDATION_ERROR, 422, $validator->errors());
        }
        $data = $validator->validated();
        ContactMessage::create($data);
        //send email
        $users = User::where("agence", "=", true)->first();
        Mail::to($users)->send(
            new ContactUs(
                $request->input("message"),
                $request->input("email"),
                $request->input("tel", "-"),
                $request->input("subject")
            )
        );
        return $this->jsonResponse(true, self::SUCCESS, 200, null);
    }
}
