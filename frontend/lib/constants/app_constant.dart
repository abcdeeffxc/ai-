class AppConstant {
  /// ✅ 只改这里：你的后端局域网IP+端口 【必改】
  static const String baseUrl = "http://192.168.31.219:8000";

  static const String api_user_register = "/api/user/register";
  static const String api_user_login = "/api/user/login";
  static const String api_user_info = "/api/user/info";
  static const String api_change_nickname = "/api/user/change_nickname";
  static const String api_change_pwd = "/api/user/change_pwd";
  static const String api_upload_avatar = "/api/user/upload_avatar";
  static const String api_logout = "/api/user/logout";
  static const String api_save_hobby = "/api/user/save_hobby";
  static const String api_translate = "/api/translate"; // 翻译接口地址
  static const List<String> supportLanguages = ["中文", "英文", "日语"]; // 支持的翻译语言
  static const String api_stable = "/api/stable";

}