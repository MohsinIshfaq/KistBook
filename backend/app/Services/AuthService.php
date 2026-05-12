<?php

namespace App\Services;

use App\Contracts\Repositories\UserRepositoryInterface;
use App\Contracts\Services\AuthServiceInterface;
use App\Models\User;
use Illuminate\Support\Facades\Hash;
use Symfony\Component\HttpKernel\Exception\UnauthorizedHttpException;

class AuthService implements AuthServiceInterface
{
    public function __construct(private readonly UserRepositoryInterface $users)
    {
    }

    public function register(array $data): array
    {
        $user = $this->users->create($data);

        return [
            'user' => $user,
            'token' => $user->createToken('mobile-api-token')->plainTextToken,
        ];
    }

    public function login(array $credentials): array
    {
        $user = $this->users->findByPhone($credentials['phone']);

        if (! $user || ! Hash::check($credentials['password'], $user->password)) {
            throw new UnauthorizedHttpException('', 'Invalid phone or password.');
        }

        if (! $user->is_active) {
            throw new UnauthorizedHttpException('', 'This user account is inactive.');
        }

        return [
            'user' => $user,
            'token' => $user->createToken('mobile-api-token')->plainTextToken,
        ];
    }

    public function logout(User $user): void
    {
        $user->currentAccessToken()?->delete();
    }
}
