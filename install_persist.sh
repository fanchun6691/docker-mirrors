#!/bin/bash
# install_persist.sh - 持久化安装脚本（只在镜像构建时执行）

set -e

echo "=========================================="
echo "🔧 持久化安装 Jupyter-AI 环境"
echo "=========================================="

# 配置变量（从环境变量读取，与 Dockerfile 保持一致）
CONDA_ENV_NAME="ai_env"
PYTHON_VERSION="3.10"
OLLAMA_EXTERNAL_URL="${OLLAMA_HOST:-http://192.168.112.136:11434}"
OLLAMA_DEFAULT_MODEL="${OLLAMA_DEFAULT_MODEL:-qwen2.5-coder:7b-q4}"

# 初始化 conda
source /opt/conda/etc/profile.d/conda.sh

# 检查环境是否已存在，存在则跳过
if conda env list | grep -q "^${CONDA_ENV_NAME} "; then
    echo "✅ Conda 环境 ${CONDA_ENV_NAME} 已存在，跳过创建"
else
    echo "📦 创建 Conda 环境: ${CONDA_ENV_NAME} (Python ${PYTHON_VERSION})"
    conda create -n ${CONDA_ENV_NAME} python=${PYTHON_VERSION} -y
fi

# 激活环境
conda activate ${CONDA_ENV_NAME}

# 升级 pip
pip install --upgrade pip setuptools wheel

# ============================================
# 安装 Node.js 20（使用 conda，避免 apt 冲突）
# ============================================
echo "📦 安装 Node.js 20..."
conda install -n ${CONDA_ENV_NAME} -c conda-forge nodejs=20 -y

# 确保环境变量正确
export PATH=/opt/conda/envs/${CONDA_ENV_NAME}/bin:$PATH
node --version


# ============================================
# 安装 Python 包（持久化在镜像中）
# ============================================
echo "📚 安装 Python 包..."
# ============================================
# 安装 AI 专用包（不重复安装 JupyterLab）
# ============================================
echo "📚 安装 AI 专用包..."

# 只在需要时安装 JupyterLab
if [ "$INSTALL_JUPYTER" = true ]; then
    echo "安装 JupyterLab..."
    pip install jupyterlab>=4.0.0
else
    echo "⏭️ 跳过 JupyterLab 安装（使用 base 环境预装版本）"
fi

# 安装 Jupyter AI 扩展（必需）
# Jupyter 核心包
pip install \
    'jupyter-ai[magics]==3.0.0' \
    ipykernel>=6.0.0 \
    ipywidgets>=8.0.0 

# 重建 JupyterLab 确保前端扩展生效
echo " 重建 JupyterLab 扩展..."
jupyter lab build --minimize=False
echo " Jupyter AI 核心包安装完成"
# 验证扩展安装
echo " 验证扩展列表:"
jupyter labextension list
echo " Jupyter AI 核心包安装完成"

# 新增这一行，用 conda 安装 nb_conda_kernels
pip install --force-reinstall setuptools==69.0.2
conda install -n ${CONDA_ENV_NAME} -c conda-forge nb_conda_kernels=2.3.1 -y

# 数据科学基础库
pip install \
    numpy>=1.24.0 \
    pandas>=2.0.0 \
    matplotlib>=3.7.0 \
    seaborn>=0.12.0 \
    scikit-learn>=1.3.0 \
    scipy>=1.10.0 \
    xgboost>=2.0.0

# 深度学习框架（CPU 版本，如需 GPU 可更换）
pip install --force-reinstall protobuf==7.34.0
pip install  torch>=2.0.0   torchvision>=0.15.0    tensorflow>=2.15.0
pip install --force-reinstall protobuf==7.34.0
# LangChain 生态系统
pip install --force-reinstall  google-ai-generativelanguage==0.7.0 
pip install \
    langchain>=0.3.0 \
    langchain-core>=0.3.0 \
    langchain-community>=0.3.0 \
    langchain-openai>=0.2.0 \
    langchain-anthropic>=0.2.0 \
    langchain-google-genai>=2.0.0 \
    langchain-ollama>=0.2.0 

pip install --force-reinstall  google-ai-generativelanguage==0.7.0 
# AI 模型工具
pip install \
    transformers>=4.30.0 \
    datasets>=2.14.0 \
    accelerate>=0.20.0 \
    openai>=1.0.0 \
    anthropic>=0.3.0 \
    google-generativeai>=0.3.0

# 可视化库
pip install \
    plotly>=5.15.0 \
    bokeh>=3.2.0 \
    altair>=5.0.0

# 向量数据库
pip install \
    faiss-cpu>=1.7.0 \
    chromadb>=0.4.0 \
    pinecone-client>=2.2.0

# 工具库
pip install \
    requests>=2.31.0 \
    tqdm>=4.65.0 \
    python-dotenv>=1.0.0 \
    pyyaml>=6.0 \
    httpx>=0.25.0 \
    aiohttp>=3.8.0 \
    pypdf>=3.0.0 \
    python-docx>=0.8.11 \
    openpyxl>=3.1.0

# Jupyter 扩展
pip install \
    jupyterlab-git>=0.45.0 \
    jupyterlab-lsp>=5.0.0


# ============================================
# 注册 Jupyter Kernel
# ============================================
echo "🎯 注册 Jupyter Kernel..."

python -m ipykernel install \
    --user \
    --name ${CONDA_ENV_NAME} \
    --display-name "Python 3.10 (AI)"

# 创建 kernel 配置（从环境变量读取）
KERNEL_DIR="/home/jovyan/.local/share/jupyter/kernels/${CONDA_ENV_NAME}"
mkdir -p ${KERNEL_DIR}

