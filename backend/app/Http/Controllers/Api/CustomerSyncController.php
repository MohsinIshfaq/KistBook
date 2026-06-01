<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\Customers\CustomerSyncUploadRequest;
use App\Services\CustomerSyncService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class CustomerSyncController extends Controller
{
    public function __construct(private readonly CustomerSyncService $sync) {}

    public function download(Request $request): JsonResponse
    {
        $maxLimit = max(1, min(10, (int) config('kistbook.customer_sync.max_limit', 10)));
        $validated = $request->validate([
            'lastUpdatedAt' => ['nullable', 'date', 'required_with:lastServerId'],
            'lastServerId' => ['nullable', 'uuid'],
            'limit' => ['nullable', 'integer', 'min:1', 'max:'.$maxLimit],
        ]);

        return response()->json($this->sync->download(
            $request->user(),
            $validated['lastUpdatedAt'] ?? null,
            (int) ($validated['limit'] ?? min($maxLimit, max(1, (int) config('kistbook.customer_sync.default_limit', 10)))),
            $validated['lastServerId'] ?? null,
        ));
    }

    public function create(CustomerSyncUploadRequest $request): JsonResponse
    {
        return $this->upload($request, 'pending_create');
    }

    public function update(CustomerSyncUploadRequest $request): JsonResponse
    {
        return $this->upload($request, 'pending_update');
    }

    public function delete(CustomerSyncUploadRequest $request): JsonResponse
    {
        return $this->upload($request, 'pending_delete');
    }

    private function upload(CustomerSyncUploadRequest $request, string $operation): JsonResponse
    {
        $validated = $request->validated();

        return response()->json($this->sync->upload(
            $request->user(),
            $validated['deviceId'] ?? $validated['device_id'] ?? null,
            $validated['customers'],
            $operation,
        ));
    }
}
