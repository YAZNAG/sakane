<?php

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Broadcast;
use Illuminate\Support\Facades\Route;

Route::prefix("app")->group(function () {
    require __DIR__ . "/app/app_routes.php";
});

Route::prefix("dashboard")->group(function () {
    require __DIR__ . "/dashboard/dashboard_routes.php";
});


// Route::middleware('auth:sanctum')->post('/broadcasting/auth', function (Request $request) {
//     return Broadcast::auth($request);
// });
