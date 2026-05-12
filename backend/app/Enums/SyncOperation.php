<?php

namespace App\Enums;

enum SyncOperation: string
{
    case Created = 'created';
    case Updated = 'updated';
    case Deleted = 'deleted';
}
