<?php

namespace Database\Seeders;

use App\Enums\AccessLevel;
use App\Models\Company;
use App\Models\User;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;

class AdminUserSeeder extends Seeder
{
    public function run(): void
    {
        $company = Company::query()->firstOrCreate(
            ['email' => 'admin@kistbook.test'],
            [
                'uuid' => (string) Str::uuid(),
                'name' => 'KistBook Demo Company',
                'phone' => '03000000001',
                'address' => 'Bahawalpur',
                'status' => 'active',
            ],
        );
        $owner = User::query()->updateOrCreate(
            ['phone' => '03000000001'],
            [
                'uuid' => (string) Str::uuid(),
                'company_id' => $company->id,
                'name' => 'Owner User',
                'email' => 'admin@kistbook.test',
                'password' => Hash::make('password'),
                'first_name' => 'Owner',
                'last_name' => 'User',
                'access_level' => AccessLevel::Owner->value,
                'role' => AccessLevel::Owner->value,
                'status' => 'active',
                'is_active' => true,
                'is_deleted' => false,
            ],
        );
        $company->update(['owner_id' => $owner->id]);
    }
}
