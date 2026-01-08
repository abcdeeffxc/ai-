import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart'; // 剪贴板
import 'package:fluttertoast/fluttertoast.dart'; // 提示框
import 'package:flutter/foundation.dart' show kIsWeb;

void main() {
  runApp(const TranslateApp());
}

class TranslateApp extends StatelessWidget {
  const TranslateApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI翻译助手',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const TranslatePage(),
    );
  }
}

class TranslatePage extends StatefulWidget {
  const TranslatePage({super.key});

  @override
  State<TranslatePage> createState() => _TranslatePageState();
}

class _TranslatePageState extends State<TranslatePage> {
  final TextEditingController _inputController = TextEditingController();
  String _translation = '';
  List<String> _keywords = [];
  bool _isLoading = false;
  String _errorMsg = '';

  // 新增：复制翻译文本方法
// 复制翻译文本方法（含SnackBar+Toast双提示）
void _copyTranslation() {
  if (_translation.isEmpty) {
    // SnackBar提示（原生，全平台兼容）
    ScaffoldMessenger.of(context).showSnackBar(
       SnackBar(
        content: Text("暂无翻译内容可复制"),
        backgroundColor: Colors.grey.shade700,
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
    // Toast提示（备用）
    Fluttertoast.showToast(
      msg: "暂无翻译内容可复制",
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      timeInSecForIosWeb: 2,
      backgroundColor: Colors.grey.shade800,
      textColor: Colors.white,
      fontSize: 14.0,
    );
    return;
  }

  Clipboard.setData(ClipboardData(text: _translation)).then((_) {
    // SnackBar成功提示
    ScaffoldMessenger.of(context).showSnackBar(
       SnackBar(
        content: Text("✅ 翻译文本已复制到剪贴板"),
        backgroundColor: Colors.green.shade600,
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
    // Toast成功提示
    Fluttertoast.showToast(
      msg: "翻译文本已复制",
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      timeInSecForIosWeb: 2,
      backgroundColor: Colors.green.shade600,
      textColor: Colors.white,
      fontSize: 14.0,
    );
  }).catchError((error) {
    // 复制失败提示
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("❌ 复制失败：$error"),
        backgroundColor: Colors.red.shade600,
        duration: Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  });
}

  Future<void> _translateText() async {
    setState(() {
      _translation = '';
      _keywords = [];
      _errorMsg = '';
      _isLoading = true;
    });

    final inputText = _inputController.text.trim();
    if (inputText.isEmpty) {
      setState(() {
        _isLoading = false;
        _errorMsg = '请输入要翻译的中文内容';
      });
      return;
    }

    try {
      // 适配Web/模拟器/真机的接口地址
      String apiUrl = '';
      if (kIsWeb) {
        apiUrl = 'http://localhost:8000/translate'; // Web端（Edge）
      } else {
        apiUrl = 'http://10.0.2.2:8000/translate'; // 安卓模拟器

        // apiUrl = 'http://192.168.31.219:8000/translate';//真机请替换为：
      }

      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'text': inputText}),
      );

      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        setState(() {
          _translation = result['translation'];
          _keywords = List<String>.from(result['keywords']);
        });
      } else {
        setState(() {
          _errorMsg = '翻译失败：${response.statusCode} - ${response.body}';
        });
      }
    } catch (e) {
      setState(() {
        _errorMsg = '网络错误：${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI翻译助手'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _inputController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: '请输入要翻译的中文内容...',
                border: OutlineInputBorder(),
                labelText: '中文输入',
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isLoading ? null : _translateText,
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('翻译'),
            ),
            const SizedBox(height: 20),
            if (_errorMsg.isNotEmpty)
              Text(
                _errorMsg,
                style: const TextStyle(color: Colors.red, fontSize: 14),
              ),
            if (_translation.isNotEmpty)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '英文翻译：',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    // 可点击复制的翻译文本
                    InkWell(
                      onTap: _copyTranslation,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              _translation,
                              style: TextStyle(
                                fontSize: 15,
                                color: Colors.black87,
                                decoration: TextDecoration.underline,
                                decorationColor: Colors.blue.shade100,
                                decorationThickness: 1,
                              ),
                            ),
                          ),
                           Icon(
                            Icons.copy_rounded,
                            size: 18,
                            color: Colors.blue.shade400,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      '核心关键词：',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _keywords
                          .map((keyword) => Chip(
                                label: Text(keyword),
                                backgroundColor: Colors.blue.shade100,
                              ))
                          .toList(),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }
}