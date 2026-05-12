<?php

namespace App\Models;

use App\Traits\HasUuid;
use App\Traits\LogsSyncChanges;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsToMany;
use Illuminate\Database\Eloquent\SoftDeletes;

class ProductCategory extends Model
{
    use HasFactory;
    use HasUuid;
    use LogsSyncChanges;
    use SoftDeletes;

    protected $fillable = [
        'uuid',
        'name',
        'is_deleted',
    ];

    protected function casts(): array
    {
        return [
            'is_deleted' => 'boolean',
        ];
    }

    public function products(): BelongsToMany
    {
        return $this->belongsToMany(Product::class, 'product_category_map', 'category_uuid', 'product_uuid', 'uuid', 'uuid')
            ->withTimestamps();
    }
}
