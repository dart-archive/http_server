// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import "package:http_server/http_server.dart";
import 'package:path/path.dart' as pathos;
import "package:unittest/unittest.dart";

import 'utils.dart';

void _testEncoding(name, expected, [bool create = true]) {
  testVirtualDir('encode-$name', (dir) {
    if (create) new File('${dir.path}/$name').createSync();
    var virDir = new VirtualDirectory(dir.path);
    virDir.allowDirectoryListing = true;

    return getStatusCodeForVirtDir(virDir, '/$name').then((result) {
      expect(result, expected);
    });
  });
}

void main() {
  group('serve-root', () {
    testVirtualDir('dir-exists', (dir) {
      var virDir = new VirtualDirectory(dir.path);

      return getStatusCodeForVirtDir(virDir, '/').then((result) {
        expect(result, HttpStatus.NOT_FOUND);
      });
    });

    testVirtualDir('dir-not-exists', (dir) {
      var virDir = new VirtualDirectory(pathos.join(dir.path + 'foo'));

      return getStatusCodeForVirtDir(virDir, '/').then((result) {
        expect(result, HttpStatus.NOT_FOUND);
      });
    });
  });

  group('serve-file', () {
    group('top-level', () {
      testVirtualDir('file-exists', (dir) {
        var file = new File('${dir.path}/file')..createSync();
        var virDir = new VirtualDirectory(dir.path);
        return getStatusCodeForVirtDir(virDir, '/file').then((result) {
          expect(result, HttpStatus.OK);
        });
      });

      testVirtualDir('file-not-exists', (dir) {
        var virDir = new VirtualDirectory(dir.path);

        return getStatusCodeForVirtDir(virDir, '/file').then((result) {
          expect(result, HttpStatus.NOT_FOUND);
        });
      });
    });

    group('in-dir', () {
      testVirtualDir('file-exists', (dir) {
        var dir2 = new Directory('${dir.path}/dir')..createSync();
        var file = new File('${dir2.path}/file')..createSync();
        var virDir = new VirtualDirectory(dir.path);
        return getStatusCodeForVirtDir(virDir, '/dir/file').then((result) {
          expect(result, HttpStatus.OK);
        });
      });

      testVirtualDir('file-not-exists', (dir) {
        var dir2 = new Directory('${dir.path}/dir')..createSync();
        var file = new File('${dir.path}/file')..createSync();
        var virDir = new VirtualDirectory(dir.path);

        return getStatusCodeForVirtDir(virDir, '/dir/file').then((result) {
          expect(result, HttpStatus.NOT_FOUND);
        });
      });
    });
  });

  group('serve-dir', () {
    group('top-level', () {
      testVirtualDir('simple', (dir) {
        var virDir = new VirtualDirectory(dir.path);
        virDir.allowDirectoryListing = true;

        return getAsString(virDir, '/').then((result) {
          expect(result, contains('Index of &#x2F'));
        });
      });

      testVirtualDir('files', (dir) {
        var virDir = new VirtualDirectory(dir.path);
        for (int i = 0; i < 10; i++) {
          new File('${dir.path}/$i').createSync();
        }
        virDir.allowDirectoryListing = true;

        return getAsString(virDir, '/').then((result) {
          expect(result, contains('Index of &#x2F'));
        });
      });

      testVirtualDir('dir-href', (dir) {
        var virDir = new VirtualDirectory(dir.path);
        new Directory('${dir.path}/dir').createSync();
        virDir.allowDirectoryListing = true;

        return getAsString(virDir, '/').then((result) {
          expect(result, contains('<a href="dir/">'));
        });
      });

      testVirtualDir('dirs', (dir) {
        var virDir = new VirtualDirectory(dir.path);
        for (int i = 0; i < 10; i++) {
          new Directory('${dir.path}/$i').createSync();
        }
        virDir.allowDirectoryListing = true;

        return getAsString(virDir, '/').then((result) {
          expect(result, contains('Index of &#x2F'));
        });
      });

      testVirtualDir('encoded-dir', (dir) {
        var virDir = new VirtualDirectory(dir.path);
        new Directory('${dir.path}/alert(\'hacked!\');').createSync();
        virDir.allowDirectoryListing = true;

        return getAsString(virDir, '/alert(\'hacked!\');').then((result) {
          expect(result, contains('&#x2F;alert(&#x27;hacked!&#x27;);&#x2F;'));
        });
      });

      testVirtualDir('non-ascii-dir', (dir) {
        var virDir = new VirtualDirectory(dir.path);
        new Directory('${dir.path}/æø').createSync();
        virDir.allowDirectoryListing = true;

        return getAsString(virDir, '/').then((result) {
          expect(result, contains('æø'));
        });
      });

      testVirtualDir('content-type', (dir) {
        var virDir = new VirtualDirectory(dir.path);
        virDir.allowDirectoryListing = true;

        return getHeaders(virDir, '/').then((headers) {
          var contentType = headers.contentType.toString();
          expect(contentType, 'text/html; charset=utf-8');
        });
      });

      if (!Platform.isWindows) {
        testVirtualDir('recursive-link', (dir) {
          var link = new Link('${dir.path}/recursive')..createSync('.');
          var virDir = new VirtualDirectory(dir.path);
          virDir.allowDirectoryListing = true;

          return Future.wait([
            getAsString(virDir, '/').then((s) => s.contains('recursive&#x2F;')),
            getAsString(virDir, '/').then((s) => !s.contains('../')),
            getAsString(virDir, '/').then((s) => s.contains('Index of &#x2F;')),
            getAsString(virDir, '/recursive')
                .then((s) => s.contains('recursive&#x2F;')),
            getAsString(virDir, '/recursive')
                .then((s) => s.contains('..&#x2F;')),
            getAsString(virDir, '/recursive')
                .then((s) => s.contains('Index of &#x2F;recursive'))
          ]).then((result) {
            expect(result, equals([true, true, true, true, true, true]));
          });
        });

        testVirtualDir('encoded-path', (dir) {
          var virDir = new VirtualDirectory(dir.path);
          new Directory('${dir.path}/javascript:alert(document);"')
              .createSync();
          virDir.allowDirectoryListing = true;

          return getAsString(virDir, '/').then((result) {
            expect(result, contains('javascript%3Aalert(document)%3B%22/'));
          });
        });

        testVirtualDir('encoded-special', (dir) {
          var virDir = new VirtualDirectory(dir.path);
          new Directory('${dir.path}/<>&"').createSync();
          virDir.allowDirectoryListing = true;

          return getAsString(virDir, '/').then((result) {
            expect(result, contains('&lt;&gt;&amp;&quot;&#x2F;'));
            expect(result, contains('href="%3C%3E%26%22/"'));
          });
        });
      }
    });

    group('custom', () {
      testVirtualDir('simple', (dir) {
        var virDir = new VirtualDirectory(dir.path);
        virDir.allowDirectoryListing = true;
        virDir.directoryHandler = (dir2, request) {
          expect(dir2, isNotNull);
          expect(FileSystemEntity.identicalSync(dir.path, dir2.path), isTrue);
          request.response.write('My handler ${request.uri.path}');
          request.response.close();
        };

        return getAsString(virDir, '/').then((result) {
          expect(result, 'My handler /');
        });
      });

      testVirtualDir('index-1', (dir) {
        new File('${dir.path}/index.html').writeAsStringSync('index file');
        var virDir = new VirtualDirectory(dir.path);
        virDir.allowDirectoryListing = true;
        virDir.directoryHandler = (dir2, request) {
          // Redirect directory-requests to index.html files.
          var indexUri = new Uri.file(dir2.path).resolve('index.html');
          return virDir.serveFile(new File(indexUri.toFilePath()), request);
        };

        return getAsString(virDir, '/').then((result) {
          expect(result, 'index file');
        });
      });

      testVirtualDir('index-2', (dir) {
        new Directory('${dir.path}/dir').createSync();
        var virDir = new VirtualDirectory(dir.path);
        virDir.allowDirectoryListing = true;

        virDir.directoryHandler = (dir2, request) {
          fail('not expected');
        };

        return getStatusCodeForVirtDir(virDir, '/dir', followRedirects: false)
            .then((result) {
          expect(result, 301);
        });
      });

      testVirtualDir('index-3', (dir) {
        new File('${dir.path}/dir/index.html')
          ..createSync(recursive: true)
          ..writeAsStringSync('index file');
        var virDir = new VirtualDirectory(dir.path);
        virDir.allowDirectoryListing = true;
        virDir.directoryHandler = (dir2, request) {
          // Redirect directory-requests to index.html files.
          var indexUri = new Uri.file(dir2.path).resolve('index.html');
          return virDir.serveFile(new File(indexUri.toFilePath()), request);
        };
        return getAsString(virDir, '/dir').then((result) {
          expect(result, 'index file');
        });
      });

      testVirtualDir('index-4', (dir) {
        new File('${dir.path}/dir/index.html')
          ..createSync(recursive: true)
          ..writeAsStringSync('index file');
        var virDir = new VirtualDirectory(dir.path);
        virDir.allowDirectoryListing = true;
        virDir.directoryHandler = (dir2, request) {
          // Redirect directory-requests to index.html files.
          var indexUri = new Uri.file(dir2.path).resolve('index.html');
          virDir.serveFile(new File(indexUri.toFilePath()), request);
        };
        return getAsString(virDir, '/dir/').then((result) {
          expect(result, 'index file');
        });
      });
    });

    group('path-prefix', () {
      testVirtualDir('simple', (dir) {
        var virDir = new VirtualDirectory(dir.path, pathPrefix: '/path');
        virDir.allowDirectoryListing = true;
        virDir.directoryHandler = (d, request) {
          expect(FileSystemEntity.identicalSync(dir.path, d.path), isTrue);
          return request.response.close();
        };

        return getStatusCodeForVirtDir(virDir, '/path').then((result) {
          expect(result, HttpStatus.OK);
        });
      });

      testVirtualDir('trailing-slash', (dir) {
        var virDir = new VirtualDirectory(dir.path, pathPrefix: '/path/');
        virDir.allowDirectoryListing = true;
        virDir.directoryHandler = (d, request) {
          expect(FileSystemEntity.identicalSync(dir.path, d.path), isTrue);
          return request.response.close();
        };

        return getStatusCodeForVirtDir(virDir, '/path').then((result) {
          expect(result, HttpStatus.OK);
        });
      });

      testVirtualDir('not-matching', (dir) {
        var virDir = new VirtualDirectory(dir.path, pathPrefix: '/path/');
        return getStatusCodeForVirtDir(virDir, '/').then((result) {
          expect(result, HttpStatus.NOT_FOUND);
        });
      });
    });
  });

  group('links', () {
    if (!Platform.isWindows) {
      group('follow-links', () {
        testVirtualDir('dir-link', (dir) {
          var dir2 = new Directory('${dir.path}/dir2')..createSync();
          var link = new Link('${dir.path}/dir3')..createSync('dir2');
          var file = new File('${dir2.path}/file')..createSync();
          var virDir = new VirtualDirectory(dir.path);
          virDir.followLinks = true;

          return getStatusCodeForVirtDir(virDir, '/dir3/file').then((result) {
            expect(result, HttpStatus.OK);
          });
        });

        testVirtualDir('root-link', (dir) {
          var link = new Link('${dir.path}/dir3')..createSync('.');
          var file = new File('${dir.path}/file')..createSync();
          var virDir = new VirtualDirectory(dir.path);
          virDir.followLinks = true;

          return getStatusCodeForVirtDir(virDir, '/dir3/file').then((result) {
            expect(result, HttpStatus.OK);
          });
        });

        group('bad-links', () {
          testVirtualDir('absolute-link', (dir) {
            var file = new File('${dir.path}/file')..createSync();
            var link = new Link('${dir.path}/file2')
              ..createSync('${dir.path}/file');
            var virDir = new VirtualDirectory(dir.path);
            virDir.followLinks = true;

            return getStatusCodeForVirtDir(virDir, '/file2').then((result) {
              expect(result, HttpStatus.NOT_FOUND);
            });
          });

          testVirtualDir('relative-parent-link', (dir) {
            var dir2 = new Directory('${dir.path}/dir')..createSync();
            var file = new File('${dir.path}/file')..createSync();
            var link = new Link('${dir2.path}/file')..createSync('../file');
            var virDir = new VirtualDirectory(dir2.path);
            virDir.followLinks = true;

            return getStatusCodeForVirtDir(virDir, '/dir3/file').then((result) {
              expect(result, HttpStatus.NOT_FOUND);
            });
          });
        });
      });

      group('not-follow-links', () {
        testVirtualDir('dir-link', (dir) {
          var dir2 = new Directory('${dir.path}/dir2')..createSync();
          var link = new Link('${dir.path}/dir3')..createSync('dir2');
          var file = new File('${dir2.path}/file')..createSync();
          var virDir = new VirtualDirectory(dir.path);
          virDir.followLinks = false;

          return getStatusCodeForVirtDir(virDir, '/dir3/file').then((result) {
            expect(result, HttpStatus.NOT_FOUND);
          });
        });
      });

      group('follow-links', () {
        group('no-root-jail', () {
          testVirtualDir('absolute-link', (dir) {
            var file = new File('${dir.path}/file')..createSync();
            var link = new Link('${dir.path}/file2')
              ..createSync('${dir.path}/file');
            var virDir = new VirtualDirectory(dir.path);
            virDir.followLinks = true;
            virDir.jailRoot = false;

            return getStatusCodeForVirtDir(virDir, '/file2').then((result) {
              expect(result, HttpStatus.OK);
            });
          });

          testVirtualDir('relative-parent-link', (dir) {
            var dir2 = new Directory('${dir.path}/dir')..createSync();
            var file = new File('${dir.path}/file')..createSync();
            var link = new Link('${dir2.path}/file')..createSync('../file');
            var virDir = new VirtualDirectory(dir2.path);
            virDir.followLinks = true;
            virDir.jailRoot = false;

            return getStatusCodeForVirtDir(virDir, '/file').then((result) {
              expect(result, HttpStatus.OK);
            });
          });
        });
      });
    }
  });

  group('last-modified', () {
    group('file', () {
      testVirtualDir('file-exists', (dir) {
        var file = new File('${dir.path}/file')..createSync();
        var virDir = new VirtualDirectory(dir.path);

        return getHeaders(virDir, '/file').then((headers) {
          expect(headers.value(HttpHeaders.LAST_MODIFIED), isNotNull);
          var lastModified =
              HttpDate.parse(headers.value(HttpHeaders.LAST_MODIFIED));

          return getStatusCodeForVirtDir(virDir, '/file',
              ifModifiedSince: lastModified);
        }).then((result) {
          expect(result, HttpStatus.NOT_MODIFIED);
        });
      });

      testVirtualDir('file-changes', (dir) {
        var file = new File('${dir.path}/file')..createSync();
        var virDir = new VirtualDirectory(dir.path);

        return getHeaders(virDir, '/file').then((headers) {
          expect(headers.value(HttpHeaders.LAST_MODIFIED), isNotNull);
          var lastModified =
              HttpDate.parse(headers.value(HttpHeaders.LAST_MODIFIED));

          // Fake file changed by moving date back in time.
          lastModified = lastModified.subtract(const Duration(seconds: 10));

          return getStatusCodeForVirtDir(virDir, '/file',
              ifModifiedSince: lastModified);
        }).then((result) {
          expect(result, HttpStatus.OK);
        });
      });
    });
  });

  group('content-type', () {
    group('mime-type', () {
      testVirtualDir('from-path', (dir) {
        var file = new File('${dir.path}/file.jpg')..createSync();
        var virDir = new VirtualDirectory(dir.path);

        return getHeaders(virDir, '/file.jpg').then((headers) {
          var contentType = headers.contentType.toString();
          expect(contentType, 'image/jpeg');
        });
      });

      testVirtualDir('from-magic-number', (dir) {
        var file = new File('${dir.path}/file.jpg')..createSync();
        file.writeAsBytesSync([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
        var virDir = new VirtualDirectory(dir.path);

        return getHeaders(virDir, '/file.jpg').then((headers) {
          var contentType = headers.contentType.toString();
          expect(contentType, 'image/png');
        });
      });
    });
  });

  group('range', () {
    var fileContent = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9];
    var virDir;

    prepare(dir) {
      new File('${dir.path}/file').writeAsBytesSync(fileContent);
      virDir = new VirtualDirectory(dir.path);
    }

    testVirtualDir('range', (dir) {
      prepare(dir);
      Future test(int from, int to, [List<int> expected, String contentRange]) {
        if (expected == null) {
          expected = fileContent.sublist(from, to + 1);
        }
        if (contentRange == null) {
          contentRange = 'bytes $from-$to/${fileContent.length}';
        }
        return getContentAndResponse(virDir, '/file', from: from, to: to)
            .then(expectAsync((result) {
          var content = result[0];
          var response = result[1];
          expect(content, expected);
          expect(response.headers[HttpHeaders.CONTENT_RANGE][0], contentRange);
          expect(expected.length, response.headers.contentLength);
          expect(response.statusCode, HttpStatus.PARTIAL_CONTENT);
        }));
      }

      return Future.forEach([
        () => test(0, 0),
        () => test(0, 1),
        () => test(1, 2),
        () => test(1, 9),
        () => test(0, 9),
        () => test(8, 9),
        () => test(9, 9),
        () => test(0, 10, fileContent, 'bytes 0-9/10'),
        () => test(9, 10, [9], 'bytes 9-9/10'),
        () => test(0, 1000, fileContent, 'bytes 0-9/10'),
      ], (f) => f().then(expectAsync((_) {})));
    });

    testVirtualDir('prefix-range', (dir) {
      prepare(dir);
      Future test(int from,
          [List<int> expected,
          String contentRange,
          bool expectContentRange = true,
          int expectedStatusCode = HttpStatus.PARTIAL_CONTENT]) {
        if (expected == null) {
          expected = fileContent.sublist(from, fileContent.length);
        }
        if (contentRange == null && expectContentRange) {
          contentRange = 'bytes ${from}-'
              '${fileContent.length - 1}/'
              '${fileContent.length}';
        }
        return getContentAndResponse(virDir, '/file', from: from)
            .then(expectAsync((result) {
          var content = result[0];
          var response = result[1];
          expect(content, expected);
          if (expectContentRange) {
            expect(
                response.headers[HttpHeaders.CONTENT_RANGE][0], contentRange);
          } else {
            expect(response.headers[HttpHeaders.CONTENT_RANGE], null);
          }
          expect(response.statusCode, expectedStatusCode);
        }));
      }

      return Future.forEach([
        () => test(0),
        () => test(1),
        () => test(9),
        () => test(10, fileContent, null, false, HttpStatus.OK),
        () => test(11, fileContent, null, false, HttpStatus.OK),
        () => test(1000, fileContent, null, false, HttpStatus.OK),
      ], (f) => f().then(expectAsync((_) {})));
    });

    testVirtualDir('suffix-range', (dir) {
      prepare(dir);
      Future test(int to, [List<int> expected, String contentRange]) {
        if (expected == null) {
          expected =
              fileContent.sublist(fileContent.length - to, fileContent.length);
        }
        if (contentRange == null) {
          contentRange = 'bytes ${fileContent.length - to}-'
              '${fileContent.length - 1}/'
              '${fileContent.length}';
        }
        return getContentAndResponse(virDir, '/file', to: to)
            .then(expectAsync((result) {
          var content = result[0];
          var response = result[1];
          expect(content, expected);
          expect(response.headers[HttpHeaders.CONTENT_RANGE][0], contentRange);
          expect(response.statusCode, HttpStatus.PARTIAL_CONTENT);
        }));
      }

      return Future.forEach([
        () => test(1),
        () => test(2),
        () => test(9),
        () => test(10),
        () => test(11, fileContent, 'bytes 0-9/10'),
        () => test(1000, fileContent, 'bytes 0-9/10')
      ], (f) => f().then(expectAsync((_) {})));
    });

    testVirtualDir('unsatisfiable-range', (dir) {
      prepare(dir);
      Future test(int from, int to) {
        return getContentAndResponse(virDir, '/file', from: from, to: to)
            .then(expectAsync((result) {
          var content = result[0];
          var response = result[1];
          expect(content.length, 0);
          expect(response.headers[HttpHeaders.CONTENT_RANGE], isNull);
          expect(
              response.statusCode, HttpStatus.REQUESTED_RANGE_NOT_SATISFIABLE);
        }));
      }

      return Future.forEach(
          [() => test(10, 11), () => test(10, 1000), () => test(1000, 1000)],
          (f) => f().then(expectAsync((_) {})));
    });

    testVirtualDir('invalid-range', (dir) {
      prepare(dir);
      Future test(int from, int to) {
        return getContentAndResponse(virDir, '/file', from: from, to: to)
            .then(expectAsync((result) {
          var content = result[0];
          var response = result[1];
          expect(content, fileContent);
          expect(response.headers[HttpHeaders.CONTENT_RANGE], isNull);
          expect(response.statusCode, HttpStatus.OK);
        }));
      }

      return Future.forEach([
        () => test(1, 0),
        () => test(10, 0),
        () => test(1000, 999),
        () => test(null, 0), // This is effectively range 10-9.
      ], (f) => f().then(expectAsync((_) {})));
    });
  });

  group('error-page', () {
    testVirtualDir('default', (dir) {
      var virDir = new VirtualDirectory(pathos.join(dir.path, 'foo'));

      return getAsString(virDir, '/').then((result) {
        expect(result, matches(new RegExp('404.*Not Found')));
      });
    });

    testVirtualDir('custom', (dir) {
      var virDir = new VirtualDirectory(pathos.join(dir.path, 'foo'));

      virDir.errorPageHandler = (request) {
        request.response.write('my-page ');
        request.response.write(request.response.statusCode);
        request.response.close();
      };

      return getAsString(virDir, '/').then((result) {
        expect(result, 'my-page 404');
      });
    });
  });

  group('escape-root', () {
    testVirtualDir('escape1', (dir) {
      var virDir = new VirtualDirectory(dir.path);
      virDir.allowDirectoryListing = true;

      return getStatusCodeForVirtDir(virDir, '/../').then((result) {
        expect(result, HttpStatus.NOT_FOUND);
      });
    });

    testVirtualDir('escape2', (dir) {
      new Directory('${dir.path}/dir').createSync();
      var virDir = new VirtualDirectory(dir.path);
      virDir.allowDirectoryListing = true;

      return getStatusCodeForVirtDir(virDir, '/dir/../../').then((result) {
        expect(result, HttpStatus.NOT_FOUND);
      });
    });
  });

  group('url-decode', () {
    testVirtualDir('with-space', (dir) {
      var file = new File('${dir.path}/my file')..createSync();
      var virDir = new VirtualDirectory(dir.path);

      return getStatusCodeForVirtDir(virDir, '/my file').then((result) {
        expect(result, HttpStatus.OK);
      });
    });

    testVirtualDir('encoded-space', (dir) {
      var file = new File('${dir.path}/my file')..createSync();
      var virDir = new VirtualDirectory(dir.path);

      return getStatusCodeForVirtDir(virDir, '/my%20file').then((result) {
        expect(result, HttpStatus.NOT_FOUND);
      });
    });

    testVirtualDir('encoded-path-separator', (dir) {
      new Directory('${dir.path}/a').createSync();
      new Directory('${dir.path}/a/b').createSync();
      new Directory('${dir.path}/a/b/c').createSync();
      var virDir = new VirtualDirectory(dir.path);
      virDir.allowDirectoryListing = true;

      return getStatusCodeForVirtDir(virDir, '/a%2fb/c', rawPath: true)
          .then((result) {
        expect(result, HttpStatus.NOT_FOUND);
      });
    });

    testVirtualDir('encoded-null', (dir) {
      var virDir = new VirtualDirectory(dir.path);
      virDir.allowDirectoryListing = true;

      return getStatusCodeForVirtDir(virDir, '/%00', rawPath: true)
          .then((result) {
        expect(result, HttpStatus.NOT_FOUND);
      });
    });

    _testEncoding('..', HttpStatus.NOT_FOUND, false);
    _testEncoding('%2e%2e', HttpStatus.OK);
    _testEncoding('%252e%252e', HttpStatus.OK);
    _testEncoding('/', HttpStatus.OK, false);
    _testEncoding('%2f', HttpStatus.NOT_FOUND, false);
    _testEncoding('%2f', HttpStatus.OK, true);
  });

  group('serve-file', () {
    testVirtualDir('from-dir-handler', (dir) {
      new File('${dir.path}/file')..writeAsStringSync('file contents');
      var virDir = new VirtualDirectory(dir.path);
      virDir.allowDirectoryListing = true;
      virDir.directoryHandler = (d, request) {
        expect(FileSystemEntity.identicalSync(dir.path, d.path), isTrue);
        return virDir.serveFile(new File('${d.path}/file'), request);
      };

      return getAsString(virDir, '/').then((result) {
        expect(result, 'file contents');
        return getHeaders(virDir, '/').then(expectAsync((headers) {
          expect('file contents'.length, headers.contentLength);
        }));
      });
    });
  });
}