cat > ${KERNEL_DIR}/kernel.json << EOF
{
 "argv": [
  "/opt/conda/envs/${CONDA_ENV_NAME}/bin/python",
  "-m",
  "ipykernel_launcher",
  "-f",
  "{connection_file}"
 ],
 "display_name": "Python 3.10 (AI)",
 "language": "python",
 "metadata": {
  "debugger": true
 },
 "env": {
  "OLLAMA_HOST": "${OLLAMA_EXTERNAL_URL}",
  "OLLAMA_BASE_URL": "${OLLAMA_EXTERNAL_URL}",
  "OLLAMA_DEFAULT_MODEL": "${OLLAMA_DEFAULT_MODEL}",
  "HF_ENDPOINT": "${HF_ENDPOINT:-https://hf-mirror.com}",
  "OPENAI_API_KEY": "${OPENAI_API_KEY}",
  "OPENAI_BASE_URL": "${OPENAI_BASE_URL:-https://api.openai.com/v1}",
  "ANTHROPIC_API_KEY": "${ANTHROPIC_API_KEY}",
  "GOOGLE_API_KEY": "${GOOGLE_API_KEY}",
  "HUGGINGFACEHUB_API_TOKEN": "${HUGGINGFACEHUB_API_TOKEN}",
  "COHERE_API_KEY": "${COHERE_API_KEY}",
  "AI21_API_KEY": "${AI21_API_KEY}",
  "AWS_ACCESS_KEY_ID": "${AWS_ACCESS_KEY_ID}",
  "AWS_SECRET_ACCESS_KEY": "${AWS_SECRET_ACCESS_KEY}",
  "AWS_DEFAULT_REGION": "${AWS_DEFAULT_REGION:-us-east-1}"
 }
}
EOF

# ============================================
# 配置 JupyterLab（持久化配置）
# ============================================
echo "⚙️ 配置 JupyterLab..."

CONFIG_DIR="/home/jovyan/.jupyter"
mkdir -p ${CONFIG_DIR}

# JupyterLab 配置
cat > ${CONFIG_DIR}/jupyter_lab_config.py << EOF
import os
# 从环境变量获取配置（无则使用默认值）
OLLAMA_BASE_URL = os.getenv("OLLAMA_BASE_URL", "http://192.168.112.136:11434")
OLLAMA_MODEL = os.getenv("OLLAMA_DEFAULT_MODEL", "qwen2.5-coder:7b-q4")
# JupyterLab 持久化配置
c.ServerApp.allow_root = True
c.ServerApp.ip = '0.0.0.0'
c.ServerApp.port = 8881
c.ServerApp.open_browser = False
c.ServerApp.token = ''
c.ServerApp.password = ''
c.ServerApp.disable_check_xsrf = True
c.ServerApp.allow_origin = '*'
c.ServerApp.allow_remote_access = True
c.ServerApp.root_dir = '/home/jovyan'
c.ServerApp.trust_xheaders = True

c.ContentsManager.allow_hidden = True
# 避免 MCP 端口冲突
c.MCPExtensionApp.mcp_port = 3002
# Jupyter AI 配置
# 核心配置（自动拼接）
c.JupyterAI.model_provider_id = "ollama"
c.JupyterAI.model_id = OLLAMA_MODEL
c.JupyterAI.chat_provider = f"ollama:{OLLAMA_MODEL}"
c.JupyterAI.autocomplete_provider = f"ollama:{OLLAMA_MODEL}"

# Ollama 连接地址
c.JupyterOllama.base_url = OLLAMA_BASE_URL
c.JupyterOllama.default_model = OLLAMA_MODEL

c.LabApp.extensions_in_dev_mode = True
EOF

# Jupyter AI JSON 配置
cat > ${CONFIG_DIR}/jupyter_ai_config.json << EOF
{
  "model_provider_id": "ollama",
  "model_id": "${OLLAMA_DEFAULT_MODEL}",
  "api_keys": {},
  "model_parameters": {
    "temperature": ${OLLAMA_TEMPERATURE:-0.7},
    "max_tokens": ${MAX_TOKENS:-2048},
    "top_p": ${OLLAMA_TOP_P:-0.9},
    "repeat_penalty": ${OLLAMA_REPEAT_PENALTY:-1.1}
  },
  "ollama_config": {
    "base_url": "${OLLAMA_EXTERNAL_URL}",
    "default_model": "${OLLAMA_DEFAULT_MODEL}"
  },
  "send_with_shift_enter": false,
  "autocomplete_provider": "ollama:${OLLAMA_DEFAULT_MODEL}",
  "chat_provider": "ollama:${OLLAMA_DEFAULT_MODEL}"
}
EOF

# ============================================
# IPython 启动脚本（持久化）
# ============================================
echo "📝 配置 IPython 启动脚本..."

IPYTHON_DIR="/home/jovyan/.ipython/profile_default/startup"
mkdir -p ${IPYTHON_DIR}

cat > ${IPYTHON_DIR}/00-jupyter-ai-setup.py << EOF
# -*- coding: utf-8 -*-
"""Jupyter AI 自动配置脚本（持久化）"""

import os

# 设置环境变量
os.environ.setdefault('OLLAMA_HOST', '${OLLAMA_EXTERNAL_URL}')
os.environ.setdefault('OLLAMA_BASE_URL', '${OLLAMA_EXTERNAL_URL}')
os.environ.setdefault('OLLAMA_DEFAULT_MODEL', '${OLLAMA_DEFAULT_MODEL}')
os.environ.setdefault('HF_ENDPOINT', '${HF_ENDPOINT:-https://hf-mirror.com}')

# 加载 Jupyter AI 魔法命令
try:
    from IPython import get_ipython
    ip = get_ipython()
    if ip:
        ip.magic('load_ext jupyter_ai')
        ip.magic('load_ext jupyter_ai_magics')
        print("✅ Jupyter AI 已加载")
        print(f"🦙 Ollama 服务器: ${OLLAMA_EXTERNAL_URL}")
        print(f"📦 默认模型: ${OLLAMA_DEFAULT_MODEL}")
        print("📝 使用方法: %%ai ollama:${OLLAMA_DEFAULT_MODEL} 你的问题")
        print("💡 模型特点: 代码生成与理解优化")
