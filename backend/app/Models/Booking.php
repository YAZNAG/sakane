<?php

namespace App\Models;

use Carbon\Carbon;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\SoftDeletes;
use Spatie\MediaLibrary\HasMedia;
use Spatie\MediaLibrary\InteractsWithMedia;

class Booking extends Model implements HasMedia
{
    use InteractsWithMedia,SoftDeletes;
    protected $fillable = [
        "heure_arrivee",
        "heure_depart",
        "client_id",
        "realestate_id",
        "status_id",
        "checkin",
        "checkout",
        "nb_days",
        "nb_guest",
        "amount",
        "payment_intent",
        "payment_method",
        "is_cron_pass",
        "night_price",
        "type_id",
        "created_by",
        "avance",
        "caution",
        "remarques",
        "type_guest"
    ];
    protected $appends = ['is_ratable'];

    public function getIsRatableAttribute()
    {
        return (optional($this->status)->code == "completed");
    }


    public function registerMediaCollections(): void
    {
        $this->addMediaCollection('signature')->singleFile();
        $this->addMediaCollection('contract-private')->singleFile();
        $this->addMediaCollection('contract-public')->singleFile();
    }


    public function status()
    {
        return $this->belongsTo(BookingStatus::class, "status_id");
    }

    public function realestate()
    {
        return $this->belongsTo(Realstate::class, "realestate_id");
    }
    public function client()
    {
        return $this->belongsTo(User::class, "client_id");
    }
    /** Le gestionnaire qui a supprime la reservation. */
    public function supprimeePar()
    {
        return $this->belongsTo(Manager::class, "supprimee_par");
    }

    public function manager()
    {
        return $this->belongsTo(Manager::class, "created_by");
    }

    // public function clientReviews()
    // {
    //     return $this->belongsTo(ClientReview::class, "client_review_id");
    // }
    public function hostReview()
    {
        return $this->belongsTo(HostReview::class, "host_review_id");
    }

    public function paymentMethod()
    {
        return $this->belongsTo(PaymentMethod::class, "payment_method");
    }


    public function clientReview()
    {
        return $this->belongsTo(ClientReview::class, "client_review_id");
    }
    public function type()
    {
        return $this->belongsTo(TypeBooking::class, "type_id");
    }
}
