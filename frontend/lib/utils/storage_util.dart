import 'package:shared_preferences/shared_preferences.dart';

class StorageUtil {
  static late SharedPreferences _prefs;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  static Future<bool> setString(String key, String value) => _prefs.setString(key, value);
  static String? getString(String key) => _prefs.getString(key);
  static Future<bool> remove(String key) => _prefs.remove(key);
  static Future<bool> clear() => _prefs.clear();

  static const String tokenKey = "token";
  static const String emailKey = "email";
  static const String avatarKey = "avatarUrl";
  static const String nicknameKey = "nickname";

  static String? getToken() => getString(tokenKey);
  static Future<bool> setToken(String token) => setString(tokenKey, token);
  static String? getEmail() => getString(emailKey);
  static Future<bool> setEmail(String email) => setString(emailKey, email);
  static String? getAvatar() => getString(avatarKey);
  static Future<bool> setAvatar(String avatar) => setString(avatarKey, avatar);
  static String? getNickname() => getString(nicknameKey);
  static Future<bool> setNickname(String nickname) => setString(nicknameKey, nickname);
}