<?php

namespace App\Policies;

use App\Models\Customer;
use App\Models\User;
use App\Models\UserCustomerAccess;

class CustomerPolicy
{
    public function viewAny(User $user): bool
    {
        return $user->company_id !== null;
    }

    public function create(User $user): bool
    {
        return $user->company_id !== null;
    }

    public function view(User $user, Customer $customer): bool
    {
        return $this->canAccess($user, $customer);
    }

    public function update(User $user, Customer $customer): bool
    {
        return $this->canAccess($user, $customer);
    }

    public function delete(User $user, Customer $customer): bool
    {
        return $this->canAccess($user, $customer);
    }

    private function canAccess(User $user, Customer $customer): bool
    {
        if ($user->company_id === null || $customer->company_id !== $user->company_id) {
            return false;
        }

        if ($user->isOwner()) {
            return true;
        }

        return UserCustomerAccess::query()
            ->where('user_uuid', $user->uuid)
            ->where('customer_uuid', $customer->uuid)
            ->where('is_deleted', false)
            ->exists();
    }
}
