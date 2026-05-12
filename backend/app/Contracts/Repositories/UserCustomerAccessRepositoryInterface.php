<?php

namespace App\Contracts\Repositories;

use App\Models\UserCustomerAccess;

interface UserCustomerAccessRepositoryInterface
{
    public function assign(string $userUuid, string $customerUuid): UserCustomerAccess;
}
