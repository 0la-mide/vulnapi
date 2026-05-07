<?php

use App\Http\Controllers\AuthController;
use App\Http\Controllers\NoteController;
use App\Http\Controllers\AdminController;
use Illuminate\Support\Facades\Route;

// PUBLIC ROUTES (anyone can use these)
Route::post('/register', [AuthController::class, 'register']);
Route::post('/login', [AuthController::class, 'login']);  // ❌ V5: No rate limiting

// PROTECTED ROUTES (you must be logged in)
Route::middleware('auth:api')->group(function () {
    
    // Auth endpoints
    Route::post('/logout', [AuthController::class, 'logout']);
    Route::get('/me', [AuthController::class, 'me']);
    
    // Note endpoints
    Route::get('/notes', [NoteController::class, 'index']);
    Route::post('/notes', [NoteController::class, 'store']);
    Route::get('/notes/{id}', [NoteController::class, 'show']);      // ❌ V2: IDOR
    Route::put('/notes/{id}', [NoteController::class, 'update']);    // ❌ V2: IDOR
    Route::delete('/notes/{id}', [NoteController::class, 'destroy']); // ❌ V2: IDOR
    
    // Search (has SQL injection)
    Route::get('/search', [NoteController::class, 'search']);        // ❌ V1: SQL Injection
    
    // Admin route (missing role check)
    Route::get('/admin/users', [AdminController::class, 'listUsers']); // ❌ V3: No admin check
});