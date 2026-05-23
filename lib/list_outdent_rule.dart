import 'package:flutter_quill/flutter_quill.dart';
// InsertRule lives in an internal-use library; custom heuristic rules require
// it. extensions.dart is deprecated in favor of flutter_quill_internal.dart.
import 'package:flutter_quill/flutter_quill_internal.dart' show InsertRule;
import 'package:flutter_quill/quill_delta.dart';

/// Makes pressing Enter on an *empty* nested list item outdent by one level
/// (indent 3 -> 2 -> 1 -> 0) instead of flutter_quill's default, which strips
/// the `list` attribute and leaves the indent stranded.
///
/// flutter_quill applies custom rules before its built-in rules and uses the
/// first non-null result (see `Rules.apply`). This rule fires only on an empty
/// list line with `indent >= 1`. At level 0 (a list item with no indent) it
/// returns null and defers to the built-in `AutoExitBlockRule`, which removes
/// the list and yields a plain paragraph.
class OutdentEmptyListItemRule extends InsertRule {
  const OutdentEmptyListItemRule();

  bool _isEmptyLine(Operation? before, Operation? after) {
    if (before == null) {
      return true;
    }
    return before.data is String &&
        (before.data as String).endsWith('\n') &&
        after!.data is String &&
        (after.data as String).startsWith('\n');
  }

  @override
  Delta? applyRule(
    Document document,
    int index, {
    int? len,
    Object? data,
    Attribute? attribute,
  }) {
    if (data is! String || data != '\n') {
      return null;
    }

    final itr = DeltaIterator(document.toDelta());
    final prev = itr.skip(index);
    final cur = itr.next();

    final attributes = cur.attributes;
    // Only act on list items. Anything else falls through to the built-ins.
    if (attributes == null || !attributes.containsKey(Attribute.list.key)) {
      return null;
    }

    final indent = attributes[Attribute.indent.key];
    // No indent to reduce (level 0): defer to AutoExitBlockRule so the list is
    // removed and the line becomes a plain paragraph.
    if (indent is! int || indent < 1) {
      return null;
    }

    // Outdent only applies when the caret sits on an empty list line.
    if (!_isEmptyLine(prev, cur)) {
      return null;
    }

    final nextIndent = indent - 1;
    final update = <String, dynamic>{
      // Reaching level 0 removes the indent attribute but keeps the list.
      Attribute.indent.key: nextIndent == 0 ? null : nextIndent,
    };

    // Absorb the Enter: retain the line's terminating '\n' and lower its indent
    // in place. No new line is inserted.
    return Delta()
      ..retain(index + (len ?? 0))
      ..retain(1, update);
  }
}

/// Registers [OutdentEmptyListItemRule] for the editor.
///
/// flutter_quill stores rules on a process-wide singleton (`Rules.getInstance`)
/// shared by every [Document], so a single call applies to all editors. It is
/// safe to call repeatedly: it just re-sets the same const rule list.
///
/// Note: this replaces the custom-rule list. This app registers no other custom
/// rules, so there is nothing to preserve here.
void installListOutdentRules(Document document) {
  document.setCustomRules(const [OutdentEmptyListItemRule()]);
}
