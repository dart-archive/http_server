// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import 'package:test/test.dart';
import 'package:http_server/http_server.dart';

import 'utils.dart';

void main() {
  setUpAll(setupSecure);

  group('virtual host', () {
    HttpServer server;
    VirtualHost virHost;

    setUp(() async {
      server = await HttpServer.bind('localhost', 0);
      virHost = VirtualHost(server);
    });

    tearDown(() async {
      await server.close();
    });
    test('empty-host', () async {
      var statusCode = await fetchStatusCode(server.port, '/');
      expect(statusCode, equals(HttpStatus.forbidden));
    });

    test('empty-host-unhandled', () async {
      var statusCodes = fetchStatusCode(server.port, '/');
      var request = await virHost.unhandled.first;
      await request.response.close();
      expect(await statusCodes, equals(HttpStatus.ok));
    });

    test('single-host', () async {
      var host = virHost.addHost('*.host.com');
      var statusCode = fetchStatusCode(server.port, '/', host: 'my.host.com');
      var request = await host.first;
      await request.response.close();
      expect(await statusCode, equals(HttpStatus.ok));
    });

    test('multiple-host', () async {});

    group('domain', () {
      test('specific-sub-domain', () async {
        var hosts = [
          virHost.addHost('my1.host.com'),
          virHost.addHost('my2.host.com'),
          virHost.addHost('my3.host.com'),
        ];
        var statusCodes = [
          fetchStatusCode(server.port, '/', host: 'my1.host.com'),
          fetchStatusCode(server.port, '/', host: 'my2.host.com'),
          fetchStatusCode(server.port, '/', host: 'my3.host.com'),
        ];
        for (var host in hosts) {
          var request = await host.first;
          await request.response.close();
        }
        expect(await Future.wait(statusCodes),
            equals([HttpStatus.ok, HttpStatus.ok, HttpStatus.ok]));
      });

      test('wildcard-sub-domain', () async {
        var hosts = [
          virHost.addHost('*.host1.com'),
          virHost.addHost('*.host2.com'),
          virHost.addHost('*.host3.com'),
        ];
        var statusCodes = [
          fetchStatusCode(server.port, '/', host: 'my.host1.com'),
          fetchStatusCode(server.port, '/', host: 'my.host2.com'),
          fetchStatusCode(server.port, '/', host: 'my.host3.com'),
        ];
        for (var host in hosts) {
          var request = await host.first;
          await request.response.close();
        }
        expect(await Future.wait(statusCodes),
            equals([HttpStatus.ok, HttpStatus.ok, HttpStatus.ok]));
      });

      test('mix-sub-domain', () async {
        var hosts = [
          virHost.addHost('my1.host.com'),
          virHost.addHost('my2.host.com'),
          virHost.addHost('*.host.com'),
        ];
        var statusCodes = [
          fetchStatusCode(server.port, '/', host: 'my1.host.com'),
          fetchStatusCode(server.port, '/', host: 'my2.host.com'),
          fetchStatusCode(server.port, '/', host: 'my3.host.com'),
        ];
        for (var host in hosts) {
          var request = await host.first;
          await request.response.close();
        }
        expect(await Future.wait(statusCodes),
            equals([HttpStatus.ok, HttpStatus.ok, HttpStatus.ok]));
      });

      test('wildcard', () async {
        var hosts = [
          virHost.addHost('*'),
          virHost.addHost('*.com'),
          virHost.addHost('*.host.com'),
        ];
        var statusCodes = [
          fetchStatusCode(server.port, '/', host: 'some.host.dk'),
          fetchStatusCode(server.port, '/', host: 'my.host2.com'),
          fetchStatusCode(server.port, '/', host: 'long.sub.of.host.com'),
        ];
        for (var host in hosts) {
          var request = await host.first;
          await request.response.close();
        }
        expect(await Future.wait(statusCodes),
            equals([HttpStatus.ok, HttpStatus.ok, HttpStatus.ok]));
      });
    });

    test('multiple-source-https', () async {
      var secondServer =
          await HttpServer.bindSecure('localhost', 0, serverContext);
      virHost.addSource(secondServer);
      virHost.unhandled.listen((request) {
        request.response.close();
      });
      var statusCodes = await Future.wait([
        fetchStatusCode(server.port, '/', host: 'myhost1.com'),
        fetchStatusCode(secondServer.port, '/',
            host: 'myhost2.com', secure: true)
      ]);
      expect(statusCodes, [HttpStatus.ok, HttpStatus.ok]);
      await secondServer.close();
    });

    test('duplicate-domain', () {
      var virHost = VirtualHost();
      virHost.addHost('my1.host.com');
      expect(() => (virHost.addHost('my1.host.com')), throwsArgumentError);
      virHost.addHost('*.host.com');
      expect(() => (virHost.addHost('*.host.com')), throwsArgumentError);
      virHost.addHost('my2.host.com');
      virHost.addHost('my3.host.com');
      virHost.addHost('*.com');
      virHost.addHost('*');
      expect(() => (virHost.addHost('*')), throwsArgumentError);
    });
  });
}
