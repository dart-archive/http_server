// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http_server/http_server.dart';
import 'package:mime/mime.dart';
import 'package:test/test.dart';

// Representation of a form field from a multipart/form-data form POST body.
class FormField {
  // Name of the form field specified in Content-Disposition.
  final String name;
  // Value of the form field. This is either a String or a List<int> depending
  // on the Content-Type.
  final value;
  // Content-Type of the form field.
  final String contentType;
  // Filename if specified in Content-Disposition.
  final String filename;

  FormField(this.name, this.value, {this.contentType, this.filename});

  @override
  bool operator ==(other) =>
      other is FormField &&
      _valuesEqual(value, other.value) &&
      name == other.name &&
      contentType == other.contentType &&
      filename == other.filename;

  @override
  int get hashCode => name.hashCode;

  @override
  String toString() {
    return "FormField('$name', '$value', '$contentType', '$filename')";
  }

  static bool _valuesEqual(a, b) {
    if (a is String && b is String) {
      return a == b;
    } else if (a is List && b is List) {
      if (a.length != b.length) {
        return false;
      }
      for (var i = 0; i < a.length; i++) {
        if (a[i] != b[i]) {
          return false;
        }
      }
      return true;
    }
    return false;
  }
}

Future _postDataTest(List<int> message, String contentType, String boundary,
    List<FormField> expectedFields,
    {Encoding defaultEncoding = latin1}) async {
  var addr = (await InternetAddress.lookup('localhost'))[0];

  var server = await HttpServer.bind(addr, 0);

  server.listen((request) async {
    var boundary = request.headers.contentType.parameters['boundary'];
    var fields = await MimeMultipartTransformer(boundary)
        .bind(request)
        .map((part) =>
            HttpMultipartFormData.parse(part, defaultEncoding: defaultEncoding))
        .asyncMap((multipart) async {
      dynamic data;
      if (multipart.isText) {
        data = await multipart.join();
      } else {
        data = await multipart.fold([], (b, s) => b..addAll(s));
      }
      String contentType;
      if (multipart.contentType != null) {
        contentType = multipart.contentType.mimeType;
      }
      return FormField(multipart.contentDisposition.parameters['name'], data,
          contentType: contentType,
          filename: multipart.contentDisposition.parameters['filename']);
    }).toList();
    expect(fields, equals(expectedFields));
    await request.response.close();
    await server.close();
  });

  var client = HttpClient();

  var request = await client.post('localhost', server.port, '/');

  request.headers
      .set('content-type', 'multipart/form-data; boundary=$boundary');
  request.add(message);

  await request.close();
  client.close();
  await server.close(force: true);
}

