from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware  # 确保导入正确
from pydantic import BaseModel
import os
import json
from dotenv import load_dotenv
import dashscope
from dashscope import Generation

# 1. 先加载环境变量
load_dotenv()
dashscope.api_key = os.getenv("DASHSCOPE_API_KEY")

# 2. 初始化FastAPI（必须先初始化app，再添加跨域）
app = FastAPI(title="翻译与关键词提取接口", version="1.0")

# 3. 跨域配置（核心：必须在接口定义之前添加，且配置完整）
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # 允许所有域名（Web端必须）
    allow_credentials=True,
    allow_methods=["*"],  # 允许所有HTTP方法（包括OPTIONS/POST）
    allow_headers=["*"],  # 允许所有请求头
    expose_headers=["*"],  # 额外暴露响应头（可选，防止隐性报错）
)


# 4. 定义请求/响应模型
class TranslateRequest(BaseModel):
    text: str


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


# 6. 翻译接口（跨域配置已提前加载，能处理OPTIONS请求）
@app.post("/translate", response_model=TranslateResponse)
async def translate(request: TranslateRequest):
    input_text = request.text.strip()
    if not input_text:
        raise HTTPException(status_code=400, detail="输入文本不能为空")

    try:
        prompt = f"""
        你是一个专业的翻译模型，请将输入的文本翻译成准确流畅的英文，并提取1-5个核心中文关键词。
        请使用JSON格式返回结果，请勿添加其他内容：
        {{
          "translation": "将「{input_text}」翻译成准确流畅的英文",
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


# 7. 启动代码（修正reload警告）
if __name__ == "__main__":
    import uvicorn

    uvicorn.run(
        "AI_Translate:app",  # 替换为你的文件名（比如translate.py则写"translate:app"）
        host="0.0.0.0",# 监听所有IP
        port=8000,#
        reload=True,# 自动重载
        log_level="debug"# 日志级别
    )