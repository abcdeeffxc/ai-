import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:http/http.dart' show MediaType;
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
import 'dart:io';
import '../../router/app_router.dart';
import '../../constants/app_constant.dart';
import '../../utils/http_util.dart';
import '../../utils/storage_util.dart';
import 'package:flutter/foundation.dart';
import 'package:mime_type/mime_type.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final HttpUtil _http = HttpUtil();
  final ImagePicker _picker = ImagePicker();
  String? _userEmail;
  String? _userName;
  String? _userAvatar;

  @override
  void initState() {
    super.initState();
    _initUserInfo();
  }

  Future<void> _initUserInfo() async {
    if (!mounted) return;
    setState(() {
      _userEmail = StorageUtil.getEmail() ?? "用户账号";
      _userName = StorageUtil.getNickname() ?? _userEmail;
      _userAvatar = StorageUtil.getAvatar();
    });
    await _refreshUserInfo();
  }

  Future<void> _refreshUserInfo() async {
    try {
      var res = await _http.get(AppConstant.api_user_info);
      if (mounted && res["code"] == 200) {
        setState(() {
          _userName = res["data"]["nickname"] ?? _userEmail;
          _userAvatar = res["data"]["avatar"];
        });
        await StorageUtil.setNickname(_userName!);
        await StorageUtil.setAvatar(_userAvatar!);
      }
    } catch (e) {
      debugPrint("刷新信息失败: $e");
    }
  }

Future<void> printAvatarFormData(FormData formData) async {
  print("\n========== 头像上传 FormData 详情 ==========");

  // 1. 打印普通字段（如果有）
  if (formData.fields.isNotEmpty) {
    print("【普通字段】");
    for (var entry in formData.fields) {
      print("  ${entry.key} = ${entry.value}");
    }
  } else {
    print("【普通字段】：无");
  }

  // 2. 打印字节流文件字段（核心：适配 MultipartFile.fromBytes）
  if (formData.files.isNotEmpty) {
    print("\n【头像文件字段（字节流）】");
    for (var entry in formData.files) {
      String fieldName = entry.key; // 字段名（你的场景是 "avatar"）
      MultipartFile file = entry.value;

      // 解析字节流文件的关键信息
      String fileName = file.filename ?? "未设置文件名";
      String contentType = file.contentType?.toString() ?? "image/jpeg（默认）";
      int byteLength = await file.length; // 字节长度（关键：字节流的大小）
      double sizeKB = byteLength / 1024; // 转KB更易读
      double sizeMB = sizeKB / 1024; // 转MB（可选）

      // 移除了不存在的 file.isBytes 属性
      print("  字段名：$fieldName");
      print("  文件名：$fileName");
      print("  文件类型：$contentType");
      print("  字节长度：$byteLength B");
      print("  文件大小：${sizeKB.toStringAsFixed(2)} KB (${sizeMB.toStringAsFixed(2)} MB)");
      print("  是否为字节流：无法直接判断（已移除不存在的属性）");
    }
  } else {
    print("\n【头像文件字段】：无");
  }
}

Future<void> _uploadAvatar() async {
  final XFile? image = await _picker.pickImage(
    source: ImageSource.gallery, imageQuality: 80);

  if (image == null) return;

  try {
    // 统一文件大小检测
    List<int> fileBytes = await image.readAsBytes();
    int fileSize = fileBytes.length;

    if (fileSize > 5 * 1024 * 1024) {
      EasyLoading.showError("图片大小不能超过5MB");
      return;
    }

    // 验证文件类型
    String extension = image.name.toLowerCase();
    if (!['.jpg', '.jpeg', '.png', '.webp'].any((ext) => extension.endsWith(ext))) {
      EasyLoading.showError("仅支持JPG/JPEG/PNG/WEBP格式的图片");
      return;
    }

    EasyLoading.show(status: "头像上传中...");
    if (fileBytes.isEmpty) {
      EasyLoading.showError("文件内容为空");
      return;
    }

// 确保 FormData 正确构建
FormData formData;
if (kIsWeb) {
  String mimeType = mime(extension) ?? 'image/jpeg';
  formData = FormData.fromMap({
    "file": MultipartFile.fromBytes(
      fileBytes,
      filename: "${DateTime.now().millisecondsSinceEpoch}${extension}",
      contentType: mimeType.isNotEmpty ? MediaType.parse(mimeType) : MediaType.parse('image/jpeg'),
    ),
  });

  await printAvatarFormData(formData);
} else {
  formData = FormData.fromMap({
    "file": await MultipartFile.fromFile(
      image.path,
      filename: "${DateTime.now().millisecondsSinceEpoch}${extension}",
    ),
  });
}

    var res = await _http.uploadFile(AppConstant.api_upload_avatar, formData);
    EasyLoading.dismiss();

    if (res["code"] == 200) {
      EasyLoading.showSuccess("头像更换成功！");
      String avatarUrl = res["data"]["avatar_url"];
      String processedUrl = _processAvatarUrl(avatarUrl);
      setState(() => _userAvatar = processedUrl);
      await StorageUtil.setAvatar(processedUrl);
    } else {
      String errorMsg = res["msg"] ?? res["message"] ?? "头像上传失败";
      EasyLoading.showError(errorMsg);
    }
  } on DioException catch (e) {
    EasyLoading.dismiss();
    // 错误处理逻辑保持不变
    if (e.response != null) {
      var errorResponse = e.response!;
      String errorMsg = "";
      print("afsdfj");
      if (errorResponse.data != null && errorResponse.data is Map<String, dynamic>) {
        print(errorResponse.data);
        errorMsg = errorResponse.data["msg"] ?? errorResponse.data["message"] ??
            "服务器错误 (${errorResponse.statusCode})";
      } else {
        print("错误2");
        errorMsg = "服务器错误 (${errorResponse.statusCode})";

      }
      EasyLoading.showError(errorMsg);
    } else if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout) {
      EasyLoading.showError("网络超时，请检查网络连接");
    } else if (e.type == DioExceptionType.connectionError) {
      EasyLoading.showError("网络连接错误，请检查网络");
    } else {
      EasyLoading.showError("上传失败：${e.message}");
    }
  } catch (e) {
    EasyLoading.dismiss();
    EasyLoading.showError("头像上传失败：${e.toString()}");
  }
}