void main() {
  test('empty', () async {
    var message0 = '''
------WebKitFormBoundaryU3FBruSkJKG0Yor1--\r\n''';

    await _postDataTest(message0.codeUnits, 'multipart/form-data',
        '----WebKitFormBoundaryU3FBruSkJKG0Yor1', []);
  });

  test('test 1', () async {
    var message = '''
\r\n--AaB03x\r
Content-Disposition: form-data; name="submit-name"\r
\r
Larry\r
--AaB03x\r
Content-Disposition: form-data; name="files"; filename="file1.txt"\r
Content-Type: text/plain\r
\r
Content of file\r
--AaB03x--\r\n''';

    await _postDataTest(message.codeUnits, 'multipart/form-data', 'AaB03x', [
      FormField('submit-name', 'Larry'),
      FormField('files', 'Content of file',
          contentType: 'text/plain', filename: 'file1.txt')
    ]);
  });

  test('With content transfer encoding', () async {
    var message = '''
\r\n--AaB03x\r
Content-Disposition: form-data; name="submit-name"\r
Content-Transfer-Encoding: 8bit\r
\r
Larry\r
--AaB03x--\r\n''';

    await _postDataTest(message.codeUnits, 'multipart/form-data', 'AaB03x',
        [FormField('submit-name', 'Larry')]);
  });

  test('Windows/IE style file upload', () async {
    var message = '''
\r\n--AaB03x\r
Content-Disposition: form-data; name="files"; filename="C:\\file1\\".txt"\r
Content-Type: text/plain\r
\r
Content of file\r
--AaB03x--\r\n''';

    await _postDataTest(message.codeUnits, 'multipart/form-data', 'AaB03x', [
      FormField('files', 'Content of file',
          contentType: 'text/plain', filename: 'C:\\file1".txt')
    ]);
  });

  test('Similar test using Chrome posting.', () async {
    var message2 = [
      // Dartfmt, please do not touch.
      45, 45, 45, 45, 45, 45, 87, 101, 98, 75, 105, 116, 70, 111, 114, 109, 66,
      111, 117, 110, 100, 97, 114, 121, 81, 83, 113, 108, 56, 107, 68, 65, 76,
      77, 55, 116, 65, 107, 67, 49, 13, 10, 67, 111, 110, 116, 101, 110, 116,
      45, 68, 105, 115, 112, 111, 115, 105, 116, 105, 111, 110, 58, 32, 102,
      111, 114, 109, 45, 100, 97, 116, 97, 59, 32, 110, 97, 109, 101, 61, 34,
      115, 117, 98, 109, 105, 116, 45, 110, 97, 109, 101, 34, 13, 10, 13, 10,
      84, 101, 115, 116, 13, 10, 45, 45, 45, 45, 45, 45, 87, 101, 98, 75, 105,
      116, 70, 111, 114, 109, 66, 111, 117, 110, 100, 97, 114, 121, 81, 83, 113,
      108, 56, 107, 68, 65, 76, 77, 55, 116, 65, 107, 67, 49, 13, 10, 67, 111,
      110, 116, 101, 110, 116, 45, 68, 105, 115, 112, 111, 115, 105, 116, 105,
      111, 110, 58, 32, 102, 111, 114, 109, 45, 100, 97, 116, 97, 59, 32, 110,
      97, 109, 101, 61, 34, 102, 105, 108, 101, 115, 34, 59, 32, 102, 105, 108,
      101, 110, 97, 109, 101, 61, 34, 86, 69, 82, 83, 73, 79, 78, 34, 13, 10,
      67, 111, 110, 116, 101, 110, 116, 45, 84, 121, 112, 101, 58, 32, 97, 112,
      112, 108, 105, 99, 97, 116, 105, 111, 110, 47, 111, 99, 116, 101, 116, 45,
      115, 116, 114, 101, 97, 109, 13, 10, 13, 10, 123, 32, 10, 32, 32, 34, 114,
      101, 118, 105, 115, 105, 111, 110, 34, 58, 32, 34, 50, 49, 56, 54, 48, 34,
      44, 10, 32, 32, 34, 118, 101, 114, 115, 105, 111, 110, 34, 32, 58, 32, 34,
      48, 46, 49, 46, 50, 46, 48, 95, 114, 50, 49, 56, 54, 48, 34, 44, 10, 32,
      32, 34, 100, 97, 116, 101, 34, 32, 32, 32, 32, 58, 32, 34, 50, 48, 49, 51,
      48, 52, 50, 51, 48, 48, 48, 52, 34, 10, 125, 13, 10, 45, 45, 45, 45, 45,
      45, 87, 101, 98, 75, 105, 116, 70, 111, 114, 109, 66, 111, 117, 110, 100,
      97, 114, 121, 81, 83, 113, 108, 56, 107, 68, 65, 76, 77, 55, 116, 65, 107,
      67, 49, 45, 45, 13, 10
    ];

    var data = [
      // Dartfmt, please do not touch.
      123, 32, 10, 32, 32, 34, 114, 101, 118, 105, 115, 105, 111, 110, 34, 58,
      32, 34, 50, 49, 56, 54, 48, 34, 44, 10, 32, 32, 34, 118, 101, 114, 115,
      105, 111, 110, 34, 32, 58, 32, 34, 48, 46, 49, 46, 50, 46, 48, 95, 114,
      50, 49, 56, 54, 48, 34, 44, 10, 32, 32, 34, 100, 97, 116, 101, 34, 32, 32,
      32, 32, 58, 32, 34, 50, 48, 49, 51, 48, 52, 50, 51, 48, 48, 48, 52, 34,
      10, 125
    ];

    await _postDataTest(message2, 'multipart/form-data',
        '----WebKitFormBoundaryQSql8kDALM7tAkC1', [
      FormField('submit-name', 'Test'),
      FormField('files', data,
          contentType: 'application/octet-stream', filename: 'VERSION')
    ]);
  });

  test('HTML entity encoding in values in form fields', () async {
    // In Chrome, Safari and Firefox HTML entity encoding might be used for
    // values in form fields. The HTML entity encoding for ひらがな is
    // &#12402;&#12425;&#12364;&#12394;
    var message3 = [
      // Dartfmt, please do not touch.
      45, 45, 45, 45, 45, 45, 87, 101, 98, 75, 105, 116, 70, 111, 114, 109, 66,
      111, 117, 110, 100, 97, 114, 121, 118, 65, 86, 122, 117, 103, 75, 77, 116,
      90, 98, 121, 87, 111, 66, 71, 13, 10, 67, 111, 110, 116, 101, 110, 116,
      45, 68, 105, 115, 112, 111, 115, 105, 116, 105, 111, 110, 58, 32, 102,
      111, 114, 109, 45, 100, 97, 116, 97, 59, 32, 110, 97, 109, 101, 61, 34,
      110, 97, 109, 101, 34, 13, 10, 13, 10, 38, 35, 49, 50, 52, 48, 50, 59, 38,
      35, 49, 50, 52, 50, 53, 59, 38, 35, 49, 50, 51, 54, 52, 59, 38, 35, 49,
      50, 51, 57, 52, 59, 13, 10, 45, 45, 45, 45, 45, 45, 87, 101, 98, 75, 105,
      116, 70, 111, 114, 109, 66, 111, 117, 110, 100, 97, 114, 121, 118, 65, 86,
      122, 117, 103, 75, 77, 116, 90, 98, 121, 87, 111, 66, 71, 45, 45, 13, 10
    ];

    await _postDataTest(
        message3,
        'multipart/form-data',
        '----WebKitFormBoundaryvAVzugKMtZbyWoBG',
        [FormField('name', '&#12402;&#12425;&#12364;&#12394;')],
        defaultEncoding: utf8);
  });

  test('UTF', () async {
    // The UTF-8 encoding of ひらがな is
    // [227, 129, 178, 227, 130, 137, 227, 129, 140, 227, 129, 170].
    var message4 = [
      // Dartfmt, please do not touch.
      45, 45, 45, 45, 45, 45, 87, 101, 98, 75, 105, 116, 70, 111, 114, 109, 66,
      111, 117, 110, 100, 97, 114, 121, 71, 88, 116, 66, 114, 99, 106, 120, 104,
      101, 75, 101, 78, 54, 105, 48, 13, 10, 67, 111, 110, 116, 101, 110, 116,
      45, 68, 105, 115, 112, 111, 115, 105, 116, 105, 111, 110, 58, 32, 102,
      111, 114, 109, 45, 100, 97, 116, 97, 59, 32, 110, 97, 109, 101, 61, 34,
      116, 101, 115, 116, 34, 13, 10, 13, 10, 227, 129, 178, 227, 130, 137, 227,
      129, 140, 227, 129, 170, 13, 10, 45, 45, 45, 45, 45, 45, 87, 101, 98, 75,
      105, 116, 70, 111, 114, 109, 66, 111, 117, 110, 100, 97, 114, 121, 71, 88,
      116, 66, 114, 99, 106, 120, 104, 101, 75, 101, 78, 54, 105, 48, 45, 45,
      13, 10
    ];

    await _postDataTest(message4, 'multipart/form-data',
        '----WebKitFormBoundaryGXtBrcjxheKeN6i0', [FormField('test', 'ひらがな')],
        defaultEncoding: utf8);
  });

  test('WebKit', () async {
    var message5 = [
      // Dartfmt, please do not touch.
      45, 45, 45, 45, 45, 45, 87, 101, 98, 75, 105, 116, 70, 111, 114, 109, 66,
      111, 117, 110, 100, 97, 114, 121, 102, 101, 48, 69, 122, 86, 49, 97, 78,
      121, 115, 68, 49, 98, 80, 104, 13, 10, 67, 111, 110, 116, 101, 110, 116,
      45, 68, 105, 115, 112, 111, 115, 105, 116, 105, 111, 110, 58, 32, 102,
      111, 114, 109, 45, 100, 97, 116, 97, 59, 32, 110, 97, 109, 101, 61, 34,
      110, 97, 109, 101, 34, 13, 10, 13, 10, 248, 118, 13, 10, 45, 45, 45, 45,
      45, 45, 87, 101, 98, 75, 105, 116, 70, 111, 114, 109, 66, 111, 117, 110,
      100, 97, 114, 121, 102, 101, 48, 69, 122, 86, 49, 97, 78, 121, 115, 68,
      49, 98, 80, 104, 45, 45, 13, 10
    ];

    await _postDataTest(message5, 'multipart/form-data',
        '----WebKitFormBoundaryfe0EzV1aNysD1bPh', [FormField('name', 'øv')]);
  });
}
