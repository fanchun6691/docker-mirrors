#!/bin/bash
# install_persist.sh - 持久化安装脚本（只在镜像构建时执行）

set -e

echo "=========================================="
echo "🔧 持久化安装 Jupyter-AI 环境"
echo "=========================================="

# 配置变量（修正 IP 和模型）
CONDA_ENV_NAME="ai_env"
PYTHON_VERSION="3.10"
OLLAMA_EXTERNAL_URL="http://192.168.112.136:11434"
OLLAMA_DEFAULT_MODEL="qwen2.5-coder:7b-q4"

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

# 创建 kernel 配置（修正 IP 和模型）
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
  "OLLAMA_BASE_URL": "${OLLAMA_EXTERNAL_URL}",
  "OLLAMA_DEFAULT_MODEL": "${OLLAMA_DEFAULT_MODEL}",
  "HF_ENDPOINT": "https://hf-mirror.com"
 }
}
EOF

# ============================================
# 配置 JupyterLab（持久化配置，修正 IP 和模型）
# ============================================
echo "⚙️ 配置 JupyterLab..."

CONFIG_DIR="/home/jovyan/.jupyter"
mkdir -p ${CONFIG_DIR}

# JupyterLab 配置
cat > ${CONFIG_DIR}/jupyter_lab_config.py << 'EOF'
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

# Jupyter AI 配置（修正 IP 和模型）
c.JupyterAI.model_provider_id = 'ollama'
c.JupyterAI.model_id = 'qwen2.5-coder:7b-q4'
c.JupyterOllama.base_url = 'http://192.168.112.136:11434'
c.JupyterOllama.default_model = 'qwen2.5-coder:7b-q4'

c.LabApp.extensions_in_dev_mode = True
EOF

