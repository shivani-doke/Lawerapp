class UploadNavigationContext {
  static String? _referenceOnlyDocumentType;

  static void openReferenceOnly(String documentType) {
    _referenceOnlyDocumentType = documentType;
  }

  static bool consumeReferenceOnlyMode(String documentType) {
    if (_referenceOnlyDocumentType == documentType) {
      _referenceOnlyDocumentType = null;
      return true;
    }
    return false;
  }
}
