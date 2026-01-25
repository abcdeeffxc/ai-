import requests
import json
import base64
import os
import random
from PIL import Image
from io import BytesIO
from datetime import datetime

# 1. 配置SD API基础地址（秋叶包默认）
SD_API_URL = "http://127.0.0.1:7860/sdapi/v1/txt2img"

# 2. 预定义支持的模型列表
SUPPORTED_MODELS = [
    "anythingAnd_anythingAndEverything.safetensors",
    "chilloutmix_NiPrunedFp32Fix.safetensors",
    "CounterfeitV30_v30.safetensors",
    "cyberrealistic_v40.safetensors",
    "GuoFeng3-non-ema-fp16.safetensors",
    "ipDESIGN3D_v31.safetensors"

]
# 3. 模型到风格的映射
MODEL_TO_STYLE_MAP = {
    "anythingAnd_anythingAndEverything.safetensors": ["2次元", "卡通", "动漫", "万能"],
    "chilloutmix_NiPrunedFp32Fix.safetensors": ["现代", "写真", "真实", "人物"],
    "CounterfeitV30_v30.safetensors": ["2次元", "动漫", "人物", "卡通"],
    "cyberrealistic_v40.safetensors": ["赛博", "科幻", "现实", "现代"],
    "GuoFeng3-non-ema-fp16.safetensors": ["古风", "中国风", "传统", "古典"],
    "ipDESIGN3D_v31.safetensors": ["3D", "设计", "立体", "现代"]
}

# 3. 风格类型到模型的映射
STYLE_TO_MODEL_MAP = {
    "古风": "GuoFeng3-non-ema-fp16.safetensors",      # 国风模型适合古风
    "现代": "chilloutmix_NiPrunedFp32Fix.safetensors",  # 真实感模型适合现代
    "2次元": "CounterfeitV30_v30.safetensors",  # 通用动漫模型
    "卡通": "anythingAnd_anythingAndEverything.safetensors",   # 通用动漫模型
    "写真": "chilloutmix_NiPrunedFp32Fix.safetensors",         # 真实感模型适合写真
    "万能": "anythingAnd_anythingAndEverything.safetensors",    # 通用模型
    "赛博": "cyberrealistic_v40.safetensors", # 科幻模型适合赛博
    "3D": "ipDESIGN3D_v31.safetensors", # 3D模型适合3D
}

Lora_list = [
    "koreanDollLikeness_v15.safetensors",
    "IP人物3D设计.safetensors"
]

# 4. 根据风格选择模型的函数
def get_model_by_style(style: str) -> str:
    """
    根据风格类型获取对应的模型名称
    :param style: 风格类型，如"古风"、"现代"、"2次元"、"卡通"、"写真"、"万能"
    :return: 对应的模型名称，如果风格不匹配则返回默认模型
    """
    return STYLE_TO_MODEL_MAP.get(style, SUPPORTED_MODELS[0])

# 5. 根据模型获取风格的函数
def get_styles_by_model(model_name: str) -> list:
    """
    根据模型名称获取其支持的风格列表
    :param model_name: 模型名称
    :return: 风格列表，如果模型不匹配则返回空列表
    """
    return MODEL_TO_STYLE_MAP.get(model_name, [])
Lora_list = [
    "koreanDollLikeness_v15.safetensors",
    "IP人物3D设计.safetensors"
]

# 3. 生成唯一文件名的工具函数（核心：防覆盖）
def get_unique_filename(base_dir: str = "static/avatar", ext: str = "png") -> str:
    """
    生成唯一的文件名，避免覆盖
    :param base_dir: 保存基础目录
    :param ext: 文件后缀（png/jpg等）
    :return: 完整的唯一文件路径
    """
    # 确保基础目录存在（不存在则创建）
    os.makedirs(base_dir, exist_ok=True)

    # 生成唯一标识：时间戳（精确到微秒）+ 随机数（避免同一微秒重复）
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S_%f")  # 年-月-日_时-分-秒-微秒
    random_num = random.randint(1000, 9999)  # 4位随机数
    unique_name = f"sd_image_{timestamp}_{random_num}.{ext}"

    # 拼接完整路径
    full_path = os.path.join(base_dir, unique_name)
    return full_path


