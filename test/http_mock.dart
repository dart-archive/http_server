library http_mock;

import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

class MockHttpHeaders implements HttpHeaders {
  final Map<String, List<String>> _headers = HashMap<String, List<String>>();

  operator [](key) => _headers[key];

  int get contentLength =>
      int.parse(_headers[HttpHeaders.contentLengthHeader][0]);

  DateTime get ifModifiedSince {
    var values = _headers[HttpHeaders.ifModifiedSinceHeader];
    if (values != null) {
      try {
        return HttpDate.parse(values[0]);
      } on Exception {
        return null;
      }
    }
    return null;
  }

  set ifModifiedSince(DateTime ifModifiedSince) {
    // Format "ifModifiedSince" header with date in Greenwich Mean Time (GMT).
    var formatted = HttpDate.format(ifModifiedSince.toUtc());
    _set(HttpHeaders.ifModifiedSinceHeader, formatted);
  }

  ContentType contentType;

  void set(String name, Object value) {
    name = name.toLowerCase();
    _headers.remove(name);
    _addAll(name, value);
  }

  String value(String name) {
    name = name.toLowerCase();
    var values = _headers[name];
    if (values == null) return null;
    if (values.length > 1) {
      throw HttpException("More than one value for header $name");
    }
    return values[0];
  }

  String toString() => '$runtimeType : $_headers';

  // [name] must be a lower-case version of the name.
  void _add(String name, value) {
    if (name == HttpHeaders.ifModifiedSinceHeader) {
      if (value is DateTime) {
        ifModifiedSince = value;
      } else if (value is String) {
        _set(HttpHeaders.ifModifiedSinceHeader, value);
      } else {
        throw HttpException("Unexpected type for header named $name");
      }
    } else {
      _addValue(name, value);
    }
  }

  void _addAll(String name, value) {
    if (value is List) {
      for (var i = 0; i < value.length; i++) {
        _add(name, value[i]);
      }
    } else {
      _add(name, value);
    }
  }

  void _addValue(String name, Object value) {
    var values = _headers[name];
    if (values == null) {
      values = <String>[];
      _headers[name] = values;
    }
    if (value is DateTime) {
      values.add(HttpDate.format(value));
    } else {
      values.add(value.toString());
    }
  }

  void _set(String name, String value) {
    assert(name == name.toLowerCase());
    var values = <String>[];
    _headers[name] = values;
    values.add(value);
  }

  /*
   * Implemented to remove editor warnings
   */
  dynamic noSuchMethod(Invocation invocation) {
    print([
      invocation.memberName,
      invocation.isGetter,
      invocation.isSetter,
      invocation.isMethod,
      invocation.isAccessor
    ]);
    return super.noSuchMethod(invocation);
  }
}

class MockHttpRequest implements HttpRequest {
  final Uri uri;
  final MockHttpResponse response = MockHttpResponse();
  final HttpHeaders headers = MockHttpHeaders();
  final String method = 'GET';
  final bool followRedirects;

  MockHttpRequest(this.uri,
      {this.followRedirects = true, DateTime ifModifiedSince}) {
    if (ifModifiedSince != null) {
      headers.ifModifiedSince = ifModifiedSince;
    }
  }

  /*
   * Implemented to remove editor warnings
   */
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockHttpResponse implements HttpResponse {
  final HttpHeaders headers = MockHttpHeaders();
  final Completer _completer = Completer();
  final List<int> _buffer = <int>[];
  String _reasonPhrase;
  Future _doneFuture;

  MockHttpResponse() {
    _doneFuture = _completer.future.whenComplete(() {
      assert(!_isDone);
      _isDone = true;
    });
  }

  bool _isDone = false;

  int statusCode = HttpStatus.ok;

  String get reasonPhrase => _findReasonPhrase(statusCode);

  set reasonPhrase(String value) {
    _reasonPhrase = value;
  }

  Future get done => _doneFuture;

  Future close() {
    _completer.complete();
    return _doneFuture;
  }

  void add(List<int> data) {
    _buffer.addAll(data);
  }

  void addError(error, [StackTrace stackTrace]) {
    // doesn't seem to be hit...hmm...
  }

  Future redirect(Uri location, {int status = HttpStatus.movedPermanently}) {
    statusCode = status;
    headers.set(HttpHeaders.locationHeader, location.toString());
    return close();
  }

  void write(Object obj) {
    var str = obj.toString();
    add(utf8.encode(str));
  }

  /*
   * Implemented to remove editor warnings
   */
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  String get mockContent => utf8.decode(_buffer);

  List<int> get mockContentBinary => _buffer;

  bool get mockDone => _isDone;

  // Copied from SDK http_impl.dart @ 845 on 2014-01-05
  // TODO: file an SDK bug to expose this on HttpStatus in some way
  String _findReasonPhrase(int statusCode) {
    if (_reasonPhrase != null) {
      return _reasonPhrase;
    }

    switch (statusCode) {
      case HttpStatus.notFound:
        return "Not Found";
      default:
        return "Status $statusCode";
    }
  }
}
