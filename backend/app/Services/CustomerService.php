<?php

namespace App\Services;

use App\Contracts\Repositories\CustomerRepositoryInterface;
use App\Contracts\Services\CustomerServiceInterface;
use App\Models\Customer;
use Illuminate\Contracts\Pagination\LengthAwarePaginator;

class CustomerService implements CustomerServiceInterface
{
    public function __construct(private readonly CustomerRepositoryInterface $customers)
    {
    }

    public function list(int $perPage = 15): LengthAwarePaginator
    {
        return $this->customers->paginate($perPage, ['plans', 'users']);
    }

    public function create(array $data): Customer
    {
        return $this->customers->create($data);
    }

    public function show(string $uuid): Customer
    {
        return $this->customers->findByUuidOrFail($uuid, ['plans.installments', 'payments', 'users']);
    }

    public function update(string $uuid, array $data): Customer
    {
        $customer = $this->customers->findByUuidOrFail($uuid);

        return $this->customers->update($customer, $data);
    }

    public function delete(string $uuid): void
    {
        $customer = $this->customers->findByUuidOrFail($uuid);
        $this->customers->softDelete($customer);
    }
}
