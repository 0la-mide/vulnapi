<?php

namespace App\Http\Controllers;

use App\Models\User;

class AdminController extends Controller
{
    public function listUsers()
    {
        // ❌ VULNERABILITY V3 — No admin role check
        // ANY logged-in user can see ALL users!
        // Should only be for admins, but we forgot to check
        $users = User::all();
        return response()->json($users);
    }
}