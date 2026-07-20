class AppConfig {
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://travellens-gamma.vercel.app/api',
  );
  static String assetUrl(String? value) {
    if (value == null || value.isEmpty) return '';
    if (value.startsWith('http://') || value.startsWith('https://'))
      return value;
    final origin = Uri.parse(apiBaseUrl).origin;
    return '$origin${value.startsWith('/') ? '' : '/'}$value';
  }
}