// 获取 MIME 类型辅助方法
String _getMimeType(String extension) {
  switch (extension.toLowerCase()) {
    case '.jpg':
    case '.jpeg':
      return 'image/jpeg';
    case '.png':
      return 'image/png';
    case '.webp':
      return 'image/webp';
    default:
      return 'application/octet-stream';
  }
}



  // 处理头像URL格式
  String _processAvatarUrl(String url) {
    // 如果URL已经包含完整的协议部分，则直接返回
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return url;
    }

    // 如果是相对路径，则拼接基础URL
    if (url.startsWith('/')) {
      return "${AppConstant.baseUrl}$url";
    } else {
      return "${AppConstant.baseUrl}/$url";
    }
  }
Widget _buildAvatarWidget() {
  if (_userAvatar != null && _userAvatar!.isNotEmpty) {
    return CachedNetworkImage(
      imageUrl: _userAvatar!,  // 已经处理过的URL
      fit: BoxFit.cover,
      width: 100,
      height: 100,
      placeholder: (context, url) => const CircularProgressIndicator(),
      errorWidget: (context, url, error) => defaultAvatar(),
    );
  }
  return defaultAvatar();
}



  // ✅ 登出功能 - 安全无崩溃、无回退栈、清除所有缓存
  Future<void> _logout() async {
    EasyLoading.show(status: "登出中...");
    try {
      await _http.post(AppConstant.api_logout);
      await StorageUtil.clear();
      EasyLoading.dismiss();
      EasyLoading.showSuccess("登出成功！");
      // ✅ 安全跳转登录页，判断上下文非空，绝对无空值异常
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          AppRouter.login,
          (Route<dynamic> route) => false,
        );
      }
    } catch (e) {
      EasyLoading.dismiss();
      EasyLoading.showError("登出失败，请重试");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text("个人信息修改", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            // 用户信息卡片
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
                boxShadow: [BoxShadow(color: Color(0x0F000000), blurRadius: 8, offset: Offset(0, 2))],
              ),
              child: Column(
                children: [
                  GestureDetector(
                    onTap: _uploadAvatar,
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.blue.shade100, width: 3),
                        borderRadius: BorderRadius.circular(50),
                        boxShadow: [BoxShadow(color: Colors.blue.shade50, blurRadius: 6, offset: Offset(0, 3))],
                      ),
                      child: ClipOval(child: _buildAvatarWidget()),
                    ),
                  ),
                  const SizedBox(height: 5),
                  const Text("点击更换头像", style: TextStyle(color: Colors.grey, fontSize: 12)),
                  const SizedBox(height: 15),
                  Text(
                    _userName!,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: Colors.black87),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _userEmail!,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // 功能按钮组
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Color(0x0F000000), blurRadius: 8, offset: Offset(0, 2))],
              ),
              child: Column(
                children: [
                  _buildFuncItem(Icons.person_outline, "修改昵称", () {
                    Navigator.pushNamed(context, AppRouter.editNickname).then((_) => _refreshUserInfo());
                  }),
                  _buildLine(),
                  _buildFuncItem(Icons.lock_outline, "修改密码", () {
                    Navigator.pushNamed(context, AppRouter.editPwd);
                  }),
                  _buildLine(),
                  _buildFuncItem(Icons.favorite_border, "兴趣列表管理", () {
                    Navigator.pushNamed(context, AppRouter.hobby).then((_) => _refreshUserInfo());
                  }),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // 登出按钮-独立展示，红色警示
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _logout,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent.shade200,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  elevation: 0,
                ),
                child: const Text("安全登出", style: TextStyle(fontSize: 16, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget defaultAvatar() {
    return const Icon(Icons.person, size: 80, color: Colors.white70);
  }

  Widget _buildFuncItem(IconData icon, String title, Function() onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        child: Row(
          children: [
            Icon(icon, color: Colors.blue.shade600, size: 22),
            const SizedBox(width: 15),
            Text(title, style: const TextStyle(fontSize: 16, color: Colors.black87)),
            const Spacer(),
            Icon(Icons.arrow_forward_ios, color: Colors.grey.shade400, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildLine() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      height: 0.8,
      color: Colors.grey.shade100,
    );
  }
}
