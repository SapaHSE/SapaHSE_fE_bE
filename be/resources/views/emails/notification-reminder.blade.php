<!DOCTYPE html>
<html lang="id">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Pengingat Notifikasi</title>
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', 'Roboto', 'Oxygen', 'Ubuntu', 'Cantarell', 'Fira Sans', 'Droid Sans', 'Helvetica Neue', sans-serif;
            line-height: 1.6;
            color: #333;
            background-color: #f5f5f5;
            margin: 0;
            padding: 0;
        }
        .email-container {
            max-width: 600px;
            margin: 20px auto;
            background-color: #fff;
            border-radius: 8px;
            box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
            overflow: hidden;
        }
        .email-header {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 30px 20px;
            text-align: center;
        }
        .email-header h1 {
            margin: 0;
            font-size: 24px;
        }
        .email-body {
            padding: 30px 20px;
        }
        .greeting {
            font-size: 16px;
            margin-bottom: 20px;
        }
        .notification-box {
            background-color: #f9f9f9;
            border-left: 4px solid #667eea;
            padding: 20px;
            margin: 20px 0;
            border-radius: 4px;
        }
        .notification-box .title {
            font-weight: bold;
            font-size: 16px;
            color: #667eea;
            margin-bottom: 10px;
        }
        .notification-box .body {
            color: #555;
            line-height: 1.6;
        }
        .cta-button {
            display: inline-block;
            background-color: #667eea;
            color: white;
            padding: 12px 30px;
            text-decoration: none;
            border-radius: 4px;
            margin: 20px 0;
            font-weight: bold;
        }
        .cta-button:hover {
            background-color: #764ba2;
        }
        .footer {
            background-color: #f9f9f9;
            border-top: 1px solid #eee;
            padding: 20px;
            text-align: center;
            font-size: 12px;
            color: #999;
        }
        .divider {
            height: 1px;
            background-color: #eee;
            margin: 20px 0;
        }
    </style>
</head>
<body>
    <div class="email-container">
        <div class="email-header">
            <h1>📬 Pengingat Notifikasi</h1>
        </div>

        <div class="email-body">
            <div class="greeting">
                Halo {{ $user->full_name }},
            </div>

            <p>Anda memiliki notifikasi penting yang belum dibaca selama 3 hari terakhir. Silakan periksa notifikasi tersebut:</p>

            <div class="notification-box">
                <div class="title">📌 {{ $notification->title }}</div>
                <div class="body">{{ $notification->body }}</div>
            </div>

            <p style="text-align: center;">
                <a href="{{ url('/') }}" class="cta-button">Buka Aplikasi</a>
            </p>

            <div class="divider"></div>

            <p style="font-size: 14px; color: #666;">
                Notifikasi ini dikirim karena Anda belum membuka atau menutup notifikasi ini selama 3 hari.
                Jika Anda sudah membalas atau menyelesaikan notifikasi ini, abaikan pesan ini.
            </p>
        </div>

        <div class="footer">
            <p>&copy; {{ date('Y') }} {{ config('app.name') }}. Semua hak dilindungi.</p>
            <p>Jangan ingin menerima email ini? Silakan ubah preferensi notifikasi Anda di aplikasi.</p>
        </div>
    </div>
</body>
</html>
