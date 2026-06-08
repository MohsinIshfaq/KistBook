<?php

use App\Http\Controllers\Api\AccessController;
use App\Http\Controllers\Api\AuthController;
use App\Http\Controllers\Api\CategoryController;
use App\Http\Controllers\Api\CompanyUserController;
use App\Http\Controllers\Api\CustomerController;
use App\Http\Controllers\Api\CustomerSyncController;
use App\Http\Controllers\Api\DashboardController;
use App\Http\Controllers\Api\InstallmentController;
use App\Http\Controllers\Api\InstallmentPlanController;
use App\Http\Controllers\Api\InstallmentPlanSyncController;
use App\Http\Controllers\Api\PaymentController;
use App\Http\Controllers\Api\PlanController;
use App\Http\Controllers\Api\ProductController;
use App\Http\Controllers\Api\ProductSyncController;
use App\Http\Controllers\Api\RuntimeBootstrapController;
use App\Http\Controllers\Api\SyncController;
use Illuminate\Support\Facades\Route;

Route::prefix('auth')->group(function (): void {
    Route::post('register', [AuthController::class, 'register']);
    Route::post('login', [AuthController::class, 'login']);
});

Route::middleware('auth:sanctum')->group(function (): void {
    Route::post('auth/logout', [AuthController::class, 'logout']);
    Route::get('auth/profile', [AuthController::class, 'me']);
    Route::patch('auth/profile', [AuthController::class, 'updateProfile']);
    Route::get('me', [AuthController::class, 'me']);
    Route::post('company/users', [CompanyUserController::class, 'store']);
    Route::get('bootstrap', [RuntimeBootstrapController::class, 'show']);

    Route::get('customers/sync', [CustomerSyncController::class, 'download']);
    Route::post('customers/sync', [CustomerSyncController::class, 'create']);
    Route::put('customers/sync', [CustomerSyncController::class, 'update']);
    Route::delete('customers/sync', [CustomerSyncController::class, 'delete']);
    Route::get('customers/{uuid}/plans', [CustomerController::class, 'plans']);
    Route::get('customers/{uuid}', [CustomerController::class, 'show']);
    Route::get('products/sync', [ProductSyncController::class, 'download']);
    Route::post('products/sync', [ProductSyncController::class, 'create']);
    Route::put('products/sync', [ProductSyncController::class, 'update']);
    Route::delete('products/sync', [ProductSyncController::class, 'delete']);
    Route::get('products/{uuid}', [ProductController::class, 'show']);
    Route::get('installment-plans/sync', [InstallmentPlanSyncController::class, 'download']);
    Route::post('installment-plans/sync', [InstallmentPlanSyncController::class, 'create']);
    Route::put('installment-plans/sync', [InstallmentPlanSyncController::class, 'update']);
    Route::delete('installment-plans/sync', [InstallmentPlanSyncController::class, 'delete']);
    Route::get('plans/sync', [InstallmentPlanSyncController::class, 'download']);
    Route::post('plans/sync', [InstallmentPlanSyncController::class, 'create']);
    Route::put('plans/sync', [InstallmentPlanSyncController::class, 'update']);
    Route::delete('plans/sync', [InstallmentPlanSyncController::class, 'delete']);
    Route::apiResource('categories', CategoryController::class)->parameter('categories', 'uuid');
    Route::apiResource('installment-plans', InstallmentPlanController::class)->parameter('installment-plans', 'uuid');
    Route::apiResource('plans', PlanController::class)->parameter('plans', 'uuid');
    Route::apiResource('installments', InstallmentController::class)->parameter('installments', 'uuid');
    Route::apiResource('payments', PaymentController::class)->parameter('payments', 'uuid');

    Route::post('access/customer', [AccessController::class, 'assignCustomer']);
    Route::post('access/plan', [AccessController::class, 'assignPlan']);
    Route::put('access/assignments', [AccessController::class, 'replaceAssignments']);

    Route::post('sync/upload', [SyncController::class, 'upload']);
    Route::get('sync/download', [SyncController::class, 'download']);

    Route::get('dashboard', [DashboardController::class, 'index']);
});
