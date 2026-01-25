import 'package:flutter/material.dart';
import 'dart:convert';
// 新增：导入剪贴板相关包
import 'package:flutter/services.dart';
// 必须导入你的工具类，和你首页的导入路径一致！！！
import '../../utils/storage_util.dart';
import '../../utils/http_util.dart';
import '../../constants/app_constant.dart';
import 'package:dio/dio.dart';
// 新增：导入文件操作相关包
import 'dart:io';
import 'package:path_provider/path_provider.dart';
// 新增：导入shared_preferences包用于存储图片信息
import 'package:shared_preferences/shared_preferences.dart';

class StablePage extends StatefulWidget {
  const StablePage({super.key});

  @override
  State<StablePage> createState() => _StablePageState();
}

class _StablePageState extends State<StablePage> with SingleTickerProviderStateMixin {
  // 源语言输入控制器
  final TextEditingController _sourceController = TextEditingController();
  // 日期显示控制器
  late final TextEditingController _dateController;
  // 想象结果+关键词
  String _image_url = "";
  String _translateResult = "";
  String _keywords = "";
  // 源语言/目标语言选择
  String _sourceLang = "${DateTime.now().year}-${DateTime.now().month}-${DateTime.now().day}";
  String _targetLang = "万能";
  // 模型列表
  final List<String> _langList = ['古风', '现代', '2次元', '卡通', '写真', '万能', '赛博', '3D'];
  // 加载状态
  bool _isLoading = false;
  
  // 图片库相关
  List<Map<String, String>> _generatedImages = [];

  // ========== 新增：从服务器获取图片列表 ==========
  Future<void> _loadServerImages() async {
    try {
      String? token = StorageUtil.getToken();
      if (token == null || token.isEmpty) {
        print("用户未登录，无法获取服务器图片列表");
        await _loadGeneratedImages(); // 回退到本地存储
        return;
      }

      // 调用后端API获取图片列表
      Map<String, dynamic> headers = {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token"
      };

      var response = await HttpUtil().get(
        '${AppConstant.baseUrl}/api/stable/gallery', // 调用新的API
      );

      if (response != null && response["code"] == 200) {
        List<dynamic> serverImages = response["data"] as List<dynamic>;
        
        setState(() {
          // 清空现有列表并添加服务器图片
          _generatedImages.clear();
          for (var img in serverImages) {
            String imageUrl = img["image_url"];
            String prompt = img["prompt"] ?? "";
            String negativePrompt = img["negative_prompt"] ?? "";
            String date = img["date"] != null 
              ? img["date"].toString()
              : DateTime.now().toString();
            
            _generatedImages.add({
              'url': _cleanImageUrl(imageUrl),
              'prompt': prompt,
              'negativePrompt': negativePrompt,
              'date': date
            });
          }
        });
        
        // 同时保存到本地存储以便离线访问
        await _saveGeneratedImages();
      } else {
        print("获取服务器图片列表失败或列表为空: ${response?["msg"]}");
        // 如果API不可用，回退到本地存储
        await _loadGeneratedImages();
      }
    } catch (e) {
      print('加载服务器图片失败: $e');
      // 发生错误时回退到本地存储
      await _loadGeneratedImages();
    }
  }
  
  @override
  void initState() {
    super.initState();
    _dateController = TextEditingController(text: _sourceLang);
    _loadServerImages(); // 改为加载服务器图片列表
  }

  @override
  void dispose() {
    _sourceController.dispose();
    _dateController.dispose(); // 释放日期控制器
    super.dispose();
  }

