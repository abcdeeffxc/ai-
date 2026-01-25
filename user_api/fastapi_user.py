from datetime import datetime
from random import randint

from fastapi import FastAPI, HTTPException, Body, Depends, status, UploadFile, File
from fastapi.security import APIKeyHeader
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel, field_validator
from passlib.context import CryptContext
from sqlalchemy import create_engine, Column, BigInteger, String, DateTime, Boolean
from sqlalchemy.orm import sessionmaker, Session, declarative_base
from sqlalchemy.sql import func
import re
import jwt
import time
import uuid
import yagmail
import os
from typing import List, Optional, Set
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware  # 新增：导入跨域中间件
import stable_diff


from pydantic import BaseModel

import json
from dotenv import load_dotenv
import dashscope
from dashscope import Generation


# 10. 先加载环境变量
load_dotenv()
dashscope.api_key = os.getenv("DASHSCOPE_API_KEY")
# ===================== 基础全局配置 =====================
app = FastAPI(
    title="用户注册-激活-登录-信息修改-兴趣管理-安全登出 完整接口(V6)",
    version="1.0.0",
    docs_url="/docs",
    redoc_url="/redoc",
    openapi_url="/openapi.json"
)

# ========== 新增：跨域配置 核心代码 ==========
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # 允许所有前端地址访问（开发环境推荐，生产环境可指定你的域名）
    allow_credentials=True,
    allow_methods=["*"],  # 允许所有请求方法：GET/POST/PUT/DELETE等
    allow_headers=["*"],  # 允许所有请求头：包括你的Bearer Token请求头
)
from config import SEND_EMAIL, SEND_EMAIL_PWD, SEND_EMAIL_HOST, SERVER_DOMAIN

# ========== 核心配置（可灵活修改） ==========
AVATAR_UPLOAD_DIR = "static/avatar"  # 头像存储目录
ALLOWED_EXTENSIONS = {"jpg", "jpeg", "png", "webp"}  # 允许的头像格式
MAX_HOBBY_NUM = 10  # ✅兴趣列表最大数量，可按需修改（当前配置10个）
TOKEN_BLACKLIST: Set[str] = set()  # ✅Token黑名单，登出后加入这里，全局生效

# JWT Token配置
SECRET_KEY = os.getenv("SECRET_KEY") # 从环境变量获取密钥
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 120
ACTIVE_TOKEN_EXPIRE_HOURS = 24

# ========== 【修改这里！你的MySQL数据库配置】 ==========
from config import DB_URL
engine = create_engine(DB_URL)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()

# 自动创建头像目录+挂载静态文件
os.makedirs(AVATAR_UPLOAD_DIR, exist_ok=True)
app.mount("/static", StaticFiles(directory="static"), name="static")

# 密码加密配置 - 零依赖 无报错
pwd_context = CryptContext(schemes=["pbkdf2_sha256"], deprecated="auto")

# 完美适配的鉴权方式 - Authorize仅1个输入框
api_key_header = APIKeyHeader(name="Authorization", auto_error=False)


# ===================== 数据库模型 (无新增字段，复用所有历史字段) =====================
class DBUser(Base):
    __tablename__ = "sys_user"
    id = Column(BigInteger, primary_key=True, autoincrement=True, nullable=False)
    email = Column(String(100), unique=True, nullable=False, index=True, comment="登录邮箱")
    password = Column(String(255), nullable=False, comment="加密密码")
    nickname = Column(String(50), default="默认用户", nullable=False, comment="用户昵称")
    avatar = Column(String(255), default="", comment="头像存储路径")
    hobby_list = Column(String(1000), default="", comment="兴趣列表，逗号分隔，上限10个")
    is_active = Column(Boolean, default=False, comment="是否激活：False未激活，True已激活")
    create_time = Column(DateTime, default=func.now(), nullable=False, comment="注册时间")
    update_time = Column(DateTime, default=func.now(), onupdate=func.now(), nullable=False, comment="更新时间")


# 自动建表（已存在则不修改）
Base.metadata.create_all(bind=engine)


