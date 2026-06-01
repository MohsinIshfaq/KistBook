<?php

namespace App\Contracts\Services;

use App\Models\Customer;
use App\Models\User;

interface CustomerServiceInterface
{
    public function show(User $actor, string $uuid): Customer;
}
