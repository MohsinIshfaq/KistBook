<?php

namespace App\Repositories;

use App\Contracts\Repositories\UserCustomerAccessRepositoryInterface;
use App\Models\UserCustomerAccess;
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
}
