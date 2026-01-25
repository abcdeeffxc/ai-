import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import '../../utils/storage_util.dart';
import '../../utils/http_util.dart';
import '../../constants/app_constant.dart';
import '../../router/app_router.dart';

class IndexPage extends StatefulWidget {
  const IndexPage({super.key});

  @override
  State<IndexPage> createState() => _IndexPageState();
}

class _IndexPageState extends State<IndexPage> {
  final HttpUtil _http = HttpUtil();
  String? _userName; // 用户名/昵称
  String? _userAvatar; // 用户头像
  String? _userEmail; // 用户邮箱

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  // 加载用户信息-修复空值问题
  Future<void> _loadUserInfo() async {
    // 初始化：先从本地取，避免null
    final localEmail = StorageUtil.getEmail() ?? "用户";
    final localNickname = StorageUtil.getNickname() ?? localEmail;
    final localAvatar = StorageUtil.getAvatar();

    setState(() {
      _userEmail = localEmail;
      _userName = localNickname;
      _userAvatar = localAvatar;
    });

    try {
      var res = await _http.get(AppConstant.api_user_info);
      // 1. 校验接口返回的核心字段，避免空值
      if (res["code"] == 200 && res["data"] != null) {
        final data = res["data"];
        // 2. 给默认值，避免nickname/avatar为null
        final newNickname = data["nickname"] ?? localNickname;
        final newAvatar = data["avatar_url"] ?? localAvatar;

        setState(() {
          _userName = newNickname;
          _userAvatar = newAvatar;
        });

        // 3. 修复强制解包：仅当值非null时才存储
        if (newNickname.isNotEmpty) {
          await StorageUtil.setNickname(newNickname);
        }
        if (newAvatar != null && newAvatar.isNotEmpty) {
          await StorageUtil.setAvatar(newAvatar);
        }
      }
    } catch (e) {
      debugPrint("加载用户信息失败: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 添加左侧抽屉菜单
      drawer: _buildDrawer(),
      drawerEdgeDragWidth: 20.0, // 设置边缘拖拽宽度

      // 主内容区域
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.home,
              size: 80,
              color: Colors.blue,
            ),
            const SizedBox(height: 20),
            const Text(
              "AI翻译助手主页面",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.blue
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              "欢迎使用AI翻译助手",
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey
              ),
            ),
            const SizedBox(height: 30),
            Card(
              elevation: 4,
              margin: const EdgeInsets.symmetric(horizontal: 20),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.translate, color: Colors.green),
                      title: const Text("AI翻译"),
                      subtitle: const Text("使用大模型进行智能翻译"),
                      trailing: const Icon(Icons.arrow_forward_ios),
                      onTap: () {
                        Navigator.pushNamed(context, AppRouter.translate);
                      },
                    ),
                    const Divider(),
                    ListTile(
                      leading: const Icon(Icons.account_circle, color: Colors.blue),
                      title: const Text("个人资料"),
                      subtitle: const Text("管理您的个人信息"),
                      trailing: const Icon(Icons.arrow_forward_ios),
                      onTap: () {
                        Navigator.pushNamed(context, AppRouter.profile);
                      },
                    ),
                    const Divider(),
                    ListTile(
                      leading: const Icon(Icons.translate, color: Colors.green),
                      title: const Text("AI绘图"),
                      subtitle: const Text("使用stable生图"),
                      trailing: const Icon(Icons.arrow_forward_ios),
                      onTap: () {
                        Navigator.pushNamed(context, AppRouter.stable);
                      },
                    ),

                  ],
                ),
              ),
            ),
          ],
        ),
      ),

      appBar: AppBar(
        title: const Text("AI翻译助手", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 1,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        // 左侧汉堡菜单按钮，用于打开抽屉
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        // 右侧操作栏：新增翻译按钮 + 原有用户信息
        actions: [
          // 新增：翻译工具入口按钮
          IconButton(
            icon: const Icon(Icons.translate, color: Colors.black87),
            onPressed: () {
              // 跳转翻译页面（使用命名路由）
              Navigator.pushNamed(context, AppRouter.translate);
              // 也可使用MaterialPageRoute跳转：
              // Navigator.push(
              //   context,
              //   MaterialPageRoute(builder: (ctx) => const TranslatePage()),
              // );
            },
            tooltip: "AI翻译工具",
          ),
          // 原有用户信息区域
          GestureDetector(
            onTap: () {
              Navigator.pushNamed(context, AppRouter.profile);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ClipOval(
                    child: _userAvatar != null && _userAvatar!.isNotEmpty
                        ? Image.network(
                            "$_userAvatar",
                            width: 32,
                            height: 32,
                            fit: BoxFit.cover,
                            errorBuilder: (ctx, e, s) => defaultAvatar(),
                          )
                        : defaultAvatar(), // 当头像为空时显示默认头像
                  ),

                  const SizedBox(width: 8),
                  Text(
                    _userName ?? "用户",
                    style: const TextStyle(fontSize: 14, color: Colors.black87),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 构建左侧抽屉菜单
  Widget _buildDrawer() {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          // 抽屉头部 - 用户信息
          UserAccountsDrawerHeader(
            accountName: Text(_userName ?? "用户"),
            accountEmail: Text(_userEmail ?? ""),
            currentAccountPicture: CircleAvatar(
              child: _userAvatar != null && _userAvatar!.isNotEmpty
                  ? Image.network(
                      "$_userAvatar",
                      width: 60,
                      height: 60,
                      fit: BoxFit.cover,
                      errorBuilder: (ctx, e, s) => defaultAvatarLarge(),
                    )
                  : defaultAvatarLarge(),
            ),
            decoration: const BoxDecoration(
              color: Colors.blue,
            ),
          ),

          // 功能列表项
          ListTile(
            leading: const Icon(Icons.home, color: Colors.blue),
            title: const Text('首页'),
            selected: true,
            onTap: () {
              // 当前页面，无需跳转
              Navigator.pop(context); // 关闭抽屉
            },
          ),

          const Divider(),

          ListTile(
            leading: const Icon(Icons.translate, color: Colors.green),
            title: const Text('AI翻译'),
            onTap: () {
              Navigator.pushNamed(context, AppRouter.translate);
              Navigator.pop(context); // 关闭抽屉
            },
          ),

          ListTile(
            leading: const Icon(Icons.history, color: Colors.orange),
            title: const Text('翻译历史'),
            onTap: () {
              // TODO: 添加翻译历史页面
              debugPrint("跳转翻译历史页面");
              Navigator.pop(context); // 关闭抽屉
            },
          ),

          ListTile(
            leading: const Icon(Icons.settings, color: Colors.purple),
            title: const Text('系统设置'),
            onTap: () {
              // TODO: 添加设置页面
              debugPrint("跳转设置页面");
              Navigator.pop(context); // 关闭抽屉
            },
          ),

          const Divider(),

          ListTile(
            leading: const Icon(Icons.account_circle, color: Colors.red),
            title: const Text('个人资料'),
            onTap: () {
              Navigator.pushNamed(context, AppRouter.profile);
              Navigator.pop(context); // 关闭抽屉
            },
          ),

          ListTile(
            leading: const Icon(Icons.help_outline, color: Colors.grey),
            title: const Text('帮助中心'),
            onTap: () {
              // TODO: 添加帮助页面
              debugPrint("跳转帮助页面");
              Navigator.pop(context); // 关闭抽屉
            },
          ),
        ],
      ),
    );
  }

  // 默认小头像
  Widget defaultAvatar() {
    return Container(
      width: 32,
      height: 32,
      color: Colors.blue.shade100,
      child: const Icon(Icons.person, size: 18, color: Colors.white),
    );
  }

  // 默认大头像（抽屉用）
  Widget defaultAvatarLarge() {
    return Container(
      width: 60,
      height: 60,
      color: Colors.blue.shade100,
      child: const Icon(Icons.person, size: 30, color: Colors.white),
    );
  }
}
