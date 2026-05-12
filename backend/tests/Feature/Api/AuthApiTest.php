<?php

namespace Tests\Feature\Api;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class AuthApiTest extends TestCase
{
    use RefreshDatabase;

    public function test_user_can_register_login_and_view_profile(): void
    {
        $registerResponse = $this->postJson('/api/auth/register', [
            'phone' => '03001234567',
            'email' => 'tester@example.com',
            'password' => 'password',
            'first_name' => 'Test',
            'last_name' => 'User',
            'access_level' => 'salesman',
        ]);

        $registerResponse->assertCreated()->assertJsonPath('success', true);

        $loginResponse = $this->postJson('/api/auth/login', [
            'phone' => '03001234567',
            'password' => 'password',
        ]);

        $token = $loginResponse->json('data.token');

        $this->withHeader('Authorization', 'Bearer '.$token)
            ->getJson('/api/me')
            ->assertOk()
            ->assertJsonPath('data.phone', '03001234567');
    }
}
