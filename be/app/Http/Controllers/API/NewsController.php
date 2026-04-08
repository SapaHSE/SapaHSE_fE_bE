<?php

namespace App\Http\Controllers\API;

use App\Http\Controllers\Controller;
use App\Models\News;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Storage;

class NewsController extends Controller
{
    // GET /api/news
    // Filter  : ?category=K3/HSE &is_featured=1
    // Search  : ?search=keyword
    // Paginate: ?page=1&per_page=10
    public function index(Request $request)
    {
        $query = News::active()->with('creator')->latest();

        if ($request->filled('category'))   $query->where('category', $request->category);
        if ($request->filled('is_featured')) $query->where('is_featured', true);

        if ($request->filled('search')) {
            $kw = $request->search;
            $query->where(function ($q) use ($kw) {
                $q->where('title', 'like', "%{$kw}%")
                  ->orWhere('excerpt', 'like', "%{$kw}%")
                  ->orWhere('category', 'like', "%{$kw}%");
            });
        }

        $perPage = (int) $request->get('per_page', 10);
        $news    = $query->paginate($perPage);

        return response()->json([
            'status' => 'success',
            'meta'   => [
                'total'        => $news->total(),
                'per_page'     => $news->perPage(),
                'current_page' => $news->currentPage(),
                'last_page'    => $news->lastPage(),
                'has_more'     => $news->hasMorePages(),
            ],
            'data' => collect($news->items())->map(fn($n) => $this->formatNews($n, false)),
        ]);
    }

    // GET /api/news/{id}
    public function show($id)
    {
        $news = News::active()->with('creator')->findOrFail($id);

        return response()->json([
            'status' => 'success',
            'data'   => $this->formatNews($news, true), // true = include full content
        ]);
    }

    // POST /api/news (admin/supervisor only)
    public function store(Request $request)
    {
        $request->validate([
            'title'       => 'required|string|max:300',
            'excerpt'     => 'nullable|string',
            'content'     => 'required|string',
            'category'    => 'required|string|max:50',
            'author_name' => 'nullable|string|max:100',
            'is_featured' => 'boolean',
            'image'       => 'nullable|image|mimes:jpg,jpeg,png|max:2048',
        ]);

        $imageUrl = null;
        if ($request->hasFile('image')) {
            $imageUrl = asset('storage/' . $request->file('image')->store('news', 'public'));
        }

        $news = News::create([
            'created_by'  => Auth::id(),
            'title'       => $request->title,
            'excerpt'     => $request->excerpt,
            'content'     => $request->content,
            'category'    => $request->category,
            'author_name' => $request->author_name ?? Auth::user()->full_name,
            'image_url'   => $imageUrl,
            'is_featured' => $request->boolean('is_featured', false),
            'is_active'   => true,
        ]);

        return response()->json([
            'status'  => 'success',
            'message' => 'News article created successfully',
            'data'    => $this->formatNews($news->load('creator'), true),
        ], 201);
    }

    // DELETE /api/news/{id} (admin only)
    public function destroy($id)
    {
        $news = News::findOrFail($id);

        if ($news->image_url) {
            $path = str_replace(asset('storage/') . '/', '', $news->image_url);
            Storage::disk('public')->delete($path);
        }

        $news->delete();

        return response()->json([
            'status'  => 'success',
            'message' => 'News article deleted successfully',
        ]);
    }

    private function formatNews(News $news, bool $withContent = true): array
    {
        $data = [
            'id'          => $news->id,
            'title'       => $news->title,
            'excerpt'     => $news->excerpt,
            'category'    => $news->category,
            'author_name' => $news->author_name,
            'image_url'   => $news->image_url,
            'is_featured' => $news->is_featured,
            'date'        => $news->created_at?->format('d F Y'),
            'created_at'  => $news->created_at?->toDateTimeString(),
        ];

        if ($withContent) {
            $data['content'] = $news->content;
        }

        return $data;
    }
}