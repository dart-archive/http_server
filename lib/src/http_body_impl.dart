// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:mime/mime.dart';

import 'http_body.dart';
import 'http_multipart_form_data.dart';

class HttpBodyHandlerTransformer
    extends StreamTransformerBase<HttpRequest, HttpRequestBody> {
  final Encoding _defaultEncoding;

  const HttpBodyHandlerTransformer(this._defaultEncoding);

  @override
  Stream<HttpRequestBody> bind(Stream<HttpRequest> stream) {
    var pending = 0;
    var closed = false;
    return stream.transform(StreamTransformer.fromHandlers(
        handleData: (request, sink) async {
          pending++;
          try {
            var body = await HttpBodyHandlerImpl.processRequest(
                request, _defaultEncoding);
            sink.add(body);
          } catch (e, st) {
            sink.addError(e, st);
          } finally {
            pending--;
            if (closed && pending == 0) sink.close();
          }
        },
        handleDone: (sink) {}));
  }
}

class HttpBodyHandlerImpl {
  static Future<HttpRequestBody> processRequest(
      HttpRequest request, Encoding defaultEncoding) async {
    try {
      var body = await process(request, request.headers, defaultEncoding);
      return _HttpRequestBody(request, body);
    } catch (e) {
      // Try to send BAD_REQUEST response.
      request.response.statusCode = HttpStatus.badRequest;
      await request.response.close();
      rethrow;
    }
  }

  static Future<HttpClientResponseBody> processResponse(
      HttpClientResponse response, Encoding defaultEncoding) async {
    var body = await process(response, response.headers, defaultEncoding);
    return _HttpClientResponseBody(response, body);
  }

  static Future<HttpBody> process(Stream<List<int>> stream, HttpHeaders headers,
      Encoding defaultEncoding) async {
    var contentType = headers.contentType;

    Future<HttpBody> asBinary() async {
      var builder = await stream.fold(
          BytesBuilder(), (builder, data) => builder..add(data));
      return _HttpBody('binary', builder.takeBytes());
    }

    Future<HttpBody> asText(Encoding defaultEncoding) async {
      Encoding encoding;
      var charset = contentType.charset;
      if (charset != null) encoding = Encoding.getByName(charset);
      encoding ??= defaultEncoding;
      var buffer = await encoding.decoder
          .bind(stream)
          .fold(StringBuffer(), (buffer, data) => buffer..write(data));
      return _HttpBody('text', buffer.toString());
    }

    Future<HttpBody> asFormData() async {
      var values =
          await MimeMultipartTransformer(contentType.parameters['boundary'])
              .bind(stream)
              .map((part) => HttpMultipartFormData.parse(part,
                  defaultEncoding: defaultEncoding))
              .map((multipart) async {
        dynamic data;
        if (multipart.isText) {
          var buffer = await multipart.fold<StringBuffer>(
              StringBuffer(), (b, s) => b..write(s));
          data = buffer.toString();
        } else {
          var buffer = await multipart.fold<BytesBuilder>(
              BytesBuilder(), (b, d) => b..add(d as List<int>));
          data = buffer.takeBytes();
        }
        var filename = multipart.contentDisposition.parameters['filename'];
        if (filename != null) {
          data = _HttpBodyFileUpload(multipart.contentType, filename, data);
        }
        return [multipart.contentDisposition.parameters['name'], data];
      }).toList();
      var parts = await Future.wait(values);
      var map = <String, dynamic>{};
      for (var part in parts) {
        map[part[0] as String] = part[1]; // Override existing entries.
      }
      return _HttpBody('form', map);
    }

    if (contentType == null) {
      return asBinary();
    }

    switch (contentType.primaryType) {
      case 'text':
        return asText(defaultEncoding);

      case 'application':
        switch (contentType.subType) {
          case 'json':
            var body = await asText(utf8);
            return _HttpBody('json', jsonDecode(body.body as String));

          case 'x-www-form-urlencoded':
            var body = await asText(ascii);
            var map = Uri.splitQueryString(body.body as String,
                encoding: defaultEncoding);
            var result = {};
            for (var key in map.keys) {
              result[key] = map[key];
            }
            return _HttpBody('form', result);

          default:
            break;
        }
        break;

      case 'multipart':
        switch (contentType.subType) {
          case 'form-data':
            return asFormData();

          default:
            break;
        }
        break;

      default:
        break;
    }

    return asBinary();
  }
}

class _HttpBodyFileUpload implements HttpBodyFileUpload {
  @override
  final ContentType contentType;
  @override
  final String filename;
  @override
  final dynamic content;
  _HttpBodyFileUpload(this.contentType, this.filename, this.content);
}

class _HttpBody implements HttpBody {
  @override
  final String type;
  @override
  final dynamic body;

  _HttpBody(this.type, this.body);
}

class _HttpRequestBody extends _HttpBody implements HttpRequestBody {
  @override
  final HttpRequest request;

  _HttpRequestBody(this.request, HttpBody body) : super(body.type, body.body);
}

class _HttpClientResponseBody extends _HttpBody
    implements HttpClientResponseBody {
  @override
  final HttpClientResponse response;

  _HttpClientResponseBody(this.response, HttpBody body)
      : super(body.type, body.body);
}
