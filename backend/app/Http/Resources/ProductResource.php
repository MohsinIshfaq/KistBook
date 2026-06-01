<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class ProductResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'uuid' => $this->uuid,
            'basePrice' => (float) ($this->base_price ?? $this->sales_price),
            'skuCode' => $this->code,
            'brandName' => $this->brand_name,
            'productName' => $this->product_name,
            'categoryId' => $this->primary_category_uuid,
            'notes' => $this->notes,
            'categories' => ProductCategoryResource::collection($this->whenLoaded('categories')),
            'images' => ProductImageResource::collection($this->whenLoaded('images')),
            'variants' => ProductVariantResource::collection($this->whenLoaded('variants')),
            'primaryImage' => $this->whenLoaded(
                'images',
                fn () => $this->images->isEmpty() ? null : new ProductImageResource($this->images->first())
            ),
            'plans' => PlanResource::collection($this->whenLoaded('plans')),
            'createdAt' => $this->created_at,
            'updatedAt' => $this->updated_at,
        ];
    }
}
