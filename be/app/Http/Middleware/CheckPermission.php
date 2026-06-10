<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class CheckPermission
{
    public function handle(Request $request, Closure $next, string ...$permissions): Response
    {
        $user = $request->user();

        if (! $user) {
            return response()->json([
                'status'  => 'error',
                'message' => 'Akses ditolak. Anda tidak memiliki izin.',
            ], 403);
        }

        if ($user->role === 'superadmin') {
            return $next($request);
        }

        foreach ($permissions as $permission) {
            if ($user->hasAccessPermission($permission)) {
                return $next($request);
            }
        }

        return response()->json([
            'status'  => 'error',
            'message' => 'Akses ditolak. Permission akun belum aktif.',
        ], 403);
    }
}
