<?php

namespace App\Services;

use App\Contracts\Services\CustomerServiceInterface;
use App\Contracts\Repositories\CustomerRepositoryInterface;
use App\Models\Customer;
use App\Models\User;
use Illuminate\Support\Facades\Gate;

class CustomerService implements CustomerServiceInterface
{
    public function __construct(private readonly CustomerRepositoryInterface $customers) {}

    public function show(User $actor, string $uuid): Customer
    {
        $customer = $this->customers->findAccessibleByUuidOrFail($actor, $uuid, ['plans.installments', 'payments', 'users']);
        Gate::forUser($actor)->authorize('view', $customer);

        return $customer;
    }
}
