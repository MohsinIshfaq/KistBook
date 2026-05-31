<?php

namespace App\Models;

use App\Traits\HasUuid;
use App\Traits\LogsSyncChanges;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\SoftDeletes;

class ProductImage extends Model
{
    use HasUuid;
    use LogsSyncChanges;
    use SoftDeletes;

    protected $fillable = [
        'uuid',
        'product_uuid',
        'disk',
        'path',
        'original_name',
        'mime_type',
        'size',
        'sort_order',
        'is_deleted',
    ];

    protected function casts(): array
    {
        return [
            'size' => 'integer',
            'sort_order' => 'integer',
            'is_deleted' => 'boolean',
        ];
    }

    public function product(): BelongsTo
    {
        return $this->belongsTo(Product::class, 'product_uuid', 'uuid');
    }
}
