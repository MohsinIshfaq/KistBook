<?php

use App\Http\Controllers\Api\AccessController;
use App\Http\Controllers\Api\AuthController;
use App\Http\Controllers\Api\CategoryController;
use App\Http\Controllers\Api\CustomerController;
use App\Http\Controllers\Api\DashboardController;
use App\Http\Controllers\Api\InstallmentController;
use App\Http\Controllers\Api\PaymentController;
use App\Http\Controllers\Api\PlanController;
use App\Http\Controllers\Api\ProductController;
use Illuminate\Support\Facades\Route;

Route::prefix('auth')->group(function (): void {
    Route::post('register', [AuthController::class, 'register']);
    Route::post('login', [AuthController::class, 'login']);
});

Route::middleware('auth:sanctum')->group(function (): void {
    Route::post('auth/logout', [AuthController::class, 'logout']);
    Route::get('me', [AuthController::class, 'me']);

    Route::apiResource('customers', CustomerController::class)->parameter('customers', 'uuid');
    Route::apiResource('products', ProductController::class)->parameter('products', 'uuid');
    Route::apiResource('categories', CategoryController::class)->parameter('categories', 'uuid');
    Route::apiResource('plans', PlanController::class)->parameter('plans', 'uuid');
    Route::apiResource('installments', InstallmentController::class)->parameter('installments', 'uuid');
    Route::apiResource('payments', PaymentController::class)->parameter('payments', 'uuid');

    Route::post('access/customer', [AccessController::class, 'assignCustomer']);
    Route::post('access/plan', [AccessController::class, 'assignPlan']);

    Route::get('dashboard', [DashboardController::class, 'index']);
});
