import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:validatorless/validatorless.dart';
import '../../constants/app_constant.dart';
import '../../utils/http_util.dart';
import '../../utils/storage_util.dart';
import '../../router/app_router.dart';

class LoginRegisterPage extends StatefulWidget {
  const LoginRegisterPage({super.key});

  @override
  State<LoginRegisterPage> createState() => _LoginRegisterPageState();
}

class _LoginRegisterPageState extends State<LoginRegisterPage> with SingleTickerProviderStateMixin {
  final HttpUtil _http = HttpUtil();
  final _formKeyLogin = GlobalKey<FormState>();
  final _formKeyReg = GlobalKey<FormState>();
  late TabController _tabController;

  String _loginEmail = "", _loginPwd = "";
  String _regEmail = "", _regPwd = "";

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }


  Future<void> _register() async {
    if (!_formKeyReg.currentState!.validate()) return;
    _formKeyReg.currentState!.save();
    EasyLoading.show(status: "注册中...");

    try {
      var res = await _http.post(AppConstant.api_user_register, data: {
        "email": _regEmail.trim(),
        "password": _regPwd.trim()
      });

      if (!mounted) return;
      EasyLoading.dismiss();

      // 注册成功判断
      if (res["code"] == 200) {
        EasyLoading.showSuccess("注册成功，请前往邮箱激活！");
        _tabController.animateTo(0);
        _formKeyReg.currentState!.reset();
      } else {
        // 注册失败：提取接口返回的错误信息，无则用默认提示
        String errorMsg = res["msg"] ?? res["message"] ?? "注册失败，邮箱已存在或格式错误";
        EasyLoading.showError(errorMsg);
      }
    } on Exception catch (e) {
      if (!mounted) return;
      EasyLoading.dismiss();

      // 检查错误类型
      if (e.toString().contains("400") || e.toString().contains("Bad Request")) {
        // HTTP 400 错误，通常是邮箱格式错误或已被注册
        EasyLoading.showError("邮箱格式不正确或已被注册");
      } else {
        // 仅网络/请求异常时提示网络问题
        EasyLoading.showError("注册失败，请检查网络或稍后重试");
      }

      // 调试日志（可选）
      debugPrint("注册请求异常：$e");
    }
  }


  Future<void> _login() async {
    if (!_formKeyLogin.currentState!.validate()) return;
    _formKeyLogin.currentState!.save();
    EasyLoading.show(status: "登录中...");

    try {
      var res = await _http.post(AppConstant.api_user_login, data: {
        "email": _loginEmail.trim(),
        "password": _loginPwd.trim()
      });

      if (!mounted) return;
      EasyLoading.dismiss();

      // 检查响应是否包含access_token（登录成功）
      if (res["access_token"] != null) {
        await StorageUtil.setToken(res["access_token"]);
        await StorageUtil.setEmail(_loginEmail.trim());
        EasyLoading.showSuccess("登录成功！");
        Navigator.pushNamedAndRemoveUntil(context, AppRouter.index, (route) => false);
      } else {
        // 如果响应中包含错误信息
        String errorMsg = res["msg"] ?? res["message"] ?? "账号或密码错误，请重新输入";
        EasyLoading.showError(errorMsg);
      }
    } catch (e) {
      if (!mounted) return;
      EasyLoading.dismiss();

      // 检查错误类型
      if (e.toString().contains("400") || e.toString().contains("Bad Request")) {
        // HTTP 400 错误，通常意味着邮箱或密码错误
        EasyLoading.showError("邮箱或密码错误，请重新输入");
      } else if (e.toString().contains("403") || e.toString().contains("Forbidden")) {
        // HTTP 403 错误，账号未激活
        EasyLoading.showError("账号未激活！请先去邮箱完成激活");
      } else {
        // 其他网络错误
        EasyLoading.showError("登录失败，请检查网络或稍后重试");
      }

      debugPrint("登录请求异常：$e");
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // 背景图片
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              image: DecorationImage(
                // image: NetworkImage("https://picsum.photos/id/239/1920/1080"),
                image: AssetImage("images/login_bg.png"),
                fit: BoxFit.cover,
                alignment: Alignment.center,
              ),
            ),
          ),
          // 模糊效果层
          // BackdropFilter(
          //   filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          //   child: Container(
          //     color: Colors.transparent,
          //   ),
          // ),
          // 主内容
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                width: 420,
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 40),
                decoration: BoxDecoration(
                  color: const Color(0xFF1D2939).withOpacity(0.85),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: const [
                    BoxShadow(
                      color: Color.fromRGBO(0, 0, 0, 0.3),
                      blurRadius: 20,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "用户登录",
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      "欢迎登录系统，开始您的操作",
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFFD1D5DB),
                      ),
                    ),
                    const SizedBox(height: 30),

                    TabBar(
                      controller: _tabController,
                      labelColor: const Color(0xFF60A5FA),
                      unselectedLabelColor: const Color(0xFF9CA3AF),
                      indicatorColor: const Color(0xFF60A5FA),
                      indicatorWeight: 2,
                      indicatorSize: TabBarIndicatorSize.label,
                      labelStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                      unselectedLabelStyle: const TextStyle(fontSize: 16),
                      tabs: const [
                        Tab(text: "账号登录"),
                        Tab(text: "账号注册"),
                      ],
                    ),
                    const SizedBox(height: 25),

                    SizedBox(
                      height: 220,
                      child: TabBarView(
                        controller: _tabController,
                        children: [_buildLoginForm(), _buildRegForm()],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ========== 登录表单 深色适配样式 ==========
  Widget _buildLoginForm() {
    return Form(
      key: _formKeyLogin,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              hintText: "请输入登录邮箱",
              hintStyle: TextStyle(fontSize: 14, color: Color(0xFF9CA3AF)),
              border: UnderlineInputBorder(
                borderSide: BorderSide(color: Color(0xFF374151)),
              ),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Color(0xFF374151)),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Color(0xFF60A5FA), width: 1.5),
              ),
              contentPadding: EdgeInsets.symmetric(vertical: 12),
            ),
            validator: Validatorless.multiple([
              Validatorless.required("请输入邮箱"),
              Validatorless.email("邮箱格式不正确")
            ]),
            onSaved: (v) => _loginEmail = v?.trim() ?? "",
          ),
          const SizedBox(height: 25),
          TextFormField(
            style: const TextStyle(color: Colors.white),
            obscureText: true,
            decoration: const InputDecoration(
              hintText: "请输入登录密码",
              hintStyle: TextStyle(fontSize: 14, color: Color(0xFF9CA3AF)),
              border: UnderlineInputBorder(
                borderSide: BorderSide(color: Color(0xFF374151)),
              ),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Color(0xFF374151)),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Color(0xFF60A5FA), width: 1.5),
              ),
              contentPadding: EdgeInsets.symmetric(vertical: 12),
            ),
            validator: Validatorless.multiple([
              Validatorless.required("请输入密码"),
              Validatorless.min(6, "密码至少6位")
            ]),
            onSaved: (v) => _loginPwd = v?.trim() ?? "",
          ),
          const SizedBox(height: 30),
          ElevatedButton(
            onPressed: _login,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF096DD9),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              padding: const EdgeInsets.symmetric(vertical: 14),
              elevation: 0,
              shadowColor: Colors.transparent,
            ),
            child: const Text("登 录", style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
  }

  // ========== 注册表单 深色适配样式 ==========
  Widget _buildRegForm() {
    return Form(
      key: _formKeyReg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              hintText: "请输入注册邮箱",
              hintStyle: TextStyle(fontSize: 14, color: Color(0xFF9CA3AF)),
              border: UnderlineInputBorder(
                borderSide: BorderSide(color: Color(0xFF374151)),
              ),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Color(0xFF374151)),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Color(0xFF60A5FA), width: 1.5),
              ),
              contentPadding: EdgeInsets.symmetric(vertical: 12),
            ),
            validator: Validatorless.multiple([
              Validatorless.required("请输入邮箱"),
              Validatorless.email("邮箱格式不正确")
            ]),
            onSaved: (v) => _regEmail = v?.trim() ?? "",
          ),
          const SizedBox(height: 25),
          TextFormField(
            style: const TextStyle(color: Colors.white),
            obscureText: true,
            decoration: const InputDecoration(
              hintText: "请设置密码（至少6位）",
              hintStyle: TextStyle(fontSize: 14, color: Color(0xFF9CA3AF)),
              border: UnderlineInputBorder(
                borderSide: BorderSide(color: Color(0xFF374151)),
              ),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Color(0xFF374151)),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Color(0xFF60A5FA), width: 1.5),
              ),
              contentPadding: EdgeInsets.symmetric(vertical: 12),
            ),
            validator: Validatorless.multiple([
              Validatorless.required("请设置密码"),
              Validatorless.min(6, "密码至少6位")
            ]),
            onSaved: (v) => _regPwd = v?.trim() ?? "",
          ),
          const SizedBox(height: 30),
          ElevatedButton(
            onPressed: _register,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF096DD9),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              padding: const EdgeInsets.symmetric(vertical: 14),
              elevation: 0,
              shadowColor: Colors.transparent,
            ),
            child: const Text("注 册", style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
  }
}
