<?php

use App\Http\Controllers\app\AuthController;
use App\Http\Controllers\app\BecomeHostController;
use App\Http\Controllers\app\ClientBookingController;
use App\Http\Controllers\app\CategoryController;
use App\Http\Controllers\app\ChatController;
use App\Http\Controllers\app\CityController;
use App\Http\Controllers\app\ContactController;
use App\Http\Controllers\app\DashboardController;
use App\Http\Controllers\app\EtatController;
use App\Http\Controllers\app\FavoritesController;
use App\Http\Controllers\app\FeaturesController;
use App\Http\Controllers\app\HomeImages;
use App\Http\Controllers\app\HostBookingController;
use App\Http\Controllers\app\HostRealestateController;
use App\Http\Controllers\app\ProfileController;
use App\Http\Controllers\app\ProfilesController;
use App\Http\Controllers\app\PublicRealEstateController;
use App\Http\Controllers\app\RealEstateController;
use App\Http\Controllers\app\RegionController;
use App\Http\Controllers\app\ReviewsController;
use App\Http\Controllers\app\StripeWebhookController;
use App\Http\Controllers\app\TransactionController;
use App\Http\Controllers\app\TransactionTypeController;
use Illuminate\Foundation\Auth\EmailVerificationRequest;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Route;
use Illuminate\Support\Facades\URL;
use Symfony\Component\HttpKernel\Profiler\Profile;

Route::post('/register', [AuthController::class, 'register']);
Route::post('/login', [AuthController::class, 'login']);
Route::post("/forget-password", [AuthController::class, "forgetPassword"]);
Route::post("/check-otp", [AuthController::class, "checkOtp"]);

Route::prefix("realestates")->group(function () {
    Route::get("/categories", [CategoryController::class, "index"]);
    Route::get("/transaction-types", [TransactionTypeController::class, "index"]);
    Route::get("/etats", [EtatController::class, "index"]);
    Route::get("/", [PublicRealEstateController::class, "index"]);
    Route::get("/{id}", [PublicRealEstateController::class, "show"]);
});

Route::get("/regions", [RegionController::class, "index"]);
Route::get("/cities", [CityController::class, "index"]);
Route::get("/home-images", [HomeImages::class, "index"]);

Route::get("/features", [FeaturesController::class, "index"]);
Route::get('/host/reviews/{id}', [ReviewsController::class, "hostReviews"]);
Route::get('/realestate/reviews/{id}', [ReviewsController::class, "realstateReviews"]);

Route::post('/webhook/payment-success', [StripeWebhookController::class, 'paymentSuccess']);

Route::patch('/host/bookings/{id}/confirm', [ClientBookingController::class, 'confirmBooking']);
Route::patch('/host/bookings/{id}/reject', [ClientBookingController::class, 'rejectBooking']);
Route::get('/host/bookings', [ClientBookingController::class, 'hostBookings']);

Route::get("/client/profile/{id}", [ProfileController::class, "clientProfile"]);
Route::get("/host/profile/{id}", [ProfileController::class, "hostProfile"]);

Route::get("/client/reviews/{id}", [ReviewsController::class, "clientReviews"]);


Route::get('/email/verify/{id}/{hash}', [AuthController::class, "verifyEmail"])
    ->middleware("signed")
    ->name('verification.verify');

Route::post("/contact-us", [ContactController::class, "contactUs"]);

Route::group(['middleware' => ['auth:sanctum']], function () {
    Route::get('/me', [AuthController::class, 'me']);
    Route::post('/logout', [AuthController::class, 'logout']);
    Route::post("/reset-password", [AuthController::class, "resetPassword"]);
    Route::post("/become-host", [BecomeHostController::class, "becomeHost"]);
    Route::post("/profile/update", [ProfileController::class, "updateProfile"]);
    Route::get("/resend-verification", [AuthController::class, "resendEmailVerification"]);


    //host routes
    Route::prefix("host")->group(function () {
        Route::apiResource("realestates", HostRealestateController::class);
        Route::post("/realestates/{id}", [HostRealestateController::class, "update"]);
        Route::patch("/realestates/{id}/pause", [HostRealestateController::class, "pause"]);
        Route::patch("/realestates/{id}/activate", [HostRealestateController::class, "activate"]);
        Route::get("/bookings", [HostBookingController::class, 'index']);
        Route::patch("/bookings/{id}/reject", [HostBookingController::class, 'rejectBooking']);
        Route::patch("/bookings/{id}/confirm", [HostBookingController::class, 'confirmBooking']);
        Route::post("/bookings/{id}/rate", [HostBookingController::class, 'rateBooking']);
        Route::get("/transactions", [TransactionController::class, "index"]);
        Route::get("/balances", [TransactionController::class, "blances"]);
        Route::prefix("dashboard")->group(function () {
            Route::get("/kpis", [DashboardController::class, "kpis"]);
            Route::get("/bookings-over-time", [DashboardController::class, "bookingsOverTime"]);
            Route::get("/total-revenue", [DashboardController::class, "totalRevenue"]);
        });
    });


    //client routes
    Route::prefix("client")->group(function () {
        Route::post("/bookings", [ClientBookingController::class, "clientBook"]);
        Route::get("/bookings", [ClientBookingController::class, "clientBookings"]);
        Route::get("/bookings/{id}", [ClientBookingController::class, "clientBooking"]);
        Route::post('/bookings/{id}/rate', [ClientBookingController::class, 'clientRateBooking']);
        Route::get('/bookings/{id}/pay', [ClientBookingController::class, 'clientPayBooking']);
        Route::post("/add-favorite", [FavoritesController::class, "addRealestateToFavorites"]);
        Route::post("/remove-favorite", [FavoritesController::class, "removeRealestateFromFavorites"]);
        Route::get("/favorites", [FavoritesController::class, "index"]);
    });

    Route::get("/bookings/status", [ClientBookingController::class, "bookingStatus"]);




    //chat routes
    Route::prefix("chat")->group(function () {

        Route::post("/{receiverid}/send-message", [ChatController::class, "sendMessage"]);
        Route::get("/{receiverid}/messages", [ChatController::class, "messages"]);
        Route::get("/conversations", [ChatController::class, "conversations"]);
        Route::get("/profile/{id}", [ChatController::class, "profile"]);
    });
});



//====================test

Route::get("/test", function () {
    Log::info("hello", ["test" => "test"]);
    return "success";
});
