#!/bin/bash
# install_persist.sh - 持久化安装脚本（只在镜像构建时执行）

set -e

echo "=========================================="
echo "🔧 持久化安装 Jupyter-AI v3.0 环境"
echo "=========================================="

# 配置变量（从环境变量读取，与 Dockerfile 保持一致）
CONDA_ENV_NAME="ai_env"
PYTHON_VERSION="3.11"
OLLAMA_EXTERNAL_URL="${OLLAMA_HOST:-http://192.168.112.136:11434}"
OLLAMA_DEFAULT_MODEL="${OLLAMA_DEFAULT_MODEL:-qwen2.5-coder:7b-q4}"
JUPYTER_PORT="${JUPYTER_PORT:-8881}"
JUPYTER_TOKEN="${JUPYTER_TOKEN:-}"
JUPYTER_PASSWORD="${JUPYTER_PASSWORD:-}"

# 初始化 conda
source /opt/conda/etc/profile.d/conda.sh

# 检查并创建环境
if conda env list | grep -q "^${CONDA_ENV_NAME} "; then
    echo "✅ Conda 环境 ${CONDA_ENV_NAME} 已存在，跳过创建"
else
    echo "📦 创建 Conda 环境: ${CONDA_ENV_NAME} (Python ${PYTHON_VERSION})"
    conda create -n ${CONDA_ENV_NAME} python=${PYTHON_VERSION} -y
fi

# ============================================
# 激活环境（后续所有命令都在此环境下执行）
# ============================================
conda activate ${CONDA_ENV_NAME}

# 升级 pip
echo "📦 升级 pip..."
pip install --upgrade pip setuptools wheel

# ============================================
# 安装 Node.js 20
# ============================================
echo "📦 安装 Node.js 20..."
conda install -n ${CONDA_ENV_NAME} -c conda-forge nodejs=20 -y
node --version

# ============================================
# 1. 安装 JupyterLab 4.x
# ============================================
echo "📦 安装 JupyterLab 4.x..."
pip install "jupyterlab>=4.0.0,<5.0.0" "jupyter_server"

# ============================================
# 2. 验证 JupyterLab 版本
# ============================================
JLAB_VERSION=$(jupyter lab --version)
echo "✅ JupyterLab 版本: ${JLAB_VERSION}"

# ============================================
# 3. 安装 Jupyter AI v3.0 核心包（关键修复）
# ============================================
echo "📦 安装 Jupyter AI v3.0..."
# ============================================
# 【关键】强制清理可能存在的旧版本
# ============================================
echo "🧹 强制清理可能存在的旧版本..."
pip uninstall jupyter-ai-litellm -y 2>/dev/null
rm -rf /opt/conda/envs/ai_env/lib/python3.11/site-packages/jupyter_ai_litellm*
pip cache purge

pip install --no-cache-dir --force-reinstall --upgrade \
  "jupyter-ai>=3.0.0" \
  "jupyter-ai-magic-commands" \
  "jupyter-ai-jupyternaut" \
  "jupyter-ai-tools" \
  "jupyter-ai-litellm==0.0.2" \
  "jupyter_server_mcp" \
  ipykernel \
  ipywidgets \
  jupyterlab-language-pack-zh-CN \
  'litellm[proxy]'    

# 修复 jupyter-ai-litellm 的版本显示 bug
SITE_PACKAGES=$(python -c "import site; print(site.getsitepackages()[0])")
PACKAGE_DIR="${SITE_PACKAGES}/jupyter_ai_litellm"

if [ -d "$PACKAGE_DIR" ]; then
    echo "🔧 修复 jupyter-ai-litellm 版本显示..."
    # 创建 _version.py
    echo '__version__ = "0.0.2"' > ${PACKAGE_DIR}/_version.py
    # 删除硬编码的 version = "dev"
    sed -i '/version = "dev"/d' ${PACKAGE_DIR}/__init__.py
    echo "✅ 修复完成"
fi

echo "📋 验证服务器扩展:"
jupyter server extension list | grep jupyter_ai

# ============================================
# 4. 安装 LangChain 生态
# ============================================
echo "🦜 安装 LangChain 生态..."
pip install  --upgrade\
    langchain \
    langchain-core \
    langchain-community \
    langchain-openai \
    langchain-anthropic \
    langchain-google-genai \
    langchain-ollama \
    langchain-text-splitters \
    langchain-experimental

# ============================================
# 3.6 启用服务器扩展（关键！之前缺失）
# ============================================
echo "🔌 启用 Jupyter AI 服务器扩展..."
# ==============================================
jupyter server extension enable jupyter_ai_litellm --sys-prefix
jupyter server extension enable jupyter_ai_jupyternaut --sys-prefix   # 如果安装了
jupyter server extension enable jupyter_ai_tools  --sys-prefix      # 如果安装了
jupyter server extension enable jupyter_server_mcp --sys-prefix

echo "📋 验证服务器扩展:"
jupyter server extension list | grep jupyter

# ============================================
# 6. 重建 JupyterLab（扩展启用后）
# ============================================
echo "🔨 重建 JupyterLab 扩展..."
jupyter lab build --minimize=False

# ============================================
# 7. 验证前端扩展
# ============================================
echo "📋 验证前端扩展:"
jupyter labextension list | grep -E "jupyter-ai|jupyternaut|mcp" || true

# ============================================
# 6. 数据科学基础库
# ============================================
echo "📚 安装数据科学基础库..."
pip install --upgrade\
    numpy \
    pandas \
    matplotlib \
    seaborn \
    scikit-learn \
    scipy \
    xgboost

# ============================================
# 7. 深度学习框架 (2026 最新版)
# ============================================
echo "🔥 安装深度学习框架 (2026 Optimized)..."

# 1. 强制升级 protobuf (解决潜在的依赖冲突)
pip install --upgrade protobuf

# 2. 安装 PyTorch (使用官方 CUDA 12.4 或 CPU)
# 根据你的机器环境选择，如果是 CPU 版本，保留 cpu；如果是 GPU，替换为 cu121/cu124
echo " 安装 PyTorch 2.8+ ..."
pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cpu

# 3. 安装 TensorFlow (2.20+)
echo " 安装 TensorFlow 2.20+ ..."
pip install tensorflow --upgrade

# 验证安装
python -c "import torch; print(f'PyTorch OK: {torch.__version__}')"
python -c "import tensorflow as tf; print(f'TensorFlow OK: {tf.__version__}')"


