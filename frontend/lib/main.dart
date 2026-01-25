import 'package:flutter/material.dart';
import 'router/app_router.dart';
import 'utils/storage_util.dart';
import 'utils/http_util.dart';
import 'pages/index/index_page.dart';
import 'pages/login/login_register_page.dart'; // 确保导入登录页
import 'package:flutter_easyloading/flutter_easyloading.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await StorageUtil.init();
  runApp(const MyApp());
  // 可选：配置EasyLoading样式
  configLoading();
}

// 新增EasyLoading配置方法
void configLoading() {
  EasyLoading.instance
    ..displayDuration = const Duration(milliseconds: 2000)
    ..indicatorType = EasyLoadingIndicatorType.fadingCircle
    ..maskType = EasyLoadingMaskType.clear
    ..backgroundColor = Colors.blue
    ..textColor = Colors.white
    ..indicatorColor = Colors.white
    ..userInteractions = false;
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: HttpUtil.navigatorKey,
      // 优化builder，避免child为空时的强制解包风险
      builder: (context, child) {
        return EasyLoading.init()(
          context,
          child ?? const SizedBox.shrink(), // 空值时返回空组件
        );
      },
      title: '用户中心',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: Colors.white,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
      ),
      initialRoute: AppRouter.login, // 初始页仍为登录页
      routes: AppRouter.routes,
      onGenerateRoute: (settings) {
        // 1. 核心逻辑：未登录（无Token）且请求的不是登录页 → 强制跳登录页
        bool isLogin = StorageUtil.getToken() != null;
        String targetRoute = settings.name ?? AppRouter.login;

        if (!isLogin && !AppRouter.noAuthRoutes.contains(targetRoute)) {
          return MaterialPageRoute(builder: (_) => const LoginRegisterPage());
}

        // 2. 已登录且请求登录页 → 跳首页
        if (isLogin && targetRoute == AppRouter.login) {
          return MaterialPageRoute(builder: (_) => const IndexPage());
        }

        // 3. 路由名不存在的兜底（已登录时跳首页）
        if (AppRouter.routes[targetRoute] == null) {
          return MaterialPageRoute(builder: (_) => const IndexPage());
        }

        // 4. 正常路由跳转（已登录且路由存在）
        return MaterialPageRoute(
          builder: (context) => AppRouter.routes[targetRoute]!(context),
        );
      },
    );
  }
}