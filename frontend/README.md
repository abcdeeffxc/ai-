# AI大模型翻译助手 - 前端

这是一个基于Flutter开发的智能翻译助手前端应用，集成了AI大模型翻译功能，支持多种语言互译，并提供用户认证、个人资料管理等功能。

## 功能特性

- **智能翻译**：集成AI大模型翻译API，支持多语言实时翻译
- **用户系统**：完整的注册、登录、个人信息管理功能
- **多语言支持**：支持中文、英文、日语等多种语言翻译
- **关键词提取**：自动提取翻译内容中的核心关键词
- **界面友好**：现代化UI设计，简洁易用的操作体验
- **离线存储**：使用本地存储保存用户登录状态和信息

## 技术栈

- **框架**：Flutter (SDK: ^3.10.4)
- **状态管理**：Dart语言 + Flutter内置状态管理
- **网络请求**：Dio库 + 自定义HTTP工具类
- **本地存储**：SharedPreferences
- **UI组件**：Material Design组件
- **其他依赖**：
  - http: 网络请求
  - image_picker: 图片选择
  - fluttertoast: 提示消息
  - flutter_easyloading: 加载动画
  - url_launcher: URL跳转
  - validatorless: 表单验证

## 项目结构

```
lib/
├── constants/           # 常量配置
│   └── app_constant.dart
├── pages/              # 页面组件
│   ├── Drawing/        # 绘画页面
│   │   └── stable_page.dart
│   ├── hobby/          # 兴趣管理
│   │   └── hobby_manager_page.dart
│   ├── index/          # 首页
│   │   └── index_page.dart
│   ├── login/          # 登录注册
│   │   └── login_register_page.dart
│   ├── profile/        # 个人资料
│   │   └── profile_page.dart
│   ├── trans/          # 翻译功能
│   │   └── translate_page.dart
│   └── user_info/      # 用户信息编辑
│       ├── edit_nickname_page.dart
│       └── edit_pwd_page.dart
├── router/             # 路由管理
│   └── app_router.dart
├── utils/              # 工具类
│   ├── http_util.dart  # HTTP请求工具
│   └── storage_util.dart # 本地存储工具
└── main.dart           # 应用入口
```

## 安装与运行

### 环境要求

- Flutter SDK >= 3.10.4
- Dart SDK >= 3.10.4
- Android Studio 或 VS Code
- Android/iOS开发环境

### 安装步骤

1. 克隆项目到本地：

```bash
git clone <repository_url>
cd frontend
```

2. 安装依赖：

```bash
flutter pub get
```

3. 配置后端API地址：

编辑 `lib/constants/app_constant.dart` 文件，修改 `baseUrl` 为你自己的后端服务地址：

```dart
static const String baseUrl = "http://your_backend_ip:port";
```

4. 运行应用：

```bash
flutter run
```

## 使用说明

### 1. 注册/登录

首次使用需要注册账号，已有账号可直接登录。

### 2. 翻译功能

- 在翻译页面选择源语言和目标语言
- 输入需要翻译的文本
- 点击"开始翻译"按钮获取翻译结果
- 翻译结果下方会显示提取的核心关键词
- 可通过复制按钮快速复制翻译结果或关键词

### 3. 个人中心

- 查看和编辑个人资料
- 修改昵称和密码
- 更换头像
- 管理个人兴趣爱好

### 4. 语言支持

当前支持以下语言翻译：
- 中文 ↔ 英文
- 中文 ↔ 日语
- 中文 ↔ 韩语
- 中文 ↔ 法语
- 中文 ↔ 西班牙语

## API接口

应用通过以下API与后端交互：

- `/api/user/register` - 用户注册
- `/api/user/login` - 用户登录
- `/api/user/info` - 获取用户信息
- `/api/user/change_nickname` - 修改昵称
- `/api/user/change_pwd` - 修改密码
- `/api/user/upload_avatar` - 上传头像
- `/api/user/logout` - 用户登出
- `/api/user/save_hobby` - 保存兴趣爱好
- `/api/translate` - 文本翻译
- `/api/stable` - AI绘画

## 配置说明

### 网络配置

在 `lib/constants/app_constant.dart` 中配置后端API基础URL：

```dart
static const String baseUrl = "http://192.168.31.219:8000";
```

### 支持的语言

在 `AppConstant` 类中可以扩展支持的翻译语言：

```dart
static const List<String> supportLanguages = ["中文", "英文", "日语"];
```

## 开发指南

### 添加新页面

1. 在 `lib/pages/` 目录下创建新页面文件
2. 在 `lib/router/app_router.dart` 中注册路由
3. 在导航菜单中添加相应入口

### 添加新功能

1. 在 `lib/utils/` 下创建新的工具类
2. 在 `lib/constants/` 中添加相关常量
3. 在对应页面中调用新功能

## 注意事项

- 请确保后端服务正常运行且网络可达
- 首次启动应用需要联网获取资源
- 个人数据仅存储在本地和后端服务器，注意保护隐私
- 如遇问题请检查网络连接和API地址配置

## 许可证

此项目仅供学习和参考使用。

## 更新日志

### v1.0.0
- 实现基本翻译功能
- 完成用户认证系统
- 添加个人资料管理
- 支持关键词提取