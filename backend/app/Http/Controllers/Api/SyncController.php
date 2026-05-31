<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Services\SyncService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class SyncController extends Controller
{
    public function __construct(private readonly SyncService $syncService) {}

    public function upload(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'changes' => ['required', 'array'],
        ]);

        return $this->successResponse(
            $this->syncService->upload($validated['changes'], $request->user()),
            'Sync upload completed.'
        );
    }

    public function download(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'last_sync_date' => ['nullable', 'date'],
        ]);

        return $this->successResponse(
            $this->syncService->download($validated['last_sync_date'] ?? null, $request->user()),
            'Sync download completed.'
        );
    }
}
