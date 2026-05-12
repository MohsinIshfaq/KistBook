<?php

namespace Database\Seeders;

use App\Enums\AccessLevel;
use App\Models\User;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;

class AdminUserSeeder extends Seeder
{
    public function run(): void
    {
        User::query()->updateOrCreate(
            ['phone' => '03000000001'],
            [
                'uuid' => (string) Str::uuid(),
                'email' => 'admin@kistbook.test',
                'password' => Hash::make('password'),
                'first_name' => 'Admin',
                'last_name' => 'User',
                'access_level' => AccessLevel::Admin->value,
                'is_active' => true,
                'is_deleted' => false,
            ],
        );
    }
}
