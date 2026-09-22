<?php

namespace App\Http\Controllers\app;

use App\Http\Controllers\Controller;
use App\Models\Booking;
use App\Models\Realstate;
use App\Models\Transaction;
use App\utils\JsonResponses;
use Carbon\Carbon;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Validator;

class DashboardController extends Controller
{

    use JsonResponses;
    public function kpis(Request $request)
    {
        $validator = Validator::make($request->all(), [
            "from" => ["sometimes", "date_format:Y-m-d"],
            "to" => ["sometimes", "date_format:Y-m-d", "after:from"],
        ]);
        if ($validator->fails()) {
            return $this->jsonResponse(false, self::VALIDATION_ERROR, 422, $validator->errors());
        }
        $user = $request->user();

        $nbReservation = Booking::whereHas("realestate.host", function ($query) use ($user) {
            $query->where("id", "=", $user->id);
        })->whereHas("status", function ($query) {
            $query->where("code", "=", "completed");
        })->when($request->filled("from") && $request->filled("to"), function ($query) use ($request) {
            $query->whereBetween("created_at", [$request->input("from"), $request->input("to")]);
        })->count();

        $total = Transaction::whereHas("operation", function ($query) use ($request) {
            $query->where("code", "=", "success-payment");
        })->when($request->filled("from") && $request->filled("to"), function ($query) use ($request) {
            $query->whereBetween("created_at", [$request->input("from"), $request->input("to")]);
        })->where("user_id", "=", $user->id)
            ->sum("amount");

        $nbReserved = Realstate::where("host_id", "=", $user->id)
            ->whereHas("bookings", function ($query) {

                $query->where("checkin", "<=", now())
                    ->where("checkout", ">=", now())
                    ->whereHas("status", function ($query) {
                        $query->where("code", "=", "payed");
                    });
            })->count();
        $nbPending = Booking::whereHas("realestate.host", function ($query) use ($user) {
            $query->where("id", "=", $user->id);
        })->whereHas("status", function ($query) {
            $query->where("code", "=", "pending");
        })->where("checkin", ">", now())
            ->count();
        return $this->jsonResponse(true, self::SUCCESS, 200, [
            "nbReservation" => $nbReservation,
            "total" => $total,
            "reservedProperty" => $nbReserved,
            "pendingReservation" => $nbPending
        ]);
    }

    public function bookingsOverTime(Request $request)
    {
        $user = $request->user();

        $validated = $request->validate([
            'from' => ['required', 'date'],
            'to' => ['required', 'date', 'after_or_equal:from'],
            'groupBy' => ['in:day,month'],
        ]);

        $from = Carbon::parse($request->input('from'))->startOfDay();
        $to = Carbon::parse($request->input('to'))->endOfDay();
        $groupBy = $request->input('groupBy', 'day');


        $format = $groupBy === 'month' ? '%Y-%m' : '%Y-%m-%d';

        $results = Booking::select(DB::raw("DATE_FORMAT(checkin, '$format') as period"), DB::raw('COUNT(*) as count'))
            ->whereHas('realestate', function ($query) use ($user) {
                $query->where('host_id', $user->id);
            })
            ->whereHas('status', function ($query) {
                $query->where('code', 'payed')
                    ->orWhere("code", "completed"); // or completed if you prefer
            })
            ->whereBetween('created_at', [$from, $to])
            ->groupBy('period')
            ->orderBy('period')
            ->get()
            ->map(
                function ($item) {
                    return [
                        "period" => $item["period"],
                        "count" => $item["count"],
                    ];
                }
            );


        return $this->jsonResponse(true, self::SUCCESS, 200, $results);
    }



    public function totalRevenue(Request $request)
    {
        $user = $request->user();

        $validated = $request->validate([
            'from' => ['required', 'date'],
            'to' => ['required', 'date', 'after_or_equal:from'],
            'group_by' => ['in:day,month'], // Optional, default = day
        ]);

        $from = Carbon::parse($request->input('from'))->startOfDay();
        $to = Carbon::parse($request->input('to'))->endOfDay();
        $groupBy = $request->input('group_by', 'day');
        $format = $groupBy === 'month' ? '%Y-%m' : '%Y-%m-%d';

        $revenues = Transaction::select(DB::raw("DATE_FORMAT(transactions.created_at, '$format') as period"), DB::raw("SUM(amount) as total"))
            ->whereHas('operation', function ($q) {
                $q->where('code', 'success-payment');
            })
            ->where("user_id", "=", $user->id)
            ->whereBetween('transactions.created_at', [$from, $to])
            ->groupBy('period')
            ->orderBy('period')
            ->get()
            ->map(
                function ($item) {
                    return [
                        "period" => $item["period"],
                        "total" => $item["total"]
                    ];
                }
            );

        return $this->jsonResponse(true, self::SUCCESS, 200, $revenues);
    }
}
