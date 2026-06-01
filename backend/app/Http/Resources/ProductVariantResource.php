<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class ProductVariantResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'uuid' => $this->uuid,
            'skuCode' => $this->sku_code,
            'salePrice' => (float) $this->sale_price,
            'attributes' => ProductVariantAttributeResource::collection($this->whenLoaded('attributes')),
        ];
    }
}
