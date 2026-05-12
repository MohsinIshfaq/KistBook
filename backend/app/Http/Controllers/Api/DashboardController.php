<?php

namespace App\Http\Controllers\Api;

use App\Contracts\Services\DashboardServiceInterface;
use App\Http\Controllers\Controller;
use Illuminate\Http\JsonResponse;

class DashboardController extends Controller
{
    public function __construct(private readonly DashboardServiceInterface $dashboard)
    {
    }

    public function index(): JsonResponse
    {
        return $this->successResponse($this->dashboard->getMetrics(), 'Dashboard metrics fetched successfully.');
    }
}
