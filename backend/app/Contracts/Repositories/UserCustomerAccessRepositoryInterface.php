<?php

namespace App\Contracts\Repositories;

use App\Models\UserCustomerAccess;
use Illuminate\Support\Collection;

interface UserCustomerAccessRepositoryInterface
{
    public function assign(string $userUuid, string $customerUuid): UserCustomerAccess;

    /**
     * @param  array<int, string>  $customerUuids
     * @return Collection<int, UserCustomerAccess>
     */
    public function replaceForUser(string $userUuid, array $customerUuids): Collection;
}