# ============================================
# 9. AI 模型工具
# ============================================
echo "🤗 安装 AI 模型工具..."
pip install  --upgrade\
    transformers \
    datasets \
    accelerate \
    peft \
    bitsandbytes \
    sentencepiece \
    tokenizers \
    huggingface-hub

pip install --upgrade \
    openai \
    anthropic \
    google-generativeai \
    mistralai \
    groq \
    cohere

# ============================================
# 10. 向量数据库
# ============================================
echo "🗄️ 安装向量数据库..."
pip install --upgrade \
    chromadb \
    faiss-cpu 

# ============================================
# 11. 可视化库
# ============================================
echo "📊 安装可视化库..."
pip install --upgrade \
    plotly \
    streamlit \
    matplotlib \
    seaborn

# ============================================
# 12. 工具库
# ============================================
echo "🔧 安装工具库..."
pip install --upgrade \
    requests \
    tqdm \
    python-dotenv \
    pyyaml \
    httpx \
    aiohttp \
    pypdf \
    python-docx \
    openpyxl \
    pillow \
    click \
    rich \
    loguru

# ============================================
# 13. Jupyter 扩展
# ============================================
echo "🧩 安装 Jupyter 扩展..."
pip install --upgrade \
    jupyterlab-git \
    jupyterlab-lsp \
    jupyterlab-code-formatter \
    jupyterlab-execute-time

echo "=========================================="
echo "✅ Jupyter AI v3.0 安装完成！"
echo "=========================================="

# ============================================
# 1. 确定配置目录
# ============================================
export JUPYTER_AI_CONFIG_DIR="/home/jovyan/.local/share/jupyter/jupyter_ai"

# ============================================
# 2. 生成最终修复版 config.json
# ============================================
mkdir -p ${JUPYTER_AI_CONFIG_DIR}

cat > ${JUPYTER_AI_CONFIG_DIR}/config.json << EOF
{
    "model_provider_id": "ollama/qwen2.5-coder:7b-q4",
    "embeddings_provider_id": "ollama-chat",
    "api_keys": {
        "LITELLM_API_KEY": "sk-litellm-dummy-key"
    },
    "fields": {
        "api_base": {
            "value": "${OLLAMA_HOST}"
        }
    },
    "embeddings_fields": {
        "model_id": {
            "value": "${OLLAMA_EMBEDDING_MODEL}"
        },
        "base_uri": {
            "value": "${OLLAMA_HOST}"
        }
    }
}
EOF

echo "✅ Jupyter AI 配置已修复完成！"
echo "📍 配置路径：${JUPYTER_AI_CONFIG_DIR}/config.json"

# ============================================
# 14. 配置 LiteLLM 模型列表
# ============================================
echo "⚙️ 配置 LiteLLM 模型..."
mkdir -p /home/jovyan/.jupyter/litellm

# 设置默认值（如果未定义）
OLLAMA_HOST="${OLLAMA_HOST:-http://192.168.112.136:11434}"
OLLAMA_TEMPERATURE="${OLLAMA_TEMPERATURE:-0.7}"
OLLAMA_MAX_TOKENS="${OLLAMA_MAX_TOKENS:-2048}"

# 创建模板文件（使用占位符）
cat > /home/jovyan/.jupyter/litellm/config.yaml.template << 'EOF'
model_list:
  - model_name: ollama/qwen2.5-coder:7b-q4
    litellm_params:
      model: ollama/qwen2.5-coder:7b-q4
      api_base: __OLLAMA_HOST__
      api_key: none
      temperature: __OLLAMA_TEMPERATURE__
      max_tokens: __OLLAMA_MAX_TOKENS__
  - model_name: ollama/deepseek-coder:6.7b
    litellm_params:
      model: ollama/deepseek-coder:6.7b
      api_base: __OLLAMA_HOST__
      api_key: none
      temperature: __OLLAMA_TEMPERATURE__
      max_tokens: __OLLAMA_MAX_TOKENS__
  # 嵌入模型（向量化）
  - model_name: ollama/nomic-embed-text
    litellm_params:
      model: ollama/nomic-embed-text
      api_base: __OLLAMA_HOST__
      api_key: none

litellm_settings:
  drop_params: true
  #set_verbose: false
  set_verbose: true
EOF

# 使用 sed 替换占位符
sed -e "s|__OLLAMA_HOST__|${OLLAMA_HOST}|g" \
    -e "s|__OLLAMA_TEMPERATURE__|${OLLAMA_TEMPERATURE}|g" \
    -e "s|__OLLAMA_MAX_TOKENS__|${OLLAMA_MAX_TOKENS}|g" \
    /home/jovyan/.jupyter/litellm/config.yaml.template > /home/jovyan/.jupyter/litellm/config.yaml

# 删除模板文件（可选）
rm -f /home/jovyan/.jupyter/litellm/config.yaml.template

echo "✅ LiteLLM 配置文件生成完成"

# ============================================
# 15. 启动 LiteLLM Proxy 服务 (后台)
# ============================================
echo "🚀 配置 LiteLLM 启动服务..."

# 创建日志目录
mkdir -p /home/jovyan/.jupyter/litellm/logs

# 将启动命令写入 profile 或直接在启动脚本中调用
# 我们将在 start_jupyter_ai.sh 中启动它


# ============================================
# 15. 创建 kernel 配置（v3使用Python 3.11）
# ============================================
KERNEL_DIR="/home/jovyan/.local/share/jupyter/kernels/${CONDA_ENV_NAME}"
mkdir -p ${KERNEL_DIR}

cat > ${KERNEL_DIR}/kernel.json << EOF
{
 "argv": [
  "/opt/conda/envs/ai_env/bin/python",
  "-m",
  "ipykernel_launcher",
  "-f",
  "{connection_file}"
 ],
 "display_name": "Python 3.11 (AI v3)",
 "language": "python",
 "metadata": {"debugger": true},
 "env": {
  "OLLAMA_HOST": "${OLLAMA_HOST}",
  "OLLAMA_DEFAULT_MODEL": "${OLLAMA_DEFAULT_MODEL}",
  "OLLAMA_EMBEDDING_MODEL": "${OLLAMA_EMBEDDING_MODEL}",
  "OLLAMA_TEMPERATURE": "${OLLAMA_TEMPERATURE}",
  "MAX_TOKENS": "${OLLAMA_MAX_TOKENS}",
  "LITELLM_CONFIG_PATH": "${LITELLM_CONFIG_PATH}",
  "LITELLM_LOCAL_MODEL_COST_MAP": "True"
 }
}
EOF

# ============================================
# 16. 配置 JupyterLab（v3专用配置）
# ============================================
echo "⚙️ 配置 JupyterLab v3..."

