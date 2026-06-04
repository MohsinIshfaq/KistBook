<?php

namespace Tests\Feature\Api;

use App\Models\Product;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class ProductApiTest extends TestCase
{
    use RefreshDatabase;

    public function test_authenticated_user_can_fetch_product_detail(): void
    {
        $owner = User::factory()->owner()->create();
        $product = Product::factory()->create([
            'company_id' => $owner->company_id,
            'product_name' => 'Reno 13',
            'sales_price' => 145000,
        ]);
        Sanctum::actingAs($owner);

        $this->getJson('/api/products/'.$product->uuid)
            ->assertOk()
            ->assertJsonPath('data.productName', 'Reno 13')
            ->assertJsonPath('data.salesPrice', 145000);
    }

    public function test_direct_product_mutation_and_list_routes_are_not_exposed(): void
    {
        $owner = User::factory()->owner()->create();
        $product = Product::factory()->create(['company_id' => $owner->company_id]);
        Sanctum::actingAs($owner);

        $this->getJson('/api/products')->assertNotFound();
        $this->postJson('/api/products', [])->assertNotFound();
        $this->patchJson('/api/products/'.$product->uuid, [])->assertStatus(405);
        $this->deleteJson('/api/products/'.$product->uuid)->assertStatus(405);
    }
}
