<?php

namespace App\Http\Controllers\Api;

use App\Contracts\Repositories\UserRepositoryInterface;
use App\Enums\AccessLevel;
use App\Http\Controllers\Controller;
use App\Http\Requests\CompanyUsers\StoreCompanyUserRequest;
use App\Http\Resources\UserResource;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\DB;

class CompanyUserController extends Controller
{
    public function __construct(private readonly UserRepositoryInterface $users) {}

    public function store(StoreCompanyUserRequest $request): JsonResponse
    {
        $owner = $request->user();
        $data = $request->validated();
        $user = DB::transaction(function () use ($data, $owner) {
            [$firstName, $lastName] = $this->splitName($data['name']);

            return $this->users->create([
                'company_id' => $owner->company_id,
                'name' => $data['name'],
                'email' => $data['email'],
                'phone' => $data['phone'],
                'password' => $data['password'],
                'first_name' => $firstName,
                'last_name' => $lastName,
                'role' => AccessLevel::Salesman,
                'status' => 'active',
                'access_level' => AccessLevel::Salesman,
                'is_active' => true,
                'is_deleted' => false,
            ]);
        });

        return response()->json([
            'success' => true,
            'message' => 'Salesman user created successfully.',
            'user' => new UserResource($user),
        ], 201);
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
