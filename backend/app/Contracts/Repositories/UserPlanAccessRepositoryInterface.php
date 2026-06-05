<?php

namespace App\Contracts\Repositories;

use App\Models\UserPlanAccess;
use Illuminate\Support\Collection;

interface UserPlanAccessRepositoryInterface
{
    public function assign(string $userUuid, string $planUuid): UserPlanAccess;

    public function activeAssigneeForPlan(string $planUuid, ?string $exceptUserUuid = null): ?UserPlanAccess;

    /**
     * @param  array<int, string>  $planUuids
     * @return Collection<int, UserPlanAccess>
     */
    public function replaceForUser(string $userUuid, array $planUuids): Collection;
}
