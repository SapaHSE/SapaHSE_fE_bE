<!DOCTYPE html>
<html lang="id">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Reset Password - SapaHSE</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background-color: #f0f4f8;
            padding: 40px 20px;
        }
        .container {
            max-width: 560px;
            margin: 0 auto;
            background: #ffffff;
            border-radius: 16px;
            overflow: hidden;
            box-shadow: 0 4px 24px rgba(0,0,0,0.08);
        }
        .header {
            background: linear-gradient(135deg, #1a1a2e 0%, #16213e 50%, #0f3460 100%);
            padding: 36px 40px;
            text-align: center;
        }
        .header .logo {
            font-size: 28px;
            font-weight: 800;
            color: #ffffff;
            letter-spacing: -0.5px;
        }
        .header .logo span {
            color: #e94560;
        }
        .header .subtitle {
            color: rgba(255,255,255,0.6);
            font-size: 13px;
            margin-top: 6px;
        }
        .body {
            padding: 40px;
        }
        .greeting {
            font-size: 18px;
            font-weight: 600;
            color: #1a1a2e;
            margin-bottom: 12px;
        }
        .message {
            font-size: 14px;
            color: #64748b;
            line-height: 1.7;
            margin-bottom: 32px;
        }
        .btn {
            display: inline-block;
            background: #1a56c4;
            color: #ffffff;
            font-weight: bold;
            font-size: 16px;
            text-decoration: none;
            padding: 14px 28px;
            border-radius: 8px;
            margin-bottom: 24px;
            box-shadow: 0 4px 6px rgba(26, 86, 196, 0.2);
            transition: background 0.3s ease;
        }
        .btn:hover {
            background: #144094;
        }
        .expiry-note {
            display: inline-block;
            background: #fff7ed;
            border: 1px solid #fed7aa;
            border-radius: 8px;
            padding: 10px 16px;
            font-size: 13px;
            color: #c2410c;
            margin-bottom: 32px;
            width: 100%;
            text-align: center;
        }
        .expiry-note strong { font-weight: 700; }
        .security-banner {
            background: #f0fdf4;
            border: 1px solid #86efac;
            border-radius: 10px;
            padding: 16px;
            margin-bottom: 24px;
        }
        .security-banner p {
            font-size: 13px;
            color: #15803d;
            line-height: 1.6;
        }
        .security-banner strong { font-weight: 700; }
        .divider {
            border: none;
            border-top: 1px solid #e2e8f0;
            margin: 28px 0;
        }
        .warning {
            font-size: 13px;
            color: #94a3b8;
            line-height: 1.6;
        }
        .footer {
            background: #f8fafc;
            padding: 24px 40px;
            text-align: center;
            border-top: 1px solid #e2e8f0;
        }
        .footer p {
            font-size: 12px;
            color: #94a3b8;
            line-height: 1.6;
        }
        .footer strong { color: #64748b; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <div class="logo">Sapa<span>HSE</span></div>
            <div class="subtitle">Sistem Pelaporan & Keselamatan Kerja</div>
        </div>

        <div class="body">
            <p class="greeting">Halo, {{ $userName }}!</p>
            <p class="message">
                Kami menerima permintaan untuk mereset password akun SapaHSE Anda.
                Silakan klik tombol di bawah ini untuk mengatur ulang password Anda:
            </p>

            <div style="text-align: center;">
                <a href="{{ $resetUrl }}" class="btn">Reset Password Anda</a>
            </div>

            <p style="text-align: center; font-size: 12px; margin-bottom: 24px; color: #64748b;">
                Atau salin dan tempel tautan berikut di browser Anda:<br>
                <a href="{{ $resetUrl }}" style="word-break: break-all; color: #1a56c4;">{{ $resetUrl }}</a>
            </p>

            <div class="expiry-note">
                ⏱️ Kode ini hanya berlaku selama <strong>15 menit</strong>.
            </div>

            <div class="security-banner">
                <p>🔒 <strong>Tips Keamanan:</strong> Jangan bagikan kode ini kepada siapapun,
                termasuk tim support kami. Kami tidak pernah meminta kode OTP Anda.</p>
            </div>

            <hr class="divider">

            <p class="warning">
                Jika Anda tidak meminta reset password, abaikan email ini.
                Password Anda tidak akan berubah tanpa klik tautan di atas.
            </p>
        </div>

        <div class="footer">
            <p>
                Email ini dikirim otomatis oleh sistem <strong>SapaHSE</strong>.<br>
                Mohon jangan membalas email ini.
            </p>
        </div>
    </div>
</body>
</html>