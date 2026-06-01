<?php

namespace Database\Factories;

use App\Enums\AccessLevel;
use App\Models\Company;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;

/**
 * @extends Factory<User>
 */
class UserFactory extends Factory
{
    protected static ?string $password;

    public function definition(): array
    {
        return [
            'uuid' => (string) Str::uuid(),
            'company_id' => Company::factory(),
            'name' => fake()->name(),
            'phone' => fake()->unique()->numerify('03#########'),
            'email' => fake()->unique()->safeEmail(),
            'password' => static::$password ??= Hash::make('password'),
            'first_name' => fake()->firstName(),
            'last_name' => fake()->lastName(),
            'access_level' => AccessLevel::Salesman->value,
            'role' => AccessLevel::Salesman->value,
            'status' => 'active',
            'is_active' => true,
            'is_deleted' => false,
            'remember_token' => Str::random(10),
        ];
    }

    public function owner(): static
    {
        return $this
            ->state(fn (): array => [
                'access_level' => AccessLevel::Owner->value,
                'role' => AccessLevel::Owner->value,
            ])
            ->afterCreating(function (User $user): void {
                $user->company()->update(['owner_id' => $user->id]);
            });
    }
}
