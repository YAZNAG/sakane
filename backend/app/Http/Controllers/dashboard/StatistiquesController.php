<?php

namespace App\Http\Controllers\dashboard;

use App\Http\Controllers\Controller;
use App\Models\Booking;
use App\Models\Charge;
use App\utils\JsonResponses;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Validator;

class StatistiquesController extends Controller
{
    use JsonResponses;



    public function stats(Request $request)
    {
        $from = $request->input("from");
        $to = $request->input("to");
        $realestate = $request->input("realestate");
        $groupBy = $request->input("groupBy", "day");



        $dtFrom = Carbon::parse($from)->startOfDay();
        $dtTo = Carbon::parse($to)->endOfDay();
        $totalCharges = Charge::whereBetween("created_at", [$dtFrom, $dtTo])->where("realestate_id", $realestate)->sum("amount");

        $totalPlatform = Booking::whereHas("type", function ($query) {
            $query->where("code", "platform");
        })->whereBetween("created_at", [$dtFrom, $dtTo])
            ->where("realestate_id", $realestate)
            ->whereHas("status", function ($query) {
                $query->where("code", "payed")
                    ->orWhere("code", "completed");
            })->sum("amount");

        $totalRealworld = Booking::whereHas("type", function ($query) {
            $query->where("code", "realworld");
        })->whereBetween("created_at", [$dtFrom, $dtTo])
            ->where("realestate_id", $realestate)
            ->whereHas("status", function ($query) {
                $query->where("code", "payed")
                    ->orWhere("code", "completed");
            })->sum("amount");

        $format = $groupBy == "day" ? "%Y-%m-%d" : "%Y-%m";


        $resultsPlatform = Booking::select(DB::raw("DATE_FORMAT(created_at, '$format') as period"), DB::raw('SUM(amount) as total'))
            ->where('realestate_id', $realestate)
            ->whereHas('status', function ($query) {
                $query->where('code', 'payed')
                    ->orWhere("code", "completed");
            })->whereHas("type", function ($query) {
                $query->where("code", "platform");
            })->whereBetween('created_at', [$dtFrom, $dtTo])
            ->groupBy('period')
            ->orderBy('period')
            ->get()
            ->map(
                function ($item) {
                    return [
                        "period" => $item["period"],
                        "amount" => $item["total"],
                    ];
                }
            );


        $resultsRealworld = Booking::select(DB::raw("DATE_FORMAT(created_at, '$format') as period"), DB::raw('SUM(amount) as total'))
            ->where('realestate_id', $realestate)
            ->whereHas('status', function ($query) {
                $query->where('code', 'payed')
                    ->orWhere("code", "completed");
            })->whereHas("type", function ($query) {
                $query->where("code", "realworld");
            })->whereBetween('created_at', [$dtFrom, $dtTo])
            ->groupBy('period')
            ->orderBy('period')
            ->get()
            ->map(
                function ($item) {
                    return [
                        "period" => $item["period"],
                        "amount" => $item["total"],
                    ];
                }
            );


        return $this->successResponse(
            [
                "platform" => $totalPlatform,
                "realworld" => $totalRealworld,
                "charges" => $totalCharges,
                "platformValues" => $resultsPlatform,
                "realworldValues" => $resultsRealworld
            ]
        );
    }



    public function globalStats(Request $request)
    {
        $from = $request->input("from");
        $to = $request->input("to");
        $groupBy = $request->input("groupBy", "day");
        $format = $groupBy == "day" ? "%Y-%m-%d" : "%Y-%m";

        $dtFrom = Carbon::parse($from)->startOfDay();
        $dtTo = Carbon::parse($to)->endOfDay();

        $resultsPlatform = Booking::select(DB::raw("DATE_FORMAT(created_at, '$format') as period"), DB::raw('SUM(amount) as total'))
            ->whereHas('realestate.host', function ($query) {
                $query->where("agence", true);
            })
            ->whereHas('status', function ($query) {
                $query->where('code', 'payed')
                    ->orWhere("code", "completed");
            })->whereHas("type", function ($query) {
                $query->where("code", "platform");
            })->whereBetween('created_at', [$dtFrom, $dtTo])
            ->groupBy('period')
            ->orderBy('period')
            ->get()
            ->map(
                function ($item) {
                    return [
                        "period" => $item["period"],
                        "amount" => $item["total"],
                    ];
                }
            );


        $resultsRealworld = Booking::select(DB::raw("DATE_FORMAT(created_at, '$format') as period"), DB::raw('SUM(amount) as total'))
            ->whereHas('realestate.host', function ($query) {
                $query->where("agence", true);
            })
            ->whereHas('status', function ($query) {
                $query->where('code', 'payed')
                    ->orWhere("code", "completed");
            })->whereHas("type", function ($query) {
                $query->where("code", "realworld");
            })->whereBetween('created_at', [$dtFrom, $dtTo])
            ->groupBy('period')
            ->orderBy('period')
            ->get()
            ->map(
                function ($item) {
                    return [
                        "period" => $item["period"],
                        "amount" => $item["total"],
                    ];
                }
            );


        $charges = Charge::query()
            ->select(DB::raw("DATE_FORMAT(created_at, '$format') as period"), DB::raw('SUM(amount) as total'))
            ->whereBetween("created_at", [$dtFrom, $dtTo])
            ->groupBy('period')
            ->orderBy('period')
            ->get()
            ->map(
                function ($item) {
                    return [
                        "period" => $item["period"],
                        "amount" => $item["total"],
                    ];
                }
            );

        //kpis
        $totalPlatform = Booking::whereHas('realestate.host', function ($query) {
            $query->where("agence", true);
        })
            ->whereHas('status', function ($query) {
                $query->whereIn('code', ['payed', 'completed']);
            })
            ->whereHas('type', function ($query) {
                $query->where("code", "platform");
            })
            ->whereBetween('created_at', [$dtFrom, $dtTo])
            ->sum('amount');

        $totalRealworld = Booking::whereHas('realestate.host', function ($query) {
            $query->where("agence", true);
        })
            ->whereHas('status', function ($query) {
                $query->whereIn('code', ['payed', 'completed']);
            })
            ->whereHas('type', function ($query) {
                $query->where("code", "realworld");
            })
            ->whereBetween('created_at', [$dtFrom, $dtTo])
            ->sum('amount');

        $totalCharges = Charge::whereBetween('created_at', [$dtFrom, $dtTo])
            ->sum('amount');

        $response = [
            "totalPlatform" => $totalPlatform,
            "totalRealworld" => $totalRealworld,
            "totalCharges" => $totalCharges,
            "platform" => $resultsPlatform,
            "realworld" => $resultsRealworld,
            "charges" => $charges
        ];
        return $this->successResponse($response);
    }
}
