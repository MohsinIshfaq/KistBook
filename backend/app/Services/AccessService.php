<?php

namespace App\Services;

use App\Contracts\Repositories\UserCustomerAccessRepositoryInterface;
use App\Contracts\Repositories\UserPlanAccessRepositoryInterface;
use App\Contracts\Services\AccessServiceInterface;
use App\Models\Customer;
use App\Models\Plan;
use App\Models\User;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

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
        $assignment = $this->customerAccess->assign($userUuid, $customerUuid);

        return [
            'assignment' => [
                'uuid' => $assignment->uuid,
                'userId' => $assignment->user_uuid,
                'customerId' => $assignment->customer_uuid,
                'isDeleted' => (bool) $assignment->is_deleted,
                'createdAt' => $assignment->created_at,
                'updatedAt' => $assignment->updated_at,
            ],
        ];
    }

    public function assignPlan(string $userUuid, string $planUuid): array
    {
        $this->salesmanForOwner($userUuid);
        Plan::query()->where('uuid', $planUuid)->firstOrFail();
        $existing = $this->planAccess->activeAssigneeForPlan($planUuid, $userUuid);
        if ($existing !== null) {
            throw ValidationException::withMessages([
                'planId' => ['This plan is already assigned to another salesman. Remove it from that user first.'],
            ]);
        }

        $assignment = $this->planAccess->assign($userUuid, $planUuid);

        return [
            'assignment' => [
                'uuid' => $assignment->uuid,
                'userId' => $assignment->user_uuid,
                'planId' => $assignment->plan_uuid,
                'isDeleted' => (bool) $assignment->is_deleted,
                'createdAt' => $assignment->created_at,
                'updatedAt' => $assignment->updated_at,
            ],
        ];
    }

    public function replaceAssignments(string $userUuid, array $customerUuids, array $planUuids): array
    {
        $salesman = $this->salesmanForOwner($userUuid);
        $customerUuids = $this->uniqueValues($customerUuids);
        $planUuids = $this->uniqueValues($planUuids);

        $this->assertCustomersBelongToOwner($customerUuids);
        $this->assertPlansBelongToOwner($planUuids);
        foreach ($planUuids as $planUuid) {
            $existing = $this->planAccess->activeAssigneeForPlan($planUuid, $salesman->uuid);
            if ($existing !== null) {
                throw ValidationException::withMessages([
                    'planIds' => ['This plan is already assigned to another salesman. Remove it from that user first.'],
                ]);
            }
        }

        [$customerAccess, $planAccess] = DB::transaction(fn (): array => [
            $this->customerAccess->replaceForUser($salesman->uuid, $customerUuids),
            $this->planAccess->replaceForUser($salesman->uuid, $planUuids),
        ]);

        return [
            'userId' => $salesman->uuid,
            'customerAccess' => $customerAccess
                ->map(fn ($assignment): array => $this->customerAssignment($assignment))
                ->values()
                ->all(),
            'planAccess' => $planAccess
                ->map(fn ($assignment): array => $this->planAssignment($assignment))
                ->values()
                ->all(),
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

    /**
     * @param  array<int, string>  $values
     * @return array<int, string>
     */
    private function uniqueValues(array $values): array
    {
        return array_values(array_unique(array_filter(
            array_map(fn (mixed $value): string => trim((string) $value), $values),
            fn (string $value): bool => $value !== '',
        )));
    }

    /**
     * @param  array<int, string>  $customerUuids
     */
    private function assertCustomersBelongToOwner(array $customerUuids): void
    {
        if ($customerUuids === []) {
            return;
        }

        $count = Customer::query()
            ->whereIn('uuid', $customerUuids)
            ->where('is_deleted', false)
            ->count();

        if ($count !== count($customerUuids)) {
            throw ValidationException::withMessages([
                'customerIds' => ['One or more selected customers are unavailable.'],
            ]);
        }
    }

    /**
     * @param  array<int, string>  $planUuids
     */
    private function assertPlansBelongToOwner(array $planUuids): void
    {
        if ($planUuids === []) {
            return;
        }

        $count = Plan::query()
            ->whereIn('uuid', $planUuids)
            ->where('is_deleted', false)
            ->count();

        if ($count !== count($planUuids)) {
            throw ValidationException::withMessages([
                'planIds' => ['One or more selected plans are unavailable.'],
            ]);
        }
    }

    private function customerAssignment($assignment): array
    {
        return [
            'serverId' => $assignment->uuid,
            'userId' => $assignment->user_uuid,
            'customerId' => $assignment->customer_uuid,
            'isDeleted' => (bool) $assignment->is_deleted,
            'createdAt' => $assignment->created_at?->toJSON(),
            'updatedAt' => $assignment->updated_at?->toJSON(),
        ];
    }

    private function planAssignment($assignment): array
    {
        return [
            'serverId' => $assignment->uuid,
            'userId' => $assignment->user_uuid,
            'planId' => $assignment->plan_uuid,
            'isDeleted' => (bool) $assignment->is_deleted,
            'createdAt' => $assignment->created_at?->toJSON(),
            'updatedAt' => $assignment->updated_at?->toJSON(),
        ];
    }
}
