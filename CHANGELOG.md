# 1.0.0

* Migrate to null safety.
* Allow multipart form data with specified encodings that don't require
  decoding.

# 0.9.8+3

* Prepare for `HttpClientResponse` SDK change (implements `Stream<Uint8List>`
  rather than `Stream<List<int>>`).

# 0.9.8+2

* Prepare for `File.openRead()` SDK change in signature.

# 0.9.8+1

* Fix a Dart 2 type issue.

# 0.9.8

* Updates to support Dart 2 constants.

# 0.9.7

* Updates to support Dart 2.0 core library changes (wave
  2.2). See [issue 31847][sdk#31847] for details.

  [sdk#31847]: https://github.com/dart-lang/sdk/issues/31847

# 0.9.6

* Updated the secure networking code to the SDKs version 1.15 SecurityContext api

# 0.9.5+1

* Updated the layout of package contents.

# 0.9.5

* Removed the decoding of HTML entity values (in the form &#xxxxx;) for
  values when parsing multipart/form-post requests.

# 0.9.4

* Fixed bugs in the handling of the Range header
