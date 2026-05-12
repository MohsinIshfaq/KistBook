<?php

namespace App\Services;

use App\Contracts\Repositories\UserCustomerAccessRepositoryInterface;
use App\Contracts\Repositories\UserPlanAccessRepositoryInterface;
use App\Contracts\Services\AccessServiceInterface;

class AccessService implements AccessServiceInterface
{
    public function __construct(
        private readonly UserCustomerAccessRepositoryInterface $customerAccess,
        private readonly UserPlanAccessRepositoryInterface $planAccess,
    ) {
    }

    public function assignCustomer(string $userUuid, string $customerUuid): array
    {
        return [
            'assignment' => $this->customerAccess->assign($userUuid, $customerUuid),
        ];
    }

    public function assignPlan(string $userUuid, string $planUuid): array
    {
        return [
            'assignment' => $this->planAccess->assign($userUuid, $planUuid),
        ];
    }
}
