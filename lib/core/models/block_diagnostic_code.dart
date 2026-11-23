/// Only fixed detection codes may enter newly persisted activity records.
/// Free-form legacy descriptions remain decodable, but are not copied into new events.
String blockDiagnosticCode(String value) =>
    _blockDiagnosticCodes.contains(value) ? value : 'SURGICAL_HEURISTIC';

const _blockDiagnosticCodes = {
  'PRIMARY_RESOURCE_ID',
  'CLIPS_CONTAINER', // Supported legacy bridge diagnostic, never screen text.
  'FALLBACK_REGEX_ID',
  'CLASS_HIERARCHY',
  'CONTENT_DESCRIPTION',
  'MULTILINGUAL_TEXT',
  'ACTIVITY_OR_WINDOW_NAME',
  'REEL_CONTAINER_MATCH',
  'SURGICAL_HEURISTIC',
};
