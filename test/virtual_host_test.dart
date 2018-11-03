// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import "package:test/test.dart";
import "package:http_server/http_server.dart";

import 'utils.dart';

void main() {
  setUpAll(setupSecure);

  test('empty-host', () {
    expect(
        HttpServer.bind('localhost', 0).then((server) {
          VirtualHost(server);
          return getStatusCode(server.port, '/').whenComplete(server.close);
        }),
        completion(equals(HttpStatus.forbidden)));
  });

  test('empty-host-unhandled', () {
    expect(
        HttpServer.bind('localhost', 0).then((server) {
          var virHost = VirtualHost(server);
          expect(virHost.unhandled.first.then((request) {
            request.response.close();
          }), completion(isNull));
          return getStatusCode(server.port, '/').whenComplete(server.close);
        }),
        completion(equals(HttpStatus.ok)));
  });

  test('single-host', () {
    expect(
        HttpServer.bind('localhost', 0).then((server) {
          var virHost = VirtualHost(server);
          expect(
              virHost.addHost('*.host.com').first.then((request) {
                request.response.close();
              }),
              completion(isNull));
          return getStatusCode(server.port, '/', host: 'my.host.com')
              .whenComplete(server.close);
        }),
        completion(equals(HttpStatus.ok)));
  });

  test('multiple-host', () {
    expect(
        HttpServer.bind('localhost', 0).then((server) {
          var virHost = VirtualHost(server);
          expect(
              virHost.addHost('*.host1.com').first.then((request) {
                request.response.close();
              }),
              completion(isNull));
          expect(
              virHost.addHost('*.host2.com').first.then((request) {
                request.response.close();
              }),
              completion(isNull));
          expect(
              virHost.addHost('*.host3.com').first.then((request) {
                request.response.close();
              }),
              completion(isNull));
          return Future.wait([
            getStatusCode(server.port, '/', host: 'my.host1.com'),
            getStatusCode(server.port, '/', host: 'my.host2.com'),
            getStatusCode(server.port, '/', host: 'my.host3.com')
          ]).whenComplete(server.close);
        }),
        completion(equals([HttpStatus.ok, HttpStatus.ok, HttpStatus.ok])));
  });

  test('multiple-source-https', () {
    expect(
        Future.wait([
          HttpServer.bind('localhost', 0),
          HttpServer.bindSecure('localhost', 0, serverContext)
        ]).then((servers) {
          var virHost = VirtualHost();
          virHost.addSource(servers[0]);
          virHost.addSource(servers[1]);
          virHost.unhandled.listen((request) {
            request.response.close();
          });
          return Future.wait([
            getStatusCode(servers[0].port, '/', host: 'myhost1.com'),
            getStatusCode(servers[1].port, '/',
                host: 'myhost2.com', secure: true)
          ]).whenComplete(() => servers.forEach((s) => s.close()));
        }),
        completion(equals([HttpStatus.ok, HttpStatus.ok])));
  });

  group('domain', () {
    test('specific-sub-domain', () {
      expect(
          HttpServer.bind('localhost', 0).then((server) {
            var virHost = VirtualHost(server);
            expect(
                virHost.addHost('my1.host.com').first.then((request) {
                  request.response.close();
                }),
                completion(isNull));
            expect(
                virHost.addHost('my2.host.com').first.then((request) {
                  request.response.close();
                }),
                completion(isNull));
            expect(
                virHost.addHost('my3.host.com').first.then((request) {
                  request.response.close();
                }),
                completion(isNull));
            return Future.wait([
              getStatusCode(server.port, '/', host: 'my1.host.com'),
              getStatusCode(server.port, '/', host: 'my2.host.com'),
              getStatusCode(server.port, '/', host: 'my3.host.com')
            ]).whenComplete(server.close);
          }),
          completion(equals([HttpStatus.ok, HttpStatus.ok, HttpStatus.ok])));
    });

    test('wildcard-sub-domain', () {
      expect(
          HttpServer.bind('localhost', 0).then((server) {
            var virHost = VirtualHost(server);
            expect(
                virHost.addHost('*.host1.com').first.then((request) {
                  request.response.close();
                }),
                completion(isNull));
            expect(
                virHost.addHost('*.host2.com').first.then((request) {
                  request.response.close();
                }),
                completion(isNull));
            expect(
                virHost.addHost('*.host3.com').first.then((request) {
                  request.response.close();
                }),
                completion(isNull));
            return Future.wait([
              getStatusCode(server.port, '/', host: 'my.host1.com'),
              getStatusCode(server.port, '/', host: 'my.host2.com'),
              getStatusCode(server.port, '/', host: 'my.host3.com')
            ]).whenComplete(server.close);
          }),
          completion(equals([HttpStatus.ok, HttpStatus.ok, HttpStatus.ok])));
    });

    test('mix-sub-domain', () {
      expect(
          HttpServer.bind('localhost', 0).then((server) {
            var virHost = VirtualHost(server);
            expect(
                virHost.addHost('my1.host.com').first.then((request) {
                  request.response.close();
                }),
                completion(isNull));
            expect(
                virHost.addHost('my2.host.com').first.then((request) {
                  request.response.close();
                }),
                completion(isNull));
            expect(
                virHost.addHost('*.host.com').first.then((request) {
                  request.response.close();
                }),
                completion(isNull));
            return Future.wait([
              getStatusCode(server.port, '/', host: 'my1.host.com'),
              getStatusCode(server.port, '/', host: 'my2.host.com'),
              getStatusCode(server.port, '/', host: 'my3.host.com')
            ]).whenComplete(server.close);
          }),
          completion(equals([HttpStatus.ok, HttpStatus.ok, HttpStatus.ok])));
    });

    test('wildcard', () {
      expect(
          HttpServer.bind('localhost', 0).then((server) {
            var virHost = VirtualHost(server);
            expect(
                virHost.addHost('*').first.then((request) {
                  request.response.close();
                }),
                completion(isNull));
            expect(
                virHost.addHost('*.com').first.then((request) {
                  request.response.close();
                }),
                completion(isNull));
            expect(
                virHost.addHost('*.host.com').first.then((request) {
                  request.response.close();
                }),
                completion(isNull));
            return Future.wait([
              getStatusCode(server.port, '/', host: 'some.host.dk'),
              getStatusCode(server.port, '/', host: 'my.host2.com'),
              getStatusCode(server.port, '/', host: 'long.sub.of.host.com')
            ]).whenComplete(server.close);
          }),
          completion(equals([HttpStatus.ok, HttpStatus.ok, HttpStatus.ok])));
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
