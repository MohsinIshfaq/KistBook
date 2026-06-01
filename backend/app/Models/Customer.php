<?php

namespace App\Models;

use App\Traits\BelongsToCompany;
use App\Traits\HasUuid;
use App\Traits\LogsSyncChanges;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsToMany;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\SoftDeletes;

class Customer extends Model
{
    use BelongsToCompany;
    use HasFactory;
    use HasUuid;
    use LogsSyncChanges;
    use SoftDeletes;

    protected $fillable = [
        'uuid',
        'company_id',
        'card_no',
        'name',
        'phone',
        'cnic',
        'address',
        'reference',
        'image_disk',
        'image_path',
        'image_original_name',
        'image_mime_type',
        'image_size',
        'is_deleted',
    ];

    protected function casts(): array
    {
        return [
            'is_deleted' => 'boolean',
            'image_size' => 'integer',
        ];
    }

    public function plans(): HasMany
    {
        return $this->hasMany(Plan::class, 'customer_uuid', 'uuid');
    }

    public function payments(): HasMany
    {
        return $this->hasMany(Payment::class, 'customer_uuid', 'uuid');
    }

    public function users(): BelongsToMany
    {
        return $this->belongsToMany(User::class, 'user_customer_access', 'customer_uuid', 'user_uuid', 'uuid', 'uuid')
            ->withPivot(['uuid', 'is_deleted'])
            ->withTimestamps();
    }
}
