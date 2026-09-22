<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class FinancialTransaction extends Model
{
    protected $fillable = [
        'type',
        'amount',
        'description',
        'realestate_id',
        'booking_id',
        'charge_id',
        'transaction_date',
        'manager_id',
    ];

    protected $casts = [
        'amount'           => 'decimal:2',
        'transaction_date' => 'date',
    ];

    // ─── Relationships ────────────────────────────────────────────────────────

    public function realestate()
    {
        return $this->belongsTo(Realstate::class, 'realestate_id');
    }

    public function booking()
    {
        return $this->belongsTo(Booking::class);
    }

    /** L'agent qui a fait l'operation (prolongation, modification...). */
    public function manager()
    {
        return $this->belongsTo(Manager::class, 'manager_id');
    }

    public function charge()
    {
        return $this->belongsTo(Charge::class);
    }

    // ─── Scopes ───────────────────────────────────────────────────────────────

    public function scopeInPeriod($query, string $from, string $to)
    {
        return $query->whereBetween('transaction_date', [$from, $to]);
    }

    public function scopeByRealestates($query, array $ids)
    {
        if (empty($ids)) return $query;
        return $query->whereIn('realestate_id', $ids);
    }

    // ─── Helpers ──────────────────────────────────────────────────────────────

    public static function record(
        string  $type,
        float   $amount,
        string  $description,
        ?int    $realestateId = null,
        ?int    $bookingId    = null,
        ?int    $chargeId     = null,
        ?string $date         = null,
        ?int    $managerId    = null
    ): self {
        return self::create([
            'type'             => $type,
            'amount'           => $amount,
            'description'      => $description,
            'realestate_id'    => $realestateId,
            'booking_id'       => $bookingId,
            'charge_id'        => $chargeId,
            'transaction_date' => $date ?? (now()->hour < 5 ? now()->subDay()->toDateString() : now()->toDateString()),
            'manager_id'       => $managerId,
        ]);
    }
}
