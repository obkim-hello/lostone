/// Module 008 encryption / backup-exclusion seam (ERD-009 §5.2).
///
/// Identity by default; Module 008 supplies an encrypting transform without
/// touching the [PersonaRepository] contract. With the identity transform the
/// on-disk bytes are exactly `PersonaJsonCodec.encode(persona)`.
abstract class PersonaBytesTransform {
  /// Transforms plaintext bytes before they are written to disk.
  List<int> onWrite(List<int> plain);

  /// Transforms stored bytes after they are read from disk.
  List<int> onRead(List<int> stored);
}

/// Default no-op transform: on-disk bytes equal the codec output.
class IdentityPersonaBytesTransform implements PersonaBytesTransform {
  /// Creates the identity transform.
  const IdentityPersonaBytesTransform();

  @override
  List<int> onWrite(List<int> plain) => plain;

  @override
  List<int> onRead(List<int> stored) => stored;
}
