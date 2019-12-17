// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library utils;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:mirrors';

import 'package:test/test.dart';
import 'package:test_api/src/backend/invoker.dart';

import 'package:http_server/http_server.dart';

import 'http_mock.dart';

Object get currentTestCase => Invoker.current.liveTest;

SecurityContext serverContext;
SecurityContext clientContext;

///  Used to flag a given test case as being a mock or not.
final _isMockTestExpando = Expando<bool>('isMockTest');

void testVirtualDir(String name, Future<void> Function(Directory) func) {
  _testVirtualDir(name, false, func);
  _testVirtualDir(name, true, func);
}

void _testVirtualDir(
    String name, bool useMocks, Future<void> Function(Directory) func) {
  if (useMocks) {
    name = '$name, with mocks';
  }

  test(name, () async {
    // see subsequent access to this expando below
    _isMockTestExpando[currentTestCase] = useMocks;

    var dir = Directory.systemTemp.createTempSync('http_server_virtual_');

    try {
      await func(dir);
    } finally {
      await dir.delete(recursive: true);
    }
  });
}

Future<int> getStatusCodeForVirtDir(VirtualDirectory virtualDir, String path,
    {String host,
    bool secure = false,
    DateTime ifModifiedSince,
    bool rawPath = false,
    bool followRedirects = true,
    int from,
    int to}) {
  // if this is a mock test, then run the mock code path
  if (_isMockTestExpando[currentTestCase]) {
    var uri = _getUri(0, path, secure: secure, rawPath: rawPath);

    var request = MockHttpRequest(uri,
        followRedirects: followRedirects, ifModifiedSince: ifModifiedSince);
    _addRangeHeader(request, from, to);

    return _withMockRequest(virtualDir, request).then((response) {
      return response.statusCode;
    });
  }

  assert(_isMockTestExpando[currentTestCase] == false);

  return _withServer(virtualDir, (port) {
    return getStatusCode(port, path,
        host: host,
        secure: secure,
        ifModifiedSince: ifModifiedSince,
        rawPath: rawPath,
        followRedirects: followRedirects,
        from: from,
        to: to);
  });
}

Future<int> getStatusCode(int port, String path,
    {String host,
    bool secure = false,
    DateTime ifModifiedSince,
    bool rawPath = false,
    bool followRedirects = true,
    int from,
    int to}) async {
  var uri = _getUri(port, path, secure: secure, rawPath: rawPath);

  HttpClient client;
  if (secure) {
    client = HttpClient(context: clientContext);
  } else {
    client = HttpClient();
  }

  try {
    var request = await client.getUrl(uri);

    if (!followRedirects) request.followRedirects = false;
    if (host != null) request.headers.host = host;
    if (ifModifiedSince != null) {
      request.headers.ifModifiedSince = ifModifiedSince;
    }
    _addRangeHeader(request, from, to);
    var response = await request.close();
    await response.drain();
    return response.statusCode;
  } finally {
    client.close();
  }
}

Future<HttpHeaders> getHeaders(VirtualDirectory virDir, String path,
    {int from, int to}) {
  // if this is a mock test, then run the mock code path
  if (_isMockTestExpando[currentTestCase]) {
    var uri = _getUri(0, path);

    var request = MockHttpRequest(uri);
    _addRangeHeader(request, from, to);

    return _withMockRequest(virDir, request).then((response) {
      return response.headers;
    });
  }

  assert(_isMockTestExpando[currentTestCase] == false);

  return _withServer(virDir, (port) {
    return _getHeaders(port, path, from, to);
  });
}

Future<String> getAsString(VirtualDirectory virtualDir, String path) {
  // if this is a mock test, then run the mock code path
  if (_isMockTestExpando[currentTestCase]) {
    var uri = _getUri(0, path);

    var request = MockHttpRequest(uri);

    return _withMockRequest(virtualDir, request).then((response) {
      return response.mockContent;
    });
  }

  assert(_isMockTestExpando[currentTestCase] == false);

  return _withServer(virtualDir, (int port) {
    return _getAsString(port, path);
  });
}

Future<List<int>> getAsBytes(VirtualDirectory virtualDir, String path,
    {int from, int to}) {
  // if this is a mock test, then run the mock code path
  if (_isMockTestExpando[currentTestCase]) {
    var uri = _getUri(0, path);

    var request = MockHttpRequest(uri);
    _addRangeHeader(request, from, to);

    return _withMockRequest(virtualDir, request).then((response) {
      return response.mockContentBinary;
    });
  }

  assert(_isMockTestExpando[currentTestCase] == false);

  return _withServer(virtualDir, (int port) {
    return _getAsBytes(port, path, from, to);
  });
}

