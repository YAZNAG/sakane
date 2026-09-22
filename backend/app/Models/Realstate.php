<?php

namespace App\Models;

use App\Filters\RealestateFilter;
use App\Models\Scopes\NotDeletedScope;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\SoftDeletes;
use Spatie\MediaLibrary\HasMedia;
use Spatie\MediaLibrary\InteractsWithMedia;
use Spatie\MediaLibrary\MediaCollections\Models\Media;
use Spatie\Image\Enums\Fit;

class Realstate extends Model implements HasMedia
{
    use InteractsWithMedia,SoftDeletes;
    protected $fillable = [
        'title',
        'description',
        'surface',
        'price',
        'address',
        'date_construction',
        'nb_etage',
        'nb_rooms',
        'etage',
        'nb_bathroom',
        'rate',
        'nb_raters',
        'latitude',
        'longitude',
        'category_id',
        'transaction_id',
        'owner_id',
        'host_id',
        'status_id',
        'review_status_id',
        'city_id',
        'secteur_id',
        'dossier_id',
        'etat_id',
        'is_deleted',
        "tour_360_url",
        "cleaning_status",
        "checkout_at",
        "cleaning_started_at",
        "cleaning_finished_at",
        "cleaned_by",
        "last_cleaning_minutes",
        "booking_id",
        "syndic_id"
    ];
    protected $casts = [
        'surface' => 'integer',
        'price' => 'double',
        'nb_etage' => 'integer',
        'nb_rooms' => 'integer',
        'etage' => 'integer',
        'nb_bathroom' => 'integer',
        'rate' => 'double',
        'nb_raters' => 'integer',
        'checkout_at' => 'datetime',
        'cleaning_started_at' => 'datetime',
        'cleaning_finished_at' => 'datetime',
        'latitude' => 'double',
        'longitude' => 'double',
    ];

    protected static function booted()
    {
        static::addGlobalScope(new NotDeletedScope());
    }

    public function scopeFilter(Builder $builder, RealestateFilter $filters)
    {
        return $filters->filter($builder);
    }

    public function registerMediaCollections(): void
    {
        $this->addMediaCollection('images');
        $this->addMediaCollection('rapport');
    }

    /**
     * Versions allegees des photos.
     * Les originaux font en moyenne 1,2 Mo : trop lourds pour un affichage
     * mobile. On genere une version d'apercu et une miniature de liste.
     */
    public function registerMediaConversions(?Media $media = null): void
    {
        $this->addMediaConversion('apercu')
            ->fit(Fit::Max, 1280, 1280)
            ->quality(82)
            ->format('jpg')
            ->performOnCollections('images')
            // L'optimiseur d'images lance jpegoptim par proc_open, que PHP
            // interdit pour le web sur ce serveur : l'enregistrement des
            // photos echouait, et la creation d'un bien avec.
            ->nonOptimized()
            ->nonQueued();

        $this->addMediaConversion('vignette')
            ->fit(Fit::Max, 420, 420)
            ->quality(78)
            ->format('jpg')
            ->performOnCollections('images')
            // L'optimiseur d'images lance jpegoptim par proc_open, que PHP
            // interdit pour le web sur ce serveur : l'enregistrement des
            // photos echouait, et la creation d'un bien avec.
            ->nonOptimized()
            ->nonQueued();
    }

    public function cleaner()
    {
        return $this->belongsTo(Manager::class, 'cleaned_by');
    }

    public function dossier()
    {
        return $this->belongsTo(Dossier::class, "dossier_id");
    }

    public function secteur()
    {
        return $this->belongsTo(Secteur::class, "secteur_id");
    }

    public function host()
    {
        return $this->belongsTo(User::class, "host_id");
    }

    public function features()
    {
        return $this->belongsToMany(Feature::class, "realestate_feature", "realstate_id", "feature_id");
    }

    public function etat()
    {
        return $this->belongsTo(RealstateEtat::class);
    }
    public function status()
    {
        return $this->belongsTo(RealstateStatus::class);
    }
    public function reviewStatus()
    {
        return $this->belongsTo(RealstateReviewStatus::class);
    }
    public function type()
    {
        return $this->belongsTo(TypeTransaction::class, "transaction_id");
    }
    public function category()
    {
        return $this->belongsTo(RealstateCategory::class);
    }
    public function city()
    {
        return $this->belongsTo(City::class);
    }

    public function bookings()
    {
        return $this->hasMany(Booking::class, "realestate_id");
    }

    public function booking()
    {
        return $this->belongsTo(Booking::class, "booking_id");
    }

    /** Les syndics de l'immeuble : un bien peut en avoir plusieurs. */
    public function syndics()
    {
        return $this->belongsToMany(Syndic::class, "realestate_syndic", "realestate_id", "syndic_id")->withTimestamps();
    }

    public function syndic()
    {
        return $this->belongsTo(Syndic::class, "syndic_id");
    }

    public function owner()
    {
        return $this->belongsTo(Owner::class, "owner_id");
    }
}
