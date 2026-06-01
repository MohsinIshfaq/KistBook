<?php

namespace App\Services;

use App\Contracts\Repositories\UserRepositoryInterface;
use App\Contracts\Services\AuthServiceInterface;
use App\Enums\AccessLevel;
use App\Models\Company;
use App\Models\User;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Symfony\Component\HttpKernel\Exception\UnauthorizedHttpException;

class AuthService implements AuthServiceInterface
{
    public function __construct(private readonly UserRepositoryInterface $users) {}

    public function register(array $data): array
    {
        return DB::transaction(function () use ($data): array {
            $company = Company::query()->create([
                'name' => $data['company_name'] ?? $data['name'].' Shop',
                'phone' => $data['company_phone'] ?? null,
                'email' => $data['email'],
                'address' => $data['company_address'] ?? null,
                'status' => 'active',
            ]);
            [$firstName, $lastName] = $this->splitName($data['name']);
            $user = $this->users->create([
                'company_id' => $company->id,
                'name' => $data['name'],
                'email' => $data['email'],
                'phone' => $data['phone'],
                'password' => $data['password'],
                'first_name' => $firstName,
                'last_name' => $lastName,
                'role' => AccessLevel::Owner,
                'status' => 'active',
                'access_level' => AccessLevel::Owner,
                'is_active' => true,
                'is_deleted' => false,
            ]);
            $company->update(['owner_id' => $user->id]);

            return [
                'user' => $user->load('company'),
                'company' => $company->refresh(),
                'token' => $user->createToken('mobile-api-token')->plainTextToken,
            ];
        });
    }

    public function login(array $credentials): array
    {
        $user = $this->users->findByLogin($credentials['login']);

        if (! $user || ! Hash::check($credentials['password'], $user->password)) {
            throw new UnauthorizedHttpException('', 'Invalid email, phone number, or password.');
        }

        if (! $user->is_active || $user->status !== 'active') {
            throw new UnauthorizedHttpException('', 'This user account is inactive.');
        }

        return [
            'user' => $user->load('company'),
            'company' => $user->company,
            'token' => $user->createToken('mobile-api-token')->plainTextToken,
        ];
    }

    public function logout(User $user): void
    {
        $user->currentAccessToken()?->delete();
    }

    public function updateProfile(User $user, array $data): User
    {
        $firstName = $data['first_name'] ?? $user->first_name;
        $lastName = array_key_exists('last_name', $data) ? $data['last_name'] : $user->last_name;
        $data['name'] = trim(implode(' ', array_filter([$firstName, $lastName])));

        return $this->users->update($user, $data)->load('company');
    }

    /**
     * @return array{0: string, 1: string|null}
     */
    private function splitName(string $name): array
    {
        $parts = preg_split('/\s+/', trim($name), 2) ?: [];

        return [$parts[0] ?? '', $parts[1] ?? null];
    }
}
