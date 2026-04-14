<!DOCTYPE html>
<html lang="id">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>{{ $success ? 'Email Terverifikasi' : 'Verifikasi Gagal' }} - SapaHSE</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(135deg, #1a1a2e 0%, #16213e 50%, #0f3460 100%);
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
            padding: 20px;
        }
        .card {
            background: #ffffff;
            border-radius: 20px;
            padding: 48px 40px;
            max-width: 440px;
            width: 100%;
            text-align: center;
            box-shadow: 0 20px 60px rgba(0,0,0,0.3);
        }
        .icon {
            width: 80px;
            height: 80px;
            border-radius: 50%;
            display: flex;
            align-items: center;
            justify-content: center;
            margin: 0 auto 24px;
            font-size: 36px;
        }
        .icon.success { background: #dcfce7; }
        .icon.error   { background: #fee2e2; }
        .logo {
            font-size: 14px;
            font-weight: 800;
            color: #64748b;
            letter-spacing: 2px;
            text-transform: uppercase;
            margin-bottom: 24px;
        }
        .logo span { color: #e94560; }
        h1 {
            font-size: 22px;
            font-weight: 700;
            margin-bottom: 12px;
        }
        h1.success { color: #15803d; }
        h1.error   { color: #dc2626; }
        .message {
            font-size: 14px;
            color: #64748b;
            line-height: 1.7;
            margin-bottom: 32px;
        }
        .hint {
            background: #f8fafc;
            border-radius: 10px;
            padding: 14px 18px;
            font-size: 13px;
            color: #64748b;
            line-height: 1.6;
        }
        .hint strong { color: #0f3460; }
        .footer {
            margin-top: 32px;
            font-size: 12px;
            color: #cbd5e1;
        }
    </style>
</head>
<body>
    <div class="card">
        <div class="logo">Sapa<span>HSE</span></div>

        @if($success)
            <div class="icon success">✅</div>
            <h1 class="success">Email Terverifikasi!</h1>
            <p class="message">{{ $message }}</p>
            <div class="hint">
                Akun Anda sudah aktif.<br>
                <strong>Buka SapaHSE</strong> dan login sekarang.
            </div>
        @else
            <div class="icon error">❌</div>
            <h1 class="error">Verifikasi Gagal</h1>
            <p class="message">{{ $message }}</p>
            <div class="hint">
                Minta link verifikasi baru melalui <strong>SapaHSE</strong>
                di menu <em>Kirim Ulang Email Verifikasi</em>.
            </div>
        @endif

        <p class="footer">SapaHSE &copy; {{ date('Y') }}</p>
    </div>
</body>
</html>