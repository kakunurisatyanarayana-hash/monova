/// Which build is running. The GitHub build sets these with --dart-define; a local run shows "local".
const buildRef = String.fromEnvironment('BUILD_REF', defaultValue: 'local');
const buildCommit = String.fromEnvironment('BUILD_COMMIT', defaultValue: 'local');

String get buildLabel {
  final short = buildCommit.length > 7 ? buildCommit.substring(0, 7) : buildCommit;
  return 'Build $buildRef · $short';
}