  // ========== 新增：复制功能方法 ==========
  // 替换原 _copyToClipboard 方法
  void _copyToClipboard(String text) async {
    // 1. 文本有效性校验（放宽合理判断条件）
    if (text.isEmpty || text == "请输入需要想象的内容" || text.startsWith("想象失败")) {
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

        _translateResult = "请输入需要想象的内容";
        _keywords = "";
      });
      return;
    }

    // 开启加载中状态
    setState(() {
      _isLoading = true;
      _image_url = "";
      _translateResult = "";
      _keywords = "";
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
        "model": _targetLang, // 根据后端代码，应该是model参数而不是targetLang
        "text": inputText
      };

      // 4. 调用后端真实想象接口 (POST请求)
      var response = await HttpUtil().post(
        AppConstant.api_stable,
        data: params,
      );

      // 5. 解析后端返回的结果
      if (response != null && response["code"] == 200) {
        setState(() {
          print(response);
          String rawImageUrl = response["data"]["image_url"] ?? "空";
          
          // 清理图片URL，处理特殊字符
          _image_url = _cleanImageUrl(rawImageUrl);
          _translateResult = response["data"]["prompt"] ?? "暂无";
          _keywords = response["data"]["negative_prompt"] ?? "";
          
          // 添加到图片库（如果是新图片且不为空）
          if (_image_url.isNotEmpty && _image_url != "空") {
            // 检查图片是否已经在图库中（通过URL）
            bool exists = _generatedImages.any((img) => img['url'] == _image_url);
            if (!exists) {
              // 添加到图片库，使用原始URL
              _generatedImages.insert(0, {
                'url': _image_url,
                'prompt': _translateResult,
                'negativePrompt': _keywords,
                'date': DateTime.now().toString()
              });
              
              // 保存到本地存储
              _saveGeneratedImages();
            }
          }
        });
      } else {
        setState(() {
          _translateResult = "想象失败：${response?["msg"] ?? "未知错误"}";
          _keywords = "";
        });
      }

    } catch (e) {
      // 异常处理：网络错误、接口报错、Token无效等
      setState(() {
        _translateResult = "想象失败：${e.toString()}";
        _keywords = "";
      });
    } finally {
      // 关闭加载中状态
      setState(() {
        _isLoading = false;
      });
    }
  }

  // ========== 新增：清理图片URL ==========
  String _cleanImageUrl(String url) {
    if (url.isEmpty) return url;
    
    // 移除注释部分，例如 "{此为邮箱去除.com}\" 
    String cleanedUrl = url.replaceAll(RegExp(r'\{[^}]*\}'), '').trim();
    
    // 移除末尾的反斜杠和其他特殊字符
    cleanedUrl = cleanedUrl.replaceAll(RegExp(r'[\\]+$'), '').trim();
    
    // 确保URL是有效的HTTP/HTTPS链接
    if (!cleanedUrl.startsWith('http://') && !cleanedUrl.startsWith('https://')) {
      // 如果不是标准URL格式，尝试构建正确的URL
      if (cleanedUrl.startsWith('/static/')) {
        cleanedUrl = 'http://192.168.31.219:8000$cleanedUrl';
      } else if (cleanedUrl.startsWith('static/')) {
        cleanedUrl = 'http://192.168.31.219:8000/$cleanedUrl';
      } else if (!cleanedUrl.startsWith('http')) {
        // 如果是相对路径，拼接到基础URL上
        cleanedUrl = 'http://192.168.31.219:8000/static/$cleanedUrl';
      }
    }
    
    return cleanedUrl;
  }

  // ========== 新增：格式化显示日期 ==========
  String _formatDisplayDate(String dateString) {
    try {
      DateTime dateTime;
      
      // 尝试解析不同格式的日期字符串
      if (dateString.contains('T')) {
        // ISO 8601 格式，如 "2026-01-22T10:30:00.000"
        dateTime = DateTime.parse(dateString);
      } else if (RegExp(r'^\d+\.\d+$').hasMatch(dateString)) {
        // 浮点数时间戳格式（秒级带小数），如 "1769076202.585374"
        double timestampSeconds = double.tryParse(dateString) ?? DateTime.now().millisecondsSinceEpoch / 1000;
        int timestampMilliseconds = (timestampSeconds * 1000).toInt();
        dateTime = DateTime.fromMillisecondsSinceEpoch(timestampMilliseconds);
      } else if (RegExp(r'^\d{10,}$').hasMatch(dateString)) {
        // 整数时间戳格式
        int timestamp = int.tryParse(dateString) ?? DateTime.now().millisecondsSinceEpoch;
        if (timestamp.toString().length == 10) {
          // 秒级时间戳
          timestamp *= 1000;
        }
        dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
      } else {
        // 默认格式，如 "2026-01-22 10:30:00.000"
        String normalizedDateString = dateString.replaceAll(' ', 'T');
        dateTime = DateTime.parse(normalizedDateString);
      }
      
      // 格式化为 "年-月-日" 格式
      return "${dateTime.year}-${dateTime.month}-${dateTime.day}";
    } catch (e) {
      // 如果解析失败，返回原始字符串的前10位（年月日部分）
      print('日期解析失败: $e, 原始字符串: $dateString');
      // 尝试提取日期部分（前10位）
      if (dateString.length >= 10) {
        return dateString.substring(0, 10);
      } else {
        // 如果字符串太短，返回当前日期
        DateTime now = DateTime.now();
        return "${now.year}-${now.month}-${now.day}";
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2, // 两个标签页：生成和图库
      child: Scaffold(
        appBar: AppBar(
          title: const Text("stable diffusion提示词生成和生图工具", style: TextStyle(fontWeight: FontWeight.bold)),
          centerTitle: true,
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          elevation: 1,
          bottom: const TabBar(
            tabs: [
              Tab(text: "生成"),
              Tab(text: "图库"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // 生成页面
            _buildGenerationView(),
            // 图库页面
            _buildGalleryView(),
          ],
        ),
      ),
    );
  }

  // 生成页面视图
  Widget _buildGenerationView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 语言选择行
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _dateController,
                  decoration: const InputDecoration(
                    labelText: "日期",
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12),
                  ),
                  enabled: false, // 设置为只读，因为我们只是显示日期
                ),
              ),
              const SizedBox(width: 12),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _targetLang,
                  decoration: const InputDecoration(
                    labelText: "类型",
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
              labelText: "请输入想象",
              border: OutlineInputBorder(),
              hintText: "头脑风暴中想出的内容...",
              contentPadding: EdgeInsets.all(12),
            ),
          ),
          const SizedBox(height: 16),
          // 想象按钮 - 加载中显示转圈，禁止点击
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
                : const Text("开始", style: TextStyle(fontSize: 16, color: Colors.white)),
          ),
          const SizedBox(height: 20),
          // 想象结果+关键词展示区域
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
                // ========== 新增：想象结果标题行 + 复制按钮 ==========
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("正向提示词(明确需要包含的元素)：", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87)),
                    IconButton(
                      icon: const Icon(Icons.copy, color: Colors.blue, size: 20),
                      onPressed: () => _copyToClipboard(_translateResult),
                      tooltip: "复制正向提示词",
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(_translateResult, style: const TextStyle(fontSize: 16, color: Colors.black)),
                const SizedBox(height: 16), // 添加一些间距
                // ========== 新增：图片展示区域 ==========
                if (_image_url.isNotEmpty && _image_url != "空")
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("生成的图片：", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        constraints: const BoxConstraints(maxHeight: 300), // 设置最大高度
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            _image_url,
                            fit: BoxFit.contain,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Center(
                                child: CircularProgressIndicator(
                                  value: loadingProgress.expectedTotalBytes != null
                                      ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                      : null,
                                ),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                height: 200,
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Center(
                                  child: Text("图片加载失败", style: TextStyle(color: Colors.red)),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                // ========== 图片展示区域结束 ==========
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("反向提示词(明确需要排除的元素)：", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87)),
                    IconButton(
                      icon: const Icon(Icons.copy, color: Colors.blue, size: 20),
                      onPressed: () => _copyToClipboard(_keywords),
                      tooltip: "复制反向提示词",
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(_keywords, style: const TextStyle(fontSize: 16, color: Colors.black)),


              ],
            ),
          ),
        ],
      ),
    );
  }

  // ========== 新增：下载图片功能 ==========
  Future<void> _downloadImage(String imageUrl) async {
    // 清理图片URL
    String cleanImageUrl = _cleanImageUrl(imageUrl);
    
    if (cleanImageUrl.isEmpty || cleanImageUrl == "空") {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("没有图片可下载"), duration: Duration(seconds: 1)),
        );
      }
      return;
    }

    try {
      // 显示下载中提示
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("正在下载图片..."), duration: Duration(seconds: 2)),
        );
      }

      // 获取应用文档目录
      final directory = await getApplicationDocumentsDirectory();
      String fileName = 'generated_image_${DateTime.now().millisecondsSinceEpoch}.jpg';
      String filePath = '${directory.path}/$fileName';

      // 使用 Dio 下载图片
      await Dio().download(cleanImageUrl, filePath);

      // 将图片信息添加到图片库（使用本地文件路径）
      _addToGallery('file://$filePath', _translateResult, _keywords);

      // 下载完成后提示
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("图片已保存到: $filePath"), duration: Duration(seconds: 3)),
        );
      }
    } catch (e) {
      // 错误处理
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("下载失败: ${e.toString()}"), duration: Duration(seconds: 2)),
        );
      }
    }
  }

  // ========== 新增：添加图片到图片库 ==========
  void _addToGallery(String imageUrl, String prompt, String negativePrompt) {
    setState(() {
      _generatedImages.insert(0, {
        'url': imageUrl,
        'prompt': prompt,
        'negativePrompt': negativePrompt,
        'date': DateTime.now().toString()
      });
    });
    
    // 保存到本地存储
    _saveGeneratedImages();
  }

  // ========== 新增：加载本地存储的图片信息 ==========
  Future<void> _loadGeneratedImages() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final imagesJson = prefs.getString('generated_images') ?? '[]';
      final imagesList = json.decode(imagesJson) as List;
      
      setState(() {
        _generatedImages = List<Map<String, String>>.from(
          imagesList.map((item) => Map<String, String>.from(item))
        );
      });
    } catch (e) {
      print('加载图片库失败: $e');
    }
  }

  // ========== 新增：保存图片信息到本地存储 ==========
  Future<void> _saveGeneratedImages() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final imagesJson = json.encode(_generatedImages);
      await prefs.setString('generated_images', imagesJson);
    } catch (e) {
      print('保存图片库失败: $e');
    }
  }

  // ========== 新增：显示图片库 ==========
  Widget _buildGalleryView() {
    if (_generatedImages.isEmpty) {
      return const Center(
        child: Text(
          "暂无生成的图片\n快去生成第一张吧！",
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 18,
            color: Colors.grey,
          ),
        ),
      );
    }

    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 200,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 1,
      ),
      itemCount: _generatedImages.length,
      itemBuilder: (context, index) {
        final imageInfo = _generatedImages[index];
        String imageUrl = imageInfo['url']!;
        
        // 检查是否为本地文件路径
        Widget imageWidget;
        if (imageUrl.startsWith('file://')) {
          // 本地文件
          String filePath = imageUrl.replaceFirst('file://', '');
          File imageFile = File(filePath);
          
          if (imageFile.existsSync()) {
            imageWidget = Image.file(
              imageFile,
              fit: BoxFit.cover,
            );
          } else {
            imageWidget = Container(
              color: Colors.grey[300],
              child: const Icon(Icons.broken_image, size: 50),
            );
          }
        } else {
          // 清理网络图片URL
          String formattedUrl = _cleanImageUrl(imageUrl);
          
          imageWidget = Image.network(
            formattedUrl,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Center(
                child: CircularProgressIndicator(
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                      : null,
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) {
              return Container(
                color: Colors.grey[300],
                child: const Icon(Icons.broken_image, size: 50),
              );
            },
          );
        }
        
        return Card(
          elevation: 4,
          child: Column(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                  child: imageWidget,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      imageInfo['prompt']!.length > 20 
                          ? "${imageInfo['prompt']!.substring(0, 20)}..." 
                          : imageInfo['prompt']!,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatDisplayDate(imageInfo['date']!),
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}