/// A simple glob pattern matcher supporting * and ** wildcards.
///
/// Wildcards:
/// - `*` matches zero or more characters except `/` (single directory level)
/// - `**` matches zero or more characters including `/` (recursive)
///
/// Key behaviors:
/// - `foo*` matches `foo` (star can match empty string)
/// - `foo**` matches `foo` (double-star can match empty string)
/// - `lib/**` matches `lib/x` but NOT `lib/` (requires at least one segment after /)
/// - `**/lib` matches `x/lib` but NOT `lib` (requires at least one segment before /)
///
/// Examples:
/// - `lib/*.dart` matches `lib/app.dart` but not `lib/src/app.dart`
/// - `lib/**` matches any file under lib/ at any depth (but not `lib/` itself)
/// - `lib/**.g.dart` matches any .g.dart file under lib/ at any depth
/// - `**/src/**` matches any file under any src/ directory
///
/// Intentional differences from glob package:
/// - Does not support `?` (single character wildcard)
/// - Does not support `[...]` (character classes)
/// - Does not support `{a,b}` (alternatives)
/// - Does not normalize paths (no dot-dot resolution)
/// - Does not support case-insensitive matching
/// - Does not support platform-specific path contexts
class GlobMatcher {
  /// Creates a glob matcher with the given pattern.
  ///
  /// The pattern is compiled to a regex at construction time for performance.
  GlobMatcher(String pattern)
    : _pattern = pattern,
      _regex = _compileToRegex(pattern);

  final String _pattern;
  final RegExp _regex;

  /// Checks if [path] matches this glob pattern.
  bool matches(String path) => _regex.hasMatch(path);

  /// Converts a glob pattern to a regular expression.
  ///
  /// Algorithm:
  /// 1. Escape regex special characters (except *)
  /// 2. Replace ** patterns with placeholders (before single * replacement)
  /// 3. Replace single * with [^\/]* (zero or more non-slash chars)
  /// 4. Replace placeholders with actual regex patterns
  /// 5. Anchor with ^ and $
  static RegExp _compileToRegex(String pattern) {
    var regex = pattern;

    // Step 1: Escape regex special characters (except *)
    // Characters to escape: . + ? ^ $ { } [ ] ( ) | \
    regex = regex.replaceAllMapped(
      RegExp(r'[.+?^${}()\[\]\\|]'),
      (match) => '\\${match[0]}',
    );

    // Step 2: Replace ** patterns with placeholders
    // We use placeholders to avoid later * replacements affecting these patterns
    // Important: ** behavior depends on context:
    // - /**/ → matches /.+/ (at least one char between slashes)
    // - /** at end → matches /.+ (at least one char after slash)
    // - **/ at start → matches .+/ (at least one char before slash)
    // - ** standalone (no adjacent /) → matches .* (zero or more chars)

    // Use unique placeholders that won't conflict with actual patterns
    const slashStarStarSlash = '\x00SLASH_STAR_STAR_SLASH\x00';
    const slashStarStar = '\x00SLASH_STAR_STAR\x00';
    const starStarSlash = '\x00STAR_STAR_SLASH\x00';
    const starStar = '\x00STAR_STAR\x00';

    regex = regex.replaceAll('/**/', slashStarStarSlash);
    regex = regex.replaceAll('/**', slashStarStar);
    regex = regex.replaceAll('**/', starStarSlash);
    regex = regex.replaceAll('**', starStar);

    // Step 3: Replace single * with [^/]* (zero or more non-slash chars)
    regex = regex.replaceAll('*', r'[^/]*');

    // Step 4: Replace placeholders with actual regex patterns
    regex = regex.replaceAll(slashStarStarSlash, '/.+/');
    regex = regex.replaceAll(slashStarStar, '/.+');
    regex = regex.replaceAll(starStarSlash, '.+/');
    regex = regex.replaceAll(starStar, '.*'); // Zero or more for standalone **

    // Step 5: Anchor the pattern
    regex = '^$regex\$';

    return RegExp(regex);
  }

  @override
  String toString() => 'GlobMatcher($_pattern)';
}
