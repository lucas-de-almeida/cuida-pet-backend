class RequestValidationException implements Exception {
  final Map<String, String> errors;
  RequestValidationException({
    required this.errors,
  });
}
