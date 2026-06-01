<?php

namespace App\Http\Controllers\Api;

use App\Contracts\Services\ProductServiceInterface;
use App\Http\Controllers\Controller;
use App\Http\Resources\ProductResource;
use Illuminate\Http\JsonResponse;

class ProductController extends Controller
{
    public function __construct(private readonly ProductServiceInterface $products)
    {
    }

    public function show(string $uuid): JsonResponse
    {
        return $this->successResponse(new ProductResource($this->products->show($uuid)));
    }
}
