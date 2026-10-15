// Writing a PDF, as far as a page of music needs one.
//
// A PDF is a handful of numbered objects and a table saying where each one
// starts, so a reader can jump straight to any of them. What goes in here
// is the smallest set that makes a printable page: a catalogue, a page
// list, and for each page an image of the music with a one-line content
// stream that stretches it over the whole page.
//
// The music is drawn rather than typeset because the chart's hand
// lettering is an app font with no room in a PDF: embedding it properly
// means carrying the outlines and the widths of every glyph. A page of
// pixels at print resolution prints the same and reads the same, and it
// is the chart as the player has been looking at it rather than a second
// version of it in somebody else's typeface.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// One page: the picture, how big it is in pixels, and how big the paper
/// is in points (72 to the inch).
typedef PdfPage = ({
  Uint8List rgb,
  int pixelWidth,
  int pixelHeight,
  double width,
  double height,
});

/// [pages] as a PDF file.
Uint8List pdfOfPages(List<PdfPage> pages, {String title = ''}) {
  final out = BytesBuilder();
  // Object 1 is the catalogue, 2 the page list, 3 the document's details;
  // then three objects for each page: the page, its content, its picture.
  final offsets = <int, int>{};
  void add(String text) => out.add(latin1.encode(text));
  void object(int number, String body) {
    offsets[number] = out.length;
    add('$number 0 obj\n$body\nendobj\n');
  }

  final pageNumbers = [for (var i = 0; i < pages.length; i++) 4 + i * 3];
  add('%PDF-1.4\n');
  // A comment of high bytes, which is how a reader is told the file is
  // not plain text and must not be mangled by anything that moves it.
  out.add([0x25, 0xE2, 0xE3, 0xCF, 0xD3, 0x0A]);

  object(1, '<< /Type /Catalog /Pages 2 0 R >>');
  object(
    2,
    '<< /Type /Pages /Count ${pages.length} '
    '/Kids [${pageNumbers.map((n) => '$n 0 R').join(' ')}] >>',
  );
  object(
    3,
    '<< /Producer (The Changes) /Creator (The Changes)'
    '${title.isEmpty ? '' : ' /Title (${_string(title)})'} >>',
  );

  for (final (index, page) in pages.indexed) {
    final pageNumber = pageNumbers[index];
    final contentNumber = pageNumber + 1;
    final imageNumber = pageNumber + 2;
    final size = '[0 0 ${_number(page.width)} ${_number(page.height)}]';
    object(
      pageNumber,
      '<< /Type /Page /Parent 2 0 R /MediaBox $size '
      '/Resources << /XObject << /Im0 $imageNumber 0 R >> >> '
      '/Contents $contentNumber 0 R >>',
    );
    // The picture, stretched over the whole page.
    final content =
        'q ${_number(page.width)} 0 0 ${_number(page.height)} 0 0 cm '
        '/Im0 Do Q\n';
    final contentBytes = latin1.encode(content);
    offsets[contentNumber] = out.length;
    add('$contentNumber 0 obj\n<< /Length ${contentBytes.length} >>\nstream\n');
    out.add(contentBytes);
    add('endstream\nendobj\n');

    final squeezed = Uint8List.fromList(ZLibCodec().encode(page.rgb));
    offsets[imageNumber] = out.length;
    add(
      '$imageNumber 0 obj\n'
      '<< /Type /XObject /Subtype /Image /Width ${page.pixelWidth} '
      '/Height ${page.pixelHeight} /ColorSpace /DeviceRGB '
      '/BitsPerComponent 8 /Filter /FlateDecode '
      '/Length ${squeezed.length} >>\nstream\n',
    );
    out.add(squeezed);
    add('\nendstream\nendobj\n');
  }

  // The table of where every object starts, and the trailer pointing at it.
  final count = 4 + pages.length * 3;
  final start = out.length;
  add('xref\n0 $count\n0000000000 65535 f \n');
  for (var number = 1; number < count; number++) {
    add('${offsets[number]!.toString().padLeft(10, '0')} 00000 n \n');
  }
  add(
    'trailer\n<< /Size $count /Root 1 0 R /Info 3 0 R >>\n'
    'startxref\n$start\n%%EOF\n',
  );
  return out.takeBytes();
}

/// A number as a PDF writes one: no exponent, no trailing zeroes.
String _number(double value) {
  final text = value.toStringAsFixed(2);
  return text.endsWith('.00') ? text.substring(0, text.length - 3) : text;
}

/// Text inside brackets, with the brackets that would end it escaped.
String _string(String text) =>
    text.replaceAll(r'\', r'\\').replaceAll('(', r'\(').replaceAll(')', r'\)');
