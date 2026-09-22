<?php

use Illuminate\Foundation\Auth\EmailVerificationRequest;
use Illuminate\Http\Client\Request;
use Illuminate\Support\Facades\Route;

Route::get('/', function () {
    return view('home');
});


// Sends the verification link to the user's email
// Route::post('/email/verification-notification', function (Request $request) {
//     $request->user()->sendEmailVerificationNotification();
//     return response()->json(['message' => 'Verification link sent!']);
// })->middleware(['auth:api'])->name('verification.send');

// Handles the verification link
// Route::get('/email/verify/{id}/{hash}', function (EmailVerificationRequest $request) {
//     $request->fulfill(); // marks user as verified
//     return response()->json(['message' => 'Email verified!']);
// })->middleware(['auth:api', 'signed'])->name('verification.verify');
