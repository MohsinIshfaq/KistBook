<?php

namespace App\Repositories;

use App\Contracts\Repositories\UserCustomerAccessRepositoryInterface;
use App\Models\UserCustomerAccess;
use Illuminate\Support\Collection;
use Illuminate\Support\Str;

class UserCustomerAccessRepository implements UserCustomerAccessRepositoryInterface
{
    public function assign(string $userUuid, string $customerUuid): UserCustomerAccess
    {
        $assignment = UserCustomerAccess::query()->withTrashed()->firstOrCreate(
            ['user_uuid' => $userUuid, 'customer_uuid' => $customerUuid],
            ['uuid' => (string) Str::uuid(), 'is_deleted' => false],
        );
        if ($assignment->trashed() || $assignment->is_deleted) {
            $assignment->restore();
            $assignment->forceFill(['is_deleted' => false])->save();
        }

        return $assignment;
    }

    public function replaceForUser(string $userUuid, array $customerUuids): Collection
    {
        $customerUuids = array_values(array_unique($customerUuids));
        $query = UserCustomerAccess::query()
            ->withTrashed()
            ->where('user_uuid', $userUuid);

        if ($customerUuids === []) {
            $query->get()->each(fn (UserCustomerAccess $access) => $this->softDelete($access));

            return collect();
        }

        (clone $query)
            ->whereNotIn('customer_uuid', $customerUuids)
            ->get()
            ->each(fn (UserCustomerAccess $access) => $this->softDelete($access));

        foreach ($customerUuids as $customerUuid) {
            $this->assign($userUuid, $customerUuid);
        }

        return UserCustomerAccess::query()
            ->where('user_uuid', $userUuid)
            ->whereIn('customer_uuid', $customerUuids)
            ->where('is_deleted', false)
            ->orderBy('created_at')
            ->get();
    }

    private function softDelete(UserCustomerAccess $access): void
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
