<?php

namespace App\Services;

use App\Models\Customer;
use App\Models\Plan;
use App\Models\Product;
use App\Models\User;
use App\Models\UserCustomerAccess;
use App\Models\UserPlanAccess;
use Illuminate\Database\Eloquent\Builder;

class RuntimeBootstrapService
{
    public function __construct(
        private readonly CustomerSyncService $customers,
        private readonly ProductSyncService $products,
        private readonly InstallmentPlanSyncService $plans,
    ) {}

    public function bootstrap(User $actor): array
    {
        $customers = $this->customerQuery($actor)
            ->where('is_deleted', false)
            ->orderBy('updated_at')
            ->orderBy('uuid')
            ->get()
            ->map(fn (Customer $customer): array => $this->customers->serialize($customer))
            ->values()
            ->all();

        $products = Product::query()
            ->where('is_deleted', false)
            ->with(['categories', 'images', 'variants.attributes', 'priceHistory'])
            ->orderBy('updated_at')
            ->orderBy('uuid')
            ->get()
            ->map(fn (Product $product): array => $this->products->serialize($product))
            ->values()
            ->all();

        $plans = $this->planQuery($actor)
            ->where('is_deleted', false)
            ->whereIn('mode', ['common', 'separate'])
            ->with(['customer', 'items.product', 'items.variant.attributes', 'installments'])
            ->orderBy('updated_at')
            ->orderBy('uuid')
            ->get()
            ->map(fn (Plan $plan): array => $this->plans->serialize($plan))
            ->values()
            ->all();

        return [
            'serverTime' => now()->toJSON(),
            'users' => $this->users($actor),
            'customerAccess' => $this->customerAccess($actor),
            'planAccess' => $this->planAccess($actor),
            'customers' => $customers,
            'products' => $products,
            'installmentPlans' => $plans,
        ];
    }

    private function customerQuery(User $actor): Builder
    {
        return Customer::query()
            ->when($actor->isSalesman(), function (Builder $query) use ($actor): void {
                $query->where(function (Builder $query) use ($actor): void {
                    $query
                        ->whereHas('users', function (Builder $query) use ($actor): void {
                            $query
                                ->where('users.uuid', $actor->uuid)
                                ->where('user_customer_access.is_deleted', false);
                        })
                        ->orWhereHas('plans.users', function (Builder $query) use ($actor): void {
                            $query
                                ->where('users.uuid', $actor->uuid)
                                ->where('user_plan_access.is_deleted', false);
                        });
                });
            });
    }

    private function planQuery(User $actor): Builder
    {
        return Plan::query()
            ->when($actor->isSalesman(), function (Builder $query) use ($actor): void {
                $query->whereHas('users', function (Builder $query) use ($actor): void {
                    $query
                        ->where('users.uuid', $actor->uuid)
                        ->where('user_plan_access.is_deleted', false);
                });
            });
    }

    private function users(User $actor): array
    {
        $query = User::query()
            ->where('company_id', $actor->company_id)
            ->where('is_deleted', false);

        if ($actor->isSalesman()) {
            $query->where('uuid', $actor->uuid);
        }

        return $query
            ->orderBy('updated_at')
            ->get()
            ->map(fn (User $user): array => [
                'serverId' => $user->uuid,
                'uuid' => $user->uuid,
                'phoneNumber' => $user->phone,
                'email' => $user->email,
                'firstName' => $user->first_name,
                'lastName' => $user->last_name,
                'role' => $user->role instanceof \BackedEnum ? $user->role->value : $user->role,
                'isActive' => (bool) $user->is_active,
                'isDeleted' => (bool) $user->is_deleted,
                'createdAt' => $user->created_at?->toJSON(),
                'updatedAt' => $user->updated_at?->toJSON(),
            ])
            ->values()
            ->all();
    }

    private function customerAccess(User $actor): array
    {
        return UserCustomerAccess::query()
            ->where('is_deleted', false)
            ->when($actor->isSalesman(), fn (Builder $query) => $query->where('user_uuid', $actor->uuid))
            ->orderBy('updated_at')
            ->get()
            ->map(fn (UserCustomerAccess $access): array => [
                'serverId' => $access->uuid,
                'userId' => $access->user_uuid,
                'customerId' => $access->customer_uuid,
                'isDeleted' => (bool) $access->is_deleted,
                'createdAt' => $access->created_at?->toJSON(),
                'updatedAt' => $access->updated_at?->toJSON(),
            ])
            ->values()
            ->all();
    }

    private function planAccess(User $actor): array
    {
        return UserPlanAccess::query()
            ->where('is_deleted', false)
            ->when($actor->isSalesman(), fn (Builder $query) => $query->where('user_uuid', $actor->uuid))
            ->orderBy('updated_at')
            ->get()
            ->map(fn (UserPlanAccess $access): array => [
                'serverId' => $access->uuid,
                'userId' => $access->user_uuid,
                'planId' => $access->plan_uuid,
                'isDeleted' => (bool) $access->is_deleted,
                'createdAt' => $access->created_at?->toJSON(),
                'updatedAt' => $access->updated_at?->toJSON(),
            ])
            ->values()
            ->all();
    }
}
