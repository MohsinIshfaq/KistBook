<?php

namespace App\Contracts\Repositories;

use App\Models\UserPlanAccess;

interface UserPlanAccessRepositoryInterface
{
    public function assign(string $userUuid, string $planUuid): UserPlanAccess;
}
