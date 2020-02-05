// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import 'package:http_server/http_server.dart';
import 'package:path/path.dart' as pathos;
import 'package:test/test.dart';

import 'utils.dart';

void _testEncoding(name, expected, [bool create = true]) {
  testVirtualDir('encode-$name', (dir) async {
    if (create) File('${dir.path}/$name').createSync();
    var virDir = VirtualDirectory(dir.path);
    virDir.allowDirectoryListing = true;

    var result = await statusCodeForVirtDir(virDir, '/$name');
    expect(result, expected);
  });
}

void main() {
  group('serve-root', () {
    testVirtualDir('dir-exists', (dir) async {
      var virDir = VirtualDirectory(dir.path);

      var result = await statusCodeForVirtDir(virDir, '/');
      expect(result, HttpStatus.notFound);
    });

    testVirtualDir('dir-not-exists', (dir) async {
      var virDir = VirtualDirectory(pathos.join('${dir.path}foo'));

      var result = await statusCodeForVirtDir(virDir, '/');
      expect(result, HttpStatus.notFound);
    });
  });

  group('serve-file', () {
    group('top-level', () {
      testVirtualDir('file-exists', (dir) async {
        File('${dir.path}/file')..createSync();
        var virDir = VirtualDirectory(dir.path);
        var result = await statusCodeForVirtDir(virDir, '/file');
        expect(result, HttpStatus.ok);
      });

      testVirtualDir('file-not-exists', (dir) async {
        var virDir = VirtualDirectory(dir.path);

        var result = await statusCodeForVirtDir(virDir, '/file');
        expect(result, HttpStatus.notFound);
      });
    });

    group('in-dir', () {
      testVirtualDir('file-exists', (dir) async {
        var dir2 = Directory('${dir.path}/dir')..createSync();
        File('${dir2.path}/file')..createSync();
        var virDir = VirtualDirectory(dir.path);
        var result = await statusCodeForVirtDir(virDir, '/dir/file');
        expect(result, HttpStatus.ok);
      });

      testVirtualDir('file-not-exists', (dir) async {
        Directory('${dir.path}/dir')..createSync();
        File('${dir.path}/file')..createSync();
        var virDir = VirtualDirectory(dir.path);

        var result = await statusCodeForVirtDir(virDir, '/dir/file');
        expect(result, HttpStatus.notFound);
      });
    });
  });

  group('serve-dir', () {
    group('top-level', () {
      testVirtualDir('simple', (dir) async {
        var virDir = VirtualDirectory(dir.path);
        virDir.allowDirectoryListing = true;

        var result = await fetchAsString(virDir, '/');
        expect(result, contains('Index of &#47'));
      });

      testVirtualDir('files', (dir) async {
        var virDir = VirtualDirectory(dir.path);
        for (var i = 0; i < 10; i++) {
          File('${dir.path}/$i').createSync();
        }
        virDir.allowDirectoryListing = true;

        var result = await fetchAsString(virDir, '/');
        expect(result, contains('Index of &#47'));
      });

      testVirtualDir('dir-href', (dir) async {
        var virDir = VirtualDirectory(dir.path);
        Directory('${dir.path}/dir').createSync();
        virDir.allowDirectoryListing = true;

        var result = await fetchAsString(virDir, '/');
        expect(result, contains('<a href="dir/">'));
      });

      testVirtualDir('dirs', (dir) async {
        var virDir = VirtualDirectory(dir.path);
        for (var i = 0; i < 10; i++) {
          Directory('${dir.path}/$i').createSync();
        }
        virDir.allowDirectoryListing = true;

        var result = await fetchAsString(virDir, '/');
        expect(result, contains('Index of &#47'));
      });

      testVirtualDir('encoded-dir', (dir) async {
        var virDir = VirtualDirectory(dir.path);
        Directory('${dir.path}/alert(\'hacked!\');').createSync();
        virDir.allowDirectoryListing = true;

        var result = await fetchAsString(virDir, '/alert(\'hacked!\');');
        expect(result, contains('&#47;alert(&#39;hacked!&#39;);&#47;'));
      });

      testVirtualDir('non-ascii-dir', (dir) async {
        var virDir = VirtualDirectory(dir.path);
        Directory('${dir.path}/æø').createSync();
        virDir.allowDirectoryListing = true;

        var result = await fetchAsString(virDir, '/');
        expect(result, contains('æø'));
      });

      testVirtualDir('content-type', (dir) async {
        var virDir = VirtualDirectory(dir.path);
        virDir.allowDirectoryListing = true;

        var headers = await fetchHEaders(virDir, '/');
        var contentType = headers.contentType.toString();
        expect(contentType, 'text/html; charset=utf-8');
      });

      if (!Platform.isWindows) {
        testVirtualDir('recursive-link', (dir) async {
          Link('${dir.path}/recursive')..createSync('.');
          var virDir = VirtualDirectory(dir.path);
          virDir.allowDirectoryListing = true;

          var result = await Future.wait([
            fetchAsString(virDir, '/')
                .then((s) => s.contains('recursive&#47;')),
            fetchAsString(virDir, '/').then((s) => !s.contains('../')),
            fetchAsString(virDir, '/')
                .then((s) => s.contains('Index of &#47;')),
            fetchAsString(virDir, '/recursive')
                .then((s) => s.contains('recursive&#47;')),
            fetchAsString(virDir, '/recursive')
                .then((s) => s.contains('..&#47;')),
            fetchAsString(virDir, '/recursive')
                .then((s) => s.contains('Index of &#47;recursive'))
          ]);
          expect(result, equals([true, true, true, true, true, true]));
        });

        testVirtualDir('encoded-path', (dir) async {
          var virDir = VirtualDirectory(dir.path);
          Directory('${dir.path}/javascript:alert(document);"').createSync();
          virDir.allowDirectoryListing = true;

          var result = await fetchAsString(virDir, '/');
          expect(result, contains('javascript%3Aalert(document)%3B%22/'));
        });

        testVirtualDir('encoded-special', (dir) async {
          var virDir = VirtualDirectory(dir.path);
          Directory('${dir.path}/<>&"').createSync();
          virDir.allowDirectoryListing = true;

          var result = await fetchAsString(virDir, '/');
          expect(result, contains('&lt;&gt;&amp;&quot;&#47;'));
          expect(result, contains('href="%3C%3E%26%22/"'));
        });
      }
    });

    group('custom', () {
      testVirtualDir('simple', (dir) async {
        var virDir = VirtualDirectory(dir.path);
        virDir.allowDirectoryListing = true;
        virDir.directoryHandler = (dir2, request) {
          expect(dir2, isNotNull);
          expect(FileSystemEntity.identicalSync(dir.path, dir2.path), isTrue);
          request.response.write('My handler ${request.uri.path}');
          request.response.close();
        };

        var result = await fetchAsString(virDir, '/');
        expect(result, 'My handler /');
      });

      testVirtualDir('index-1', (dir) async {
        File('${dir.path}/index.html').writeAsStringSync('index file');
        var virDir = VirtualDirectory(dir.path);
        virDir.allowDirectoryListing = true;
        virDir.directoryHandler = (dir2, request) {
          // Redirect directory-requests to index.html files.
          var indexUri = Uri.file(dir2.path).resolve('index.html');
          return virDir.serveFile(File(indexUri.toFilePath()), request);
        };

        var result = await fetchAsString(virDir, '/');
        expect(result, 'index file');
      });

      testVirtualDir('index-2', (dir) async {
        Directory('${dir.path}/dir').createSync();
        var virDir = VirtualDirectory(dir.path);
        virDir.allowDirectoryListing = true;

        virDir.directoryHandler = (dir2, request) {
          fail('not expected');
        };

        var result =
            await statusCodeForVirtDir(virDir, '/dir', followRedirects: false);
        expect(result, 301);
      });

      testVirtualDir('index-3', (dir) async {
        File('${dir.path}/dir/index.html')
          ..createSync(recursive: true)
          ..writeAsStringSync('index file');
        var virDir = VirtualDirectory(dir.path);
        virDir.allowDirectoryListing = true;
        virDir.directoryHandler = (dir2, request) {
          // Redirect directory-requests to index.html files.
          var indexUri = Uri.file(dir2.path).resolve('index.html');
          return virDir.serveFile(File(indexUri.toFilePath()), request);
        };
        var result = await fetchAsString(virDir, '/dir');
        expect(result, 'index file');
      });

      testVirtualDir('index-4', (dir) async {
        File('${dir.path}/dir/index.html')
          ..createSync(recursive: true)
          ..writeAsStringSync('index file');
        var virDir = VirtualDirectory(dir.path);
        virDir.allowDirectoryListing = true;
        virDir.directoryHandler = (dir2, request) {
          // Redirect directory-requests to index.html files.
          var indexUri = Uri.file(dir2.path).resolve('index.html');
          virDir.serveFile(File(indexUri.toFilePath()), request);
        };
        var result = await fetchAsString(virDir, '/dir/');
        expect(result, 'index file');
      });
    });

    group('path-prefix', () {
      testVirtualDir('simple', (dir) async {
        var virDir = VirtualDirectory(dir.path, pathPrefix: '/path');
        virDir.allowDirectoryListing = true;
        virDir.directoryHandler = (d, request) {
          expect(FileSystemEntity.identicalSync(dir.path, d.path), isTrue);
          request.response.close();
        };

        var result = await statusCodeForVirtDir(virDir, '/path');
        expect(result, HttpStatus.ok);
      });

      testVirtualDir('trailing-slash', (dir) async {
        var virDir = VirtualDirectory(dir.path, pathPrefix: '/path/');
        virDir.allowDirectoryListing = true;
        virDir.directoryHandler = (d, request) {
          expect(FileSystemEntity.identicalSync(dir.path, d.path), isTrue);
          request.response.close();
        };

        var result = await statusCodeForVirtDir(virDir, '/path');
        expect(result, HttpStatus.ok);
      });

      testVirtualDir('not-matching', (dir) async {
        var virDir = VirtualDirectory(dir.path, pathPrefix: '/path/');
        var result = await statusCodeForVirtDir(virDir, '/');
        expect(result, HttpStatus.notFound);
      });
    });
  });

  group('links', () {
    if (!Platform.isWindows) {
      group('follow-links', () {
        testVirtualDir('dir-link', (dir) async {
          var dir2 = Directory('${dir.path}/dir2')..createSync();
          Link('${dir.path}/dir3')..createSync('dir2');
          File('${dir2.path}/file')..createSync();
          var virDir = VirtualDirectory(dir.path);
          virDir.followLinks = true;

          var result = await statusCodeForVirtDir(virDir, '/dir3/file');
          expect(result, HttpStatus.ok);
        });

        testVirtualDir('root-link', (dir) async {
          Link('${dir.path}/dir3')..createSync('.');
          File('${dir.path}/file')..createSync();
          var virDir = VirtualDirectory(dir.path);
          virDir.followLinks = true;

          var result = await statusCodeForVirtDir(virDir, '/dir3/file');
          expect(result, HttpStatus.ok);
        });

        group('bad-links', () {
          testVirtualDir('absolute-link', (dir) async {
            File('${dir.path}/file')..createSync();
            Link('${dir.path}/file2')..createSync('${dir.path}/file');
            var virDir = VirtualDirectory(dir.path);
            virDir.followLinks = true;

            var result = await statusCodeForVirtDir(virDir, '/file2');
            expect(result, HttpStatus.notFound);
          });

          testVirtualDir('relative-parent-link', (dir) async {
            var dir2 = Directory('${dir.path}/dir')..createSync();
            File('${dir.path}/file')..createSync();
            Link('${dir2.path}/file')..createSync('../file');
            var virDir = VirtualDirectory(dir2.path);
            virDir.followLinks = true;

            var result = await statusCodeForVirtDir(virDir, '/dir3/file');
            expect(result, HttpStatus.notFound);
          });
        });
      });

      group('not-follow-links', () {
        testVirtualDir('dir-link', (dir) async {
          var dir2 = Directory('${dir.path}/dir2')..createSync();
          Link('${dir.path}/dir3')..createSync('dir2');
          File('${dir2.path}/file')..createSync();
          var virDir = VirtualDirectory(dir.path);
          virDir.followLinks = false;

          var result = await statusCodeForVirtDir(virDir, '/dir3/file');
          expect(result, HttpStatus.notFound);
        });
      });

      group('follow-links', () {
        group('no-root-jail', () {
          testVirtualDir('absolute-link', (dir) async {
            File('${dir.path}/file')..createSync();
            Link('${dir.path}/file2')..createSync('${dir.path}/file');
            var virDir = VirtualDirectory(dir.path);
            virDir.followLinks = true;
            virDir.jailRoot = false;

            var result = await statusCodeForVirtDir(virDir, '/file2');
            expect(result, HttpStatus.ok);
          });

          testVirtualDir('relative-parent-link', (dir) async {
            var dir2 = Directory('${dir.path}/dir')..createSync();
            File('${dir.path}/file')..createSync();
            Link('${dir2.path}/file')..createSync('../file');
            var virDir = VirtualDirectory(dir2.path);
            virDir.followLinks = true;
            virDir.jailRoot = false;

            var result = await statusCodeForVirtDir(virDir, '/file');
            expect(result, HttpStatus.ok);
          });
        });
      });
    }
  });

  group('last-modified', () {
    group('file', () {
      testVirtualDir('file-exists', (dir) async {
        File('${dir.path}/file')..createSync();
        var virDir = VirtualDirectory(dir.path);

        var headers = await fetchHEaders(virDir, '/file');
        expect(headers.value(HttpHeaders.lastModifiedHeader), isNotNull);
        var lastModified =
            HttpDate.parse(headers.value(HttpHeaders.lastModifiedHeader));

        var result = await statusCodeForVirtDir(virDir, '/file',
            ifModifiedSince: lastModified);
        expect(result, HttpStatus.notModified);
      });

      testVirtualDir('file-changes', (dir) async {
        File('${dir.path}/file')..createSync();
        var virDir = VirtualDirectory(dir.path);

        var headers = await fetchHEaders(virDir, '/file');
        expect(headers.value(HttpHeaders.lastModifiedHeader), isNotNull);
        var lastModified =
            HttpDate.parse(headers.value(HttpHeaders.lastModifiedHeader));

        // Fake file changed by moving date back in time.
        lastModified = lastModified.subtract(const Duration(seconds: 10));

        var result = await statusCodeForVirtDir(virDir, '/file',
            ifModifiedSince: lastModified);
        expect(result, HttpStatus.ok);
      });
    });
  });

  group('content-type', () {
    group('mime-type', () {
      testVirtualDir('from-path', (dir) async {
        File('${dir.path}/file.jpg')..createSync();
        var virDir = VirtualDirectory(dir.path);

        var headers = await fetchHEaders(virDir, '/file.jpg');
        var contentType = headers.contentType.toString();
        expect(contentType, 'image/jpeg');
      });

      testVirtualDir('from-magic-number', (dir) async {
        var file = File('${dir.path}/file.jpg')..createSync();
        file.writeAsBytesSync([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
        var virDir = VirtualDirectory(dir.path);

        var headers = await fetchHEaders(virDir, '/file.jpg');
        var contentType = headers.contentType.toString();
        expect(contentType, 'image/png');
      });
    });
  });

  group('range', () {
    var fileContent = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9];
    VirtualDirectory virDir;

    void prepare(Directory dir) {
      File('${dir.path}/file').writeAsBytesSync(fileContent);
      virDir = VirtualDirectory(dir.path);
    }

    testVirtualDir('range', (dir) async {
      prepare(dir);
      Future<void> check(int from, int to,
          [List<int> expected, String contentRange]) async {
        expected ??= fileContent.sublist(from, to + 1);
        contentRange ??= 'bytes $from-$to/${fileContent.length}';
        var result =
            await fetchContentAndResponse(virDir, '/file', from: from, to: to);
        var content = result[0];
        var response = result[1];
        expect(content, expected);
        expect(
            response.headers[HttpHeaders.contentRangeHeader][0], contentRange);
        expect(expected.length, response.headers.contentLength);
        expect(response.statusCode, HttpStatus.partialContent);
      }

      await check(0, 0);
      await check(0, 1);
      await check(1, 2);
      await check(1, 9);
      await check(0, 9);
      await check(8, 9);
      await check(9, 9);
      await check(0, 10, fileContent, 'bytes 0-9/10');
      await check(9, 10, [9], 'bytes 9-9/10');
      await check(0, 1000, fileContent, 'bytes 0-9/10');
    });

    testVirtualDir('prefix-range', (dir) async {
      prepare(dir);
      Future<void> check(int from,
          [List<int> expected,
          String contentRange,
          bool expectContentRange = true,
          int expectedStatusCode = HttpStatus.partialContent]) async {
        expected ??= fileContent.sublist(from, fileContent.length);
        if (contentRange == null && expectContentRange) {
          contentRange = 'bytes $from-'
              '${fileContent.length - 1}/'
              '${fileContent.length}';
        }
        var result = await fetchContentAndResponse(virDir, '/file', from: from);
        var content = result[0];
        var response = result[1];
        expect(content, expected);
        if (expectContentRange) {
          expect(response.headers[HttpHeaders.contentRangeHeader][0],
              contentRange);
        } else {
          expect(response.headers[HttpHeaders.contentRangeHeader], null);
        }
        expect(response.statusCode, expectedStatusCode);
      }

      await check(0);
      await check(1);
      await check(9);
      await check(10, fileContent, null, false, HttpStatus.ok);
      await check(11, fileContent, null, false, HttpStatus.ok);
      await check(1000, fileContent, null, false, HttpStatus.ok);
    });

    testVirtualDir('suffix-range', (dir) async {
      prepare(dir);
      Future<void> check(int to,
          [List<int> expected, String contentRange]) async {
        expected ??=
            fileContent.sublist(fileContent.length - to, fileContent.length);
        contentRange ??= 'bytes ${fileContent.length - to}-'
            '${fileContent.length - 1}/'
            '${fileContent.length}';
        var result = await fetchContentAndResponse(virDir, '/file', to: to);
        var content = result[0];
        var response = result[1];
        expect(content, expected);
        expect(
            response.headers[HttpHeaders.contentRangeHeader][0], contentRange);
        expect(response.statusCode, HttpStatus.partialContent);
      }

      await check(1);
      await check(2);
      await check(9);
      await check(10);
      await check(11, fileContent, 'bytes 0-9/10');
      await check(1000, fileContent, 'bytes 0-9/10');
    });

    testVirtualDir('unsatisfiable-range', (dir) async {
      prepare(dir);
      Future<void> check(int from, int to) async {
        var result =
            await fetchContentAndResponse(virDir, '/file', from: from, to: to);
        var content = result[0];
        var response = result[1];
        expect(content.length, 0);
        expect(response.headers[HttpHeaders.contentRangeHeader], isNull);
        expect(response.statusCode, HttpStatus.requestedRangeNotSatisfiable);
      }

      await check(10, 11);
      await check(10, 1000);
      await check(1000, 1000);
    });

    testVirtualDir('invalid-range', (dir) async {
      prepare(dir);
      Future<void> check(int from, int to) async {
        var result =
            await fetchContentAndResponse(virDir, '/file', from: from, to: to);
        var content = result[0];
        var response = result[1];
        expect(content, fileContent);
        expect(response.headers[HttpHeaders.contentRangeHeader], isNull);
        expect(response.statusCode, HttpStatus.ok);
      }

      await check(1, 0);
      await check(10, 0);
      await check(1000, 999);
      await check(null, 0); // This is effectively range 10-9.
    });
  });

  group('error-page', () {
    testVirtualDir('default', (dir) async {
      var virDir = VirtualDirectory(pathos.join(dir.path, 'foo'));

      var result = await fetchAsString(virDir, '/');
      expect(result, matches(RegExp('404.*Not Found')));
    });

    testVirtualDir('custom', (dir) async {
      var virDir = VirtualDirectory(pathos.join(dir.path, 'foo'));

      virDir.errorPageHandler = (request) {
        request.response.write('my-page ');
        request.response.write(request.response.statusCode);
        request.response.close();
      };

      var result = await fetchAsString(virDir, '/');
      expect(result, 'my-page 404');
    });
  });

  group('escape-root', () {
    testVirtualDir('escape1', (dir) async {
      var virDir = VirtualDirectory(dir.path);
      virDir.allowDirectoryListing = true;

      var result = await statusCodeForVirtDir(virDir, '/../');
      expect(result, HttpStatus.notFound);
    });

    testVirtualDir('escape2', (dir) async {
      Directory('${dir.path}/dir').createSync();
      var virDir = VirtualDirectory(dir.path);
      virDir.allowDirectoryListing = true;

      var result = await statusCodeForVirtDir(virDir, '/dir/../../');
      expect(result, HttpStatus.notFound);
    });
  },
      skip: 'Broken. Likely due to dart:core Uri changes.'
          'See https://github.com/dart-lang/http_server/issues/40');

  group('url-decode', () {
    testVirtualDir('with-space', (dir) async {
      File('${dir.path}/my file')..createSync();
      var virDir = VirtualDirectory(dir.path);

      var result = await statusCodeForVirtDir(virDir, '/my file');
      expect(result, HttpStatus.ok);
    });

    testVirtualDir('encoded-space', (dir) async {
      File('${dir.path}/my file')..createSync();
      var virDir = VirtualDirectory(dir.path);

      var result = await statusCodeForVirtDir(virDir, '/my%20file');
      expect(result, HttpStatus.notFound);
    });

    testVirtualDir('encoded-path-separator', (dir) async {
      Directory('${dir.path}/a').createSync();
      Directory('${dir.path}/a/b').createSync();
      Directory('${dir.path}/a/b/c').createSync();
      var virDir = VirtualDirectory(dir.path);
      virDir.allowDirectoryListing = true;

      var result =
          await statusCodeForVirtDir(virDir, '/a%2fb/c', rawPath: true);
      expect(result, HttpStatus.notFound);
    });

    testVirtualDir('encoded-null', (dir) async {
      var virDir = VirtualDirectory(dir.path);
      virDir.allowDirectoryListing = true;

      var result = await statusCodeForVirtDir(virDir, '/%00', rawPath: true);
      expect(result, HttpStatus.notFound);
    });

    group('broken', () {
      _testEncoding('..', HttpStatus.notFound, false);
    },
        skip: 'Broken. Likely due to dart:core Uri changes.'
            'See https://github.com/dart-lang/http_server/issues/40');

    _testEncoding('%2e%2e', HttpStatus.ok);
    _testEncoding('%252e%252e', HttpStatus.ok);
    _testEncoding('/', HttpStatus.ok, false);
    _testEncoding('%2f', HttpStatus.notFound, false);
    _testEncoding('%2f', HttpStatus.ok, true);
  });

  group('serve-file', () {
    testVirtualDir('from-dir-handler', (dir) async {
      File('${dir.path}/file')..writeAsStringSync('file contents');
      var virDir = VirtualDirectory(dir.path);
      virDir.allowDirectoryListing = true;
      virDir.directoryHandler = (d, request) {
        expect(FileSystemEntity.identicalSync(dir.path, d.path), isTrue);
        return virDir.serveFile(File('${d.path}/file'), request);
      };

      var result = await fetchAsString(virDir, '/');
      expect(result, 'file contents');
      var headers = await fetchHEaders(virDir, '/');
      expect('file contents'.length, headers.contentLength);
    });
  });
}
