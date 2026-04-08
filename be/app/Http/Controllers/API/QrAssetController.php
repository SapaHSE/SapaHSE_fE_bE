<?php

namespace App\Http\Controllers\API;

use App\Http\Controllers\Controller;
use App\Models\QrAsset;
use Illuminate\Http\Request;

class QrAssetController extends Controller
{
    // GET /api/qr-assets
    public function index()
    {
        $assets = QrAsset::latest()->get();

        return response()->json([
            'status' => 'success',
            'data'   => $assets->map(fn($a) => $this->formatAsset($a)),
        ]);
    }

    // GET /api/qr-assets/scan?qr_code=BBE-APAR-2024-001234
    public function scan(Request $request)
    {
        $request->validate([
            'qr_code' => 'required|string',
        ]);

        $asset = QrAsset::where('qr_code', $request->qr_code)->first();

        if (! $asset) {
            return response()->json([
                'status'  => 'error',
                'message' => 'QR Code not found. Asset is not registered in the system.',
            ], 404);
        }

        return response()->json([
            'status' => 'success',
            'data'   => $this->formatAsset($asset),
        ]);
    }

    private function formatAsset(QrAsset $asset): array
    {
        return [
            'id'           => $asset->id,
            'qr_code'      => $asset->qr_code,
            'asset_name'   => $asset->asset_name,
            'asset_type'   => $asset->asset_type,
            'location'     => $asset->location,
            'condition'    => $asset->condition,
            'last_checked' => $asset->last_checked?->format('d F Y'),
            'next_check'   => $asset->next_check?->format('d F Y'),
            'notes'        => $asset->notes,
        ];
    }
}
