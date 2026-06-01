<?php

namespace App\Repositories;

use App\Contracts\Repositories\UserRepositoryInterface;
use App\Models\User;
use Illuminate\Support\Str;

class UserRepository implements UserRepositoryInterface
{
    public function create(array $data): User
    {
        $data['uuid'] ??= (string) Str::uuid();

        return User::query()->create($data);
    }

    public function findByPhone(string $phone): ?User
    {
        return User::query()->where('phone', $phone)->first();
    }

    public function findByLogin(string $login): ?User
    {
        return User::query()
            ->where('email', $login)
            ->orWhere('phone', $login)
            ->first();
    }

    public function findByUuidOrFail(string $uuid): User
    {
        return User::query()->where('uuid', $uuid)->firstOrFail();
    }
}
