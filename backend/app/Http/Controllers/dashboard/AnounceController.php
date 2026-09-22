<?php

namespace App\Http\Controllers\dashboard;

use App\Http\Controllers\Controller;
use App\Http\Resources\DashboardResource\RealestateResource;
use App\Models\Realstate;
use App\Models\RealstateReviewStatus;
use App\Models\RealstateStatus;
use App\utils\JsonResponses;
use Illuminate\Http\Request;

class AnounceController extends Controller
{

    use JsonResponses;

    public function index()
    {
        $anounces = Realstate::whereHas("reviewStatus", function ($query) {
            $query->where("code", "in-review");
        })->get();
        $response = RealestateResource::collection($anounces);
        return $this->successResponse($response);
    }

    public function refuseAnounce($id)
    {
        $anounce = Realstate::find($id);
        $status = RealstateStatus::where("code", "paused")->first();
        $reviewStatus = RealstateReviewStatus::where("code", "illegal")->first();
        $anounce->update([
            "status_id" => $status->id,
            "review_status_id" => $reviewStatus->id
        ]);
        $response = new RealestateResource($anounce->fresh());
        return $this->successResponse($response);
    }

    public function acceptAnounce($id)
    {
        $anounce = Realstate::find($id);
        $status = RealstateStatus::where("code", "active")->first();
        $reviewStatus = RealstateReviewStatus::where("code", "legal")->first();
        $anounce->update([
            "status_id" => $status->id,
            "review_status_id" => $reviewStatus->id
        ]);
        $response = new RealestateResource($anounce->fresh());
        return $this->successResponse($response);
    }
}
