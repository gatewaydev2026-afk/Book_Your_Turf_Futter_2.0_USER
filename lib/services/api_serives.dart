// api_service.dart
import 'package:dio/dio.dart';
import 'package:get/get.dart';

class ApiService extends GetxService {
  late Dio dio;

  @override
  void onInit() {
    super.onInit();
    dio = Dio(BaseOptions(
      baseUrl: 'https://your-api-base-url.com', // Update with your API base URL
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));

    // Add logging interceptor
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        print('🚀 API Request: ${options.method} ${options.path}');
        print('📦 Request Data: ${options.data}');
        return handler.next(options);
      },
      onResponse: (response, handler) {
        print('✅ API Response: ${response.statusCode} ${response.requestOptions.path}');
        print('📦 Response Data: ${response.data}');
        return handler.next(response);
      },
      onError: (error, handler) {
        print('❌ API Error: ${error.message}');
        print('📦 Error Response: ${error.response?.data}');
        return handler.next(error);
      },
    ));
  }
}