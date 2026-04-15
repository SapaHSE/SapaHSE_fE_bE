<?php

namespace App\Providers;

use App\Services\BrevoEmailService;
use Illuminate\Support\ServiceProvider;

class AppServiceProvider extends ServiceProvider
{
    public function register(): void
    {
        $this->app->singleton(BrevoEmailService::class);
    }

    public function boot(): void
    {
        //
    }
}