CONFIG_DIR="/home/jovyan/.jupyter"
mkdir -p ${CONFIG_DIR}


# ============================================
# 16. 配置 JupyterLab（v3专用配置）- 使用环境变量
# ============================================
echo "⚙️ 配置 JupyterLab v3..."

CONFIG_DIR="/home/jovyan/.jupyter"
mkdir -p ${CONFIG_DIR}

# 统一的 jupyter_server_config.py（使用环境变量）
cat > ${CONFIG_DIR}/jupyter_server_config.py << 'EOF'
import os

# 从环境变量读取配置
JUPYTER_PORT = int(os.environ.get('JUPYTER_PORT', 8881))
JUPYTER_TOKEN = os.environ.get('JUPYTER_TOKEN', '')
JUPYTER_PASSWORD = os.environ.get('JUPYTER_PASSWORD', '')
OLLAMA_HOST = os.environ.get('OLLAMA_HOST', 'http://192.168.112.136:11434')
OLLAMA_DEFAULT_MODEL = os.environ.get('OLLAMA_DEFAULT_MODEL', 'qwen2.5-coder:7b-q4')
OLLAMA_EMBEDDING_MODEL = os.environ.get('OLLAMA_EMBEDDING_MODEL', 'nomic-embed-text') # 确保获取该变量

# 设置环境变量
os.environ.setdefault('LITELLM_CONFIG_PATH', '/home/jovyan/.jupyter/litellm/config.yaml')
os.environ.setdefault('LITELLM_LOCAL_MODEL_COST_MAP', 'True')
os.environ.setdefault('OLLAMA_HOST', OLLAMA_HOST)
os.environ.setdefault('OLLAMA_BASE_URL', OLLAMA_HOST)
os.environ.setdefault('OLLAMA_DEFAULT_MODEL', OLLAMA_DEFAULT_MODEL)
os.environ.setdefault('OLLAMA_EMBEDDING_MODEL', OLLAMA_EMBEDDING_MODEL)

# Server 配置
c = get_config()
c.ServerApp.allow_root = True
c.ServerApp.ip = '0.0.0.0'
c.ServerApp.port = JUPYTER_PORT
c.ServerApp.open_browser = False
c.ServerApp.allow_origin = '*'
c.ServerApp.allow_remote_access = True
c.ServerApp.root_dir = '/home/jovyan'
c.ServerApp.trust_xheaders = True
c.ServerApp.disable_check_xsrf = True
c.ServerApp.log_level = 'DEBUG'

# 认证配置
if JUPYTER_TOKEN:
    c.IdentityProvider.token = JUPYTER_TOKEN
elif JUPYTER_PASSWORD:
    from jupyter_server.auth import passwd
    c.IdentityProvider.hashed_password = passwd(JUPYTER_PASSWORD)
else:
    c.IdentityProvider.token = ''
    c.IdentityProvider.password = ''
c.ContentsManager.allow_hidden = True
c.LabApp.extensions_in_dev_mode = False

# 启用 Jupyter AI 扩展
c.ServerApp.jpserver_extensions = {
    "jupyter_ai_litellm": True,
    "jupyter_ai_jupyternaut": True,
    "jupyter_ai_tools": True
}

# ============================================
# 🔧 AI Extension 配置 (修复关键错误)
# ============================================
# 解决 ValidationError: Input should be a valid dictionary
# 必须使用嵌套字典格式 {"value": "..."}，不能直接赋字符串
c.JupyternautExtension.config = {
    "fields": {
        "api_base": {
            "value": OLLAMA_HOST  # 使用上面定义的变量
        },
        "model_id": {
            "value": OLLAMA_DEFAULT_MODEL
        }
    },
    "embeddings_fields": {
        "model_id": {
            "value": OLLAMA_EMBEDDING_MODEL
        },
        "base_uri": {
            "value": OLLAMA_HOST
        }
    }
}
c.Jupyternaut.api_base = OLLAMA_HOST
c.OllamaProvider.api_base = OLLAMA_HOST
c.AIProvider.api_base = OLLAMA_HOST
c.Jupyternaut.allow_fallback = False
EOF

# ============================================
# 19. 创建启动脚本（使用环境变量）
# ============================================
cat > /home/jovyan/start_jupyter_ai.sh << 'EOF'
#!/bin/bash

# 设置默认值（支持环境变量覆盖）
export JUPYTER_PORT=${JUPYTER_PORT:-8881}
export JUPYTER_TOKEN=${JUPYTER_TOKEN:-}
export JUPYTER_PASSWORD=${JUPYTER_PASSWORD:-}

source /opt/conda/etc/profile.d/conda.sh
conda activate ai_env

