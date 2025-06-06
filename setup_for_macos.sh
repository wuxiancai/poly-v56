#!/bin/bash

# 设置颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

echo "=== macOS 自动化安装脚本 ==="

# 检查系统和芯片类型
if [[ "$(uname)" != "Darwin" ]]; then
    echo "${RED}错误: 此脚本只能在 macOS 系统上运行${NC}"
    exit 1
fi

CHIP_TYPE=$(uname -m)
echo "检测到芯片类型: $CHIP_TYPE"

if [[ "$CHIP_TYPE" == "arm64" ]]; then
    BREW_PREFIX="/opt/homebrew"
else
    BREW_PREFIX="/usr/local"
fi

# 自动确认所有提示

export HOMEBREW_NO_AUTO_UPDATE=1
export NONINTERACTIVE=1
export CI=1
# 在 HOSTS 文件中添加 github.com 和 raw.githubusercontent.com 的记录
#echo "185.199.108.153 raw.githubusercontent.com" | sudo tee -a /etc/hosts
#echo "185.199.109.153 raw.githubusercontent.com" | sudo tee -a /etc/hosts
#echo "185.199.110.153 raw.githubusercontent.com" | sudo tee -a /etc/hosts
#echo "185.199.111.153 raw.githubusercontent.com" | sudo tee -a /etc/hosts

# 检查并安装 Homebrew (自动模式)
if ! command -v brew &> /dev/null; then
    echo "正在安装 Homebrew..."
    NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    
    if [[ "$CHIP_TYPE" == "arm64" ]]; then
        echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zshrc
        eval "$(/opt/homebrew/bin/brew shellenv)"
    fi
fi

# 更新 Homebrew
brew update

# 安装 Python 3.9 (自动模式)
echo "安装 Python 3.9..."
brew install python@3.9 --force
brew link --force --overwrite python@3.9
echo "安装 python-tk@3.9 (自动模式)"
brew install python-tk@3.9 --force
brew install wget

# 创建虚拟环境
echo "创建虚拟环境..."
python3.9 -m venv venv --clear
source venv/bin/activate

# 升级 pip3
echo "升级 pip3..."
python3.9 -m pip install --upgrade pip

# 安装依赖 (使用 pip3)
echo "安装依赖..."
pip3 install --no-cache-dir selenium
pip3 install --no-cache-dir pyautogui
pip3 install --no-cache-dir screeninfo
pip3 install --no-cache-dir requests
# pip3 install --no-cache-dir pytesseract
# pip3 install --no-cache-dir opencv-python-headless  # 安装headless版本，通常更稳定



# 配置 Python 环境变量 (避免重复添加)
echo "配置环境变量..."
if ! grep -q "# Python 配置" ~/.zshrc; then
    echo '# Python 配置' >> ~/.zshrc
    echo "export PATH=\"${BREW_PREFIX}/opt/python@3.9/bin:\$PATH\"" >> ~/.zshrc
    echo 'export TK_SILENCE_DEPRECATION=1' >> ~/.zshrc
fi

# 检查并安装 Chrome 和 ChromeDriver
echo "检查 Chrome 和 ChromeDriver..."

# 检查 Chrome 是否已安装
if [ -d "/Applications/Google Chrome.app" ]; then
    echo "${GREEN}Chrome 已安装${NC}"
    CHROME_INSTALLED=true
else
    echo "Chrome 未安装"
    CHROME_INSTALLED=false
fi

# 检查 ChromeDriver 是否已安装
if command -v chromedriver &> /dev/null; then
    echo "${GREEN}ChromeDriver 已安装${NC}"
    CHROMEDRIVER_INSTALLED=true
else
    echo "ChromeDriver 未安装"
    CHROMEDRIVER_INSTALLED=false
fi

# 根据检查结果进行安装
if [ "$CHROME_INSTALLED" = false ]; then
    echo "安装 Chrome..."
    brew install --cask google-chrome --force
fi

if [ "$CHROMEDRIVER_INSTALLED" = false ]; then
    echo "安装 ChromeDriver..."
    brew install chromedriver --force
fi

chmod +x start_chrome.sh
# 创建自动启动脚本

cat > run_trader.sh << 'EOL'
#! /bin/bash

# 打印接收到的参数，用于调试
echo "run_trader.sh received args: $@"

# 激活虚拟环境
source venv/bin/activate

# 运行交易程序
exec python3 -u crypto_trader.py "$@"
EOL

chmod +x run_trader.sh


# 验证安装
echo "=== 验证安装 ==="
echo "Python 路径: $(which python3)"
echo "Python 版本: $(python3 --version)"
echo "Pip 版本: $(pip3 --version)"
echo "已安装的包:"
pip3 list

# 创建自动化测试脚本
cat > test_environment.py << 'EOL'
import sys
import tkinter
import selenium
import pyautogui

def test_imports():
    modules = {
        'tkinter': tkinter,
        'selenium': selenium,
        'pyautogui': pyautogui
    }
    
    print("Python 版本:", sys.version)
    print("\n已安装模块:")
    for name, module in modules.items():
        print(f"{name}: {module.__version__ if hasattr(module, '__version__') else '已安装'}")

if __name__ == "__main__":
    test_imports()
EOL

# 运行测试
echo "运行环境测试..."
python3 test_environment.py

echo "${GREEN}安装完成！${NC}"
echo "使用说明:"
echo "1. 直接运行 ./run_trader.sh 即可启动程序"
echo "2. 程序会自动启动 Chrome 并运行交易脚本"
echo "3. 所有配置已自动完成，无需手动操作"

# 自动清理安装缓存
brew cleanup -s
pip3 cache purge
rm -rf test_environment.py
