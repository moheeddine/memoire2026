class CloudinaryConfig {
  static const String cloudName    = 'dkpbxucct';
  static const String uploadPreset = 'ml_default';

  static String get imageUploadUrl =>
      'https://api.cloudinary.com/v1_1/$cloudName/image/upload';
}
