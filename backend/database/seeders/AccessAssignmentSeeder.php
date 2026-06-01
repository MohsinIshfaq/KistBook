<?php

namespace Database\Seeders;

use App\Contracts\Services\AccessServiceInterface;
use App\Models\Customer;
use App\Models\Plan;
use App\Models\User;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\Auth;

class AccessAssignmentSeeder extends Seeder
{
    public function run(): void
    {
        $service = app(AccessServiceInterface::class);
        $owner = User::query()->where('phone', '03000000001')->first();
        $salesman = User::query()->where('phone', '03000000002')->first();

        if (! $owner || ! $salesman) {
            return;
        }

        Auth::setUser($owner);
        try {
            Customer::query()->take(5)->get()->each(function (Customer $customer) use ($service, $salesman): void {
                $service->assignCustomer($salesman->uuid, $customer->uuid);
            });

            Plan::query()->take(5)->get()->each(function (Plan $plan) use ($service, $salesman): void {
                $service->assignPlan($salesman->uuid, $plan->uuid);
            });
        } finally {
            Auth::forgetUser();
        }
    }
}
