<?php

namespace Database\Seeders;

use App\Models\Customer;
use App\Models\User;
use Illuminate\Database\Seeder;

class CustomerSeeder extends Seeder
{
    public function run(): void
    {
        $companyId = User::query()->where('phone', '03000000001')->value('company_id');

        Customer::factory()->count(10)->create(['company_id' => $companyId]);
    }
}
