<?php

namespace App\Providers;

use Google\Client;
use Google\Service\Drive;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\ServiceProvider;
use Masbug\Flysystem\GoogleDriveAdapter;


use Illuminate\Filesystem\FilesystemAdapter;
use Illuminate\Support\Facades\Log;
use League\Flysystem\Filesystem;


class GoogleDriveServiceProvider extends ServiceProvider
{
    public function boot()
    {
        Storage::extend('google', function ($app, $config) {
            $client = new Client();
            $client->setClientId($config['clientId']);
            $client->setClientSecret($config['clientSecret']);
            $client->refreshToken($config['refreshToken']);

            $service = new Drive($client);
            Log::info("backup-debug", ["folder" => $config['folderId']]);
            $adapter = new GoogleDriveAdapter(
                $service,
                $config['folderId'],
                ['useHasTeamDrive' => false]
            );

            $driver = new Filesystem($adapter);

            return new FilesystemAdapter($driver, $adapter);
        });
    }
}