# Jupyter AI JSON 配置（修正 IP 和模型）
cat > ${CONFIG_DIR}/jupyter_ai_config.json << EOF
{
  "model_provider_id": "ollama",
  "model_id": "${OLLAMA_DEFAULT_MODEL}",
  "api_keys": {},
  "model_parameters": {
    "temperature": 0.7,
    "max_tokens": 2048,
    "top_p": 0.9,
    "repeat_penalty": 1.1
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
# IPython 启动脚本（持久化，修正 IP 和模型）
# ============================================
echo "📝 配置 IPython 启动脚本..."

IPYTHON_DIR="/home/jovyan/.ipython/profile_default/startup"
mkdir -p ${IPYTHON_DIR}

cat > ${IPYTHON_DIR}/00-jupyter-ai-setup.py << EOF
# -*- coding: utf-8 -*-
"""Jupyter AI 自动配置脚本（持久化）"""

import os

# 设置环境变量（修正 IP 和模型）
os.environ.setdefault('OLLAMA_BASE_URL', '${OLLAMA_EXTERNAL_URL}')
os.environ.setdefault('OLLAMA_DEFAULT_MODEL', '${OLLAMA_DEFAULT_MODEL}')
os.environ.setdefault('HF_ENDPOINT', 'https://hf-mirror.com')

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
        print("📝 使用方法: %%ai ollama:qwen2.5-coder:7b-q4 你的问题")
        print("💡 模型特点: 代码生成与理解优化")
except Exception as e:
    print(f"⚠️ Jupyter AI 加载失败: {e}")
EOF

# ============================================
# 创建启动脚本（持久化，修正 IP 和模型）
# ============================================
# 创建启动脚本
# ============================================
echo "🚀 创建启动脚本..."

cat > /home/jovyan/start_jupyter_ai.sh << 'EOF'
#!/bin/bash

# 初始化 conda
source /opt/conda/etc/profile.d/conda.sh

# 激活 AI 环境（用于 Python 包和扩展）
conda activate ai_env

# 设置环境变量
export JUPYTER_ENABLE_LAB=yes
export OLLAMA_BASE_URL=${OLLAMA_BASE_URL:-http://192.168.112.136:11434}
export OLLAMA_DEFAULT_MODEL=${OLLAMA_DEFAULT_MODEL:-qwen2.5-coder:7b-q4}
export HF_ENDPOINT=${HF_ENDPOINT:-https://hf-mirror.com}

# 确保 JupyterLab 能找到 ai_env 的包
export PYTHONPATH="/opt/conda/envs/ai_env/lib/python3.10/site-packages:$PYTHONPATH"

echo "=========================================="
echo "🚀 启动 Jupyter-AI 服务"
echo "=========================================="
echo "JupyterLab: http://localhost:8881"
echo "Ollama 服务器: ${OLLAMA_BASE_URL}"
echo "默认模型: ${OLLAMA_DEFAULT_MODEL}"
echo "=========================================="
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
if curl -s --max-time 5 ${OLLAMA_BASE_URL} > /dev/null 2>&1; then
    echo "✅ Ollama 服务器连接成功 (${OLLAMA_BASE_URL})"
    
    # 检查模型是否可用
    if curl -s --max-time 10 ${OLLAMA_BASE_URL}/api/tags 2>/dev/null | grep -q "${OLLAMA_DEFAULT_MODEL}"; then
        echo "✅ 模型 ${OLLAMA_DEFAULT_MODEL} 已就绪"
        
        # 测试模型响应（可选，会稍微延迟启动）
        # echo "🧪 测试模型响应..."
        # curl -s -X POST ${OLLAMA_BASE_URL}/api/generate \
        #   -d "{\"model\": \"${OLLAMA_DEFAULT_MODEL}\", \"prompt\": \"ping\", \"stream\": false}" > /dev/null 2>&1 && echo "✅ 模型响应正常"
    else
        echo "⚠️  模型 ${OLLAMA_DEFAULT_MODEL} 未找到"
        echo "📋 可用模型列表:"
        curl -s ${OLLAMA_BASE_URL}/api/tags 2>/dev/null | python3 -c "
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
    echo "⚠️  无法连接到 Ollama 服务器 (${OLLAMA_BASE_URL})"
    echo "   请检查:"
    echo "   1. 服务器 192.168.112.136 是否在线"
    echo "   2. 端口 11434 是否开放"
    echo "   3. 网络连接是否正常"
fi

echo ""
echo "🎯 启动 JupyterLab..."



# 后续构建步骤（比如保存镜像、上传等）
echo "✅ JupyterLab 已后台启动，继续构建流程..."


chmod +x /home/jovyan/start_jupyter_ai.sh

# ============================================
# 创建 .env 配置文件（可被 volume 覆盖）
# ============================================
cat > /home/jovyan/.env.default << EOF
# Jupyter-AI 默认环境变量
OLLAMA_BASE_URL=${OLLAMA_EXTERNAL_URL}
OLLAMA_DEFAULT_MODEL=${OLLAMA_DEFAULT_MODEL}
HF_ENDPOINT=https://hf-mirror.com
DISABLE_LOCAL_OLLAMA=true
JUPYTER_PORT=8881

# 模型参数（可选）
OLLAMA_TEMPERATURE=0.7
OLLAMA_TOP_P=0.9
OLLAMA_REPEAT_PENALTY=1.1
EOF

# ============================================
# 创建使用说明文档
# ============================================
cat > /home/jovyan/README_JUPYTER_AI.md << 'EOF'
# Jupyter-AI 使用指南

## 环境配置

- **Ollama 服务器**: http://192.168.112.136:11434
- **默认模型**: qwen2.5-coder:7b-q4
- **模型特点**: 代码生成、代码解释、代码优化专用模型

## 快速开始

### 1. 在 Jupyter Notebook 中使用

```python
# 使用魔法命令进行 AI 对话
%%ai ollama:qwen2.5-coder:7b-q4
用 Python 实现一个快速排序算法

# 代码解释
%%ai ollama:qwen2.5-coder:7b-q4
解释这段代码的作用：
def fibonacci(n):
    return n if n <= 1 else fibonacci(n-1) + fibonacci(n-2)

# 代码优化
%%ai ollama:qwen2.5-coder:7b-q4
优化这个 Python 函数，提高性能
EOF
