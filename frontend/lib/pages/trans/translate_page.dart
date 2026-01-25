import 'package:flutter/material.dart';
import 'dart:convert';
// 新增：导入剪贴板相关包
import 'package:flutter/services.dart';
// 必须导入你的工具类，和你首页的导入路径一致！！！
import '../../utils/storage_util.dart';
import '../../utils/http_util.dart';
import '../../constants/app_constant.dart';

class TranslatePage extends StatefulWidget {
  const TranslatePage({super.key});

  @override
  State<TranslatePage> createState() => _TranslatePageState();
}

class _TranslatePageState extends State<TranslatePage> {
  // 源语言输入控制器
  final TextEditingController _sourceController = TextEditingController();
  // 翻译结果+关键词
  String _translateResult = "";
  List<String> _keywords = [];
  // 源语言/目标语言选择
  String _sourceLang = "中文";
  String _targetLang = "英文";
  // 语言列表
  final List<String> _langList = ["中文", "英文", "日语", "韩语", "法语", "西班牙语"];
  // 加载状态
  bool _isLoading = false;

  // ========== 新增：复制功能方法 ==========
  // 替换原 _copyToClipboard 方法
  void _copyToClipboard(String text) async {
    // 1. 文本有效性校验（放宽合理判断条件）
    if (text.isEmpty || text == "请输入需要翻译的内容" || text.startsWith("翻译失败")) {
      // 使用全局上下文显示提示
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("暂无有效内容可复制"), duration: Duration(seconds: 1)),
        );
      }
      return;
    }

    try {
      // 2. 执行复制操作（添加异常捕获）
      await Clipboard.setData(ClipboardData(text: text));
      // 3. 全局上下文提示复制成功
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("复制成功！"), duration: Duration(seconds: 1)),
        );
      }
    } catch (e) {
      // 4. 捕获复制异常并提示
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("复制失败：${e.toString()}"), duration: Duration(seconds: 2)),
        );
      }
    }
  }
  // ========== ✅ 核心修改：替换为【真实的后端API请求】 ==========
  void _translate() async {
    String inputText = _sourceController.text.trim();
    // 判空提示
    if (inputText.isEmpty) {
      setState(() {
        _translateResult = "请输入需要翻译的内容";
        _keywords = [];
      });
      return;
    }

    // 开启加载中状态
    setState(() {
      _isLoading = true;
      _translateResult = "";
      _keywords = [];
    });

    try {
      // 1. 获取本地存储的登录Token (和你首页的鉴权逻辑一致)
      String? token = StorageUtil.getToken();
      if (token == null || token.isEmpty) {
        setState(() {
          _translateResult = "登录已过期，请重新登录！";
        });
        return;
      }

      // 2. 构建请求头：必须携带Authorization Bearer Token，后端鉴权用
      Map<String, dynamic> headers = {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token"
      };

      // 3. 构建请求体：传给后端的参数，只有一个text字段
      Map<String, dynamic> params = {
        "targetLang":_targetLang,
        "text": inputText
      };

      // 4. 调用后端真实翻译接口 (POST请求)
      var response = await HttpUtil().post(
        AppConstant.api_translate,
        data: params,
      );

      // 5. 解析后端返回的结果
      if (response != null) {
        setState(() {
          _translateResult = response["translation"] ?? "暂无翻译结果";
          _keywords = List<String>.from(response["keywords"] ?? []);
        });
      }

    } catch (e) {
      // 异常处理：网络错误、接口报错、Token无效等
      setState(() {
        _translateResult = "翻译失败：${e.toString()}";
        _keywords = [];
      });
    } finally {
      // 关闭加载中状态
      setState(() {
        _isLoading = false;
      });
    }
  }

  // 交换源语言和目标语言
  void _swapLang() {
    setState(() {
      String temp = _sourceLang;
      _sourceLang = _targetLang;
      _targetLang = temp;
    });
  }

  @override
  void dispose() {
    _sourceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("翻译工具", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 1,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 语言选择行
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _sourceLang,
                    decoration: const InputDecoration(
                      labelText: "源语言",
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12),
                    ),
                    items: _langList.map((lang) => DropdownMenuItem(
                      value: lang, child: Text(lang)
                    )).toList(),
                    onChanged: (value) {
                      if (value != null) setState(() => _sourceLang = value);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                IconButton(
                  icon: const Icon(Icons.swap_horiz, color: Colors.blue),
                  onPressed: _swapLang,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _targetLang,
                    decoration: const InputDecoration(
                      labelText: "目标语言",
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12),
                    ),
                    items: _langList.map((lang) => DropdownMenuItem(
                      value: lang, child: Text(lang)
                    )).toList(),
                    onChanged: (value) {
                      if (value != null) setState(() => _targetLang = value);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // 源文本输入框
            TextField(
              controller: _sourceController,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: "请输入需要翻译的内容",
                border: OutlineInputBorder(),
                hintText: "输入文本...",
                contentPadding: EdgeInsets.all(12),
              ),
            ),
            const SizedBox(height: 16),
            // 翻译按钮 - 加载中显示转圈，禁止点击
            ElevatedButton(
              onPressed: _isLoading ? null : _translate,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                  : const Text("开始翻译", style: TextStyle(fontSize: 16, color: Colors.white)),
            ),
            const SizedBox(height: 20),
            // 翻译结果+关键词展示区域
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade200),
                borderRadius: BorderRadius.circular(8),
                color: Colors.grey.shade50,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ========== 新增：翻译结果标题行 + 复制按钮 ==========
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("翻译结果：", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87)),
                      IconButton(
                        icon: const Icon(Icons.copy, color: Colors.blue, size: 20),
                        onPressed: () => _copyToClipboard(_translateResult),
                        tooltip: "复制翻译结果",
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(_translateResult, style: const TextStyle(fontSize: 16, color: Colors.black)),

                  // 关键词展示
                  if (_keywords.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    // ========== 新增：关键词标题行 + 复制按钮 ==========
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("核心关键词：", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87)),
                        IconButton(
                          icon: const Icon(Icons.copy, color: Colors.blue, size: 20),
                          onPressed: () => _copyToClipboard(_keywords.join(", ")),
                          tooltip: "复制关键词",
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _keywords.map((kw) => Chip(
                        label: Text(kw),
                        backgroundColor: Colors.blue.shade50,
                        labelStyle: const TextStyle(color: Colors.blue),
                      )).toList(),
                    )
                  ]
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}