# ===================== 通用工具函数 =====================
def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


# 邮箱格式校验
EMAIL_CHECK_REGEX = re.compile(r"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$")


# 密码加密/校验
def verify_password(plain_password, hashed_password):
    return pwd_context.verify(plain_password, hashed_password)


def get_password_hash(password):
    return pwd_context.hash(password)


# 根据邮箱查询用户
def get_user_by_email(db: Session, email: str):
    return db.query(DBUser).filter(DBUser.email == email).first()


# 生成登录Token
def create_access_token(data: dict):
    to_encode = data.copy()
    expire = int(time.time()) + ACCESS_TOKEN_EXPIRE_MINUTES * 60
    to_encode.update({"exp": expire})
    encoded_jwt = jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)
    return encoded_jwt


# 生成激活Token+发送激活邮件
def create_active_token(email: str):
    data = {"email": email, "exp": int(time.time()) + ACTIVE_TOKEN_EXPIRE_HOURS * 3600}
    return jwt.encode(data, SECRET_KEY, algorithm=ALGORITHM)


def send_active_email(to_email: str):
    try:
        active_token = create_active_token(to_email)
        active_url = f"{SERVER_DOMAIN}/api/user/active?token={active_token}"
        yag = yagmail.SMTP(user=SEND_EMAIL, password=SEND_EMAIL_PWD, host=SEND_EMAIL_HOST)
        yag.send(to=to_email, subject="【账号激活】完成邮箱激活成为正式用户",
                 contents=f"您好！点击链接激活账号：<a href='{active_url}'>{active_url}</a>，24小时内有效")
        yag.close()
        return True
    except Exception as e:
        print(f"邮件发送失败: {e}")
        return False


# 头像文件校验
def allowed_file(filename: str):
    return "." in filename and filename.rsplit(".", 1)[1].lower() in ALLOWED_EXTENSIONS


# ===================== 核心鉴权函数 - 升级：增加【Token黑名单校验】+ 登录态校验 =====================
def get_current_user(token: str = Depends(api_key_header), db: Session = Depends(get_db)):
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="无效的Token凭证、Token已过期或已登出，请重新登录",
        headers={"WWW-Authenticate": "Bearer"},
    )
    try:
        # 1. 校验Token格式
        if not token or not token.startswith("Bearer "):
            raise credentials_exception
        token_str = token.replace("Bearer ", "")

        # 2. ✅核心新增：校验Token是否在黑名单（登出后失效）
        if token_str in TOKEN_BLACKLIST:
            raise credentials_exception

        # 3. 解析Token+校验用户
        payload = jwt.decode(token_str, SECRET_KEY, algorithms=[ALGORITHM])
        email: str = payload.get("sub")
        if email is None:
            raise credentials_exception
        user = get_user_by_email(db, email=email)
        if user is None:
            raise credentials_exception
        return user, token_str  # 返回用户信息+纯token字符串（供登出使用）
    except:
        raise credentials_exception


# 在后端fastapi_user.py中添加以下API






# ===================== 请求体模型（所有入参校验+兴趣列表专属模型） =====================
class UserRequest(BaseModel):
    email: str
    password: str

    @field_validator("email")
    def validate_email(cls, v):
        if not EMAIL_CHECK_REGEX.match(v):
            raise ValueError("邮箱格式不正确")
        return v

    @field_validator("password")
    def validate_pwd(cls, v):
        if len(v) < 6 or len(v) > 20:
            raise ValueError("密码长度必须在6-20位之间")
        return v


class ChangePwdRequest(BaseModel):
    old_password: str
    new_password: str

    @field_validator("new_password")
    def validate_new_pwd(cls, v):
        if len(v) < 6 or len(v) > 20:
            raise ValueError("新密码长度必须在6-20位之间")
        return v


class ChangeNicknameRequest(BaseModel):
    nickname: str

    @field_validator("nickname")
    def validate_nickname(cls, v):
        if len(v) < 2 or len(v) > 20:
            raise ValueError("昵称长度必须在2-20位之间")
        return v


