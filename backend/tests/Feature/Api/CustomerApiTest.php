<?php

namespace Tests\Feature\Api;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class CustomerApiTest extends TestCase
{
    use RefreshDatabase;

    public function test_authenticated_user_can_create_and_fetch_customer(): void
    {
        Sanctum::actingAs(User::factory()->create());

        $createResponse = $this->postJson('/api/customers', [
            'card_no' => 'CARD-1001',
            'name' => 'Ali Khan',
            'phone' => '03005551234',
            'cnic' => '12345-1234567-1',
            'address' => 'Lahore',
            'reference' => 'Friend',
        ]);

        $createResponse->assertCreated()->assertJsonPath('success', true);
        $uuid = $createResponse->json('data.uuid');

        $this->getJson('/api/customers/'.$uuid)
            ->assertOk()
            ->assertJsonPath('data.name', 'Ali Khan');
    }
}
