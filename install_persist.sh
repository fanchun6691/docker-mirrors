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
    jupyter-ai>=2.0.0 \
    jupyter-ai-magics>=2.0.0 \
    ipykernel>=6.0.0 \
    ipywidgets>=8.0.0 

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
c.FileCheckpoints.checkpoint_dir = ''
c.FileContentsManager.checkpoints_kwargs = {'checkpoint_dir': None}

# Jupyter AI 配置
c.JupyterAI.model_provider_id = 'ollama'
c.JupyterAI.model_id = '${OLLAMA_DEFAULT_MODEL}'
c.JupyterOllama.base_url = '${OLLAMA_EXTERNAL_URL}'
c.JupyterOllama.default_model = '${OLLAMA_DEFAULT_MODEL}'

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

echo "🧹 清理缓存..."
pip cache purge
conda clean -afy
rm -rf /home/jovyan/.cache/pip
rm -rf /home/jovyan/.cache/conda

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
echo "  - Base 环境: JupyterLab 4 (预装)"
echo "  - AI 环境: Python 包 + Jupyter AI 扩展"
echo "  - Ollama: ${OLLAMA_EXTERNAL_URL}"
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

1. [环境配置](#环境配置)
2. [快速开始](#快速开始)
3. [使用外部 AI 服务](#使用外部-ai-服务)
4. [高级用法](#高级用法)
5. [常见问题排查](#常见问题排查)
6. [性能优化建议](#性能优化建议)
7. [注意事项](#注意事项)
8. [相关资源](#相关资源)

---

## 环境配置

### 默认配置

- **Ollama 服务器**: `http://192.168.112.136:11434`
- **默认模型**: `qwen2.5-coder:7b-q4`
- **模型特点**: 代码生成、代码解释、代码优化专用模型

### 支持的 AI 服务

| 服务 | Provider ID | 所需环境变量 | 调用示例 |
|------|-------------|--------------|----------|
| **Ollama（本地）** | `ollama` | `OLLAMA_HOST` | `%%ai ollama:qwen2.5-coder:7b-q4` |
| **OpenAI** | `openai-chat` | `OPENAI_API_KEY` | `%%ai openai-chat:gpt-4` |
| **Anthropic Claude** | `anthropic-chat` | `ANTHROPIC_API_KEY` | `%%ai anthropic-chat:claude-3-5-sonnet-20241022` |
| **Google Gemini** | `gemini` | `GOOGLE_API_KEY` | `%%ai gemini:gemini-1.5-pro` |
| **Hugging Face** | `huggingface_hub` | `HUGGINGFACEHUB_API_TOKEN` | `%%ai huggingface_hub:meta-llama/Llama-2-7b-chat-hf` |
| **Cohere** | `cohere` | `COHERE_API_KEY` | `%%ai cohere:command` |
| **AI21 Labs** | `ai21` | `AI21_API_KEY` | `%%ai ai21:j2-grande` |
| **AWS Bedrock** | `bedrock` | AWS 凭证 | `%%ai bedrock:anthropic.claude-3-sonnet-20240229-v1:0` |
| **Azure OpenAI** | `azure-chat-openai` | `AZURE_OPENAI_API_KEY` 等 | `%%ai azure-chat-openai:deployment-name` |

---

## 快速开始

### 第一步：加载 Jupyter AI 扩展

在 Notebook 的**第一个代码单元格**中执行：

```python
%load_ext jupyter_ai_magics
```

如果显示 `The jupyter_ai_magics extension is already loaded`，说明扩展已自动加载，可以跳过此步骤。

> **注意**：每个 Notebook 只需要加载一次扩展，后续单元格可直接使用 `%%ai` 命令。

### 第二步：使用 `%%ai` 魔法命令进行 AI 对话

```python
# 代码生成
%%ai ollama:qwen2.5-coder:7b-q4
用 Python 实现一个快速排序算法

# 代码解释
%%ai ollama:qwen2.5-coder:7b-q4
解释这段代码的作用：
def fibonacci(n):
    return n if n <= 1 else fibonacci(n-1) + fibonacci(n-2)

# 代码优化
%%ai ollama:qwen2.5-coder:7b-q4
优化这个 Python 函数，提高性能：
def find_duplicates(arr):
    result = []
    for i in range(len(arr)):
        for j in range(i+1, len(arr)):
            if arr[i] == arr[j] and arr[i] not in result:
                result.append(arr[i])
    return result

# 代码调试
%%ai ollama:qwen2.5-coder:7b-q4
这段代码有什么问题？如何修复？
def divide_list(lst, n):
    return [lst[i:i+n] for i in range(0, len(lst), n)]
```

### 第三步：验证配置是否生效

```python
import os
print("OLLAMA_HOST:", os.environ.get('OLLAMA_HOST'))
print("OLLAMA_BASE_URL:", os.environ.get('OLLAMA_BASE_URL'))
print("默认模型:", os.environ.get('OLLAMA_DEFAULT_MODEL'))

# 测试连接
%%ai ollama:qwen2.5-coder:7b-q4
ping
```

---

## 使用外部 AI 服务

### 设置 API Keys

#### 方式一：在 Notebook 中动态设置

```python
import os

# 设置 API Keys
os.environ['OPENAI_API_KEY'] = 'sk-your-openai-key'
os.environ['ANTHROPIC_API_KEY'] = 'sk-ant-your-key'
os.environ['GOOGLE_API_KEY'] = 'your-google-key'
os.environ['HUGGINGFACEHUB_API_TOKEN'] = 'hf_your-token'

# 重新加载扩展使环境变量生效
%reload_ext jupyter_ai_magics
```

### 调用示例

```python
# OpenAI GPT-4
%%ai openai-chat:gpt-4
解释什么是闭包，并给出 Python 示例

# Anthropic Claude
%%ai anthropic-chat:claude-3-5-sonnet-20241022
用 Python 实现一个简单的 Web 爬虫

# Google Gemini
%%ai gemini:gemini-1.5-pro
解释量子计算的基本原理

# Hugging Face 开源模型
%%ai huggingface_hub:meta-llama/Llama-2-7b-chat-hf
Write a hello world in Rust

# Cohere
%%ai cohere:command
解释什么是向量数据库

# 本地 LM Studio（通过 OpenAI 兼容 API）
%%ai openai-chat:local-model
解释什么是 Docker
```

### 查看所有可用的 AI 模型

```python
%load_ext jupyter_ai_magics
%ai list
```

---

## 高级用法

### 1. 传递变量给 AI

```python
code = """
def bubble_sort(arr):
    n = len(arr)
    for i in range(n):
        for j in range(0, n-i-1):
            if arr[j] > arr[j+1]:
                arr[j], arr[j+1] = arr[j+1], arr[j]
    return arr
"""

%%ai ollama:qwen2.5-coder:7b-q4
优化这段排序算法：
{code}
```

### 2. 多轮对话

```python
# 第一轮：设定角色
%%ai ollama:qwen2.5-coder:7b-q4
你是一个 Python 专家，我会问你一些编程问题

# 第二轮：提出问题
%%ai ollama:qwen2.5-coder:7b-q4
什么是装饰器？

# 第三轮：请求示例
%%ai ollama:qwen2.5-coder:7b-q4
请给我一个实际的装饰器例子

# 第四轮：深入探讨
%%ai ollama:qwen2.5-coder:7b-q4
装饰器在 Flask 框架中是如何使用的？
```

### 3. 指定模型参数

```python
# 指定输出格式和模型参数
%%ai ollama:qwen2.5-coder:7b-q4 --format json --temperature 0.5 --max-tokens 1000
用 JSON 格式列出 5 种常见的设计模式，每个设计模式包含名称、描述和适用场景

# 使用 Claude 并指定参数
%%ai anthropic-chat:claude-3-5-sonnet-20241022 --temperature 0.7 --max-tokens 2000
分析这段代码的时间复杂度：{code}
```

### 4. 批量处理问题

```python
questions = [
    "什么是 Python 中的 GIL？",
    "解释一下异步编程",
    "列表和元组的区别是什么"
]

for q in questions:
    print(f"问题: {q}")
    print("回答:")
    get_ipython().run_cell_magic('ai', 'ollama:qwen2.5-coder:7b-q4', q)
    print("-" * 50)
```

### 5. 代码审查助手

```python
def review_code(code_snippet):
    """使用 AI 审查代码"""
    return get_ipython().run_cell_magic(
        'ai', 'ollama:qwen2.5-coder:7b-q4',
        f"""
请审查以下代码，指出：
1. 潜在的错误
2. 性能问题
3. 代码风格问题
4. 改进建议

代码：
{code_snippet}
"""
    )

# 使用示例
my_code = """
def process_data(data):
    result = []
    for i in range(len(data)):
        if data[i] > 0:
            result.append(data[i] * 2)
    return result
"""

review_code(my_code)
```

### 6. 文档生成器

```python
def generate_docstring(function_code):
    """使用 AI 生成函数文档"""
    return get_ipython().run_cell_magic(
        'ai', 'ollama:qwen2.5-coder:7b-q4',
        f"""
为以下函数生成详细的 docstring，包括：
- 函数描述
- 参数说明（类型和含义）
- 返回值说明
- 使用示例

函数代码：
{function_code}
"""
    )

# 使用示例
code = """
def calculate_interest(principal, rate, time):
    return principal * (1 + rate) ** time - principal
"""

print(generate_docstring(code))
```

### 7. 单元测试生成器

```python
def generate_unit_test(function_code):
    """使用 AI 生成单元测试"""
    return get_ipython().run_cell_magic(
        'ai', 'ollama:qwen2.5-coder:7b-q4',
        f"""
为以下函数生成 Python 单元测试（使用 unittest 框架）：
- 覆盖正常情况
- 覆盖边界条件
- 覆盖异常情况

函数代码：
{function_code}
"""
    )

# 使用示例
code = """
def divide(a, b):
    if b == 0:
        raise ValueError("除数不能为零")
    return a / b
"""

print(generate_unit_test(code))
```

### 8. 完整示例工作流

```python
# 1. 加载扩展
%load_ext jupyter_ai_magics

# 2. 设置环境变量（使用外部服务时）
import os
os.environ['OPENAI_API_KEY'] = 'sk-xxx'  # 可选
os.environ['ANTHROPIC_API_KEY'] = 'sk-ant-xxx'  # 可选

# 3. 验证 Ollama 连接
%%ai ollama:qwen2.5-coder:7b-q4
ping

# 4. 开始使用
%%ai ollama:qwen2.5-coder:7b-q4
用 Python 实现一个单例模式

# 5. 继续对话
%%ai ollama:qwen2.5-coder:7b-q4
请解释你的实现，并说明单例模式的优缺点

# 6. 测试外部服务（如果配置了 API Key）
%%ai openai-chat:gpt-4
用一句话总结单例模式的最佳实践

# 7. 生成文档
%%ai ollama:qwen2.5-coder:7b-q4
为以下函数生成详细的 docstring：
def calculate_interest(principal, rate, time):
    return principal * (1 + rate) ** time - principal
```

---

## 常见问题排查

### 问题1：`UsageError: Line magic function '%%ai' not found`

**原因**：Jupyter AI 扩展未加载

**解决方案**：

```python
# 确保已加载扩展
%load_ext jupyter_ai_magics

# 如果仍然报错，尝试重新加载
%reload_ext jupyter_ai_magics

# 或加载完整的 jupyter_ai 扩展
%load_ext jupyter_ai

# 检查是否安装成功
pip list | grep jupyter-ai
```

### 问题2：`ConnectError: [Errno 111] Connection refused`

**原因**：Ollama 服务连接失败

**解决方案**：

```python
# 步骤1：检查环境变量
import os
print("OLLAMA_HOST:", os.environ.get('OLLAMA_HOST'))
print("OLLAMA_BASE_URL:", os.environ.get('OLLAMA_BASE_URL'))

# 步骤2：手动设置环境变量
os.environ['OLLAMA_HOST'] = 'http://192.168.112.136:11434'
os.environ['OLLAMA_BASE_URL'] = 'http://192.168.112.136:11434'

# 步骤3：重新加载扩展
%reload_ext jupyter_ai_magics

# 步骤4：测试连接
%%ai ollama:qwen2.5-coder:7b-q4
ping
```

**在容器外部检查**：

```bash
# 检查 Ollama 服务是否运行
curl http://192.168.112.136:11434/api/tags

# 如果无法连接，检查网络
ping 192.168.112.136

# 检查端口是否开放
telnet 192.168.112.136 11434
```

### 问题3：API Key 无效或未设置

**原因**：使用外部服务时未配置 API Key

**解决方案**：

```python
# 步骤1：检查环境变量
import os

api_keys = {
    'OPENAI_API_KEY': os.environ.get('OPENAI_API_KEY', 'Not set'),
    'ANTHROPIC_API_KEY': os.environ.get('ANTHROPIC_API_KEY', 'Not set'),
    'GOOGLE_API_KEY': os.environ.get('GOOGLE_API_KEY', 'Not set'),
}

for key, value in api_keys.items():
    if value and value != 'Not set':
        display_value = value[:20] + '...' if len(value) > 20 else value
        print(f"✅ {key}: {display_value}")
    else:
        print(f"❌ {key}: 未设置")

# 步骤2：手动设置
os.environ['OPENAI_API_KEY'] = 'your-actual-key'

# 步骤3：重新加载扩展
%reload_ext jupyter_ai_magics

# 步骤4：验证
%%ai openai-chat:gpt-3.5-turbo
ping
```

### 问题4：`Model not found` 错误

**原因**：指定的模型不存在

**解决方案**：

```python
# 步骤1：查看可用的 Ollama 模型
import requests

try:
    response = requests.get('http://192.168.112.136:11434/api/tags')
    print("可用的 Ollama 模型:")
    for model in response.json().get('models', []):
        print(f"  - {model['name']}")
except Exception as e:
    print(f"无法获取模型列表: {e}")

# 步骤2：查看所有 Jupyter AI 可用的模型
%load_ext jupyter_ai_magics
%ai list

# 步骤3：拉取需要的模型（如果使用 Ollama）
# 在终端执行：docker exec jupyter-ai ollama pull model-name
```

### 问题5：内存不足错误

**原因**：模型太大或同时加载多个模型

**解决方案**：

```bash
# 在容器中查看内存使用
docker exec jupyter-ai free -h

# 卸载不需要的 Ollama 模型
docker exec jupyter-ai ollama rm model-name

# 使用更小的模型
# 在 Dockerfile 中修改 OLLAMA_DEFAULT_MODEL
# 例如：qwen2.5-coder:1.5b-q4 或 llama3.2:3b
```

### 问题6：扩展加载但魔法命令不工作

**解决方案**：

```python
# 步骤1：检查扩展是否正确加载
%load_ext jupyter_ai_magics

# 步骤2：查看扩展状态
import sys
print("已加载的扩展:", sys.modules.get('jupyter_ai_magics'))

# 步骤3：重启 kernel（Jupyter 菜单 → Kernel → Restart）
# 然后重新执行加载命令

# 步骤4：检查版本兼容性
pip show jupyter-ai-magics
pip show jupyter-ai
```

### 问题7：响应速度慢

**解决方案**：

```python
# 使用更小的模型
%%ai ollama:qwen2.5-coder:1.5b-q4
你的问题

# 减少 max_tokens
%%ai ollama:qwen2.5-coder:7b-q4 --max-tokens 500
你的问题

# 对于 Ollama，确保使用量化版本
# qwen2.5-coder:7b-q4 比 qwen2.5-coder:7b 更快
```

### 调试技巧

```python
# 1. 启用详细日志
import logging
logging.basicConfig(level=logging.DEBUG)

# 2. 检查环境变量
import os
for key in ['OLLAMA_HOST', 'OPENAI_API_KEY', 'ANTHROPIC_API_KEY']:
    print(f"{key}: {os.environ.get(key, 'Not set')[:50]}")

# 3. 测试原始 API 调用
import requests
response = requests.post(
    'http://192.168.112.136:11434/api/generate',
    json={"model": "qwen2.5-coder:7b-q4", "prompt": "ping", "stream": False}
)
print(response.json())

# 4. 查看容器日志
# 在终端执行：docker logs jupyter-ai
```

---

## 性能优化建议

### 1. 选择合适的模型

| 任务类型 | 推荐模型 | 说明 |
|---------|---------|------|
| 简单代码生成 | `qwen2.5-coder:1.5b` | 快速响应，资源占用少 |
| 复杂代码分析 | `qwen2.5-coder:7b` | 默认配置，平衡性能 |
| 大规模代码审查 | `qwen2.5-coder:14b` | 更准确但需要更多内存 |
| 通用问答 | `llama3.2:3b` | 轻量级通用模型 |
| 复杂推理 | `qwen2.5:14b` | 最强能力但资源要求高 |

### 2. 启用缓存机制

```python
# LangChain 缓存
from langchain.cache import InMemoryCache
from langchain.globals import set_llm_cache
set_llm_cache(InMemoryCache())

# 或在 Jupyter AI 中复用会话
```

### 3. 批量处理优化

```python
# 使用列表推导批量处理
codes = [code1, code2, code3]
reviews = [
    get_ipython().run_cell_magic(
        'ai', 'ollama:qwen2.5-coder:7b-q4', 
        f"审查代码：\n{code}"
    ) 
    for code in codes
]
```

### 4. 模型量化

- 使用 `q4` 量化版本（如 `qwen2.5-coder:7b-q4`）可以获得 4 倍速度提升
- 量化版本已配置为默认选项

### 5. 资源限制设置

```python
# 在 %%ai 命令中限制输出长度
%%ai ollama:qwen2.5-coder:7b-q4 --max-tokens 500
请简要回答
```

### 6. 并发请求控制

```python
# 使用信号量控制并发
import asyncio
from asyncio import Semaphore

sem = Semaphore(3)  # 最多 3 个并发请求

async def call_ai(prompt):
    async with sem:
        return await some_ai_function(prompt)
```

---

## 注意事项

### 重要提醒

- **首次使用**：如果是第一次使用某个模型，可能需要等待模型加载到内存（Ollama 模型首次调用会有延迟）
- **网络要求**：使用外部 API（OpenAI、Claude 等）需要互联网连接
- **费用注意**：OpenAI、Anthropic 等云服务是收费的，请留意 API 使用量
- **本地模型**：Ollama 部署的模型完全免费，适合日常开发和测试
- **扩展加载**：每个 Notebook 只需要加载一次扩展，后续单元格可直接使用 `%%ai` 命令
- **环境变量优先级**：Docker 运行时注入 > .env 文件 > Notebook 动态设置

### 安全提示

- **不要在代码中硬编码 API Keys**，使用环境变量或 .env 文件
- **定期轮换 API Keys**，提高安全性
- **使用专用 API Key**，限制权限范围
- **谨慎处理敏感数据**，避免发送到外部 API

### 资源限制

- 同时加载多个大模型可能导致内存不足
- 建议根据实际需求选择合适的模型
- 使用 `free -h` 监控内存使用情况
- 考虑使用 CPU 版本的深度学习框架（已配置）

### 最佳实践

1. **明确需求**：选择适合任务的模型
2. **测试先行**：先用简单 prompt 测试连通性
3. **渐进优化**：从默认设置开始，逐步调整参数
4. **缓存结果**：对重复性任务启用缓存
5. **监控成本**：使用外部 API 时设置预算限制
6. **版本控制**：记录模型版本和参数设置

---

## 相关资源

### 官方文档

- [Jupyter AI 官方文档](https://jupyter-ai.readthedocs.io/)
- [Ollama 模型库](https://ollama.com/library)
- [LangChain 文档](https://python.langchain.com/)
- [OpenAI API 文档](https://platform.openai.com/docs)
- [Anthropic API 文档](https://docs.anthropic.com/)
- [Google Gemini 文档](https://ai.google.dev/docs)

### 模型资源

- [Qwen 系列模型介绍](https://github.com/QwenLM/Qwen)
- [Llama 系列模型](https://llama.meta.com/)
- [Hugging Face 模型库](https://huggingface.co/models)

### 社区与支持

- [Jupyter AI GitHub](https://github.com/jupyterlab/jupyter-ai)
- [Ollama GitHub](https://github.com/ollama/ollama)
- [Stack Overflow - Jupyter](https://stackoverflow.com/questions/tagged/jupyter)

---

## 获取帮助

如果遇到问题，请按以下顺序排查：

1. **检查扩展加载**
   ```python
   %load_ext jupyter_ai_magics
   ```

2. **检查环境变量**
   ```bash
   docker exec jupyter-ai env | grep -E "(OLLAMA|API_KEY)"
   ```

3. **测试 Ollama 连接**
   ```bash
   curl http://192.168.112.136:11434/api/tags
   ```

4. **查看容器日志**
   ```bash
   docker logs jupyter-ai
   ```

5. **验证网络连接**
   ```bash
   docker exec jupyter-ai curl http://192.168.112.136:11434/api/tags
   ```

### 快速命令参考

```python
# 加载扩展
%load_ext jupyter_ai_magics

# 查看可用模型
%ai list

# 使用 Ollama
%%ai ollama:qwen2.5-coder:7b-q4
你的问题

# 使用 OpenAI
%%ai openai-chat:gpt-4
你的问题

# 设置 API Key
import os
os.environ['OPENAI_API_KEY'] = 'your-key'
%reload_ext jupyter_ai_magics

# 调试信息
import os
print("OLLAMA_HOST:", os.environ.get('OLLAMA_HOST'))
```

---

**文档版本**: 1.0  
**最后更新**: 2024年  
**适用于**: Jupyter-AI 镜像 v1.0
EOF