<?php

namespace App\Http\Controllers\Api;

use App\Contracts\Services\AccessServiceInterface;
use App\Http\Controllers\Controller;
use App\Http\Requests\Access\AssignCustomerAccessRequest;
use App\Http\Requests\Access\AssignPlanAccessRequest;
use Illuminate\Http\JsonResponse;

class AccessController extends Controller
{
    public function __construct(private readonly AccessServiceInterface $access)
    {
    }

    public function assignCustomer(AssignCustomerAccessRequest $request): JsonResponse
    {
        return $this->successResponse($this->access->assignCustomer($request->string('user_uuid')->toString(), $request->string('customer_uuid')->toString()), 'Customer access assigned successfully.', 201);
    }

    public function assignPlan(AssignPlanAccessRequest $request): JsonResponse
    {
        return $this->successResponse($this->access->assignPlan($request->string('user_uuid')->toString(), $request->string('plan_uuid')->toString()), 'Plan access assigned successfully.', 201);
    }
}
