// API Keys - Güvenlik için ayrı dosya
// Bu dosya .gitignore'a eklenmeli ve gerçek key'ler environment variables'dan alınmalı

class ApiKeys {
  // Hugging Face API Key
  // Gerçek uygulamada bu değer environment variable'dan alınmalı
  static const String huggingFaceApiKey = String.fromEnvironment(
    'HUGGING_FACE_API_KEY',
    defaultValue: '', // Boş default değer
  );

  // Eski API key'leri reddet
  static const String _oldHuggingFaceApiKey =
      'hf_example_key_123456789'; // Eski key'i reddet

  // Diğer API key'ler buraya eklenebilir
  static const String openAiApiKey = String.fromEnvironment(
    'OPENAI_API_KEY',
    defaultValue: '',
  );

  // API key'lerin geçerli olup olmadığını kontrol et
  static bool get isHuggingFaceApiKeyValid =>
      huggingFaceApiKey.isNotEmpty &&
      huggingFaceApiKey != 'hf_example_key_123456789'; // Eski key'i reddet

  static bool get isOpenAiApiKeyValid => openAiApiKey.isNotEmpty;
}
