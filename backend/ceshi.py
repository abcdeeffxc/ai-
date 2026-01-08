from dotenv import load_dotenv
import os
#测试是否写入api密钥
# 加载.env文件
load_dotenv()

# 读取API-KEY
api_key = os.getenv("DASHSCOPE_API_KEY")

if api_key:
    print("✅ .env文件配置成功，API-KEY已读取：", api_key[:3] + "****")  # 只显示前3位，保护密钥
else:
    print("❌ 未读取到API-KEY，请检查.env文件路径或内容")