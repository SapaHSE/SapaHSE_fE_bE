<?php

use Illuminate\Auth\AuthenticationException;
use Illuminate\Foundation\Application;
use Illuminate\Foundation\Configuration\Exceptions;
use Illuminate\Foundation\Configuration\Middleware;
use Laravel\Sanctum\PersonalAccessToken;

return Application::configure(basePath: dirname(__DIR__))
    ->withRouting(
        web: __DIR__.'/../routes/web.php',
        api: __DIR__.'/../routes/api.php',
        commands: __DIR__.'/../routes/console.php',
        health: '/up',
    )
    ->withMiddleware(function (Middleware $middleware): void {
        $middleware->prepend(\Illuminate\Http\Middleware\HandleCors::class);
        $middleware->alias([
            'role' => \App\Http\Middleware\CheckRole::class,
            'permission' => \App\Http\Middleware\CheckPermission::class,
        ]);
    })
    ->withExceptions(function (Exceptions $exceptions): void {
        $exceptions->render(function (AuthenticationException $e, $request) {
            if ($request->expectsJson()) {
                $token = $request->bearerToken();
                if ($token) {
                    $accessToken = PersonalAccessToken::findToken($token);
                    if ($accessToken?->revoked_reason) {
                        $message = match ($accessToken->revoked_reason) {
                            'another_login' => 'Akun Anda telah login di perangkat lain.',
                            'password_changed' => 'Password telah diubah. Silakan login kembali.',
                            'account_deleted' => 'Akun Anda telah dihapus.',
                            default => 'Sesi telah berakhir. Silakan login kembali.',
                        };
                        return response()->json([
                            'status' => 'error',
                            'message' => $message,
                        ], 401);
                    }
                }
                return response()->json([
                    'status' => 'error',
                    'message' => 'Unauthenticated.',
                ], 401);
            }
        });
    })->create();
