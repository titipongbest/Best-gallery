// Resolves URIs that players cannot open directly without blocking,
// e.g. cloud content that needs to be downloaded first.
typedef MediaUriResolver = Future<String?> Function(String uri);

class MediaUris {
  static MediaUriResolver? resolver;

  static Future<String> resolve(String uri) async {
    final resolve = resolver;
    if (resolve == null) return uri;
    return await resolve(uri) ?? uri;
  }
}
