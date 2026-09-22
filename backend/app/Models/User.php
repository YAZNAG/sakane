<?php

namespace App\Models;

use Illuminate\Contracts\Auth\MustVerifyEmail;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\SoftDeletes;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use Laravel\Sanctum\HasApiTokens;
use Spatie\MediaLibrary\HasMedia;
use Spatie\MediaLibrary\InteractsWithMedia;

class User extends Authenticatable implements HasMedia, MustVerifyEmail
{
    /** @use HasFactory<\Database\Factories\UserFactory> */
    use InteractsWithMedia, HasApiTokens, HasFactory, Notifiable,SoftDeletes;

    protected $fillable = [
        'first_name',
        'last_name',
        'first_name_ar',
        'last_name_ar',
        'nationalite',
        'email',
        'password',
        "type_id",
        "status_id",
        "tel",
        "accepte_promotions",
        "identity_number",
        "address",
        "city_id",
        "agence",
        "identity_status",
        "host_nb_raters",
        "host_rate",
        "rib",
        "from_platform",
        "documents"
    ];

    /**
     * The attributes that should be hidden for serialization.
     *
     * @var list<string>
     */
    protected $hidden = [
        'password',
        'remember_token',
    ];

    /**
     * Get the attributes that should be cast.
     *
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'email_verified_at' => 'datetime',
            'password' => 'hashed',
        ];
    }

    public function getIsEmailVerifiedAttribute()
    {
        return ($this->email_verified_at != null);
    }

    public function getIsIdentityVerifiedAttribute()
    {
        return ($this->identity_status == "valid");
    }

    public function favorites()
    {
        return $this
            ->belongsToMany(
                Realstate::class,
                "realestate_favorites",
                "user_id",
                "realestate_id"
            )->withTimestamps();
    }


    public function registerMediaCollections(): void
    {
        $this->addMediaCollection('profile_photo')->singleFile(); // Stores only one profile photo
        $this->addMediaCollection('identity_front')->singleFile(); // Stores only one front identity document
        $this->addMediaCollection('identity_back')->singleFile(); // Stores only one back identity document
        $this->addMediaCollection('documents');
    }


    public function fullName()
    {
        return $this->first_name . " " . $this->last_name;
    }


    public function type()
    {
        return $this->belongsTo(UserType::class);
    }
    public function city()
    {
        return $this->belongsTo(City::class);
    }
    public function realestates()
    {
        return $this->hasMany(Realstate::class, "host_id");
    }


    public function bookings()
    {
        return $this->hasMany(Booking::class, "client_id");
    }
}
