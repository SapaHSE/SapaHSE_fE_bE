class SupabaseConfig {
  static const String supabaseUrl = 'https://gwzlqpukshwgmphsynkv.supabase.co';

  /// The "anon public" API key (safe for client-side use)
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imd3emxxcHVrc2h3Z21waHN5bmt2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzcyNjUyNDksImV4cCI6MjA5Mjg0MTI0OX0._q8lZ0vgqNgULcXfIayg5pGbGhrHlFxAuJd7LI1xtl0';

  /// The bucket name on Supabase Storage where images are stored.
  /// Create this bucket in the Supabase dashboard under Storage.
  static const String storageBucket = 'images';

  /// Folder paths inside the bucket (organize uploads by domain).
  static const String hazardFolder = 'hazard-reports';
  static const String inspectionFolder = 'inspection-reports';
  static const String reportLogsFolder = 'report-logs';
  static const String avatarsFolder = 'avatars';
  static const String newsFolder = 'news';
  static const String carouselFolder = 'carousel';
}