except Exception as e:
    print(f"⚠️ Jupyter AI 加载失败: {e}")
EOF

# ============================================
# 创建启动脚本
# ============================================
echo "🚀 创建启动脚本..."

cat > /home/jovyan/start_jupyter_ai.sh << EOF
#!/bin/bash

# 初始化 conda
source /opt/conda/etc/profile.d/conda.sh

# 激活 AI 环境（用于 Python 包和扩展）
conda activate ${CONDA_ENV_NAME}
# 设置环境变量
export JUPYTER_ENABLE_LAB=yes
export OLLAMA_HOST=\${OLLAMA_HOST:-${OLLAMA_EXTERNAL_URL}}
export OLLAMA_BASE_URL=\${OLLAMA_BASE_URL:-${OLLAMA_EXTERNAL_URL}}
export OLLAMA_DEFAULT_MODEL=\${OLLAMA_DEFAULT_MODEL:-${OLLAMA_DEFAULT_MODEL}}
export HF_ENDPOINT=\${HF_ENDPOINT:-${HF_ENDPOINT:-https://hf-mirror.com}}

# 确保 JupyterLab 能找到 ai_env 的包
export PYTHONPATH="/opt/conda/envs/${CONDA_ENV_NAME}/lib/python3.10/site-packages:\$PYTHONPATH"

echo "=========================================="
echo "🚀 启动 Jupyter-AI 服务"
echo "=========================================="
echo "JupyterLab: http://localhost:8881"
echo "Ollama 服务器: \${OLLAMA_HOST}"
echo "默认模型: \${OLLAMA_DEFAULT_MODEL}"
echo "=========================================="
echo "=========启动 jupyter lab========="
exec jupyter lab --config=/home/jovyan/.jupyter/jupyter_lab_config.py
EOF

chmod +x /home/jovyan/start_jupyter_ai.sh

echo "🧹 清理缓存和临时文件..."

# pip 清理
pip cache purge
pip cache remove "*" 2>/dev/null || true

# conda 清理
conda clean -afy
conda clean -t -y
conda clean -p -y

# 删除缓存目录
rm -rf /home/jovyan/.cache/pip
rm -rf /home/jovyan/.cache/conda
rm -rf /home/jovyan/.cache/huggingface
rm -rf /home/jovyan/.cache/matplotlib
rm -rf /home/jovyan/.ipython

# 删除临时文件
rm -rf /tmp/pip-*
rm -rf /tmp/tmp*
rm -rf /tmp/*.log
rm -rf /var/tmp/*

# 删除 Python 字节码文件
find /opt/conda/envs/${CONDA_ENV_NAME} -name "*.pyc" -delete 2>/dev/null || true
find /opt/conda/envs/${CONDA_ENV_NAME} -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null || true

# 删除 npm 缓存（如果有）
npm cache clean --force 2>/dev/null || true

# 删除误写入工作目录的垃圾文件
echo "🧹 清理垃圾文件..."
rm -f /home/jovyan/=* 2>/dev/null
rm -f /home/jovyan/work/=* 2>/dev/null

echo "✅ 清理完成"

# ============================================
# 验证
# ============================================
echo "✅ 验证安装..."

echo "JupyterLab 版本:"
conda run -n base jupyter-lab --version

echo "已安装的 AI 包:"
pip list | grep -E "jupyter-ai|langchain|torch|transformers"

echo ""
echo "=========================================="
echo "✅ 安装完成！"
echo "=========================================="
echo "环境架构:"
echo "  - Jupyter AI 版本: 3.0.0"
echo "  - Ollama 支持: 内置（无需额外安装）"
echo "  - Ollama 服务器: ${OLLAMA_EXTERNAL_URL}"
echo "  - 默认模型: ${OLLAMA_DEFAULT_MODEL}"
echo "=========================================="

# 测试 Ollama 连接
echo "🔍 测试 Ollama 服务器连接..."
if curl -s --max-time 5 ${OLLAMA_EXTERNAL_URL} > /dev/null 2>&1; then
    echo "✅ Ollama 服务器连接成功 (${OLLAMA_EXTERNAL_URL})"
    
    # 检查模型是否可用
    if curl -s --max-time 10 ${OLLAMA_EXTERNAL_URL}/api/tags 2>/dev/null | grep -q "${OLLAMA_DEFAULT_MODEL}"; then
        echo "✅ 模型 ${OLLAMA_DEFAULT_MODEL} 已就绪"
    else
        echo "⚠️  模型 ${OLLAMA_DEFAULT_MODEL} 未找到"
        echo "📋 可用模型列表:"
        curl -s ${OLLAMA_EXTERNAL_URL}/api/tags 2>/dev/null | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    models = [m['name'] for m in data.get('models', [])]
    for m in models[:5]:
        print(f'    - {m}')
except:
    pass
" || echo "    无法获取模型列表"
    fi
else
    echo "⚠️  无法连接到 Ollama 服务器 (${OLLAMA_EXTERNAL_URL})"
    echo "   请检查:"
    echo "   1. 服务器 192.168.112.136 是否在线"
    echo "   2. 端口 11434 是否开放"
    echo "   3. 网络连接是否正常"
fi

echo ""
echo "🎯 JupyterLab 已配置完成，启动命令已准备就绪"

# ============================================
# 创建 .env 配置文件（可被 volume 覆盖）
# ============================================
cat > /home/jovyan/.env.default << EOF
# Jupyter-AI 默认环境变量
OLLAMA_HOST=${OLLAMA_EXTERNAL_URL}
OLLAMA_BASE_URL=${OLLAMA_EXTERNAL_URL}
OLLAMA_DEFAULT_MODEL=${OLLAMA_DEFAULT_MODEL}
HF_ENDPOINT=${HF_ENDPOINT:-https://hf-mirror.com}
DISABLE_LOCAL_OLLAMA=true
JUPYTER_PORT=8881

# 模型参数（可选）
OLLAMA_TEMPERATURE=0.7
OLLAMA_TOP_P=0.9
OLLAMA_REPEAT_PENALTY=1.1

# 外部 API Keys（可选，运行时注入）
OPENAI_API_KEY=
ANTHROPIC_API_KEY=
GOOGLE_API_KEY=
HUGGINGFACEHUB_API_TOKEN=
COHERE_API_KEY=
AI21_API_KEY=
AWS_ACCESS_KEY_ID=
AWS_SECRET_ACCESS_KEY=
AWS_DEFAULT_REGION=us-east-1
EOF

# ============================================
# 创建使用说明文档
# ============================================
cat > /home/jovyan/README_JUPYTER_AI.md << 'EOF'
# Jupyter-AI 使用指南

## 目录

1. [环境配置](#1-环境配置)
2. [Jupyter AI 详细使用介绍](#2-jupyter-ai-详细使用介绍)
3. [已安装工具及使用方法](#3-已安装工具及使用方法)
4. [快速开始](#4-快速开始)
5. [使用外部AI服务](#5-使用外部ai服务)
6. [高级用法](#6-高级用法)
7. [常见问题排查](#7-常见问题排查)
8. [性能优化建议](#8-性能优化建议)
9. [注意事项](#9-注意事项)
10. [相关资源](#10-相关资源)

---

## 1. 环境配置

### 默认配置

| 配置项 | 值 |
|--------|-----|
| Ollama服务器 | http://192.168.112.136:11434 |
| 默认模型 | qwen2.5-coder:7b-q4 |
| Conda环境 | ai_env |
| Python版本 | 3.10 |

### 支持的AI服务

| 服务 | Provider ID | 环境变量 | 调用示例 |
|------|-------------|----------|----------|
| Ollama | ollama | OLLAMA_HOST | `%%ai ollama:qwen2.5-coder:7b-q4` |
| OpenAI | openai-chat | OPENAI_API_KEY | `%%ai openai-chat:gpt-4` |
| Claude | anthropic-chat | ANTHROPIC_API_KEY | `%%ai anthropic-chat:claude-3-5-sonnet-20241022` |
| Gemini | gemini | GOOGLE_API_KEY | `%%ai gemini:gemini-1.5-pro` |
| HuggingFace | huggingface_hub | HUGGINGFACEHUB_API_TOKEN | `%%ai huggingface_hub:model-name` |

---

## 2. Jupyter AI 详细使用介绍

### 2.1 什么是 Jupyter AI

Jupyter AI 是 Jupyter 官方推出的 AI 辅助编程工具，集成了多种大语言模型，可以在 Notebook 中直接使用 AI 进行代码生成、解释、优化、调试等操作。

### 2.2 加载扩展

在使用 Jupyter AI 之前，需要先加载扩展：

```python
# 加载魔法命令扩展（推荐）
%load_ext jupyter_ai_magics

# 或者加载完整扩展
%load_ext jupyter_ai
加载成功后，会显示：

text
The jupyter_ai_magics extension is already loaded.
2.3 基本使用语法
python
%%ai [provider]:[model] [options]
你的问题或指令
参数说明：

provider: AI服务提供商（ollama, openai-chat, anthropic-chat, gemini等）

model: 模型名称

options: 可选参数（--format, --temperature, --max-tokens等）

2.4 代码生成
python
# 生成排序算法
%%ai ollama:qwen2.5-coder:7b-q4
用 Python 实现一个快速排序算法

# 生成类定义
%%ai ollama:qwen2.5-coder:7b-q4
实现一个 Python 类，表示银行账户，包含存款、取款、查询余额方法

# 生成函数
%%ai ollama:qwen2.5-coder:7b-q4
写一个函数，判断一个字符串是否是回文串

# 生成正则表达式
%%ai ollama:qwen2.5-coder:7b-q4
写一个正则表达式，匹配中国大陆的手机号码

# 生成SQL语句
%%ai ollama:qwen2.5-coder:7b-q4
写一个SQL查询，查询每个部门工资最高的员工
2.5 代码解释
python
# 解释复杂代码
%%ai ollama:qwen2.5-coder:7b-q4
解释这段代码的作用：
def quicksort(arr):
    if len(arr) <= 1:
        return arr
    pivot = arr[len(arr) // 2]
    left = [x for x in arr if x < pivot]
    middle = [x for x in arr if x == pivot]
    right = [x for x in arr if x > pivot]
    return quicksort(left) + middle + quicksort(right)

# 解释算法原理
%%ai ollama:qwen2.5-coder:7b-q4
解释动态规划的原理，并用斐波那契数列举例

# 解释报错信息
%%ai ollama:qwen2.5-coder:7b-q4
这个错误是什么意思？如何解决？
Traceback (most recent call last):
  File "<stdin>", line 1, in <module>
KeyError: 'name'
2.6 代码优化
python
# 性能优化
%%ai ollama:qwen2.5-coder:7b-q4
优化这段代码的性能：
def find_duplicates(arr):
    result = []
    for i in range(len(arr)):
        for j in range(i+1, len(arr)):
            if arr[i] == arr[j] and arr[i] not in result:
                result.append(arr[i])
    return result

# 代码重构
%%ai ollama:qwen2.5-coder:7b-q4
重构这段代码，使其更符合Python最佳实践：
def calc(a,b,c):
    if c == 'add':
        return a + b
    elif c == 'sub':
        return a - b
    elif c == 'mul':
        return a * b
    elif c == 'div':
        return a / b

# 简化逻辑
%%ai ollama:qwen2.5-coder:7b-q4
简化这段代码的逻辑：
if x == True:
    return True
else:
    return False
2.7 代码调试
python
# 查找bug
%%ai ollama:qwen2.5-coder:7b-q4
这段代码有什么bug？如何修复？
def divide_list(lst, n):
    return [lst[i:i+n] for i in range(0, len(lst), n)]

result = divide_list([1,2,3], 0)

# 边界条件检查
%%ai ollama:qwen2.5-coder:7b-q4
检查这段代码的边界条件处理：
def binary_search(arr, target):
    left, right = 0, len(arr) - 1
    while left < right:
        mid = (left + right) // 2
        if arr[mid] == target:
            return mid
        elif arr[mid] < target:
            left = mid + 1
        else:
            right = mid - 1
    return -1

# 异常处理
%%ai ollama:qwen2.5-coder:7b-q4
为这段代码添加异常处理：
def read_file(filename):
    with open(filename, 'r') as f:
        return f.read()
2.8 单元测试生成
python
%%ai ollama:qwen2.5-coder:7b-q4
为以下函数生成单元测试：
def is_prime(n):
    if n < 2:
        return False
    for i in range(2, int(n**0.5) + 1):
        if n % i == 0:
            return False
    return True
2.9 文档生成
python
%%ai ollama:qwen2.5-coder:7b-q4
为以下函数生成 docstring：
def calculate_interest(principal, rate, time):
    return principal * (1 + rate) ** time - principal
2.10 代码转换
python
# Python转Java
%%ai ollama:qwen2.5-coder:7b-q4
将以下 Python 代码转换为 Java：
def factorial(n):
    return 1 if n <= 1 else n * factorial(n-1)

# 列表推导转循环
%%ai ollama:qwen2.5-coder:7b-q4
将列表推导式转换为普通循环：
squares = [x**2 for x in range(10) if x % 2 == 0]

# 使用lambda改写
%%ai ollama:qwen2.5-coder:7b-q4
用 lambda 表达式改写这段代码：
def add(x, y):
    return x + y
2.11 代码审查
python
%%ai ollama:qwen2.5-coder:7b-q4
审查以下代码，指出潜在问题：
def process_user_data(user_data):
    result = []
    for i in range(len(user_data)):
        if user_data[i]['age'] > 18:
            user_data[i]['status'] = 'adult'
            result.append(user_data[i])
        else:
            user_data[i]['status'] = 'minor'
            result.append(user_data[i])
    return result
2.12 学习辅助
python
# 解释概念
%%ai ollama:qwen2.5-coder:7b-q4
解释 Python 中的装饰器，给出3个实际应用场景

# 对比差异
%%ai ollama:qwen2.5-coder:7b-q4
对比列表和元组的区别，包括性能、使用场景、可变性

# 最佳实践
%%ai ollama:qwen2.5-coder:7b-q4
Python 中处理文件的最佳实践有哪些？

# 面试问题
%%ai ollama:qwen2.5-coder:7b-q4
出一道 Python 面试题，考察闭包的知识点，并给出答案
2.13 指定输出格式
python
# JSON格式输出
%%ai ollama:qwen2.5-coder:7b-q4 --format json
列出5种常见的设计模式，包含名称和描述

# Markdown表格格式
%%ai ollama:qwen2.5-coder:7b-q4
用Markdown表格格式列出Python的常用数据结构及其时间复杂度

# 指定语言
%%ai ollama:qwen2.5-coder:7b-q4
用中文回答：什么是机器学习？
2.14 使用变量
python
# 定义变量
code = """
def fibonacci(n):
    if n <= 1:
        return n
    return fibonacci(n-1) + fibonacci(n-2)
"""

# 在AI指令中使用变量
%%ai ollama:qwen2.5-coder:7b-q4
优化这段递归代码，避免重复计算：
{code}
2.15 多轮对话
python
# 第一轮：设定角色
%%ai ollama:qwen2.5-coder:7b-q4
你是一个Python专家，请用中文回答我的问题

# 第二轮：提问
%%ai ollama:qwen2.5-coder:7b-q4
什么是生成器？

# 第三轮：深入
%%ai ollama:qwen2.5-coder:7b-q4
生成器和列表推导式有什么区别？

# 第四轮：举例
%%ai ollama:qwen2.5-coder:7b-q4
给我一个使用生成器读取大文件的例子
2.16 查看可用模型
python
# 列出所有可用模型
%ai list

# 输出示例：
# | Provider | Models |
# |----------|--------|
# | ollama | qwen2.5-coder:7b-q4, llama3:latest, ... |
# | openai-chat | gpt-4, gpt-3.5-turbo, ... |
2.17 配置默认模型
python
# 在IPython启动脚本中已配置默认模型
# 可以直接使用模型名称，无需每次指定

# 查看当前默认配置
import os
print(f"默认模型: {os.environ.get('OLLAMA_DEFAULT_MODEL')}")
2.18 聊天界面
Jupyter AI 还提供了侧边栏聊天界面：

点击 JupyterLab 左侧的 🤖 图标

选择模型提供商和模型

在输入框中输入问题

AI 会在聊天界面中回复

3. 已安装工具及使用方法
3.1 NumPy
数值计算基础库。

python
import numpy as np

# 创建数组
arr = np.array([1, 2, 3, 4, 5])
zeros = np.zeros((3, 4))
ones = np.ones((2, 3))
random_arr = np.random.randn(100)

# 数组运算
print(arr.mean())      # 平均值: 3.0
print(arr.std())       # 标准差: 1.41
print(arr.sum())       # 求和: 15
print(arr.max())       # 最大值: 5
print(arr.argmax())    # 最大值索引: 4

# 索引和切片
print(arr[0])          # 第一个元素
print(arr[1:3])        # 切片
print(arr[arr > 2])    # 布尔索引

# 形状操作
arr_2d = arr.reshape(5, 1)
print(arr_2d.shape)    # (5, 1)

# 矩阵运算
matrix = np.random.randn(3, 3)
print(matrix @ matrix.T)           # 矩阵乘法
print(np.linalg.inv(matrix))       # 逆矩阵
print(np.linalg.det(matrix))       # 行列式
3.2 Pandas
数据分析核心库。

python
import pandas as pd

# 创建DataFrame
df = pd.DataFrame({
    'name': ['张三', '李四', '王五', '赵六'],
    'age': [25, 30, 28, 35],
    'salary': [8000, 12000, 10000, 15000],
    'department': ['技术', '销售', '技术', '销售']
})

# 查看数据
print(df.head())           # 前5行
print(df.tail(2))          # 后2行
print(df.info())           # 数据信息
print(df.describe())       # 统计描述

# 数据筛选
print(df[df['age'] > 28])                    # 条件筛选
print(df[df['department'] == '技术'])        # 等于筛选
print(df[(df['age'] > 25) & (df['salary'] > 9000)])  # 多条件

# 数据操作
df['bonus'] = df['salary'] * 0.1             # 新增列
df = df.drop('bonus', axis=1)                # 删除列
df.rename(columns={'name': '姓名'}, inplace=True)  # 重命名

# 分组聚合
print(df.groupby('department')['salary'].mean())   # 分组平均值
print(df.groupby('department').agg({               # 多聚合
    'salary': ['mean', 'max', 'min'],
    'age': 'mean'
}))

# 排序
print(df.sort_values('salary', ascending=False))   # 降序排序

# 缺失值处理
df.loc[1, 'age'] = None
print(df.isnull().sum())          # 统计缺失值
df['age'] = df['age'].fillna(df['age'].mean())  # 填充缺失值

# 读写文件
df.to_csv('data.csv', index=False)
df.to_excel('data.xlsx', index=False)
df_read = pd.read_csv('data.csv')
3.3 Matplotlib
数据可视化基础库。

python
import matplotlib.pyplot as plt
import numpy as np

# 折线图
x = np.linspace(0, 10, 100)
y1 = np.sin(x)
y2 = np.cos(x)

plt.figure(figsize=(10, 6))
plt.plot(x, y1, label='sin(x)', linewidth=2, color='blue')
plt.plot(x, y2, label='cos(x)', linewidth=2, color='red', linestyle='--')
plt.xlabel('x', fontsize=12)
plt.ylabel('y', fontsize=12)
plt.title('正弦和余弦曲线', fontsize=14)
plt.legend()
plt.grid(True, alpha=0.3)
plt.show()

# 散点图
x = np.random.randn(200)
y = np.random.randn(200)
colors = np.random.randn(200)
sizes = np.random.randint(20, 200, 200)

plt.figure(figsize=(10, 6))
plt.scatter(x, y, c=colors, s=sizes, alpha=0.5, cmap='viridis')
plt.colorbar(label='颜色值')
plt.xlabel('X')
plt.ylabel('Y')
plt.title('散点图')
plt.show()

# 柱状图
categories = ['A', 'B', 'C', 'D', 'E']
values = [23, 45, 56, 78, 34]
errors = [2, 3, 4, 5, 2]

plt.figure(figsize=(10, 6))
plt.bar(categories, values, yerr=errors, capsize=5, 
        color=['#FF6B6B', '#4ECDC4', '#45B7D1', '#96CEB4', '#FFEAA7'])
plt.xlabel('类别')
plt.ylabel('数值')
plt.title('柱状图')
plt.show()

# 直方图
data = np.random.randn(1000)

plt.figure(figsize=(10, 6))
plt.hist(data, bins=30, edgecolor='black', alpha=0.7, color='skyblue')
plt.xlabel('值')
plt.ylabel('频数')
plt.title('直方图')
plt.axvline(data.mean(), color='red', linestyle='--', label=f'均值: {data.mean():.2f}')
plt.legend()
plt.show()

# 饼图
sizes = [30, 25, 20, 15, 10]
labels = ['Python', 'Java', 'C++', 'JavaScript', 'Go']
explode = (0.1, 0, 0, 0, 0)

plt.figure(figsize=(8, 8))
plt.pie(sizes, explode=explode, labels=labels, autopct='%1.1f%%',
        shadow=True, startangle=90)
plt.title('编程语言使用比例')
plt.show()

# 子图布局
fig, axes = plt.subplots(2, 2, figsize=(12, 10))

axes[0, 0].plot(x, np.sin(x))
axes[0, 0].set_title('折线图')

axes[0, 1].scatter(x[:100], y[:100])
axes[0, 1].set_title('散点图')

axes[1, 0].bar(categories, values)
axes[1, 0].set_title('柱状图')

axes[1, 1].hist(data, bins=30)
axes[1, 1].set_title('直方图')

plt.tight_layout()
plt.show()
3.4 Seaborn
统计可视化库。

python
import seaborn as sns
import pandas as pd
import numpy as np

# 设置样式
sns.set_style('whitegrid')
sns.set_palette('husl')

# 热力图
data = np.random.randn(10, 10)
plt.figure(figsize=(10, 8))
sns.heatmap(data, annot=True, cmap='coolwarm', center=0,
            square=True, linewidths=1, cbar_kws={'shrink': 0.8})
plt.title('热力图')
plt.show()

# 分布图
data = np.random.randn(1000)
plt.figure(figsize=(10, 6))
sns.histplot(data, bins=30, kde=True, color='blue', stat='density')
plt.title('分布图')
plt.show()

# 箱线图
df = pd.DataFrame({
    'group': np.repeat(['A', 'B', 'C', 'D'], 100),
    'value': np.concatenate([
        np.random.randn(100),
        np.random.randn(100) + 1,
        np.random.randn(100) + 2,
        np.random.randn(100) + 3
    ])
})

plt.figure(figsize=(10, 6))
sns.boxplot(x='group', y='value', data=df, palette='Set3')
plt.title('箱线图')
plt.show()

# 小提琴图
plt.figure(figsize=(10, 6))
sns.violinplot(x='group', y='value', data=df, palette='muted')
plt.title('小提琴图')
plt.show()

# 散点图加回归线
df_scatter = pd.DataFrame({
    'x': np.random.randn(200),
    'y': np.random.randn(200) * 0.5 + np.random.randn(200) * 0.5
})

plt.figure(figsize=(10, 6))
sns.regplot(x='x', y='y', data=df_scatter, scatter_kws={'alpha': 0.5}, line_kws={'color': 'red'})
plt.title('散点图加回归线')
plt.show()

# 分类散点图
plt.figure(figsize=(10, 6))
sns.catplot(x='group', y='value', data=df, kind='swarm', height=6, aspect=1.5)
plt.title('分类散点图')
plt.show()
3.5 Scikit-learn
机器学习库。

python
from sklearn.ensemble import RandomForestClassifier, RandomForestRegressor
from sklearn.linear_model import LogisticRegression, LinearRegression
from sklearn.model_selection import train_test_split, cross_val_score, GridSearchCV
from sklearn.preprocessing import StandardScaler, MinMaxScaler
from sklearn.metrics import accuracy_score, confusion_matrix, classification_report
from sklearn.cluster import KMeans
import numpy as np

# 分类任务
X = np.random.randn(200, 5)
y = (X[:, 0] + X[:, 1] > 0).astype(int)

X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42)

scaler = StandardScaler()
X_train = scaler.fit_transform(X_train)
X_test = scaler.transform(X_test)

clf = RandomForestClassifier(n_estimators=100, random_state=42)
clf.fit(X_train, y_train)

y_pred = clf.predict(X_test)
print(f'准确率: {accuracy_score(y_test, y_pred)}')
print(confusion_matrix(y_test, y_pred))
print(classification_report(y_test, y_pred))

# 交叉验证
scores = cross_val_score(clf, X, y, cv=5)
print(f'交叉验证得分: {scores.mean():.3f} (+/- {scores.std() * 2:.3f})')

# 超参数调优
param_grid = {
    'n_estimators': [50, 100, 200],
    'max_depth': [None, 10, 20],
    'min_samples_split': [2, 5, 10]
}

grid_search = GridSearchCV(RandomForestClassifier(random_state=42), param_grid, cv=5)
grid_search.fit(X_train, y_train)
print(f'最佳参数: {grid_search.best_params_}')
print(f'最佳得分: {grid_search.best_score_}')

# 回归任务
X_reg = np.random.randn(200, 3)
y_reg = X_reg[:, 0] * 2 + X_reg[:, 1] * 1.5 + np.random.randn(200) * 0.1

reg = LinearRegression()
reg.fit(X_reg, y_reg)
print(f'R²分数: {reg.score(X_reg, y_reg)}')
print(f'系数: {reg.coef_}')
print(f'截距: {reg.intercept_}')

# 聚类任务
X_cluster = np.random.randn(300, 2)
X_cluster[:100] += 3
X_cluster[100:200] -= 2

kmeans = KMeans(n_clusters=3, random_state=42)
labels = kmeans.fit_predict(X_cluster)
print(f'聚类中心: {kmeans.cluster_centers_}')
print(f'聚类标签分布: {np.bincount(labels)}')
3.6 PyTorch
深度学习框架。

python
import torch
import torch.nn as nn
import torch.optim as optim
from torch.utils.data import DataLoader, TensorDataset

# 创建张量
x = torch.tensor([1, 2, 3, 4, 5], dtype=torch.float32)
print(f'张量: {x}')
print(f'设备: {x.device}')
print(f'类型: {x.dtype}')

# GPU支持
if torch.cuda.is_available():
    x_cuda = x.to('cuda')
    print(f'已移至GPU: {x_cuda.device}')

# 定义神经网络
class NeuralNetwork(nn.Module):
    def __init__(self, input_size, hidden_size, output_size):
        super().__init__()
        self.fc1 = nn.Linear(input_size, hidden_size)
        self.fc2 = nn.Linear(hidden_size, hidden_size)
        self.fc3 = nn.Linear(hidden_size, output_size)
        self.relu = nn.ReLU()
        self.dropout = nn.Dropout(0.2)
    
    def forward(self, x):
        x = self.relu(self.fc1(x))
        x = self.dropout(x)
        x = self.relu(self.fc2(x))
        x = self.dropout(x)
        x = self.fc3(x)
        return x

# 创建模型
model = NeuralNetwork(10, 64, 2)
print(model)

# 定义损失函数和优化器
criterion = nn.CrossEntropyLoss()
optimizer = optim.Adam(model.parameters(), lr=0.001)

# 准备数据
X = torch.randn(1000, 10)
y = torch.randint(0, 2, (1000,))

dataset = TensorDataset(X, y)
dataloader = DataLoader(dataset, batch_size=32, shuffle=True)

# 训练循环
num_epochs = 50
for epoch in range(num_epochs):
    total_loss = 0
    for batch_X, batch_y in dataloader:
        optimizer.zero_grad()
        outputs = model(batch_X)
        loss = criterion(outputs, batch_y)
        loss.backward()
        optimizer.step()
        total_loss += loss.item()
    
    if (epoch + 1) % 10 == 0:
        print(f'Epoch [{epoch+1}/{num_epochs}], Loss: {total_loss/len(dataloader):.4f}')

# 模型评估
model.eval()
with torch.no_grad():
    predictions = model(X[:10])
    predicted_classes = torch.argmax(predictions, dim=1)
    print(f'预测结果: {predicted_classes}')
3.7 LangChain
LLM应用开发框架。

python
from langchain.llms import Ollama
from langchain.chains import LLMChain, ConversationChain
from langchain.prompts import PromptTemplate
from langchain.memory import ConversationBufferMemory
from langchain.document_loaders import TextLoader
from langchain.text_splitter import CharacterTextSplitter
from langchain.embeddings import OllamaEmbeddings
from langchain.vectorstores import Chroma
from langchain.chains import RetrievalQA

# 创建Ollama实例
llm = Ollama(
    model="qwen2.5-coder:7b-q4",
    base_url="http://192.168.112.136:11434",
    temperature=0.7,
    top_p=0.9
)

# 简单调用
response = llm.invoke("什么是Python装饰器？")
print(response)

# 使用提示模板
prompt = PromptTemplate(
    input_variables=["code"],
    template="""请解释以下Python代码：
    
{code}

请说明：
1. 代码的功能
2. 时间复杂度
3. 可能的改进建议
"""
)

chain = LLMChain(llm=llm, prompt=prompt)
result = chain.run(code="def fib(n): return n if n<=1 else fib(n-1)+fib(n-2)")
print(result)

# 带记忆的对话
memory = ConversationBufferMemory()
conversation = ConversationChain(llm=llm, memory=memory)

print(conversation.predict(input="你好，我叫小明"))
print(conversation.predict(input="我叫什么名字？"))
print(conversation.predict(input="用Python实现快速排序"))

# RAG应用
# 加载文档
loader = TextLoader('document.txt')
documents = loader.load()

# 分割文本
text_splitter = CharacterTextSplitter(chunk_size=1000, chunk_overlap=0)
texts = text_splitter.split_documents(documents)

# 创建向量存储
embeddings = OllamaEmbeddings(
    model="qwen2.5-coder:7b-q4",
    base_url="http://192.168.112.136:11434"
)
vectorstore = Chroma.from_documents(texts, embeddings)

# 创建问答链
qa_chain = RetrievalQA.from_chain_type(
    llm=llm,
    chain_type="stuff",
    retriever=vectorstore.as_retriever()
)

# 提问
answer = qa_chain.run("文档中提到了什么重要信息？")
print(answer)
3.8 其他工具
python
# Transformers - 预训练模型
from transformers import pipeline, AutoTokenizer, AutoModel

# 情感分析
sentiment = pipeline('sentiment-analysis')
result = sentiment("I love programming!")
print(result)

# 文本生成
generator = pipeline('text-generation', model='gpt2')
result = generator("The future of AI is", max_length=50)
print(result)

# ChromaDB - 向量数据库
import chromadb
client = chromadb.Client()
collection = client.create_collection("my_docs")
collection.add(
    documents=["文档1", "文档2", "文档3"],
    ids=["id1", "id2", "id3"]
)
results = collection.query(query_texts=["查询"], n_results=2)
print(results)

# Plotly - 交互式可视化
import plotly.express as px
df = px.data.iris()
fig = px.scatter(df, x='sepal_width', y='sepal_length', color='species')
fig.show()
4. 快速开始
第一步：加载Jupyter AI扩展
python
%load_ext jupyter_ai_magics
第二步：使用AI对话
python
%%ai ollama:qwen2.5-coder:7b-q4
用Python实现一个快速排序算法
第三步：验证配置
python
import os
print("OLLAMA_HOST:", os.environ.get('OLLAMA_HOST'))
print("默认模型:", os.environ.get('OLLAMA_DEFAULT_MODEL'))

%%ai ollama:qwen2.5-coder:7b-q4
ping
5. 使用外部AI服务
设置API Keys
python
import os
os.environ['OPENAI_API_KEY'] = 'sk-your-openai-key'
os.environ['ANTHROPIC_API_KEY'] = 'sk-ant-your-key'
%reload_ext jupyter_ai_magics
调用示例
python
%%ai openai-chat:gpt-4
解释什么是闭包

%%ai anthropic-chat:claude-3-5-sonnet-20241022
用Python实现Web爬虫
6. 高级用法
传递变量给AI
python
code = "def add(a,b): return a+b"
%%ai ollama:qwen2.5-coder:7b-q4
优化这段代码：{code}
多轮对话
python
%%ai ollama:qwen2.5-coder:7b-q4
你是一个Python专家
%%ai ollama:qwen2.5-coder:7b-q4
什么是装饰器？
%%ai ollama:qwen2.5-coder:7b-q4
给我一个实际例子
指定模型参数
python
%%ai ollama:qwen2.5-coder:7b-q4 --temperature 0.5 --max-tokens 1000
用JSON格式列出5种设计模式
7. 常见问题排查
问题1：%%ai not found
python
%load_ext jupyter_ai_magics
问题2：Connection refused
python
import os
os.environ['OLLAMA_HOST'] = 'http://192.168.112.136:11434'
%reload_ext jupyter_ai_magics
问题3：查看可用模型
python
%ai list
8. 性能优化建议
任务类型	推荐模型	说明
简单代码生成	qwen2.5-coder:1.5b	快速响应
复杂代码分析	qwen2.5-coder:7b	平衡性能
大规模审查	qwen2.5-coder:14b	更准确
启用缓存
python
from langchain.cache import InMemoryCache
from langchain.globals import set_llm_cache
set_llm_cache(InMemoryCache())
9. 注意事项
首次调用模型需加载到内存，有延迟

外部API需要互联网连接和费用

Ollama本地模型完全免费

不要硬编码API Key，使用环境变量

每个Notebook只需加载一次扩展

10. 相关资源
Jupyter AI: https://jupyter-ai.readthedocs.io/

Ollama: https://ollama.com/library

LangChain: https://python.langchain.com/

PyTorch: https://pytorch.org/

TensorFlow: https://tensorflow.org/
EOF