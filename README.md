# README.md

# 大模型调用项目，使用大模型可以生成stable diffusion提示词，利用提示词生成图像，（FastAPI + Flutter）

一个基于 FastAPI 构建后端接口、Flutter 开发前端界面应用，前后端分离架构，单仓统一管理。

## 📋 项目结构

本项目采用单仓管理，按前后端模块拆分目录，结构清晰易维护：

此次主要提供完整的用户注册、激活、登录、信息修改等功能，并集成了AI翻译和图像生成能力。

通过使用ai模型：通义千问生成适合stable diffusion 图像的提示词，确保生成图像的可靠性。

backend文件只有翻译api，无其他改动，

主要添加了user_api，修改了frontend。

