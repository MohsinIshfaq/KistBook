<?php

namespace App\Repositories;

use App\Contracts\Repositories\CustomerRepositoryInterface;
use App\Models\Customer;
use App\Models\User;
use Illuminate\Database\Eloquent\Builder;

class CustomerRepository extends BaseRepository implements CustomerRepositoryInterface
{
    public function __construct(Customer $customer)
    {
        parent::__construct($customer);
    }

    public function findAccessibleByUuidOrFail(User $actor, string $uuid, array $with = [], bool $withTrashed = false): Customer
    {
        $query = $this->accessibleQuery($actor)->with($with);
        if ($withTrashed) {
            $query->withTrashed();
        }

        return $query->where('uuid', $uuid)->firstOrFail();
    }

    private function accessibleQuery(User $actor): Builder
    {
        return $this->model
            ->newQuery()
            ->when($actor->isSalesman(), function (Builder $query) use ($actor): void {
                $query->whereHas('users', function (Builder $query) use ($actor): void {
                    $query
                        ->where('users.uuid', $actor->uuid)
                        ->where('user_customer_access.is_deleted', false);
                });
            });
    }
}
