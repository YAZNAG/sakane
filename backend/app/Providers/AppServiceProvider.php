<?php

namespace App\Providers;

use Illuminate\Auth\Notifications\VerifyEmail;
use Illuminate\Support\Facades\URL;
use Illuminate\Support\ServiceProvider;

class AppServiceProvider extends ServiceProvider
{
    /**
     * Register any application services.
     */
    public function register(): void
    {
        //
    }

    /**
     * Bootstrap any application services.
     */
    public function boot(): void
    {
        VerifyEmail::createUrlUsing(function ($notifiable) {
            // Step 1: Generate the signed URL (default Laravel URL)
            $url = URL::temporarySignedRoute(
                'verification.verify',
                now()->addMinutes(60),
                [
                    'id' => $notifiable->getKey(),
                    'hash' => sha1($notifiable->getEmailForVerification()),
                ]
            );

            // Step 2: Parse the URL components
            $parsedUrl = parse_url($url);

            // Extract path and query
            $path = $parsedUrl['path']; // e.g., /email/verify/123/abc123
            $query = $parsedUrl['query'] ?? '';

            // Step 3: Extract ID and hash from path
            $segments = explode('/', trim($path, '/')); // ['email', 'verify', '123', 'abc123']
            $id = $segments[4] ?? null;
            $hash = $segments[5] ?? null;

            // Step 4: Parse query string
            parse_str($query, $queryParams); // ['expires' => '...', 'signature' => '...']

            // Step 5: Build new frontend URL
            $frontendUrl = env("FRONTEND_URL", "http://localhost:3000") . '/verify-email';
            $finalUrl = $frontendUrl . '?' . http_build_query([
                'id' => $id,
                'hash' => $hash,
                'expires' => $queryParams['expires'] ?? null,
                'signature' => $queryParams['signature'] ?? null,
            ]);

            return $finalUrl;
        });
    }
}
