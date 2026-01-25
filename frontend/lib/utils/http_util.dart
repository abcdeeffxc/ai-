import 'package:dio/dio.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import '../constants/app_constant.dart';
import '../utils/storage_util.dart';
import '../router/app_router.dart';
import 'package:flutter/material.dart';

class HttpUtil {
  static final HttpUtil _instance = HttpUtil._internal();
  factory HttpUtil() => _instance;
  late Dio dio;

  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  HttpUtil._internal() {
    BaseOptions options = BaseOptions(
      baseUrl: AppConstant.baseUrl,
      connectTimeout: const Duration(seconds: 12),
      receiveTimeout: const Duration(seconds: 12),
      contentType: Headers.jsonContentType,
    );
    dio = Dio(options);
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        if (options.path.contains('/stable')) {
          // 覆盖该请求的接收超时为60秒
          options.receiveTimeout = const Duration(seconds: 60);
          // 可选：如果需要，也可以调整连接超时
          // options.connectTimeout = const Duration(seconds: 20);
        }

        String? token = StorageUtil.getToken();
        if (token != null && token.isNotEmpty) {
          options.headers["Authorization"] = "Bearer $token";
        }
        handler.next(options);
      },
      onError: (DioException e, handler) {
        String msg = "请求失败，请检查网络";
        if (e.response != null) {
          msg = e.response?.data["msg"] ?? "请求失败，状态码:${e.response?.statusCode}";
          if (e.response?.statusCode == 401) {
            msg = "登录已过期，请重新登录";
            StorageUtil.clear();
            if (navigatorKey.currentState != null) {
              navigatorKey.currentState!.pushNamedAndRemoveUntil(
                AppRouter.login,
                (route) => false,
              );
            }
          }
        }
        EasyLoading.showError(msg);
        handler.next(e);
      },
    ));
  }

  Future get(String url, {Map<String, dynamic>? params}) async {
    Response res = await dio.get(url, queryParameters: params);
    return res.data;
  }

  Future post(String url, {Map<String, dynamic>? data}) async {
    Response res = await dio.post(url, data: data);
    return res.data;
  }

  Future uploadFile(String url, FormData formData) async {
    try {
      Response res = await dio.post(
        url,
        data: formData,
        onSendProgress: (int sent, int total) {
          // 可以在这里处理上传进度
          double progress = (sent / total) * 100;
          print('上传进度: ${progress.toStringAsFixed(2)}%');
        },
      );
      return res.data;
    } catch (e) {
      // 重新抛出异常以保持与其他方法的一致性
      rethrow;
    }
  }

}