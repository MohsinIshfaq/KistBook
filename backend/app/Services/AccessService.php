<?php

namespace App\Services;

use App\Contracts\Repositories\UserCustomerAccessRepositoryInterface;
use App\Contracts\Repositories\UserPlanAccessRepositoryInterface;
use App\Contracts\Services\AccessServiceInterface;
use App\Models\Customer;
use App\Models\Plan;
use App\Models\User;
use Illuminate\Support\Facades\Auth;

class AccessService implements AccessServiceInterface
{
    public function __construct(
        private readonly UserCustomerAccessRepositoryInterface $customerAccess,
        private readonly UserPlanAccessRepositoryInterface $planAccess,
    ) {}

    public function assignCustomer(string $userUuid, string $customerUuid): array
    {
        $this->salesmanForOwner($userUuid);
        Customer::query()->where('uuid', $customerUuid)->firstOrFail();

        return [
            'assignment' => $this->customerAccess->assign($userUuid, $customerUuid),
        ];
    }

    public function assignPlan(string $userUuid, string $planUuid): array
    {
        $this->salesmanForOwner($userUuid);
        Plan::query()->where('uuid', $planUuid)->firstOrFail();

        return [
            'assignment' => $this->planAccess->assign($userUuid, $planUuid),
        ];
    }

    private function salesmanForOwner(string $userUuid): User
    {
        /** @var User|null $owner */
        $owner = Auth::user();
        abort_unless($owner?->isOwner() === true && $owner->company_id !== null, 403);

        return User::query()
            ->where('uuid', $userUuid)
            ->where('company_id', $owner->company_id)
            ->where('role', 'salesman')
            ->firstOrFail();
    }
}