class HobbyListRequest(BaseModel):
    # ✅兴趣列表专属模型：接收数组，支持新增/选择/排序/去重
    hobby_list: List[str]

    @field_validator("hobby_list")
    def validate_hobby(cls, v):
        # 过滤空字符串兴趣
        v = [hobby.strip() for hobby in v if hobby.strip()]
        # 校验兴趣数量不超过上限
        if len(v) > MAX_HOBBY_NUM:
            raise ValueError(f"兴趣数量最多只能添加{MAX_HOBBY_NUM}个，请删减后重试")
        return v


class Token(BaseModel):
    access_token: str
    token_type: str
    user_id: int
    email: str


class ImageInfo(BaseModel):
    image_url: str
    prompt: str
    negative_prompt: str
    date: str

# ===================== 完整接口集合（含新增兴趣列表+登出接口，全部功能） =====================
# 1. 用户注册
@app.post("/api/user/register", summary="用户注册-发送激活邮件", tags=["用户模块"])
def register(user: UserRequest = Body(...), db: Session = Depends(get_db)):
    if get_user_by_email(db, user.email):
        raise HTTPException(400, "该邮箱已注册")
    db_user = DBUser(email=user.email, password=get_password_hash(user.password))
    db.add(db_user)
    db.commit()
    send_active_email(user.email)
    return {"code": 200, "msg": "注册成功，激活链接已发送至邮箱，请点击激活"}


# 2. 用户激活
@app.get("/api/user/active", summary="邮箱激活接口-点击链接访问", tags=["用户模块"])
def active(token: str, db: Session = Depends(get_db)):
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        user = get_user_by_email(db, payload["email"])
        if not user: raise Exception()
        if user.is_active: return {"code": 200, "msg": "账号已激活，无需重复操作"}
        user.is_active = True
        db.commit()
        return {"code": 200, "msg": "激活成功！可返回登录使用所有功能"}
    except:
        raise HTTPException(400, "激活链接无效或已过期，请重新注册")


# 3. 用户登录（仅激活用户可登录）
@app.post("/api/user/login", summary="用户登录-返回Bearer Token", tags=["用户模块"], response_model=Token)
def login(user: UserRequest = Body(...), db: Session = Depends(get_db)):
    db_user = get_user_by_email(db, user.email)
    if not db_user: raise HTTPException(400, "邮箱或密码错误")
    if not db_user.is_active: raise HTTPException(403, "账号未激活！请先去邮箱完成激活")
    if not verify_password(user.password, db_user.password): raise HTTPException(400, "邮箱或密码错误")
    return {"access_token": create_access_token({"sub": db_user.email}), "token_type": "bearer", "user_id": db_user.id,
            "email": db_user.email}


# 4. 修改密码 - 验证原密码+新密码校验
@app.post("/api/user/change_pwd", summary="修改密码-需验证原密码", tags=["用户信息修改"])
def change_pwd(data: ChangePwdRequest = Body(...), db: Session = Depends(get_db),
               user_token: tuple = Depends(get_current_user)):
    user, _ = user_token
    if not verify_password(data.old_password, user.password):
        raise HTTPException(400, "原密码输入错误！")
    if data.old_password == data.new_password:
        raise HTTPException(400, "新密码不能与原密码相同！")
    user.password = get_password_hash(data.new_password)
    db.commit()
    return {"code": 200, "msg": "密码修改成功，请重新登录"}


# 5. 修改昵称
@app.post("/api/user/change_nickname", summary="修改用户昵称", tags=["用户信息修改"])
def change_nickname(data: ChangeNicknameRequest = Body(...), db: Session = Depends(get_db),
                    user_token: tuple = Depends(get_current_user)):
    user, _ = user_token
    user.nickname = data.nickname
    db.commit()
    return {"code": 200, "msg": "昵称修改成功", "data": {"nickname": user.nickname}}


