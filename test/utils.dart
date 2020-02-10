// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:mirrors';

import 'package:test/test.dart';
import 'package:test_api/src/backend/invoker.dart';

import 'package:http_server/http_server.dart';

import 'http_fakes.dart';

Object get currentTestCase => Invoker.current.liveTest;

SecurityContext serverContext;
SecurityContext clientContext;

///  Used to flag a given test case as being a fake or not.
final _isFakeTestExpando = Expando<bool>('isFakeTest');

void testVirtualDir(String name, Future<void> Function(Directory) func) {
  _testVirtualDir(name, false, func);
  _testVirtualDir(name, true, func);
}

void _testVirtualDir(
    String name, bool useFakes, Future<void> Function(Directory) func) {
  if (useFakes) {
    name = '$name, with fakes';
  }

  test(name, () async {
    // see subsequent access to this expando below
    _isFakeTestExpando[currentTestCase] = useFakes;

    var dir = Directory.systemTemp.createTempSync('http_server_virtual_');

    try {
      await func(dir);
    } finally {
      await dir.delete(recursive: true);
    }
  });
}

Future<int> statusCodeForVirtDir(VirtualDirectory virtualDir, String path,
    {String host,
    bool secure = false,
    DateTime ifModifiedSince,
    bool rawPath = false,
    bool followRedirects = true,
    int from,
    int to}) async {
  // if this is a fake test, then run the fake code path
  if (_isFakeTestExpando[currentTestCase]) {
    var uri = _localhostUri(0, path, secure: secure, rawPath: rawPath);

    var request = FakeHttpRequest(uri,
        followRedirects: followRedirects, ifModifiedSince: ifModifiedSince);
    _addRangeHeader(request, from, to);

    var response = await _withFakeRequest(virtualDir, request);
    return response.statusCode;
  }

  assert(_isFakeTestExpando[currentTestCase] == false);

  return _withServer(virtualDir, (port) {
    return fetchStatusCode(port, path,
        host: host,
        secure: secure,
        ifModifiedSince: ifModifiedSince,
        rawPath: rawPath,
        followRedirects: followRedirects,
        from: from,
        to: to);
  });
}

Future<int> fetchStatusCode(int port, String path,
    {String host,
    bool secure = false,
    DateTime ifModifiedSince,
    bool rawPath = false,
    bool followRedirects = true,
    int from,
    int to}) async {
  var uri = _localhostUri(port, path, secure: secure, rawPath: rawPath);

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

Future<HttpHeaders> fetchHEaders(VirtualDirectory virDir, String path,
    {int from, int to}) async {
  // if this is a fake test, then run the fake code path
  if (_isFakeTestExpando[currentTestCase]) {
    var uri = _localhostUri(0, path);

    var request = FakeHttpRequest(uri);
    _addRangeHeader(request, from, to);

    var response = await _withFakeRequest(virDir, request);
    return response.headers;
  }

  assert(_isFakeTestExpando[currentTestCase] == false);

  return _withServer(virDir, (port) => _headers(port, path, from, to));
}

Future<String> fetchAsString(VirtualDirectory virtualDir, String path) async {
  // if this is a fake test, then run the fake code path
  if (_isFakeTestExpando[currentTestCase]) {
    var uri = _localhostUri(0, path);

    var request = FakeHttpRequest(uri);

    var response = await _withFakeRequest(virtualDir, request);
    return response.fakeContent;
  }

  assert(_isFakeTestExpando[currentTestCase] == false);

  return _withServer(virtualDir, (int port) => _fetchAsString(port, path));
}

Future<List<int>> fetchAsBytes(VirtualDirectory virtualDir, String path,
    {int from, int to}) async {
  // if this is a fake test, then run the fake code path
  if (_isFakeTestExpando[currentTestCase]) {
    var uri = _localhostUri(0, path);

    var request = FakeHttpRequest(uri);
    _addRangeHeader(request, from, to);

    var response = await _withFakeRequest(virtualDir, request);
    return response.fakeContentBinary;
  }

  assert(_isFakeTestExpando[currentTestCase] == false);

  return _withServer(
      virtualDir, (int port) => _fetchAsBytes(port, path, from, to));
}

Future<List> fetchContentAndResponse(VirtualDirectory virtualDir, String path,
    {int from, int to}) async {
  // if this is a fake test, then run the fake code path
  if (_isFakeTestExpando[currentTestCase]) {
    var uri = _localhostUri(0, path);

    var request = FakeHttpRequest(uri);
    _addRangeHeader(request, from, to);

    var response = await _withFakeRequest(virtualDir, request);
    return [response.fakeContentBinary, response];
  }

  assert(_isFakeTestExpando[currentTestCase] == false);

  return _withServer(
      virtualDir, (int port) => _fetchContentAndResponse(port, path, from, to));
}

Future<FakeHttpResponse> _withFakeRequest(
    VirtualDirectory virDir, FakeHttpRequest request) async {
  var value = await virDir.serveRequest(request);

  expect(value, isNull);
  expect(request.response.fakeDone, isTrue);

  var response = request.response;

  if (response.statusCode == HttpStatus.movedPermanently ||
      response.statusCode == HttpStatus.movedTemporarily) {
    if (request.followRedirects == true) {
      var uri = Uri.parse(response.headers.value(HttpHeaders.locationHeader));
      var newMock = FakeHttpRequest(uri, followRedirects: true);

      return _withFakeRequest(virDir, newMock);
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

Future<HttpHeaders> _headers(int port, String path, int from, int to) async {
  var client = HttpClient();
  try {
    var request = await client.get('localhost', port, path);
    _addRangeHeader(request, from, to);
    var response = await request.close();
    await response.drain();
    return response.headers;
  } finally {
    client.close();
  }
}

Future<String> _fetchAsString(int port, String path) async {
  var client = HttpClient();
  try {
    var request = await client.get('localhost', port, path);
    var response = await request.close();
    return await utf8.decodeStream(response.cast<List<int>>());
  } finally {
    client.close();
  }
}

Future<List<int>> _fetchAsBytes(int port, String path, int from, int to) async {
  var client = HttpClient();
  try {
    var request = await client.get('localhost', port, path);
    _addRangeHeader(request, from, to);
    var response = await request.close();
    return await response.fold([], (p, e) => p..addAll(e));
  } finally {
    client.close();
  }
}

Future<List> _fetchContentAndResponse(
    int port, String path, int from, int to) async {
  var client = HttpClient();
  try {
    var request = await client.get('localhost', port, path);
    _addRangeHeader(request, from, to);
    var response = await request.close();
    var bytes = await response.fold([], (p, e) => p..addAll(e));
    return [bytes, response];
  } finally {
    client.close();
  }
}

Uri _localhostUri(int port, String path,
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
