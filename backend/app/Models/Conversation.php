<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Conversation extends Model
{
    protected $fillable = [
        "memberOne",
        "memberTwo",
        "never_seen_messages",
        "last_message_id"
    ];


    public function lastMessage()
    {
        return $this->belongsTo(Message::class, "last_message_id");
    }

    public function mOne()
    {
        return $this->belongsTo(User::class, "memberOne");
    }
    public function mTwo()
    {
        return $this->belongsTo(User::class, "memberTwo");
    }
}
