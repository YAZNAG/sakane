<?php

namespace App\Http\Controllers\app;

use App\Http\Controllers\Controller;
use App\Http\Resources\AppResources\TransactionResource;
use App\Http\Resources\PaginationResource;
use App\Models\Transaction;
use App\utils\JsonResponses;
use Illuminate\Http\Request;

class TransactionController extends Controller
{
    use JsonResponses;
    public function index(Request $request)
    {
        $user = $request->user();
        if ($user->type->code != "host") {
            return $this->jsonResponse(false, self::NO_ACCESS, 403, null);
        }
        $transactions = Transaction::with(["booking", "operation", "user"])
            ->where("user_id", "=", $user->id)
            ->orderBy("created_at", "desc")
            ->paginate(
                $request->input("perPage", 10),
                ['*'],
                "transactions",
                $request->input("page", 1)
            );
        $response = new PaginationResource(TransactionResource::collection($transactions));
        return $this->jsonResponse(true, self::SUCCESS, 200, $response);
    }

    public function blances(Request $request)
    {
        $user = $request->user();
        $balance = $user->balance;
        $onHold = Transaction::whereHas("operation", function ($query) {
            $query->where("code", "=", "payment-on-hold");
        })->where("user_id", "=", $user->id)
            ->sum("amount");

        return $this->jsonResponse(true, self::SUCCESS, 200, [
            "balance" => $balance,
            "onHold" => $onHold
        ]);
    }
}