# 4. 核心生成函数（支持传参+防覆盖）
def generate_image_by_qiuye(
        prompt: str = "a beautiful sunset over the mountains, 8k, high detail, realistic",
        negative_prompt: str = "blurry, ugly, low resolution, deformed",
        model_name: str = "anythingAnd_anythingAndEverything.safetensors",
        width: int = 512,
        height: int = 512,
        steps: int = 30,
        cfg_scale: float = 7.5,
        sampler_index: str = "DPM++ 2M Karras",
        save_dir: str = "static/avatar",  # 仅指定保存目录，文件名自动生成
        save_ext: str = "png"  # 文件格式
):
    """
    调用秋叶SD API生成图片（防覆盖+支持传参）
    :param prompt: 正向提示词（必填，无参用默认值）
    :param negative_prompt: 反向提示词（无参用默认值）
    :param model_name: 模型名称（必须是SUPPORTED_MODELS中的值，否则用默认模型）
    :param width: 图片宽度（默认512）
    :param height: 图片高度（默认512）
    :param steps: 采样步数（默认30）
    :param cfg_scale: 提示词相关性（默认7.5）
    :param sampler_index: 采样器（默认DPM++ 2M Karras）
    :param save_dir: 保存目录（默认static/avatar），文件名自动生成唯一值
    :param save_ext: 文件后缀（默认png）
    其他参数同前
    :return: 生成的PIL.Image对象 + 保存路径（失败返回None, None）
    """
    # 校验模型名称
    if model_name not in SUPPORTED_MODELS:
        print(f"⚠️ 模型 {model_name} 不在支持列表中，自动使用默认模型：{SUPPORTED_MODELS[0]}")
        model_name = SUPPORTED_MODELS[0]

    # 构建请求参数
    payload = {
        "prompt": prompt,
        "negative_prompt": negative_prompt,
        "width": width,
        "height": height,
        "steps": steps,
        "cfg_scale": cfg_scale,
        "sampler_index": sampler_index,
        "return_images": True,
        "sd_model_checkpoint": model_name
    }

    try:
        # 发送请求
        response = requests.post(
            url=SD_API_URL,
            headers={"Content-Type": "application/json"},
            data=json.dumps(payload)
        )
        response.raise_for_status()
        result = response.json()

        # 检查API错误
        if "error" in result:
            print(f"❌ API返回错误：{result['error']}")
            return None, None

        # 解码图片数据
        image_data_str = result["images"][0].strip().replace("\n", "")
        try:
            image_bytes = bytes.fromhex(image_data_str)
            print("✅ 使用Hex编码解码")
        except ValueError:
            image_bytes = base64.b64decode(image_data_str)
            print("✅ 使用Base64编码解码")

        # 生成唯一保存路径（核心：防覆盖）
        save_path = get_unique_filename(base_dir=save_dir, ext=save_ext)

        # 保存图片
        image = Image.open(BytesIO(image_bytes))
        image.save(save_path)
        print(f"✅ 图片生成成功！唯一保存路径：{save_path}")

        return image, save_path  # 返回图片对象+保存路径

    except requests.exceptions.RequestException as e:
        print(f"❌ 请求失败：{e}")
        return None, None
    except Exception as e:
        print(f"❌ 生成失败：{e}")
        return None, None


# 5. 调用示例
if __name__ == "__main__":
    # 示例1：默认调用（自动生成唯一文件名，保存到static/avatar）
    # print("=== 示例1：默认调用（防覆盖）===")
    generate_image_by_qiuye()

    # # 示例2：自定义提示词+模型+保存目录
    # print("\n=== 示例2：自定义参数+指定保存目录 ===")
    # generate_image_by_qiuye(
    #     prompt="korean beauty, realistic, 4k",
    #     model_name="koreanDollLikeness_v15.safetensors",
    #     save_dir="static/korean_images",  # 自定义保存目录
    #     save_ext="jpg"  # 自定义文件格式
    # )
    #
    # # 示例3：批量生成（验证不会覆盖）
    # print("\n=== 示例3：批量生成（验证唯一文件名）===")
    # for i in range(3):
    #     print(f"\n--- 批量生成第{i + 1}张 ---")
    #     generate_image_by_qiuye(
    #         prompt=f"batch test {i + 1}, cartoon style",
    #         model_name="chilloutmix_NiPrunedFp32Fix.safetensors"
    #     )