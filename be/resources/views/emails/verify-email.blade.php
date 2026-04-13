<!DOCTYPE html>
<html lang="id">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Verifikasi Email - SapaHSE</title>
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
        .header .logo span { color: #e94560; }
        .header .subtitle {
            color: rgba(255,255,255,0.6);
            font-size: 13px;
            margin-top: 6px;
        }
        .body { padding: 40px; }
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
        .btn-verify {
            display: block;
            background: linear-gradient(135deg, #0f3460, #e94560);
            color: #ffffff !important;
            text-decoration: none;
            text-align: center;
            padding: 16px 32px;
            border-radius: 12px;
            font-size: 16px;
            font-weight: 700;
            letter-spacing: 0.3px;
            margin-bottom: 20px;
            transition: opacity 0.2s;
        }
        .expiry-note {
            background: #fff7ed;
            border: 1px solid #fed7aa;
            border-radius: 8px;
            padding: 10px 16px;
            font-size: 13px;
            color: #c2410c;
            margin-bottom: 28px;
            text-align: center;
        }
        .expiry-note strong { font-weight: 700; }
        .link-fallback {
            font-size: 12px;
            color: #94a3b8;
            line-height: 1.7;
            word-break: break-all;
        }
        .link-fallback a { color: #0f3460; }
        .divider {
            border: none;
            border-top: 1px solid #e2e8f0;
            margin: 28px 0;
        }
        .warning { font-size: 13px; color: #94a3b8; line-height: 1.6; }
        .footer {
            background: #f8fafc;
            padding: 24px 40px;
            text-align: center;
            border-top: 1px solid #e2e8f0;
        }
        .footer p { font-size: 12px; color: #94a3b8; line-height: 1.6; }
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
            <p class="greeting">Halo, {{ $userName }}! 👋</p>
            <p class="message">
                Terima kasih telah mendaftar di <strong>SapaHSE</strong>.
                Klik tombol di bawah untuk memverifikasi alamat email Anda dan mengaktifkan akun.
            </p>

            <a href="{{ $verificationUrl }}" class="btn-verify">
                ✅ Verifikasi Email Sekarang
            </a>

            <div class="expiry-note">
                ⚠️ Link ini <strong>hanya bisa digunakan satu kali</strong>.
                Jika expired, minta link baru melalui aplikasi.
            </div>

            <p class="link-fallback">
                Jika tombol tidak berfungsi, salin dan tempelkan link berikut ke browser Anda:<br>
                <a href="{{ $verificationUrl }}">{{ $verificationUrl }}</a>
            </p>

            <hr class="divider">
            <p class="warning">
                Jika Anda tidak merasa mendaftar di SapaHSE, abaikan email ini.
                Akun Anda tidak akan aktif tanpa verifikasi.
            </p>
        </div>
        <div class="footer">
            <p>Email ini dikirim otomatis oleh <strong>SapaHSE</strong>.<br>Mohon jangan membalas email ini.</p>
        </div>
    </div>
</body>
</html>
