<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class DeviceSyncState extends Model
{
    use HasFactory;

    protected $table = 'device_sync_state';

    protected $fillable = [
        'user_uuid',
        'device_id',
        'last_pulled_at',
        'last_push_ack_at',
        'last_cursor',
    ];

    protected function casts(): array
    {
        return [
            'last_pulled_at' => 'datetime',
            'last_push_ack_at' => 'datetime',
        ];
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class, 'user_uuid', 'uuid');
    }
}
