<?php

namespace App\Enums;

enum AccessLevel: string
{
    case Owner = 'owner';
    case Admin = 'admin';
    case Salesman = 'salesman';
}
