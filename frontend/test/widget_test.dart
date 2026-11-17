import 'package:flutter_test/flutter_test.dart';

import 'package:agrinexus_farmer/shared/api/api_config.dart';
import 'package:agrinexus_farmer/shared/api/api_exception.dart';

void main() {
  test('ApiConfig has a usable default base URL', () {
    expect(ApiConfig.baseUrl, startsWith('http'));
  });

  test('ApiException without a status code is a network error', () {
    expect(ApiException('offline').isNetworkError, isTrue);
    expect(ApiException('nope', statusCode: 401).isUnauthorized, isTrue);
  });
}
