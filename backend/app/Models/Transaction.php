<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Spatie\MediaLibrary\HasMedia;
use Spatie\MediaLibrary\InteractsWithMedia;

class Transaction extends Model implements HasMedia
{
    use InteractsWithMedia;
    protected function casts(): array
    {
        return [
            "details" => "array"
        ];
    }
    protected $fillable = [
        "amount",
        "details",
        "user_id",
        "operation_id",
        "booking_id",
        "is_commission"
    ];

    public function operation()
    {
        return $this->belongsTo(OperationType::class, "operation_id");
    }
    public function booking()
    {
        return $this->belongsTo(Booking::class, "booking_id");
    }
    public function user()
    {
        return $this->belongsTo(User::class, "user_id");
    }
    public function registerMediaCollections(): void
    {
        $this->addMediaCollection("document")->singleFile();
    }
}
