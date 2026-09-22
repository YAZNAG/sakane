<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class ClientReview extends Model
{
    protected $fillable = [
        'rate',
        'comment',
        'cleanliness',
        'accuracy',
        'communication',
        'location',
        'client_id'
    ];

    public function client()
    {
        return $this->belongsTo(User::class, 'client_id');
    }
    public function booking(){
        return $this->hasOne(Booking::class);
    }

}