# 6. 头像上传 - 支持jpg/png/webp，返回完整访问链接
@app.post("/api/user/upload_avatar", summary="上传用户头像-支持jpg/png/webp", tags=["用户信息修改"])
def upload_avatar(file: UploadFile = File(...), db: Session = Depends(get_db),
                  user_token: tuple = Depends(get_current_user)):
    user, _ = user_token

    try:
        if not file or file.filename == "":
            return {"code": 400, "msg": "请选择要上传的头像文件"}

        if not allowed_file(file.filename):
            return {"code": 400, "msg": "仅支持上传 jpg/jpeg/png/webp 格式的图片！"}

        # 检查文件大小（例如限制为5MB）
        # 注意：UploadFile没有直接的size属性，需要读取内容检查
        file_content = file.file.read()
        if len(file_content) > 5 * 1024 * 1024:  # 5MB
            return {"code": 400, "msg": "文件大小不能超过5MB"}

        # 重置文件指针，因为上面已经读取过了
        file.file.seek(0)

        ext = file.filename.rsplit(".", 1)[1].lower()
        filename = f"{uuid.uuid4()}.{ext}"
        file_path = os.path.join(AVATAR_UPLOAD_DIR, filename)

        with open(file_path, "wb") as f:
            f.write(file.file.read())

        user.avatar = f"{SERVER_DOMAIN}/{file_path}"
        db.commit()
        print(user.avatar)

        return {"code": 200, "msg": "头像上传成功", "data": {"avatar_url": user.avatar}}

    except HTTPException:
        # 如果是已知的HTTP异常，转换为JSON响应
        raise
    except Exception as e:
        # 捕获其他异常并返回JSON格式
        db.rollback()
        return {"code": 500, "msg": f"头像上传失败：{str(e)}"}


# 7. ✅核心升级：兴趣列表管理（增选改排+上限10个+去重+排序）- 完全匹配需求
@app.post("/api/user/save_hobby", summary="兴趣列表管理-增/选/改/排，上限10个，自动去重", tags=["用户信息修改"])
def save_hobby(data: HobbyListRequest = Body(...), db: Session = Depends(get_db),
               user_token: tuple = Depends(get_current_user)):
    user, _ = user_token
    # 核心处理：1.去重 2.保留传入顺序 3.转字符串存储
    hobby_list = list(dict.fromkeys(data.hobby_list))  # 去重且保留原顺序，完美支持排序
    hobby_str = ",".join(hobby_list)
    user.hobby_list = hobby_str
    db.commit()
    return {
        "code": 200,
        "msg": f"兴趣列表修改成功，当前共{len(hobby_list)}个兴趣（最多支持{MAX_HOBBY_NUM}个）",
        "data": {"hobby_list": hobby_list}
    }


# 8. ✅核心新增：用户安全登出 - Token立即加入黑名单，永久失效
@app.post("/api/user/logout", summary="用户登出-Token立即失效，无法复用", tags=["用户模块"])
def user_logout(user_token: tuple = Depends(get_current_user)):
    _, token_str = user_token
    # 将当前Token加入黑名单，全局生效
    TOKEN_BLACKLIST.add(token_str)
    return {"code": 200, "msg": "登出成功！您的登录凭证已失效，请重新登录"}


# 9. 获取当前登录用户的完整信息（含昵称/头像/兴趣/激活状态，兴趣自动转数组）
@app.get("/api/user/info", summary="获取当前用户完整信息", tags=["用户模块"])
def get_info(user_token: tuple = Depends(get_current_user)):
    user, _ = user_token
    # 兴趣列表字符串转回数组，自动过滤空值
    hobby_list = [hobby.strip() for hobby in user.hobby_list.split(",") if hobby.strip()]
    return {
        "code": 200, "msg": "获取信息成功",
        "data": {
            "user_id": user.id, "email": user.email, "nickname": user.nickname,
            "avatar": user.avatar, "hobby_list": hobby_list, "is_active": user.is_active,
            "create_time": user.create_time.strftime("%Y-%m-%d %H:%M:%S"),
            "hobby_count": len(hobby_list),
            "max_hobby_num": MAX_HOBBY_NUM
        }
    }