Future<List> getContentAndResponse(VirtualDirectory virtualDir, String path,
    {int from, int to}) {
  // if this is a mock test, then run the mock code path
  if (_isMockTestExpando[currentTestCase]) {
    var uri = _getUri(0, path);

    var request = MockHttpRequest(uri);
    _addRangeHeader(request, from, to);

    return _withMockRequest(virtualDir, request).then((response) {
      return [response.mockContentBinary, response];
    });
  }

  assert(_isMockTestExpando[currentTestCase] == false);

  return _withServer(virtualDir, (int port) {
    return _getContentAndResponse(port, path, from, to);
  });
}

Future<MockHttpResponse> _withMockRequest(
    VirtualDirectory virDir, MockHttpRequest request) async {
  var value = await virDir.serveRequest(request);

  expect(value, isNull);
  expect(request.response.mockDone, isTrue);

  var response = request.response;

  if (response.statusCode == HttpStatus.movedPermanently ||
      response.statusCode == HttpStatus.movedTemporarily) {
    if (request.followRedirects == true) {
      var uri = Uri.parse(response.headers.value(HttpHeaders.locationHeader));
      var newMock = MockHttpRequest(uri, followRedirects: true);

      return _withMockRequest(virDir, newMock);
    }
  }
  return response;
}

Future<T> _withServer<T>(
    VirtualDirectory virDir, Future<T> Function(int port) func) async {
  var server = await HttpServer.bind('localhost', 0);

  try {
    virDir.serve(server);
    return await func(server.port);
  } finally {
    await server.close();
  }
}

Future<HttpHeaders> _getHeaders(int port, String path, int from, int to) {
  var client = HttpClient();
  return client
      .get('localhost', port, path)
      .then((request) {
        _addRangeHeader(request, from, to);
        return request.close();
      })
      .then((response) => response.drain().then((_) => response.headers))
      .whenComplete(() => client.close());
}

Future<String> _getAsString(int port, String path) {
  var client = HttpClient();
  return client
      .get('localhost', port, path)
      .then((request) => request.close())
      .then((response) => utf8.decodeStream(response.cast<List<int>>()))
      .whenComplete(() => client.close());
}

Future<List<int>> _getAsBytes(int port, String path, int from, int to) {
  var client = HttpClient();
  return client
      .get('localhost', port, path)
      .then((request) {
        _addRangeHeader(request, from, to);
        return request.close();
      })
      .then((response) => response.fold<List<int>>([], (p, e) => p..addAll(e)))
      .whenComplete(() => client.close());
}

Future<List> _getContentAndResponse(int port, String path, int from, int to) {
  var client = HttpClient();
  return client
      .get('localhost', port, path)
      .then((request) {
        _addRangeHeader(request, from, to);
        return request.close();
      })
      .then((response) => response
          .fold([], (p, e) => p..addAll(e)).then((bytes) => [bytes, response]))
      .whenComplete(() => client.close());
}

Uri _getUri(int port, String path,
    {bool secure = false, bool rawPath = false}) {
  if (rawPath) {
    return Uri(
        scheme: secure ? 'https' : 'http',
        host: 'localhost',
        port: port,
        path: path);
  } else {
    return (secure
        ? Uri.https('localhost:$port', path)
        : Uri.http('localhost:$port', path));
  }
}

void _addRangeHeader(request, int from, int to) {
  var fromStr = from != null ? '$from' : '';
  var toStr = to != null ? '$to' : '';
  if (fromStr.isNotEmpty || toStr.isNotEmpty) {
    request.headers.set(HttpHeaders.rangeHeader, 'bytes=$fromStr-$toStr');
  }
}

void setupSecure() {
  var currentFileUri =
      (reflect(setupSecure) as ClosureMirror).function.location.sourceUri;

  String localFile(String path) => currentFileUri.resolve(path).toFilePath();

  serverContext = SecurityContext()
    ..useCertificateChain(localFile('certificates/server_chain.pem'))
    ..usePrivateKey(localFile('certificates/server_key.pem'),
        password: 'dartdart');

  clientContext = SecurityContext()
    ..setTrustedCertificates(localFile('certificates/trusted_certs.pem'));
}
