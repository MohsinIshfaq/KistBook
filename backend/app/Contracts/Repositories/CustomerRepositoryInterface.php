<?php

namespace App\Contracts\Repositories;

use App\Models\Customer;
use App\Models\User;

interface CustomerRepositoryInterface extends UuidRepositoryInterface
{
    public function findAccessibleByUuidOrFail(User $actor, string $uuid, array $with = [], bool $withTrashed = false): Customer;
}
