# README.md

# AI 翻译项目（FastAPI + Flutter）

一个基于 FastAPI 构建后端接口、Flutter 开发前端界面的 AI 翻译应用，支持文本翻译功能，前后端分离架构，单仓统一管理。

## 📋 项目结构

本项目采用单仓管理，按前后端模块拆分目录，结构清晰易维护：

```plain text

your-project/
├── backend/          # FastAPI 后端模块
│   ├── main.py       # 后端接口入口（翻译接口核心逻辑）
│   └── requirements.txt # 后端依赖清单
├── frontend/         # Flutter 前端模块
│   ├── lib/          # 前端业务代码（页面、接口请求、UI 组件）
│   └── pubspec.yaml  # 前端依赖配置
├── .gitignore        # Git 忽略规则（过滤缓存、虚拟环境、敏感文件）
└── README.md         # 项目说明文档（本文档）
```

## 🔧 环境准备

### 后端环境（FastAPI）

1. 安装 Python 3.9+（推荐 3.10 版本）；

2. 进入后端目录，安装依赖：
        `cd backend
# 可选：创建虚拟环境隔离依赖
python -m venv venv
# 激活虚拟环境
# Windows：venv\Scripts\activate
# macOS/Linux：source venv/bin/activate
# 安装依赖
pip install -r requirements.txt`

### 前端环境（Flutter）

1. 安装 Flutter 3.0+（参考 [Flutter 官方安装指南](https://flutter.dev/docs/get-started/install)）；

2. 进入前端目录，安装依赖并检查环境：
        `cd frontend
# 安装依赖
flutter pub get
# 检查 Flutter 环境（确保无缺失依赖）
flutter doctor`

## 🚀 启动项目

### 1. 启动后端接口（FastAPI）

```bash

cd backend
# 开发模式启动（自动重载，适合调试）
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

接口启动后可访问：

- 接口地址：http://localhost:8000

- 自动生成接口文档：http://localhost:8000/docs（可直接调试接口）

### 2. 启动前端应用（Flutter）

```bash

cd frontend
# 启动应用（默认连接模拟器/真机）
flutter run
```

启动前需确保前端代码中配置的后端接口地址与 FastAPI 启动地址一致（通常在 `lib/services/api_service.dart` 中修改）。

## 🔗 核心功能

- 文本翻译：前端输入文本，调用后端 FastAPI 接口完成翻译，返回结果并展示；

- 接口调试：通过 FastAPI 自动生成的 Swagger 文档（/docs）快速调试接口；

- 跨端运行：Flutter 前端支持 Android、iOS、Web 多端部署。
