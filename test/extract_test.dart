import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:richtext/extract.dart';

void main() {
  test('plain text becomes one paragraph with one run', () {
    final doc = Document()..insert(0, 'hello');
    final paras = extractParagraphs(doc);
    expect(paras.length, 1);
    expect(paras[0].runs.length, 1);
    expect(paras[0].runs[0].text, 'hello');
    expect(paras[0].runs[0].bold, false);
    expect(paras[0].align, 'left');
  });

  test('two paragraphs separated by newline', () {
    final doc = Document()..insert(0, 'first\nsecond');
    final paras = extractParagraphs(doc);
    expect(paras.length, 2);
    expect(paras[0].runs[0].text, 'first');
    expect(paras[1].runs[0].text, 'second');
  });

  test('mixed bold run inside paragraph', () {
    final doc = Document();
    doc.insert(0, 'hello world');
    doc.format(0, 5, Attribute.bold);
    final paras = extractParagraphs(doc);
    expect(paras[0].runs.length, 2);
    expect(paras[0].runs[0].text, 'hello');
    expect(paras[0].runs[0].bold, true);
    expect(paras[0].runs[1].text, ' world');
    expect(paras[0].runs[1].bold, false);
  });

  test('center-aligned paragraph', () {
    final doc = Document()..insert(0, 'x');
    doc.format(0, 1, Attribute.centerAlignment);
    final paras = extractParagraphs(doc);
    expect(paras[0].align, 'center');
  });

  test('indent level 2', () {
    final doc = Document()..insert(0, 'x');
    doc.format(0, 1, Attribute.indentL2);
    final paras = extractParagraphs(doc);
    expect(paras[0].indentLevel, 2);
  });

  test('superscript run', () {
    final doc = Document()..insert(0, 'x');
    doc.format(0, 1, Attribute.superscript);
    final paras = extractParagraphs(doc);
    expect(paras[0].runs[0].script, 'super');
  });

  test('bullet list', () {
    final doc = Document()..insert(0, 'x');
    doc.format(0, 1, Attribute.ul);
    final paras = extractParagraphs(doc);
    expect(paras[0].list, 'bullet');
  });
}
