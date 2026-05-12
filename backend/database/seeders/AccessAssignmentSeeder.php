<?php

namespace Database\Seeders;

use App\Contracts\Services\AccessServiceInterface;
use App\Models\Customer;
use App\Models\Plan;
use App\Models\User;
use Illuminate\Database\Seeder;

class AccessAssignmentSeeder extends Seeder
{
    public function run(): void
    {
        $service = app(AccessServiceInterface::class);
        $salesman = User::query()->where('phone', '03000000002')->first();

        if (! $salesman) {
            return;
        }

        Customer::query()->take(5)->get()->each(function (Customer $customer) use ($service, $salesman): void {
            $service->assignCustomer($salesman->uuid, $customer->uuid);
        });

        Plan::query()->take(5)->get()->each(function (Plan $plan) use ($service, $salesman): void {
            $service->assignPlan($salesman->uuid, $plan->uuid);
        });
    }
}
