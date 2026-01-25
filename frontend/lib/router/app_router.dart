import 'package:flutter/material.dart';
import '../pages/Drawing/stable_page.dart';
import '../pages/login/login_register_page.dart';
import '../pages/index/index_page.dart';
import '../pages/profile/profile_page.dart';
import '../pages/user_info/edit_nickname_page.dart';
import '../pages/user_info/edit_pwd_page.dart';
import '../pages/hobby/hobby_manager_page.dart';
import '../pages/trans/translate_page.dart';
class AppRouter {
  // 路由常量 全部正确，无拼写错误

  static const String login = "/login";
  static const String index = "/index";
  static const String profile = "/profile";
  static const String editNickname = "/editNickname";
  static const String editPwd = "/editPwd";
  static const String hobby = "/hobby";
  static const String translate = "/translate";
  static const String stable = "/stable";

  static const List<String> noAuthRoutes = [AppRouter.login];

  // 路由映射表 一一对应，绝对正确
  static final Map<String, WidgetBuilder> routes = {

    login: (context) => const LoginRegisterPage(),
    index: (context) => const IndexPage(),
    profile: (context) => const ProfilePage(),
    editNickname: (context) => const EditNicknamePage(),
    editPwd: (context) => const EditPwdPage(),
    hobby: (context) => const HobbyManagerPage(),
    translate: (context) => const TranslatePage(),
    stable: (context) => const StablePage(),
  };
}