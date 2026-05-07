<?php

namespace App\Http\Controllers;

use App\Models\Note;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class NoteController extends Controller
{
    public function index()
    {
        // This one is fine - only shows YOUR notes
        $notes = Note::where('user_id', auth()->id())->get();
        return response()->json($notes);
    }

    public function store(Request $request)
    {
        $request->validate([
            'title' => 'required|string|max:255',
            'body' => 'required|string',
        ]);

        $note = Note::create([
            'user_id' => auth()->id(),
            'title' => $request->title,
            'body' => $request->body,
        ]);

        return response()->json($note, 201);
    }

    public function show($id)
    {
        // ❌ VULNERABILITY V2 — IDOR (Insecure Direct Object Reference)
        // No check that this note belongs to YOU!
        // You can see ANY note by guessing its ID number
        $note = Note::findOrFail($id);
        return response()->json($note);
    }

    public function update(Request $request, $id)
    {
        // ❌ VULNERABILITY V2 — IDOR on update
        $note = Note::findOrFail($id);

        $request->validate([
            'title' => 'sometimes|string|max:255',
            'body' => 'sometimes|string',
        ]);

        $note->update($request->only(['title', 'body']));
        return response()->json($note);
    }

    public function destroy($id)
    {
        // ❌ VULNERABILITY V2 — IDOR on delete
        $note = Note::findOrFail($id);
        $note->delete();
        return response()->json(['message' => 'Note deleted']);
    }

    public function search(Request $request)
    {
        $keyword = $request->input('keyword');

        // ❌ VULNERABILITY V1 — SQL INJECTION
        // We're putting user input DIRECTLY into the SQL query!
        // This is like giving a stranger your house keys
        $notes = DB::select(
            "SELECT * FROM notes WHERE body LIKE '%" . $keyword . "%'"
        );

        return response()->json($notes);
    }
}