# 4. 定义请求/响应模型
class TranslateRequest(BaseModel):
    targetLang: str
    text: str

class KeyWordRequest(BaseModel):
    text: str
    model: str

class TranslateResponse(BaseModel):
    translation: str
    keywords: list[str]


# 5. 核心翻译函数
def call_bailian_model(prompt: str) -> dict:
    try:
        response = Generation.call(
            model='qwen-plus',
            messages=[{"role": "user", "content": prompt}],
            result_format='json',
            temperature=0.1,
            max_tokens=1000
        )
        if response.status_code != 200:
            raise Exception(f"百炼API调用失败：{response.code} - {response.message}")
        return json.loads(response.output.choices[0].message.content)
    except Exception as e:
        raise Exception(f"百炼模型调用异常：{str(e)}")

# 6. 翻译接口（需要登录才能调用）
@app.post("/api/translate", response_model=TranslateResponse,tags=["功能"])
async def translate(
    request: TranslateRequest,
    user_token: tuple = Depends(get_current_user)  # 添加这行来要求用户登录
):
    input_text = request.text.strip()
    target_Lang = request.targetLang.strip()
    if not input_text:
        raise HTTPException(status_code=400, detail="输入文本不能为空")

    try:
        prompt = f"""
               你是一个专业的翻译模型，请将输入的文本翻译成准确流畅的{target_Lang}，并提取1-5个核心中文关键词。
               请使用JSON格式返回结果，请勿添加其他内容：
               {{
                 "translation": "将「{input_text}」翻译成准确流畅的{target_Lang}",
                 "keywords": ["提取1-5个核心中文关键词"]
               }}
               """
        model_result = call_bailian_model(prompt)

        if not isinstance(model_result, dict) or "translation" not in model_result or "keywords" not in model_result:
            raise Exception("模型返回格式错误，缺少translation/keywords字段")

        return TranslateResponse(
            translation=model_result["translation"],
            keywords=model_result["keywords"]
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"翻译失败：{str(e)}")

# 7. 画图接口（需要登录才能调用）
@app.post("/api/stable", summary="使用大模型生成有效的提示词，生成图片",tags=["stable图片生成"])
async def stable_generate(
    request: KeyWordRequest,
    user_token: tuple = Depends(get_current_user)  # 添加这行来要求用户登录
):
    user, _ = user_token
    user = user.email.split('.')[0]

    input_text = request.text.strip()
    model = request.model.strip()


    # target_Lang = request.targetLang.strip()
    if not input_text:
        raise HTTPException(status_code=400, detail="输入文本不能为空")

    try:
        prompt = f"""
        你是一位Stable Diffusion提示词（Prompt）编写经验的资深专家，擅长从用户输入的短句中快速拆解核心要素，生成精准高效的中英文提示词方案，
        若短句缺少关键信息（如未提风格/细节），随机添加关键信息，返回正向提示词和反向提示词。
        请使用JSON格式返回结果，请勿添加其他内容：
               {{
                 "Positive": f"{input_text}正向提示词",
                 "Reverse": f"{input_text}反向提示词"
               }}
               """
        model_result = call_bailian_model(prompt)

        if not isinstance(model_result, dict) or "Positive" not in model_result or "Reverse" not in model_result:
            raise Exception("模型返回格式错误，缺少Positive/Reverse字段")


        for i in range(randint(3,6)):
            image,save_path =stable_diff.generate_image_by_qiuye(prompt= model_result["Positive"],
                                                       negative_prompt=model_result["Reverse"],
                                                       steps=randint(20,30),
                                                       save_dir=f"static/{user}",
                                                       model_name=stable_diff.get_model_by_style(model))
            if save_path:
                # 创建专门存放提示词的目录
                prompt_dir = os.path.join(os.path.dirname(save_path), "prompts")
                os.makedirs(prompt_dir, exist_ok=True)

                base_path = os.path.splitext(save_path)[0]  # 移除文件扩展名
                # 将提示词文件保存到专门的prompts子目录中
                pos_prompt_file = os.path.join(prompt_dir, os.path.basename(base_path) + "_prompt.txt")
                neg_prompt_file = os.path.join(prompt_dir, os.path.basename(base_path) + "_neg_prompt.txt")

                # 保存正向提示词
                with open(pos_prompt_file, 'w', encoding='utf-8') as f:
                    f.write(model_result["Positive"])

                # 保存反向提示词
                with open(neg_prompt_file, 'w', encoding='utf-8') as f:
                    f.write(model_result["Reverse"])
        return {"code": 200, "msg": "生成成功", "data": {"image_url": f"{SERVER_DOMAIN}/{save_path}","prompt": model_result["Positive"],"negative_prompt": model_result["Reverse"]}}

    except Exception as e:
        raise HTTPException(status_code=500, detail=f"大模型生成失败：{str(e)}")

