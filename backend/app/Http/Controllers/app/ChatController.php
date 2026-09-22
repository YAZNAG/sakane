<?php

namespace App\Http\Controllers\app;

use App\Events\MessageSent;
use App\Http\Controllers\Controller;
use App\Http\Resources\AppResources\ConversationResource;
use App\Http\Resources\AppResources\MessageResource;
use App\Http\Resources\AppResources\ProfileResource;
use App\Http\Resources\PaginationResource;
use App\Models\Conversation;
use App\Models\Message;
use App\Models\User;
use App\utils\JsonResponses;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Validator;

class ChatController extends Controller
{

    use JsonResponses;

    public function sendMessage(Request $request, $receiverId)
    {
        $user = $request->user();
        $validator = Validator::make($request->all(), [
            "text" => ["required", "string"],
        ]);
        if ($validator->fails()) {
            return $this->jsonResponse(false, self::VALIDATION_ERROR, 422, null);
        }
        $receiver = User::where("id", "=", $receiverId)->first();
        if (!$receiver) {
            return $this->jsonResponse(false, self::NOT_FOUND, 404, null);
        }
        if ($user->id == $receiverId) {
            return $this->jsonResponse(false, self::VALIDATION_ERROR, 422, [
                "receiver" => ["le destinataire invalide"]
            ]);
        }
        //find conversation
        $conversation = Conversation::where(function ($query) use ($user, $receiverId) {
            $query->where("memberOne", "=", $user->id)
                ->where("memberTwo", "=", $receiverId);
        })->orWhere(function ($query) use ($user, $receiverId) {
            $query->where("memberOne", "=", $receiverId)
                ->where("memberTwo", "=", $user->id);
        })->first();
        //create conversation if not exists
        if (!$conversation) {
            $conversation = Conversation::create([
                "memberOne" => $user->id,
                "memberTwo" => $receiverId,
            ]);
        }
        $message = Message::create([
            "text" => $request->input("text"),
            "sender_id" => $user->id,
            "receiver_id" => $receiverId,
            "conversation_id" => $conversation->id
        ]);
        $conversation->last_message_id = $message->id;
        $conversation->never_seen_messages += 1;
        $conversation->save();

        $messageResource = new MessageResource($message);
        $messageEvent = new MessageSent($messageResource->withEvent(true), $receiverId);
        broadcast($messageEvent)->toOthers();

        //broadcast it
        return $this->jsonResponse(true, self::SUCCESS, 200, new MessageResource($message));
    }

    public function conversations(Request $request)
    {
        $user = $request->user();
        $conversations = Conversation::with(["lastMessage", "mOne", "mTwo"])
            ->where("memberOne", "=", $user->id)
            ->orWhere("memberTwo", "=", $user->id)
            ->orderBy(DB::raw("(select created_at from messages where messages.id=conversations.last_message_id)"), "desc")
            ->paginate($request->input("perPage", 20), ['*'], 'conversations', $request->input("page", 1));
        $response = new PaginationResource(ConversationResource::collection($conversations));
        return $this->jsonResponse(true, self::SUCCESS, 200, $response);
    }


    public function messages(Request $request, $with)
    {
        $user = $request->user();
        $withUser = User::find($with);
        if (!$withUser) {
            return $this->jsonResponse(false, self::NOT_FOUND, 404, null);
        }
        $messages = Message::whereHas("conversation", function ($query) use ($with, $user) {
            $query->where(function ($query) use ($with, $user) {
                $query->where("memberOne", "=", $user->id)->where("memberTwo", "=", $with);
            })->orWhere(function ($query) use ($with, $user) {
                $query->where("memberOne", "=", $with)->where("memberTwo", "=", $user->id);
            });
        })->orderBy("created_at", "desc")
            ->paginate($request->input("perPage", 40), ['*'], 'messages', $request->input("page", 1));

        $response = new PaginationResource(MessageResource::collection($messages));
        return  $this->jsonResponse(true, self::SUCCESS, 200, $response);
    }


    public function profile(Request $request, $id)
    {
        $user = User::find($id);
        if (!$user) {
            return $this->jsonResponse(false, self::NOT_FOUND, 404, null);
        }
        $response = new ProfileResource($user);
        return $this->jsonResponse(true, self::SUCCESS, 200, $response);
    }
}