export LITELLM_CONFIG_PATH=/home/jovyan/.jupyter/litellm/config.yaml
export LITELLM_LOCAL_MODEL_COST_MAP=True
export JUPYTER_ENABLE_LAB=yes
export OLLAMA_HOST=${OLLAMA_HOST:-http://192.168.112.136:11434}
export OLLAMA_BASE_URL=${OLLAMA_BASE_URL:-${OLLAMA_HOST}}
export OLLAMA_DEFAULT_MODEL=${OLLAMA_DEFAULT_MODEL:-qwen2.5-coder:7b-q4}
export OLLAMA_TEMPERATURE=${OLLAMA_TEMPERATURE:-0.7}
export OLLAMA_EMBEDDING_MODEL=${OLLAMA_EMBEDDING_MODEL:-nomic-embed-text}
export OLLAMA_MAX_TOKENS=${OLLAMA_MAX_TOKENS:-2048}
export HF_ENDPOINT=${HF_ENDPOINT:-https://hf-mirror.com}

# 深度学习框架环境变量
export TF_CPP_MIN_LOG_LEVEL=2
export PYTORCH_CUDA_ALLOC_CONF=max_split_size_mb:512

echo "=========================================="
echo "🚀 启动 Jupyter AI v3.0 服务"
echo "=========================================="
echo "JupyterLab: http://localhost:${JUPYTER_PORT}"
echo "Ollama: ${OLLAMA_HOST}"
echo "默认模型: ${OLLAMA_DEFAULT_MODEL}"
echo "PyTorch: $(python -c 'import torch; print(torch.__version__)' 2>/dev/null || echo '未安装')"
echo "TensorFlow: $(python -c 'import tensorflow as tf; print(tf.__version__)' 2>/dev/null || echo '未安装')"
echo "=========================================="


# --- 新增：启动 LiteLLM Proxy ---
echo "🚀 启动 LiteLLM Proxy 服务 (端口 4000)..."
nohup litellm --config /home/jovyan/.jupyter/litellm/config.yaml --port 4000 --host 0.0.0.0 > /home/jovyan/.jupyter/litellm/litellm.log 2>&1 &
LITELLM_PID=$!
echo "✅ LiteLLM PID: $LITELLM_PID"

# 等待服务启动
sleep 5

# 检查是否启动成功
if ! kill -0 $LITELLM_PID 2>/dev/null; then
    echo "❌ LiteLLM 启动失败，请检查日志。"
    cat /home/jovyan/.jupyter/litellm/litellm.log
    exit 1
fi

# 直接在当前激活的环境中启动 Jupyter Lab
exec jupyter lab \
    --port=${JUPYTER_PORT} \
    --ip=0.0.0.0 \
    --no-browser \
    --config=/home/jovyan/.jupyter/jupyter_server_config.py
EOF

chmod +x /home/jovyan/start_jupyter_ai.sh

# ============================================
# 20. 修复权限
# ============================================
chown -R jovyan:users /home/jovyan/.jupyter
chown -R jovyan:users /home/jovyan/.local/share/jupyter/kernels
chown -R jovyan:users /home/jovyan/.cache

# ============================================
# 21. 清理缓存
# ============================================
echo "🧹 清理缓存..."
conda clean -afy 2>/dev/null || true
pip cache purge 2>/dev/null || true
rm -rf /home/jovyan/.cache/pip
rm -rf /home/jovyan/.cache/conda
rm -rf /home/jovyan/.cache/huggingface
rm -rf /tmp/pip-*
rm -rf /tmp/tmp*

# ============================================
# Jupyternaut 硬编码 localhost → 读取环境变量 OLLAMA_HOST
# ============================================
echo "🔧 补丁：Jupyternaut 从 OLLAMA_HOST 环境变量读取地址..."

SITE_PACKAGES=$(python -c "import site; print(site.getsitepackages()[0])")
JUPYTERNAUT_CHAT_MODELS="${SITE_PACKAGES}/jupyter_ai_jupyternaut/jupyternaut/chat_models.py"

if [ -f "$JUPYTERNAUT_CHAT_MODELS" ]; then
    # 👉 关键：确保文件顶部有 import os
    if ! grep -q '^import os' "$JUPYTERNAUT_CHAT_MODELS"; then
        sed -i '1i import os' "$JUPYTERNAUT_CHAT_MODELS"
        echo "✅ 已添加 import os"
    fi

    # 替换所有硬编码地址为环境变量
    sed -i "s|\"http://localhost:11434\"|os.getenv('OLLAMA_HOST')|g" "$JUPYTERNAUT_CHAT_MODELS"
    sed -i "s|\"http://127.0.0.1:11434\"|os.getenv('OLLAMA_HOST')|g" "$JUPYTERNAUT_CHAT_MODELS"

    echo "✅ Jupyternaut 已完全使用 OLLAMA_HOST 环境变量"
fi


# ============================================
# 22. 验证安装（在激活的环境下执行）
# ============================================
echo "✅ 验证安装..."

# 确保在激活的环境下
source /opt/conda/etc/profile.d/conda.sh
conda activate ${CONDA_ENV_NAME}

echo "当前环境: ${CONDA_DEFAULT_ENV}"
echo "Python 路径: $(which python)"

echo ""
echo "JupyterLab 版本:"
jupyter-lab --version

echo ""
echo "已安装的 AI 包:"
pip list | grep -E "jupyter-ai|langchain|torch|tensorflow|transformers"

echo ""
echo "PyTorch 版本:"
python -c "import torch; print(f'  PyTorch: {torch.__version__}')" 2>/dev/null || echo "  PyTorch: 未安装"

echo "TensorFlow 版本:"
python -c "import tensorflow as tf; print(f'  TensorFlow: {tf.__version__}')" 2>/dev/null || echo "  TensorFlow: 未安装"

echo "Jupyter AI 服务器扩展状态:"
jupyter server extension list | grep jupyter_ai
echo ""
echo "=========================================="
echo "✅ Jupyter AI v3.0 安装完成！"
echo "=========================================="
echo "📦 已安装的深度学习框架:"
echo "  - PyTorch 2.5.1"
echo "  - TensorFlow 2.18.0"
echo "  - Keras 3.6.0"
echo "  - JAX 0.4.35"
echo "  - ONNX 1.16.0"
echo ""
echo "启动服务: ./start_jupyter_ai.sh"
echo ""
echo "=========================================="
echo "📖 在 Notebook 中测试:"
echo "=========================================="
echo ""
echo "  # 1. 加载 v3 魔法命令"
echo "  %load_ext jupyter_ai_magic_commands"
echo ""
echo "  # 2. 查看可用模型"
echo "  %ai list"
echo ""
echo "  # 3. 使用 Ollama 模型"
echo "  %%ai ollama/qwen2.5-coder:7b-q4"
echo "  你好，请介绍一下自己"
echo ""
echo "  # 4. 测试深度学习框架"
echo "  import torch"
echo "  import tensorflow as tf"
echo "  print(f'PyTorch: {torch.__version__}')"
echo "  print(f'TensorFlow: {tf.__version__}')"
echo ""
echo "=========================================="

# ============================================
# 23. 创建完整使用手册
# ============================================
cat > /home/jovyan/JUPYTER_AI_V3_COMPLETE_GUIDE.md << 'EOF'
# Jupyter AI v3.0 完整使用手册

## 📋 目录

1. [环境概述](#1-环境概述)
2. [快速开始](#2-快速开始)
3. [Jupyter AI v3 核心功能](#3-jupyter-ai-v3-核心功能)
4. [深度学习框架使用指南](#4-深度学习框架使用指南)
5. [LangChain 应用开发](#5-langchain-应用开发)
6. [向量数据库与RAG](#6-向量数据库与rag)
7. [API 集成](#7-api-集成)
8. [高级技巧](#8-高级技巧)
9. [性能优化](#9-性能优化)
10. [常见问题排查](#10-常见问题排查)
11. [最佳实践](#11-最佳实践)

---

## 1. 环境概述

### 1.1 版本信息

| 组件 | 版本 | 说明 |
|------|------|------|
| Jupyter AI | 3.0.0 | 多智能体协作平台 |
| JupyterLab | 4.x | 下一代笔记本界面 |
| Python | 3.11 | 推荐版本 |
| PyTorch | 2.5.1 | CPU版本 |
| TensorFlow | 2.18.0 | CPU版本 |
| LangChain | 0.3.13 | LLM应用框架 |
| Ollama | 最新 | 本地模型服务 |

### 1.2 环境变量

```bash
# Jupyter AI 配置
LITELLM_CONFIG_PATH=/home/jovyan/.jupyter/litellm/config.yaml
LITELLM_LOCAL_MODEL_COST_MAP=True

# Ollama 配置
OLLAMA_HOST=http://192.168.112.136:11434
OLLAMA_BASE_URL=http://192.168.112.136:11434
OLLAMA_DEFAULT_MODEL=qwen2.5-coder:7b-q4
OLLAMA_TEMPERATURE=0.7
MAX_TOKENS=2048

# Hugging Face 镜像
HF_ENDPOINT=https://hf-mirror.com
1.3 启动服务
bash
./start_jupyter_ai.sh
访问: http://localhost:8881

2. 快速开始
2.1 加载 AI 魔法命令
python
# 加载 v3 魔法命令
%load_ext jupyter_ai_magic_commands

# 查看所有可用提供商
%ai list

# 查看 Ollama 可用模型
%ai list ollama
2.2 基础 AI 对话
python
# 单行对话
%ai ollama/qwen2.5-coder:7b-q4 你好

# 多行对话
%%ai ollama/qwen2.5-coder:7b-q4
请用 Python 实现一个快速排序算法
2.3 带参数的 AI 调用
python
# 指定温度参数
%%ai ollama/qwen2.5-coder:7b-q4 --temperature 0.5
用简单的语言解释机器学习

# 指定最大输出长度
%%ai ollama/qwen2.5-coder:7b-q4 --max-tokens 500
列出 Python 的 10 个最佳实践
3. Jupyter AI v3 核心功能
3.1 代码生成
python
# 生成类定义
%%ai ollama/qwen2.5-coder:7b-q4
创建一个 Python 类表示银行账户，包含:
- 属性: 账号、余额、客户姓名
- 方法: 存款、取款、查询余额、转账
- 添加适当的异常处理
3.2 代码解释
python
# 解释复杂代码
%%ai ollama/qwen2.5-coder:7b-q4
详细解释以下代码的工作原理:

def quicksort(arr):
    if len(arr) <= 1:
        return arr
    pivot = arr[len(arr) // 2]
    left = [x for x in arr if x < pivot]
    middle = [x for x in arr if x == pivot]
    right = [x for x in arr if x > pivot]
    return quicksort(left) + middle + quicksort(right)
3.3 代码优化
python
# 性能优化建议
%%ai ollama/qwen2.5-coder:7b-q4
优化这段代码的性能:

def find_duplicates(arr):
    result = []
    for i in range(len(arr)):
        for j in range(i+1, len(arr)):
            if arr[i] == arr[j] and arr[i] not in result:
                result.append(arr[i])
    return result
3.4 单元测试生成
python
# 生成单元测试
%%ai ollama/qwen2.5-coder:7b-q4
为以下函数生成 pytest 单元测试:

def is_prime(n):
    if n < 2:
        return False
    for i in range(2, int(n**0.5) + 1):
        if n % i == 0:
            return False
    return True
3.5 文档生成
python
# 生成 docstring
%%ai ollama/qwen2.5-coder:7b-q4
为以下函数生成 Google 风格的 docstring:

def calculate_compound_interest(principal, rate, time, compound_freq=12):
    """
    参数:
        principal: 本金
        rate: 年利率（小数形式）
        time: 年数
        compound_freq: 复利频率（每年次数）
    """
    return principal * (1 + rate/compound_freq) ** (compound_freq * time)
3.6 多轮对话
python
# 设定角色
%%ai ollama/qwen2.5-coder:7b-q4
你是一个 Python 专家，请用中文回答问题

# 提问
%%ai ollama/qwen2.5-coder:7b-q4
什么是装饰器？有什么实际应用场景？

# 深入
%%ai ollama/qwen2.5-coder:7b-q4
给我一个用于函数执行时间计时的装饰器示例

# 扩展
%%ai ollama/qwen2.5-coder:7b-q4
如何让装饰器同时接受参数？
3.7 变量传递
python
# 定义变量
code = """
def fibonacci(n):
    if n <= 1:
        return n
    return fibonacci(n-1) + fibonacci(n-2)
"""

# 在 AI 指令中使用变量
%%ai ollama/qwen2.5-coder:7b-q4
优化这段递归代码，避免重复计算:

{code}
4. 深度学习框架使用指南
4.1 PyTorch 基础
python
import torch
import torch.nn as nn
import torch.optim as optim
from torch.utils.data import DataLoader, TensorDataset

# 检查版本
print(f"PyTorch 版本: {torch.__version__}")

# 创建张量
x = torch.tensor([1, 2, 3, 4, 5], dtype=torch.float32)
y = torch.randn(3, 4)
z = torch.zeros(2, 3)

# 简单神经网络
class SimpleNN(nn.Module):
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
model = SimpleNN(10, 64, 2)
criterion = nn.CrossEntropyLoss()
optimizer = optim.Adam(model.parameters(), lr=0.001)

# 训练循环示例
X = torch.randn(1000, 10)
y = torch.randint(0, 2, (1000,))

for epoch in range(10):
    optimizer.zero_grad()
    outputs = model(X)
    loss = criterion(outputs, y)
    loss.backward()
    optimizer.step()
    print(f"Epoch {epoch+1}, Loss: {loss.item():.4f}")
4.2 TensorFlow 基础
python
import tensorflow as tf
from tensorflow import keras
from tensorflow.keras import layers

# 检查版本和配置
print(f"TensorFlow 版本: {tf.__version__}")
print(f"可用设备: {tf.config.list_physical_devices()}")

# 创建 Sequential 模型
model = keras.Sequential([
    layers.Dense(64, activation='relu', input_shape=(10,)),
    layers.Dropout(0.2),
    layers.Dense(32, activation='relu'),
    layers.Dropout(0.2),
    layers.Dense(2, activation='softmax')
])

# 编译模型
model.compile(
    optimizer='adam',
    loss='sparse_categorical_crossentropy',
    metrics=['accuracy']
)

# 生成示例数据
import numpy as np
X = np.random.randn(1000, 10)
y = np.random.randint(0, 2, (1000,))

# 训练模型
history = model.fit(
    X, y,
    epochs=10,
    batch_size=32,
    validation_split=0.2,
    verbose=1
)

# 模型保存和加载
model.save('my_model.keras')
loaded_model = keras.models.load_model('my_model.keras')
4.3 Hugging Face Transformers
python
from transformers import pipeline, AutoTokenizer, AutoModelForSequenceClassification

# 情感分析
sentiment_analyzer = pipeline("sentiment-analysis", model="distilbert-base-uncased-finetuned-sst-2-english")
result = sentiment_analyzer("I love using Jupyter AI for my work!")
print(result)

# 文本生成
generator = pipeline("text-generation", model="gpt2")
result = generator("The future of AI is", max_length=50, num_return_sequences=1)
print(result[0]['generated_text'])

# 使用本地模型
tokenizer = AutoTokenizer.from_pretrained("bert-base-uncased")
model = AutoModelForSequenceClassification.from_pretrained("bert-base-uncased")

# 文本分类
classifier = pipeline("text-classification", model=model, tokenizer=tokenizer)
result = classifier("This is a great product!")
print(result)
4.4 模型转换与优化
python
# PyTorch 模型转 ONNX
import torch.onnx

class SimpleModel(torch.nn.Module):
    def __init__(self):
        super().__init__()
        self.fc = torch.nn.Linear(10, 2)
    
    def forward(self, x):
        return self.fc(x)

model = SimpleModel()
dummy_input = torch.randn(1, 10)

torch.onnx.export(
    model,
    dummy_input,
    "model.onnx",
    input_names=['input'],
    output_names=['output'],
    dynamic_axes={'input': {0: 'batch_size'}, 'output': {0: 'batch_size'}}
)

# TensorFlow 模型优化
converter = tf.lite.TFLiteConverter.from_keras_model(model)
tflite_model = converter.convert()

# 保存 TFLite 模型
with open('model.tflite', 'wb') as f:
    f.write(tflite_model)
5. LangChain 应用开发
5.1 基础 LLM 调用
python
from langchain_community.llms import Ollama
from langchain_core.messages import HumanMessage, SystemMessage
from langchain_core.output_parsers import StrOutputParser
from langchain_core.prompts import ChatPromptTemplate

# 初始化 Ollama
llm = Ollama(
    model="qwen2.5-coder:7b-q4",
    base_url="http://192.168.112.136:11434",
    temperature=0.7,
    top_p=0.9
)

# 直接调用
response = llm.invoke("什么是机器学习？")
print(response)

# 使用提示模板
prompt = ChatPromptTemplate.from_messages([
    ("system", "你是一个 Python 专家助手。"),
    ("human", "{input}")
])

chain = prompt | llm | StrOutputParser()
result = chain.invoke({"input": "如何优化 Python 代码性能？"})
print(result)
5.2 对话记忆
python
from langchain.memory import ConversationBufferMemory
from langchain.chains import ConversationChain

# 创建带记忆的对话链
memory = ConversationBufferMemory()
conversation = ConversationChain(
    llm=llm,
    memory=memory,
    verbose=True
)

# 多轮对话
print(conversation.predict(input="你好，我叫小明"))
print(conversation.predict(input="我叫什么名字？"))
print(conversation.predict(input="帮我写一个计算斐波那契数列的函数"))
5.3 链式调用
python
from langchain.chains import LLMChain
from langchain.prompts import PromptTemplate

# 代码生成链
code_prompt = PromptTemplate(
    input_variables=["task", "language"],
    template="""用 {language} 实现以下功能:
{task}

请提供完整的代码和简要说明。"""
)

code_chain = LLMChain(llm=llm, prompt=code_prompt)
result = code_chain.run(task="快速排序算法", language="Python")
print(result)
5.4 RAG (检索增强生成)
python
from langchain_community.document_loaders import TextLoader
from langchain.text_splitter import CharacterTextSplitter
from langchain_community.embeddings import OllamaEmbeddings
from langchain_community.vectorstores import Chroma
from langchain.chains import RetrievalQA

# 加载文档
loader = TextLoader('document.txt')
documents = loader.load()

# 分割文本
text_splitter = CharacterTextSplitter(chunk_size=1000, chunk_overlap=200)
texts = text_splitter.split_documents(documents)

# 创建向量存储
embeddings = OllamaEmbeddings(
    model="qwen2.5-coder:7b-q4",
    base_url="http://192.168.112.136:11434"
)
vectorstore = Chroma.from_documents(texts, embeddings)

# 创建 RAG 链
qa_chain = RetrievalQA.from_chain_type(
    llm=llm,
    chain_type="stuff",
    retriever=vectorstore.as_retriever(search_kwargs={"k": 3})
)

# 提问
answer = qa_chain.run("文章中提到了哪些重要概念？")
print(answer)
6. 向量数据库与 RAG
6.1 ChromaDB 基础
python
import chromadb
from chromadb.utils import embedding_functions

# 初始化客户端
client = chromadb.Client()

# 创建集合
collection = client.create_collection(
    name="my_documents",
    embedding_function=embedding_functions.DefaultEmbeddingFunction()
)

# 添加文档
collection.add(
    documents=[
        "机器学习是人工智能的一个子领域",
        "深度学习使用多层神经网络",
        "自然语言处理处理文本数据"
    ],
    metadatas=[
        {"source": "AI基础"},
        {"source": "深度学习"},
        {"source": "NLP"}
    ],
    ids=["doc1", "doc2", "doc3"]
)

# 查询
results = collection.query(
    query_texts=["神经网络"],
    n_results=2
)
print(results)

# 更新文档
collection.update(
    ids=["doc1"],
    documents=["机器学习是AI的核心技术"],
    metadatas=[{"source": "AI基础", "updated": True}]
)

# 删除集合
client.delete_collection("my_documents")
6.2 FAISS 向量检索
python
import numpy as np
import faiss

# 创建向量
dimension = 128
vectors = np.random.random((1000, dimension)).astype('float32')

# 创建索引
index = faiss.IndexFlatL2(dimension)
index.add(vectors)

# 搜索
query = np.random.random((1, dimension)).astype('float32')
distances, indices = index.search(query, k=5)
print(f"最近的5个向量索引: {indices}")
print(f"对应的距离: {distances}")

# 保存和加载
faiss.write_index(index, "index.faiss")
loaded_index = faiss.read_index("index.faiss")
7. API 集成
7.1 OpenAI API
python
from openai import OpenAI

# 配置客户端（需要在环境变量中设置 OPENAI_API_KEY）
client = OpenAI()

# 对话补全
response = client.chat.completions.create(
    model="gpt-3.5-turbo",
    messages=[
        {"role": "system", "content": "你是 Python 专家助手。"},
        {"role": "user", "content": "如何优化 Python 性能？"}
    ],
    temperature=0.7,
    max_tokens=500
)
print(response.choices[0].message.content)

# 流式响应
stream = client.chat.completions.create(
    model="gpt-3.5-turbo",
    messages=[{"role": "user", "content": "写一个快速排序"}],
    stream=True
)

for chunk in stream:
    if chunk.choices[0].delta.content:
        print(chunk.choices[0].delta.content, end="")
7.2 Anthropic Claude API
python
from anthropic import Anthropic

# 配置客户端（需要设置 ANTHROPIC_API_KEY）
client = Anthropic()

# 调用 Claude
message = client.messages.create(
    model="claude-3-5-sonnet-20241022",
    max_tokens=1024,
    temperature=0.7,
    messages=[
        {"role": "user", "content": "解释一下 Python 的装饰器"}
    ]
)
print(message.content[0].text)
7.3 Google Gemini API
python
import google.generativeai as genai

# 配置 API
genai.configure(api_key="YOUR_API_KEY")

# 创建模型
model = genai.GenerativeModel('gemini-pro')

# 生成内容
response = model.generate_content("解释一下梯度下降算法")
print(response.text)

# 多轮对话
chat = model.start_chat()
chat.send_message("你好")
chat.send_message("帮我写一个 Python 函数")
8. 高级技巧
8.1 自定义提示模板
python
from string import Template

class CodeReviewPrompt:
    template = Template("""
    请对以下 ${language} 代码进行代码审查:
    
    ```${language}
    ${code}
请从以下方面分析:

代码风格和可读性

性能问题

潜在的 Bug

安全漏洞

改进建议

请用中文回答。
""")

def format(self, code, language="Python"):
return self.template.substitute(code=code, language=language)

使用示例
reviewer = CodeReviewPrompt()
code = """
def process_data(data):
result = []
for i in range(len(data)):
if data[i] > 0:
result.append(data[i] * 2)
return result
"""

prompt = reviewer.format(code, "Python")
print(prompt)

text

### 8.2 批量处理

```python
from concurrent.futures import ThreadPoolExecutor
import time

def process_with_ai(texts, llm):
    """批量处理文本"""
    results = []
    with ThreadPoolExecutor(max_workers=5) as executor:
        futures = [executor.submit(llm.invoke, text) for text in texts]
        for future in futures:
            results.append(future.result())
    return results

# 使用示例
texts = [
    "解释什么是闭包",
    "列表和元组的区别",
    "如何使用生成器",
    "什么是装饰器",
    "异常处理的最佳实践"
]

# results = process_with_ai(texts, llm)
8.3 缓存优化
python
from functools import lru_cache
import hashlib
import json

class AICache:
    def __init__(self, llm, maxsize=128):
        self.llm = llm
        self.cache = {}
    
    def _get_key(self, prompt):
        """生成缓存键"""
        return hashlib.md5(prompt.encode()).hexdigest()
    
    def invoke(self, prompt):
        """带缓存的调用"""
        key = self._get_key(prompt)
        if key not in self.cache:
            self.cache[key] = self.llm.invoke(prompt)
        return self.cache[key]
    
    def clear(self):
        """清空缓存"""
        self.cache.clear()

# 使用示例
# cached_llm = AICache(llm)
# response = cached_llm.invoke("什么是人工智能")
8.4 流式输出处理
python
def stream_ai_response(llm, prompt):
    """处理流式响应"""
    for chunk in llm.stream(prompt):
        print(chunk, end="", flush=True)
    print()

# 使用示例
# stream_ai_response(llm, "写一个快速排序算法")
8.5 与 Pandas 集成
python
import pandas as pd

def analyze_dataframe_with_ai(df, llm):
    """使用 AI 分析 DataFrame"""
    prompt = f"""
    分析以下数据:
    
    数据形状: {df.shape}
    列名: {list(df.columns)}
    数据类型: {df.dtypes.to_dict()}
    缺失值: {df.isnull().sum().to_dict()}
    描述统计: {df.describe().to_dict()}
    
    请提供:
    1. 数据摘要
    2. 发现的数据模式
    3. 潜在问题
    4. 分析建议
    """
    
    return llm.invoke(prompt)

# 使用示例
# df = pd.read_csv('data.csv')
# analysis = analyze_dataframe_with_ai(df, llm)
# print(analysis)
9. 性能优化
9.1 模型选择建议
任务类型	推荐模型	参数量	说明
简单问答	qwen2.5-coder:1.5b	1.5B	快速响应
代码生成	qwen2.5-coder:7b	7B	平衡性能
复杂推理	qwen2.5-coder:14b	14B	更准确
代码审查	qwen2.5-coder:32b	32B	最佳效果
9.2 内存优化
python
# PyTorch 内存优化
import torch

# 清空 GPU 缓存
if torch.cuda.is_available():
    torch.cuda.empty_cache()

# 使用梯度检查点节省内存
from torch.utils.checkpoint import checkpoint

# 模型量化
import torch.quantization as quant

# TensorFlow 内存优化
import tensorflow as tf
gpus = tf.config.experimental.list_physical_devices('GPU')
if gpus:
    try:
        for gpu in gpus:
            tf.config.experimental.set_memory_growth(gpu, True)
    except RuntimeError as e:
        print(e)
9.3 并发处理
python
import asyncio
from langchain.callbacks.streaming_stdout import StreamingStdOutCallbackHandler

async def async_llm_call(llm, prompts):
    """异步并发调用 LLM"""
    tasks = [llm.ainvoke(prompt) for prompt in prompts]
    results = await asyncio.gather(*tasks)
    return results

# 使用示例
# prompts = ["问题1", "问题2", "问题3"]
# results = await async_llm_call(llm, prompts)
10. 常见问题排查
10.1 AI 命令不工作
python
# 问题: %%ai 命令找不到
# 解决方案: 重新加载扩展

%load_ext jupyter_ai_magic_commands
%ai list
10.2 Ollama 连接失败
bash
# 检查 Ollama 服务
curl http://192.168.112.136:11434/api/tags

# 测试模型调用
curl http://192.168.112.136:11434/api/generate -d '{
  "model": "qwen2.5-coder:7b-q4",
  "prompt": "你好"
}'
python
# Python 测试
import requests
response = requests.post(
    'http://192.168.112.136:11434/api/generate',
    json={'model': 'qwen2.5-coder:7b-q4', 'prompt': '你好'}
)
print(response.json()['response'])
10.3 配置文件问题
python
import os
import yaml

# 检查配置
config_path = os.environ.get('LITELLM_CONFIG_PATH')
print(f"配置路径: {config_path}")
print(f"文件存在: {os.path.exists(config_path)}")

if os.path.exists(config_path):
    with open(config_path) as f:
        config = yaml.safe_load(f)
        print(f"模型列表: {config.get('model_list', [])}")
10.4 内存不足
python
# 限制模型内存使用
import os
os.environ['OLLAMA_NUM_PARALLEL'] = '1'  # 限制并发
os.environ['OLLAMA_MAX_LOADED_MODELS'] = '1'  # 限制加载模型数

# 清理缓存
import gc
gc.collect()

# PyTorch 内存清理
import torch
torch.cuda.empty_cache() if torch.cuda.is_available() else None
10.5 调试模式
python
# 启用详细日志
import logging
logging.basicConfig(level=logging.DEBUG)

# 查看扩展加载状态
%ai list

# 查看日志
!jupyter lab log
11. 最佳实践
11.1 提示工程技巧
python
# 使用系统提示词设定角色
system_prompt = "你是一个资深的 Python 架构师，擅长代码审查和性能优化。"

# 使用少样本学习
few_shot_examples = """
示例1:
输入: 计算列表平均值
输出: 
def average(lst):
    return sum(lst) / len(lst) if lst else 0

示例2:
输入: 检查回文字符串
输出:
def is_palindrome(s):
    s = s.lower().replace(' ', '')
    return s == s[::-1]
"""

# 明确输出格式
format_prompt = "请以 JSON 格式输出，包含 'code' 和 'explanation' 字段"
11.2 代码组织
python
# 创建 AI 辅助函数库
class AIAssistant:
    def __init__(self, model="qwen2.5-coder:7b-q4"):
        self.model = model
    
    def generate_code(self, task, language="Python"):
        prompt = f"用 {language} 实现: {task}"
        return self._call_ai(prompt)
    
    def explain_code(self, code):
        prompt = f"解释这段代码:\n{code}"
        return self._call_ai(prompt)
    
    def review_code(self, code):
        prompt = f"代码审查:\n{code}"
        return self._call_ai(prompt)
    
    def _call_ai(self, prompt):
        # 实现 AI 调用
        pass

# 使用示例
assistant = AIAssistant()
code = assistant.generate_code("快速排序算法")
print(code)
11.3 错误处理
python
def safe_ai_call(func, retries=3):
    """带重试的 AI 调用"""
    for i in range(retries):
        try:
            return func()
        except Exception as e:
            print(f"尝试 {i+1}/{retries} 失败: {e}")
            if i == retries - 1:
                raise
            time.sleep(2 ** i)  # 指数退避

# 使用示例
# result = safe_ai_call(lambda: llm.invoke("你的问题"))
11.4 结果验证
python
def validate_ai_output(output, expected_format="text"):
    """验证 AI 输出质量"""
    if not output or len(output) < 10:
        return False
    
    if expected_format == "code":
        # 检查是否包含代码
        return "def " in output or "class " in output or "import " in output
    
    if expected_format == "json":
        # 检查是否是有效 JSON
        try:
            import json
            json.loads(output)
            return True
        except:
            return False
    
    return True
11.5 成本优化
python
# 缓存常用结果
from functools import lru_cache

@lru_cache(maxsize=100)
def cached_ai_query(query):
    """缓存 AI 查询结果"""
    return llm.invoke(query)

# 使用更小的模型处理简单任务
def smart_ai_call(complexity="simple"):
    if complexity == "simple":
        model = "qwen2.5-coder:1.5b"
    else:
        model = "qwen2.5-coder:7b-q4"
    # 使用对应模型
11.6 安全建议
python
# 1. 不要硬编码 API 密钥
import os
API_KEY = os.environ.get('OPENAI_API_KEY')

# 2. 验证用户输入
def sanitize_input(user_input):
    """清理用户输入"""
    # 移除潜在的危险字符
    dangerous_chars = ['`', '$', '(', ')', ';']
    for char in dangerous_chars:
        user_input = user_input.replace(char, '')
    return user_input

# 3. 限制输出长度
def safe_ai_call(prompt, max_tokens=2048):
    return llm.invoke(prompt, max_tokens=max_tokens)

# 4. 记录 AI 交互日志
import logging
logging.basicConfig(
    filename='ai_interactions.log',
    level=logging.INFO,
    format='%(asctime)s - %(message)s'
)
📝 附录
A. 常用命令速查
命令	说明
%ai list	查看所有提供商
%ai list ollama	查看 Ollama 模型
%ai reset	重置对话历史
%load_ext jupyter_ai_magic_commands	加载 AI 扩展
%%ai model --temperature 0.5	带参数调用
B. 环境变量速查
变量	默认值	说明
OLLAMA_HOST	http://192.168.112.136:11434	Ollama 服务地址
OLLAMA_DEFAULT_MODEL	qwen2.5-coder:7b-q4	默认模型
OLLAMA_TEMPERATURE	0.7	温度参数
MAX_TOKENS	2048	最大输出长度
C. 故障排除快速指南
AI 命令无效: 运行 %load_ext jupyter_ai_magic_commands

模型不存在: 运行 %ai list 查看可用模型

Ollama 连接失败: 检查 OLLAMA_HOST 环境变量

配置未加载: 检查 LITELLM_CONFIG_PATH 路径

文档版本: v1.0
最后更新: 2026-05-04
Jupyter AI 版本: 3.0.0

Happy Coding with Jupyter AI v3! 🚀
EOF

#创建快速参考卡片
cat > /home/jovyan/QUICK_REFERENCE.md << 'EOF'

Jupyter AI v3 快速参考卡片
🚀 启动
bash
./start_jupyter_ai.sh
📖 基础命令
python
%load_ext jupyter_ai_magic_commands  # 加载扩展
%ai list                              # 查看模型
%%ai ollama/qwen2.5-coder:7b-q4      # 使用模型
🔥 深度学习
python
import torch, tensorflow as tf
print(torch.__version__, tf.__version__)
🦜 LangChain
python
from langchain_community.llms import Ollama
llm = Ollama(model="qwen2.5-coder:7b-q4", base_url="http://192.168.112.136:11434")
🗄️ 向量数据库
python
import chromadb
client = chromadb.Client()
📊 数据科学
python
import numpy as np, pandas as pd
import matplotlib.pyplot as plt
🔧 常用技巧
多轮对话自动记忆上下文

用 {variable} 传递变量

用 --temperature 0.5 调整随机性

用 --max-tokens 500 限制输出

🐛 问题排查
python
%ai list                    # 检查模型
%load_ext jupyter_ai_magic_commands  # 重新加载
!curl $OLLAMA_HOST/api/tags # 测试 Ollama
EOF


