<?php

namespace Tests\Feature\Api;

use App\Models\ProductCategory;
use App\Models\ProductImage;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class ProductApiTest extends TestCase
{
    use RefreshDatabase;

    public function test_authenticated_user_can_create_product_with_ordered_images(): void
    {
        Storage::fake('public');
        Sanctum::actingAs(User::factory()->create());

        $category = ProductCategory::factory()->create();

        $response = $this->post('/api/products', [
            'brand_name' => 'Oppo',
            'product_name' => 'Reno 13',
            'code' => 'REN-13',
            'sales_price' => 118000,
            'notes' => 'Display unit',
            'category_uuids' => [$category->uuid],
            'images' => [
                UploadedFile::fake()->image('front.jpg', 800, 800),
                UploadedFile::fake()->image('side.png', 800, 800),
            ],
        ], ['Accept' => 'application/json']);

        $response
            ->assertCreated()
            ->assertJsonPath('success', true)
            ->assertJsonCount(2, 'data.images')
            ->assertJsonPath('data.images.0.sort_order', 0)
            ->assertJsonPath('data.images.0.is_primary', true)
            ->assertJsonPath('data.images.1.sort_order', 1)
            ->assertJsonPath('data.primary_image.sort_order', 0);

        ProductImage::query()->get()->each(function (ProductImage $image): void {
            Storage::disk('public')->assertExists($image->path);
        });
    }

    public function test_authenticated_user_can_reorder_remove_and_append_product_images(): void
    {
        Storage::fake('public');
        Sanctum::actingAs(User::factory()->create());

        $createResponse = $this->post('/api/products', [
            'brand_name' => 'Oppo',
            'product_name' => 'Reno 13',
            'code' => 'REN-13',
            'sales_price' => 118000,
            'images' => [
                UploadedFile::fake()->image('front.jpg', 800, 800),
                UploadedFile::fake()->image('back.jpg', 800, 800),
            ],
        ], ['Accept' => 'application/json']);

        $productUuid = $createResponse->json('data.uuid');
        $firstImageUuid = $createResponse->json('data.images.0.uuid');
        $firstImagePath = $createResponse->json('data.images.0.path');
        $secondImageUuid = $createResponse->json('data.images.1.uuid');

        $updateResponse = $this->post('/api/products/'.$productUuid, [
            'product_name' => 'Reno 13 Pro',
            'image_uuids' => [$secondImageUuid],
            'images' => [
                UploadedFile::fake()->image('box.jpg', 800, 800),
            ],
        ], ['Accept' => 'application/json']);

        $updateResponse
            ->assertOk()
            ->assertJsonPath('data.product_name', 'Reno 13 Pro')
            ->assertJsonCount(2, 'data.images')
            ->assertJsonPath('data.images.0.uuid', $secondImageUuid)
            ->assertJsonPath('data.images.0.sort_order', 0)
            ->assertJsonPath('data.images.1.sort_order', 1);

        Storage::disk('public')->assertMissing($firstImagePath);
        $this->assertDatabaseMissing('product_images', ['uuid' => $firstImageUuid]);
        Storage::disk('public')->assertExists($updateResponse->json('data.images.1.path'));
    }
}
