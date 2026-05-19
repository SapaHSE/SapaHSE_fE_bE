class SupabaseConfig {
  static const String supabaseUrl = 'PROJECTURL';

  /// The "anon public" API key (safe for client-side use)
  static const String supabaseAnonKey = 'ANONKEY';

  /// The bucket name on Supabase Storage where images are stored.
  /// Create this bucket in the Supabase dashboard under Storage.
  static const String storageBucket = 'images';

  /// Folder paths inside the bucket (organize uploads by domain).
  static const String hazardFolder = 'hazard-reports';
  static const String inspectionFolder = 'inspection-reports';
  static const String reportLogsFolder = 'report-logs';
  static const String avatarsFolder = 'avatars';
  static const String licensesFolder = 'licenses';
  static const String certificationsFolder = 'certifications';
  static const String newsFolder = 'news';
  static const String carouselFolder = 'carousel';
  static const String violationsFolder = 'violations';
}
