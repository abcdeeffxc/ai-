# 用户信息管理系统

基于FastAPI的用户信息管理系统，提供完整的用户注册、激活、登录、信息修改等功能，并集成了AI翻译和图像生成能力。

## 功能特性

- **用户管理**：
  - 用户注册与邮箱激活
  - 用户登录与身份验证
  - 密码修改
  - 昵称修改
  - 头像上传
  - 兴趣列表管理（最多10个兴趣）
  - 安全登出（Token黑名单机制）

- **AI功能**：
  - AI翻译服务（支持多语言翻译）
  - 关键词提取
  - AI图像生成（集成Stable Diffusion）

- **其他功能**：
  - 邮件通知系统
  - 图像库管理
  - CORS跨域支持

## 技术栈

- **后端框架**：FastAPI
- **数据库**：MySQL
- **身份验证**：JWT Token
- **密码加密**：PBKDF2-SHA256
- **邮件服务**：Yagmail
- **AI模型**：通义千问（DashScope）
- **图像生成**：Stable Diffusion API

## 环境准备

### 系统要求

- Python 3.7+
- MySQL数据库
- Stable Diffusion WebUI（用于AI图像生成）

### 依赖安装

```bash
pip install fastapi uvicorn pydantic[email] passlib[bcrypt] python-jose[cryptography] sqlalchemy pymysql yagmail python-multipart python-dotenv pillow
```

## 配置说明

### 1. 环境变量配置

在启动应用前，需要配置必要的环境变量：

- `DASHSCOPE_API_KEY`：通义千问API密钥
- `SECRET_KEY`：JWT密钥（用于生产环境，建议从环境变量加载）

### 2. 邮箱配置

在 config.py 文件中配置邮箱发送设置：

```python
SEND_EMAIL = "your_email@domain.com"  # 发送方邮箱
SEND_EMAIL_PWD = "your_email_password_or_auth_code"  # 邮箱授权码
SEND_EMAIL_HOST = "smtp.domain.com"  # SMTP服务器地址
SERVER_DOMAIN = "http://your_server_domain:port"  # 服务器域名
```

### 3. 数据库配置

在 config.py 文件中配置数据库连接：

```python
DB_URL = "mysql+pymysql://username:password@host:port/database_name?charset=utf8mb4"
```

## 启动服务

```bash
uvicorn fastapi_user:app --host 0.0.0.0 --port 8000
```

启动后，API文档可在以下地址访问：
- Swagger UI: http://localhost:8000/docs
- ReDoc: http://localhost:8000/redoc

## API接口说明

### 用户管理接口

- `POST /api/user/register` - 用户注册
- `GET /api/user/active` - 邮箱激活
- `POST /api/user/login` - 用户登录
- `POST /api/user/change_pwd` - 修改密码
- `POST /api/user/change_nickname` - 修改昵称
- `POST /api/user/upload_avatar` - 上传头像
- `POST /api/user/save_hobby` - 保存兴趣列表
- `POST /api/user/logout` - 用户登出
- `GET /api/user/info` - 获取用户信息

### AI功能接口

- `POST /api/translate` - AI翻译与关键词提取
- `POST /api/stable` - AI图像生成
- `GET /api/stable/gallery` - 获取用户生成的图像列表

## 项目结构

```
用户信息/
├── fastapi_user.py          # 主应用文件
├── config.py               # 配置文件（敏感信息）
├── stable_diff.py          # Stable Diffusion集成
├── ceshiji.py              # 测试文件
├── static/                 # 静态文件目录
├── .gitignore             # Git忽略规则
└── README.md              # 项目说明
```

## 安全措施

- 使用JWT进行身份验证
- 密码使用PBKDF2算法加密
- Token黑名单机制实现安全登出
- 邮箱激活验证防止恶意注册
- 输入参数校验防止注入攻击

## 开发说明

### 重要提醒

- config.py 包含敏感配置信息，请勿提交到版本控制系统
- 邮箱密码应使用授权码而非登录密码
- JWT密钥应在生产环境中定期更换

### 扩展功能

- 兴趣列表最大支持10个项目
- 头像支持 JPG/PNG/WebP 格式，最大5MB
- 邮件激活链接有效期为24小时

## 部署建议

1. 生产环境应使用HTTPS
2. 配置反向代理（如Nginx）
3. 设置适当的防火墙规则
4. 定期备份数据库
5. 监控系统资源使用情况

## 许可证

本项目为学习交流用途。