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
            'brand_name' => $this->brand_name,
            'product_name' => $this->product_name,
            'code' => $this->code,
            'sales_price' => (float) $this->sales_price,
            'notes' => $this->notes,
            'categories' => ProductCategoryResource::collection($this->whenLoaded('categories')),
            'plans' => PlanResource::collection($this->whenLoaded('plans')),
            'created_at' => $this->created_at,
            'updated_at' => $this->updated_at,
        ];
    }
}