@app.get("/api/stable/gallery", summary="获取用户生成的图片列表", tags=["stable图片生成"])
async def get_gallery(
        user_token: tuple = Depends(get_current_user)
):
    user, _ = user_token
    user_dir = user.email.split('.')[0]  # 获取邮箱用户名部分

    gallery_dir = f"static/{user_dir}"

    if not os.path.exists(gallery_dir):
        return {"code": 200, "msg": "目录不存在", "data": []}

    # 获取目录下的所有图片文件
    image_files = []
    for filename in os.listdir(gallery_dir):
        if filename.lower().endswith(('.png', '.jpg', '.jpeg', '.gif', '.bmp', '.webp')):
            # 读取关联的提示词文件（如果有的话）
            base_name = os.path.splitext(filename)[0]

            # 修改路径以匹配新的提示词保存位置
            prompt_dir = os.path.join(gallery_dir, "prompts")
            prompt_file = os.path.join(prompt_dir, f"{base_name}_prompt.txt")
            neg_prompt_file = os.path.join(prompt_dir, f"{base_name}_neg_prompt.txt")

            prompt = "未知提示词"
            negative_prompt = "未知反向提示词"

            if os.path.exists(prompt_file):
                with open(prompt_file, 'r', encoding='utf-8') as f:
                    prompt = f.read().strip()

            if os.path.exists(neg_prompt_file):
                with open(neg_prompt_file, 'r', encoding='utf-8') as f:
                    negative_prompt = f.read().strip()
            try:
                # 从文件名中提取时间戳部分
                # 文件名格式: sd_image_YYYYMMDD_HHMMSS_ffffff_randomnum.png
                filename_parts = os.path.splitext(filename)[0].split('_')  # 分割文件名（不含扩展名）
                if len(filename_parts) >= 6:  # 确保有足够的部分
                    date_part = filename_parts[2]  # YYYYMMDD
                    time_part = filename_parts[3]  # HHMMSS_ffffff
                    time_microsec_part = filename_parts[3] + '_' + filename_parts[4]  # HHMMSS_ffffff
                    # 组合日期和时间
                    datetime_str = f"{date_part}_{time_microsec_part}"
                    # 解析为datetime对象
                    file_datetime = datetime.strptime(datetime_str, "%Y%m%d_%H%M%S_%f")
                    timestamp = file_datetime.timestamp()
                else:
                    # 如果文件名格式不符合预期，回退到使用修改时间
                    timestamp = os.path.getmtime(os.path.join(gallery_dir, filename))
            except (ValueError, IndexError):
                # 如果解析失败，使用修改时间
                timestamp = os.path.getmtime(os.path.join(gallery_dir, filename))

            image_path = f"{SERVER_DOMAIN}/{gallery_dir}/{filename}"
            image_files.append({
                "image_url": image_path,
                "prompt": prompt,
                "negative_prompt": negative_prompt,
                "date": timestamp  # 获取创建时间
            })

    # 按时间倒序排列（最新的在前）
    image_files.sort(key=lambda x: x["date"], reverse=True)
    return {"code": 200, "msg": "获取成功", "data": image_files}


# ===================== 启动服务 =====================
if __name__ == "__main__":
    import uvicorn

    uvicorn.run("fastapi_user:app", host="192.168.31.219", port=8000)