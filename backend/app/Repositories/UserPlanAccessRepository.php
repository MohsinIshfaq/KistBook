<?php

namespace App\Repositories;

use App\Contracts\Repositories\UserPlanAccessRepositoryInterface;
use App\Models\UserPlanAccess;
use Illuminate\Support\Collection;
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

    public function activeAssigneeForPlan(string $planUuid, ?string $exceptUserUuid = null): ?UserPlanAccess
    {
        return UserPlanAccess::query()
            ->where('plan_uuid', $planUuid)
            ->where('is_deleted', false)
            ->when($exceptUserUuid !== null, fn ($query) => $query->where('user_uuid', '!=', $exceptUserUuid))
            ->first();
    }

    public function replaceForUser(string $userUuid, array $planUuids): Collection
    {
        $planUuids = array_values(array_unique($planUuids));
        $query = UserPlanAccess::query()
            ->withTrashed()
            ->where('user_uuid', $userUuid);

        if ($planUuids === []) {
            $query->get()->each(fn (UserPlanAccess $access) => $this->softDelete($access));

            return collect();
        }

        (clone $query)
            ->whereNotIn('plan_uuid', $planUuids)
            ->get()
            ->each(fn (UserPlanAccess $access) => $this->softDelete($access));

        foreach ($planUuids as $planUuid) {
            $this->assign($userUuid, $planUuid);
        }

        return UserPlanAccess::query()
            ->where('user_uuid', $userUuid)
            ->whereIn('plan_uuid', $planUuids)
            ->where('is_deleted', false)
            ->orderBy('created_at')
            ->get();
    }

    private function softDelete(UserPlanAccess $access): void
    {
        if ($access->trashed() && $access->is_deleted) {
            return;
        }

        $access->forceFill(['is_deleted' => true])->save();
        if (! $access->trashed()) {
            $access->delete();
        }
    }
}
