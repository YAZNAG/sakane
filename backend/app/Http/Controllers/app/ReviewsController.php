<?php

namespace App\Http\Controllers\app;

use App\Http\Controllers\Controller;
use App\Http\Resources\AppResources\ClientReviewResource;
use App\Http\Resources\AppResources\ClientReviewsPaginationResource;
use App\Http\Resources\AppResources\HostReviewResource;
use App\Http\Resources\PaginationResource;
use App\Models\ClientReview;
use App\Models\HostReview;
use App\utils\JsonResponses;
use Illuminate\Http\Request;

class ReviewsController extends Controller
{
    use JsonResponses;
    public function hostReviews(Request $request, $id)
    {
        $reviews = ClientReview::whereHas("booking.realestate", function ($query) use ($id) {
            $query->where("host_id", '=', $id);
        })->orderBy('created_at', 'desc')
            ->with('client')
            ->paginate($request->input("perPage", 10), ['*'], 'reviews', $request->input('page', 1));
        $reviews = new PaginationResource(ClientReviewResource::collection($reviews));
        return $this->jsonResponse(true, self::SUCCESS, 200, $reviews);
    }

    public function realstateReviews(Request $request, $id)
    {
        $reviews = ClientReview::whereHas('booking', function ($query) use ($id) {
            $query->where('realestate_id', '=', $id);
        })->orderBy('created_at', 'desc')
            ->with('client')
            ->paginate($request->input("perPage", 10), ['*'], 'reviews', $request->input('page', 1));
        $reviews = new PaginationResource(ClientReviewResource::collection($reviews));
        return $this->jsonResponse(true, self::SUCCESS, 200, $reviews);
    }

    public function clientReviews(Request $request, $id)
    {
        $reviews = HostReview::whereHas("booking", function ($query) use ($id) {
            $query->where("client_id", "=", $id);
        })->orderBy('created_at', 'desc')
            ->with('host')
            ->paginate($request->input("perPage", 10), ['*'], 'reviews', $request->input('page', 1));

        $response = new PaginationResource(HostReviewResource::collection($reviews));
        return $this->jsonResponse(true, self::SUCCESS, 200, $response);
    }
}
