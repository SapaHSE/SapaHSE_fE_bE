<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <style>
        body { font-family: sans-serif; line-height: 1.6; color: #333; }
        .container { max-width: 600px; margin: 20px auto; padding: 20px; border: 1px solid #eee; border-radius: 10px; }
        .header { background: #f44336; color: white; padding: 10px 20px; border-radius: 10px 10px 0 0; }
        .content { padding: 20px; }
        .reason { background: #fff3f3; border-left: 4px solid #f44336; padding: 15px; margin: 15px 0; }
        .footer { font-size: 12px; color: #888; text-align: center; margin-top: 20px; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h2>Pendaftaran Ditolak</h2>
        </div>
        <div class="content">
            <p>Halo <strong>{{ $name }}</strong>,</p>
            <p>Mohon maaf, pendaftaran akun Anda di aplikasi <strong>SapaHSE</strong> saat ini belum dapat disetujui oleh administrator.</p>
            
            <p><strong>Alasan Penolakan:</strong></p>
            <div class="reason">
                {{ $reason }}
            </div>

            <p>Anda dapat mencoba mendaftar kembali dengan memastikan seluruh data yang diinput sudah benar dan sesuai dengan identitas perusahaan Anda.</p>
            
            <p>Terima kasih atas pengertiannya.</p>
        </div>
        <div class="footer">
            &copy; {{ date('Y') }} PT. Bukit Baiduri Energi - SapaHSE
        </div>
    </div>
</body>
</html>
