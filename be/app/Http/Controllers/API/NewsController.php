<?php

namespace App\Http\Controllers\API;

use App\Http\Controllers\Controller;
use App\Models\News;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Storage;

class NewsController extends Controller
{
    protected $notificationService;

    public function __construct(\App\Services\NotificationService $notificationService)
    {
        $this->notificationService = $notificationService;
    }

    // GET /api/news
    // Filter  : ?category=K3/HSE &is_featured=1
    // Search  : ?search=keyword
    // Paginate: ?page=1&per_page=10
    // Admin   : ?include_scheduled=1 — list scheduled drafts too (requires admin/supervisor)
    //           ?only_scheduled=1 — only return scheduled drafts
    public function index(Request $request)
    {
        $user = $request->user();
        $isAdmin = $user && in_array($user->role, ['admin', 'superadmin', 'supervisor']);

        $includeScheduled = $isAdmin && $request->boolean('include_scheduled');
        $onlyScheduled    = $isAdmin && $request->boolean('only_scheduled');

        if ($onlyScheduled) {
            $query = News::scheduled();
        } elseif ($includeScheduled) {
            $query = News::active();
        } else {
            $query = News::published();
        }

        $query->with('creator')->latest();

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

        $perPage = (int) $request->input('per_page', 10);
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
    public function show(Request $request, $id)
    {
        $user = $request->user();
        $isAdmin = $user && in_array($user->role, ['admin', 'superadmin', 'supervisor']);

        $query = $isAdmin ? News::active() : News::published();
        $news  = $query->with('creator')->findOrFail($id);

        return response()->json([
            'status' => 'success',
            'data'   => $this->formatNews($news, true), // true = include full content
        ]);
    }

    // POST /api/news (admin/supervisor only)
    public function store(Request $request)
    {
        $request->validate([
            'title'        => 'required|string|max:300',
            'excerpt'      => 'nullable|string',
            'content'      => 'required|string',
            'category'     => 'required|string|max:50',
            'hashtags'     => 'nullable|string',
            'author_name'  => 'nullable|string|max:100',
            'is_featured'  => 'boolean',
            'image'        => 'nullable|image|mimes:jpg,jpeg,png|max:2048',
            'publish_date' => 'nullable|date',
        ]);

        $imageUrl = null;
        if ($request->hasFile('image')) {
            $imageUrl = asset('storage/' . $request->file('image')->store('news', 'public'));
        }

        $publishDate = $request->input('publish_date') ?? now()->toDateString();
        $isScheduled = $publishDate > now()->toDateString();
        $hashtags = $this->normalizeHashtags($request->input('hashtags'));

        $news = News::create([
            'created_by'         => Auth::id(),
            'title'              => $request->title,
            'excerpt'            => $request->excerpt,
            'content'            => $request->input('content'),
            'category'           => $request->category,
            'hashtags'           => $hashtags,
            'author_name'        => $request->author_name ?? Auth::user()->full_name,
            'image_url'          => $imageUrl,
            'is_featured'        => $request->boolean('is_featured', false),
            'is_active'          => true,
            'publish_date'       => $publishDate,
            'published_notified' => ! $isScheduled,
        ]);

        // Broadcast notification only if article is publishing today/now.
        // Scheduled articles get push fired by news:publish-scheduled command.
        if (! $isScheduled) {
            try {
                $this->notificationService->sendPushToAll(
                    "Berita HSE Baru",
                    $news->title,
                    ['news_id' => $news->id, 'type' => 'news']
                );
            } catch (\Exception $e) {
                \Log::error('Gagal broadcast berita: ' . $e->getMessage());
            }
        }

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

    // POST /api/news/{id}/publish-now (admin/superadmin)
    // Move a scheduled article to "live" immediately and fire push.
    public function publishNow($id)
    {
        $news = News::active()->findOrFail($id);

        $news->update([
            'publish_date'       => now()->toDateString(),
            'published_notified' => true,
        ]);

        try {
            $this->notificationService->sendPushToAll(
                'Berita HSE Baru',
                $news->title,
                ['news_id' => $news->id, 'type' => 'news']
            );
        } catch (\Exception $e) {
            \Log::error('publishNow push failed: ' . $e->getMessage());
        }

        return response()->json([
            'status'  => 'success',
            'message' => 'Berita berhasil dipublikasikan.',
            'data'    => $this->formatNews($news->fresh()->load('creator'), true),
        ]);
    }

    private function formatNews(News $news, bool $withContent = true): array
    {
        $publishDate = $news->publish_date ?? $news->created_at;
        $isScheduled = $news->isScheduled();

        $data = [
            'id'                 => $news->id,
            'title'              => $news->title,
            'excerpt'            => $news->excerpt,
            'category'           => $news->category,
            'hashtags'           => $news->hashtags ?? [],
            'author_name'        => $news->author_name,
            'image_url'          => $news->image_url,
            'is_featured'        => $news->is_featured,
            'date'               => $publishDate?->format('d F Y'),
            'created_at'         => $news->created_at?->toDateTimeString(),
            'publish_date'       => $news->publish_date?->format('Y-m-d'),
            'publish_date_label' => $publishDate?->locale('id')->isoFormat('dddd, D MMMM YYYY'),
            'is_scheduled'       => $isScheduled,
            'status'             => $isScheduled ? 'scheduled' : 'published',
        ];

        if ($withContent) {
            $data['content'] = $news->content;
        }

        return $data;
    }

    private function normalizeHashtags(?string $raw): array
    {
        if ($raw === null || trim($raw) === '') {
            return [];
        }

        $decoded = json_decode($raw, true);
        if (!is_array($decoded)) {
            return [];
        }

        $result = [];
        foreach ($decoded as $item) {
            if (!is_scalar($item)) {
                continue;
            }
            $tag = strtolower(trim((string) $item));
            $tag = ltrim($tag, '#');
            $tag = preg_replace('/\s+/', '', $tag) ?? '';
            if ($tag === '') {
                continue;
            }
            if (mb_strlen($tag) > 24) {
                $tag = mb_substr($tag, 0, 24);
            }
            $result[$tag] = true;
            if (count($result) >= 10) {
                break;
            }
        }

        return array_keys($result);
    }
}
