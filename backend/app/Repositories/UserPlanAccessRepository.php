<?php

namespace App\Repositories;

use App\Contracts\Repositories\UserPlanAccessRepositoryInterface;
use App\Models\UserPlanAccess;
use Illuminate\Support\Str;

class UserPlanAccessRepository implements UserPlanAccessRepositoryInterface
{
    public function assign(string $userUuid, string $planUuid): UserPlanAccess
    {
        $assignment = UserPlanAccess::query()->withTrashed()->firstOrCreate(
            ['user_uuid' => $userUuid, 'plan_uuid' => $planUuid],
            ['uuid' => (string) Str::uuid(), 'is_deleted' => false],
        );
        if ($assignment->trashed() || $assignment->is_deleted) {
            $assignment->restore();
            $assignment->forceFill(['is_deleted' => false])->save();
        }

        return $assignment;
    }
}
