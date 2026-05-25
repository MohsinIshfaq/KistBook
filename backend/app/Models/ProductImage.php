<?php

namespace App\Models;

use App\Traits\HasUuid;
use App\Traits\LogsSyncChanges;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class ProductImage extends Model
{
    use HasUuid;
    use LogsSyncChanges;

    protected $fillable = [
        'uuid',
        'product_uuid',
        'disk',
        'path',
        'original_name',
        'mime_type',
        'size',
        'sort_order',
    ];

    protected function casts(): array
    {
        return [
            'size' => 'integer',
            'sort_order' => 'integer',
        ];
    }

    public function product(): BelongsTo
    {
        return $this->belongsTo(Product::class, 'product_uuid', 'uuid');
    }
}
