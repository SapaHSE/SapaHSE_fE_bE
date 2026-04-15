<?php

namespace App\Providers;

use App\Mail\Transport\BrevoTransport;
use App\Services\BrevoEmailService;
use Illuminate\Support\Facades\Mail;
use Illuminate\Support\ServiceProvider;

class AppServiceProvider extends ServiceProvider
{
    public function register(): void
    {
        $this->app->singleton(BrevoEmailService::class);
    }

    public function boot(): void
    {
        Mail::extend('brevo', function (array $config) {
            return new BrevoTransport($config['api_key'] ?? '');
        });
    }
}