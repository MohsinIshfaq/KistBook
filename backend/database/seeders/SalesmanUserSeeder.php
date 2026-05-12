<?php

namespace Database\Seeders;

use App\Enums\AccessLevel;
use App\Models\User;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;

class SalesmanUserSeeder extends Seeder
{
    public function run(): void
    {
        User::query()->updateOrCreate(
            ['phone' => '03000000002'],
            [
                'uuid' => (string) Str::uuid(),
                'email' => 'sales@kistbook.test',
                'password' => Hash::make('password'),
                'first_name' => 'Sales',
                'last_name' => 'Man',
                'access_level' => AccessLevel::Salesman->value,
                'is_active' => true,
                'is_deleted' => false,
            ],
        );
    }
}
