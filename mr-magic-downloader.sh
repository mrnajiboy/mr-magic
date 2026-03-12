#!/bin/bash

# Mr. Magic - Song & Lyric Downloader

# The cool tool for downloading songs and lyrcs~

# =====INSTALLATION FUNCTIONS=====

# Function to install dependencies with Whisper support
install_dependencies() {
    clear
    echo "=== Mr. Magic - Dependency Installation ==="
    echo ""
    echo "This will install the following dependencies:"
    
    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo "1. Homebrew (package manager for macOS)"
    fi
    
    echo "2. pyenv (for Python version management)"
    echo "3. Python 3.9.9 (required for OpenAI Whisper)"
    echo "4. Python 3.12.7 (required for spotDL)"
    echo "5. spotDL v4 (music downloader)"
    echo "6. ffmpeg (media processing)"
    echo "7. jq (JSON processing)"
    echo "8. lyricsgenius (Python library for Genius lyrics)"
    echo "9. OpenAI Whisper (audio transcription)"
    echo "10. OpenSSL (encryption for API keys)"
    echo ""
    echo "Note: Some installations may require sudo privileges"
    echo ""
    # Use -r to avoid mangling backslashes in user input (SC2162)
    read -r -p "Continue with installation? (y/n): " continue_install
    
    if [[ ! "$continue_install" =~ ^[Yy]$ ]]; then
        echo "Installation cancelled."
        return 1
    fi
    
    # Check OS
    if [[ "$OSTYPE" == "darwin"* ]]; then
        install_dependencies_macos
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        install_dependencies_linux
    elif [[ "$OSTYPE" == "msys" || "$OSTYPE" == "win32" ]]; then
        install_dependencies_windows
    else
        echo "Unsupported operating system: $OSTYPE"
        echo "Please install dependencies manually."
        return 1
    fi
    
    # Setup pyenv environment
    setup_pyenv_environment
    
    # Install Whisper if user wants
    read -r -p "Would you like to install OpenAI Whisper for audio transcription? (y/n): " install_whisper_choice
    if [[ "$install_whisper_choice" =~ ^[Yy]$ ]]; then
        install_whisper
    fi

    echo "All dependencies installed successfully!"
    return 0
}

# Function to check if Whisper is installed
is_whisper_installed() {
    # Check if the whisper environment exists
    if command -v pyenv &> /dev/null; then
        if pyenv versions --bare | grep -q "whisper"; then
            # Try to activate and run whisper help
            eval "$(pyenv init -)"
            (pyenv activate whisper && command -v whisper) > /dev/null 2>&1
            return $?
        fi
    fi
    return 1
}

# Function to install Whisper
install_whisper() {
    echo "=== Installing OpenAI Whisper ==="
    echo "This will install:"
    echo "1. Python 3.9.9 (required for Whisper)"
    echo "2. A separate pyenv environment for Whisper"
    echo "3. OpenAI Whisper and its dependencies"
    echo ""
    read -r -p "Continue with installation? (y/n): " continue_install
    
    if [[ ! "$continue_install" =~ ^[Yy]$ ]]; then
        echo "Installation cancelled."
        return 1
    fi
    
    # Check if pyenv is installed
    if ! command -v pyenv &> /dev/null; then
        echo "pyenv is required for Whisper installation."
        echo "Please install dependencies first."
        return 1
    fi
    
    # Install Python 3.9.9 with pyenv if not already installed
    if ! pyenv versions --bare | grep -q "3.9.9"; then
        echo "Installing Python 3.9.9..."
        if ! pyenv install 3.9.9; then
            echo "Failed to install Python 3.9.9."
            return 1
        fi
    else
        echo "Python 3.9.9 is already installed."
    fi
    
    # Create a virtualenv for Whisper if not exists
    if ! pyenv versions --bare | grep -q "whisper"; then
        echo "Creating whisper environment..."
        if ! pyenv virtualenv 3.9.9 whisper; then
            echo "Failed to create whisper environment."
            return 1
        fi
    else
        echo "Whisper environment already exists."
    fi
    
    # Activate the whisper environment and install packages
    echo "Installing Whisper and dependencies..."
    eval "$(pyenv init -)"
    pyenv activate whisper
    
    # Install Whisper
    if ! pip install -U openai-whisper; then
        echo "Failed to install Whisper package."
        pyenv deactivate
        return 1
    fi
    
    # Install FFmpeg if not already installed
    if ! command -v ffmpeg &> /dev/null; then
        echo "FFmpeg is required for Whisper but not installed."
        echo "Please install FFmpeg using your package manager."
        
        # Try to install based on OS
        if [[ "$OSTYPE" == "darwin"* ]]; then
            # macOS
            echo "Attempting to install FFmpeg via Homebrew..."
            brew install ffmpeg
        elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
            # Linux
            if command -v apt-get &> /dev/null; then
                echo "Attempting to install FFmpeg via apt..."
                sudo apt-get update && sudo apt-get install -y ffmpeg
            elif command -v dnf &> /dev/null; then
                echo "Attempting to install FFmpeg via dnf..."
                sudo dnf install -y ffmpeg
            elif command -v pacman &> /dev/null; then
                echo "Attempting to install FFmpeg via pacman..."
                sudo pacman -S ffmpeg
            else
                echo "Please install FFmpeg manually."
            fi
        else
            echo "Please install FFmpeg manually."
        fi
    fi
    
    # Create Whisper script in dependencies directory
    create_whisper_script
    
    # Deactivate environment
    pyenv deactivate
    
    echo "Whisper installation complete!"
    return 0
}

# Function to check if lyricsgenius is installed in any Python environment
check_lyricsgenius_installed() {
    # First check system Python
    if python3 -c "import lyricsgenius" &> /dev/null; then
        return 0
    fi
    
    # Then check if any pyenv environments have it
    if command -v pyenv &> /dev/null; then
        # Save the current environment
        local current_env=$(pyenv version-name 2>/dev/null)
        
        # Loop through pyenv environments and check each one
        while read -r env; do
            if [[ -n "$env" ]]; then
                eval "$(pyenv init -)"
                if pyenv shell "$env" 2>/dev/null && python -c "import lyricsgenius" &> /dev/null; then
                    # Found in this environment, store it for later
                    echo "$env" > "$CACHE_DIR/lyricsgenius_env.txt"
                    pyenv shell "$current_env" 2>/dev/null || pyenv shell --unset
                    return 0
                fi
            fi
        done < <(pyenv versions --bare | grep -v system)
        
        # Restore original environment
        pyenv shell "$current_env" 2>/dev/null || pyenv shell --unset
    fi
    
    # Not found in any environment
    return 1
}

# Ensure the lrc2srt.py script is available
copy_lrc2srt_script() {
    if [ ! -f "$DEPENDENCIES_DIR/lrc2srt.py" ]; then
        # Create a simplified version of the lrc2srt.py script
        cat > "$DEPENDENCIES_DIR/lrc2srt.py" << 'EOF'
import os
import re
import sys

def parse_lrc_timestamp(timestamp):
    try:
        minutes, seconds = timestamp.split(':')
        seconds, milliseconds = seconds.split('.')
        minutes, seconds, milliseconds = int(minutes), int(seconds), int(milliseconds)
        return minutes * 60 + seconds + milliseconds / 100
    except ValueError:
        return None

def format_time(seconds):
    hours = int(seconds) // 3600
    minutes = (int(seconds) % 3600) // 60
    seconds_int = int(seconds) % 60
    milliseconds = int((seconds - int(seconds)) * 1000)
    return f"{hours:02d}:{minutes:02d}:{seconds_int:02d},{milliseconds:03d}"

def lrc_to_srt(lrc_file_path, srt_file_path):
    with open(lrc_file_path, 'r', encoding='utf-8') as lrc_file:
        lrc_content = lrc_file.read()

    subs = []
    pattern = r'\[(\d+:\d+\.\d+)\](.*)'
    matches = re.findall(pattern, lrc_content)
    
    for idx, match in enumerate(matches):
        timestamp, text = match
        start_time = parse_lrc_timestamp(timestamp)
        if start_time is not None:
            end_time = parse_lrc_timestamp(matches[idx + 1][0]) if idx + 1 < len(matches) else start_time + 5
            subs.append(f"{len(subs) + 1}\n{format_time(start_time)} --> {format_time(end_time)}\n{text.strip()}\n")

    with open(srt_file_path, 'w', encoding='utf-8') as srt_file:
        srt_file.writelines(subs)

if __name__ == "__main__":
    if len(sys.argv) == 3:
        lrc_file = sys.argv[1]
        srt_file = sys.argv[2]
        lrc_to_srt(lrc_file, srt_file)
        print(f"Converted '{lrc_file}' to '{srt_file}'")
    else:
        print("Usage: python lrc2srt.py input.lrc output.srt")
EOF
        echo "Created LRC to SRT conversion script"
        debug_log "Created LRC to SRT conversion script at $DEPENDENCIES_DIR/lrc2srt.py"
    fi
}

# Function to install dependencies on macOS
install_dependencies_macos() {
    echo "=== Installing dependencies for macOS ==="
    
    # Check if Homebrew is installed
    if ! command -v brew &>/dev/null; then
        echo "Installing Homebrew (package manager for macOS)..."
        echo "Visit https://brew.sh for more information"
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        
        # Check if Homebrew was installed successfully
        if ! command -v brew &>/dev/null; then
            echo "Failed to install Homebrew. Please install it manually from https://brew.sh"
            return 1
        else
            echo "Homebrew installed successfully!"
        fi
    else
        echo "Homebrew is already installed."
    fi
    
    # Install dependencies
    echo "Installing pyenv..."
    brew install pyenv
    
    echo "Installing ffmpeg..."
    brew install ffmpeg
    
    echo "Installing jq..."
    brew install jq
    
    echo "Installing OpenSSL..."
    brew install openssl
    
    # Add pyenv to shell if not already present
    if ! grep -q "pyenv init" ~/.zshrc &>/dev/null && ! grep -q "pyenv init" ~/.bash_profile &>/dev/null; then
        echo "Adding pyenv to shell configuration..."
        if [[ -f ~/.zshrc ]]; then
            echo 'eval "$(pyenv init -)"' >> ~/.zshrc
            source ~/.zshrc
        else
            echo 'eval "$(pyenv init -)"' >> ~/.bash_profile
            source ~/.bash_profile
        fi
    fi
    
    echo "macOS dependencies installed successfully."
}

# Function to install dependencies on Linux
install_dependencies_linux() {
    echo "=== Installing dependencies for Linux ==="
    
    # Detect package manager
    if command -v apt-get &>/dev/null; then
        # Debian/Ubuntu
        echo "Detected Debian/Ubuntu-based system"
        
        echo "Installing required packages..."
        sudo apt-get update
        sudo apt-get install -y build-essential libssl-dev zlib1g-dev libbz2-dev \
            libreadline-dev libsqlite3-dev wget curl llvm libncurses5-dev libncursesw5-dev \
            xz-utils tk-dev libffi-dev liblzma-dev git
        
        echo "Installing ffmpeg..."
        sudo apt-get install -y ffmpeg
        
        echo "Installing jq..."
        sudo apt-get install -y jq
        
        echo "Installing OpenSSL..."
        sudo apt-get install -y openssl
        
        # Install pyenv
        echo "Installing pyenv..."
        curl https://pyenv.run | bash
        
        # Add pyenv to shell if not already present
        if ! grep -q "pyenv init" ~/.bashrc &>/dev/null; then
            echo "Adding pyenv to shell configuration..."
            echo 'export PATH="$HOME/.pyenv/bin:$PATH"' >> ~/.bashrc
            echo 'eval "$(pyenv init -)"' >> ~/.bashrc
            echo 'eval "$(pyenv virtualenv-init -)"' >> ~/.bashrc
            source ~/.bashrc
        fi
        
    elif command -v dnf &>/dev/null; then
        # Fedora/RHEL
        echo "Detected Fedora/RHEL-based system"
        
        echo "Installing required packages..."
        sudo dnf install -y make gcc zlib-devel bzip2 bzip2-devel readline-devel sqlite sqlite-devel \
            openssl-devel tk-devel libffi-devel git
        
        echo "Installing ffmpeg..."
        sudo dnf install -y ffmpeg
        
        echo "Installing jq..."
        sudo dnf install -y jq
        
        echo "Installing OpenSSL..."
        sudo dnf install -y openssl openssl-devel
        
        # Install pyenv
        echo "Installing pyenv..."
        curl https://pyenv.run | bash
        
        # Add pyenv to shell if not already present
        if ! grep -q "pyenv init" ~/.bashrc &>/dev/null; then
            echo "Adding pyenv to shell configuration..."
            echo 'export PATH="$HOME/.pyenv/bin:$PATH"' >> ~/.bashrc
            echo 'eval "$(pyenv init -)"' >> ~/.bashrc
            echo 'eval "$(pyenv virtualenv-init -)"' >> ~/.bashrc
            source ~/.bashrc
        fi
        
    elif command -v pacman &>/dev/null; then
        # Arch Linux
        echo "Detected Arch-based system"
        
        echo "Installing required packages..."
        sudo pacman -Sy base-devel openssl zlib bzip2 readline sqlite curl llvm xz tk libffi git
        
        echo "Installing ffmpeg..."
        sudo pacman -S ffmpeg
        
        echo "Installing jq..."
        sudo pacman -S jq
        
        echo "Installing OpenSSL..."
        sudo pacman -S openssl
        
        # Install pyenv
        echo "Installing pyenv..."
        curl https://pyenv.run | bash
        
        # Add pyenv to shell if not already present
        if ! grep -q "pyenv init" ~/.bashrc &>/dev/null; then
            echo "Adding pyenv to shell configuration..."
            echo 'export PATH="$HOME/.pyenv/bin:$PATH"' >> ~/.bashrc
            echo 'eval "$(pyenv init -)"' >> ~/.bashrc
            echo 'eval "$(pyenv virtualenv-init -)"' >> ~/.bashrc
            source ~/.bashrc
        fi
    else
        echo "Unsupported Linux distribution. Please install dependencies manually."
        return 1
    fi
    
    echo "Linux dependencies installed successfully."
}

# Function to install dependencies on Windows (via MSYS2/Git Bash)
install_dependencies_windows() {
    echo "=== Installing dependencies for Windows ==="
    
    echo "Note: Windows installation is best done manually."
    echo "Please follow these steps:"
    echo ""
    echo "1. Install Python 3.12.7 from python.org"
    echo "2. Install ffmpeg: https://ffmpeg.org/download.html#build-windows"
    echo "3. Install jq: https://stedolan.github.io/jq/download/"
    echo "4. Install OpenSSL: https://slproweb.com/products/Win32OpenSSL.html"
    echo "5. Install spotDL via pip: pip install spotdl"
    echo ""
    echo "For pyenv on Windows, consider using pyenv-win:"
    echo "https://github.com/pyenv-win/pyenv-win"
    echo ""
    
    read -p "Would you like to try automatic installation anyway? (y/n): " windows_auto
    
    if [[ ! "$windows_auto" =~ ^[Yy]$ ]]; then
        echo "Manual installation recommended. Exiting dependency installation."
        return 1
    fi
    
    # Try to install via pacman (MSYS2)
    if command -v pacman &>/dev/null; then
        echo "MSYS2 detected, attempting installation..."
        
        echo "Installing dependencies..."
        pacman -Syu --noconfirm
        pacman -S --noconfirm git base-devel mingw-w64-x86_64-toolchain
        
        echo "Installing ffmpeg..."
        pacman -S --noconfirm mingw-w64-x86_64-ffmpeg
        
        echo "Installing jq..."
        pacman -S --noconfirm mingw-w64-x86_64-jq
        
        echo "Installing OpenSSL..."
        pacman -S --noconfirm mingw-w64-x86_64-openssl
        
        # For pyenv on MSYS2, recommend pyenv-win
        echo "For pyenv on Windows, please install pyenv-win manually:"
        echo "https://github.com/pyenv-win/pyenv-win"
    else
        echo "MSYS2 not detected. Please install dependencies manually."
        return 1
    fi
    
    echo "Windows dependencies partially installed. Please verify manually."
}

# Function to setup pyenv environment with installation options
setup_pyenv_environment() {
    echo "=== Setting up Python environment with pyenv ==="
    
    # Check if pyenv is installed
    if ! command -v pyenv &>/dev/null; then
        echo "pyenv is not installed or not in PATH."
        echo "Please install pyenv manually and try again."
        return 1
    fi
    
    # Ask for environment name
    echo "Default virtual environment name: spotdl"
    read -p "Enter environment name (or press Enter for default): " env_name
    env_name=${env_name:-spotdl}
    
    echo "Python installation options:"
    echo "1) Install Python only in the virtual environment (recommended)"
    echo "2) Install Python globally with pyenv"
    echo "3) Use existing Python installation"
    read -p "Select an option (1-3): " python_install_option
    
    case $python_install_option in
        1)
            # Install Python 3.12.7 in virtual environment only
            echo "Installing Python 3.12.7 via pyenv (virtual environment only)..."
            pyenv install 3.12.7
            
            # Create virtualenv
            echo "Creating virtual environment: $env_name"
            pyenv virtualenv 3.12.7 "$env_name"
            
            # Activate environment
            echo "Activating environment..."
            pyenv local "$env_name"
            eval "$(pyenv init -)"
            pyenv activate "$env_name"
            ;;
        2)
            # Install Python 3.12.7 globally
            echo "Installing Python 3.12.7 via pyenv (globally)..."
            pyenv install 3.12.7
            pyenv global 3.12.7
            
            # Create virtualenv
            echo "Creating virtual environment: $env_name"
            pyenv virtualenv 3.12.7 "$env_name"
            
            # Activate environment
            echo "Activating environment..."
            pyenv local "$env_name"
            eval "$(pyenv init -)"
            pyenv activate "$env_name"
            ;;
        3)
            # Use existing Python
            echo "Using existing Python installation..."
            python_version=$(python3 --version 2>/dev/null)
            
            if [ -z "$python_version" ]; then
                echo "Error: Python 3 not found. Please install Python 3 first."
                return 1
            fi
            
            echo "Found: $python_version"
            
            # Create virtualenv with existing Python
            echo "Creating virtual environment: $env_name"
            python3 -m venv "$APP_DIR/$env_name"
            
            # Activate environment
            echo "Activating environment..."
            source "$APP_DIR/$env_name/bin/activate"
            ;;
        *)
            echo "Invalid option. Using default (virtual environment only)."
            pyenv install 3.12.7
            pyenv virtualenv 3.12.7 "$env_name"
            pyenv local "$env_name"
            eval "$(pyenv init -)"
            pyenv activate "$env_name"
            ;;
    esac
    
    # Install spotDL
    echo "Installing spotDL..."
    pip install spotdl

    # Install lyricsgenius
    echo "Installing lyricsgenius..."
    pip install lyricsgenius
    
    echo "Python environment setup complete!"
    echo "Virtual environment: $env_name"
    echo "To activate manually, use: pyenv activate $env_name"
}

# Create uninstall.sh script
create_uninstall_script() {
    local uninstall_script="$APP_DIR/uninstall.sh"
    
    cat > "$uninstall_script" << 'EOF'
#!/bin/bash

# Mr. Magic - Uninstaller Script
echo "=== Mr. Magic - Uninstaller ==="
echo ""
echo "This will remove all files and configurations created by Mr. Magic."
echo ""
echo "The following will be deleted:"
echo "- All configuration files"
echo "- API credentials"
echo "- Cache files"
echo "- Script files"
echo ""
echo "Type 'UNINSTALL' (all caps) to confirm:"
read -p "> " confirm

if [ "$confirm" != "UNINSTALL" ]; then
    echo "Uninstall cancelled."
    exit 1
fi

# Get the script directory
APP_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Ask about removing dependencies
echo ""
echo "Would you like to remove installed dependencies?"
echo "1) No, keep all dependencies (Python, spotDL, ffmpeg, etc.)"
echo "2) Remove spotDL only"
echo "3) Remove python packages only (spotDL, lyricsgenius, Whisper)"
echo "4) Remove python packages and environments"
echo "5) Remove ALL dependencies"
echo ""
read -p "Enter your choice (1-5): " dep_choice

case $dep_choice in
    2)
        echo "Removing spotDL..."
        pip uninstall -y spotdl 2>/dev/null || true
        ;;
    3)
        echo "Removing spotDL, lyricsgenius and Whisper..."
        pip uninstall -y spotdl 2>/dev/null || true
        pip uninstall -y lyricsgenius 2>/dev/null || true
        
        # Try to find the whisper environment
        if command -v pyenv &>/dev/null; then
            echo "Checking for Whisper environment..."
            env_list=$(pyenv virtualenvs 2>/dev/null)
            if [[ "$env_list" == *"whisper"* ]]; then
                echo "Removing whisper pip packages..."
                eval "$(pyenv init -)"
                pyenv activate whisper 2>/dev/null && pip uninstall -y openai-whisper 2>/dev/null || true
                pyenv deactivate 2>/dev/null || true
            fi
        fi
        ;;
    4)
        echo "Removing spotDL, Whisper, lyricsgenius and their Python environments..."
        # Try to find the active pyenv environment
        if command -v pyenv &>/dev/null; then
            # Get current pyenv environments
            env_list=$(pyenv virtualenvs 2>/dev/null)
            
            # Remove spotDL environment
            if [[ "$env_list" == *"spotdl"* ]]; then
                echo "Removing spotdl environment..."
                pyenv uninstall -f spotdl
            elif [[ "$env_list" == *"mdsh"* ]]; then
                echo "Removing mdsh environment..."
                pyenv uninstall -f mdsh
            fi
            
            # Remove whisper environment
            if [[ "$env_list" == *"whisper"* ]]; then
                echo "Removing whisper environment..."
                pyenv uninstall -f whisper
            fi
        fi
        
        # Also try pip uninstall
        pip uninstall -y spotdl 2>/dev/null || true
        pip uninstall -y openai-whisper 2>/dev/null || true
        pip uninstall -y lyricsgenius 2>/dev/null || true
        ;;
    5)
        echo "Removing ALL dependencies..."
        # Remove spotDL, Whisper, lyricsgenius and their environments
        pip uninstall -y spotdl openai-whisper lyricsgenius 2>/dev/null || true
        
        if command -v pyenv &>/dev/null; then
            # Remove pyenv environments
            env_list=$(pyenv virtualenvs 2>/dev/null)
            if [[ "$env_list" == *"spotdl"* ]]; then
                pyenv uninstall -f spotdl
            elif [[ "$env_list" == *"mdsh"* ]]; then
                pyenv uninstall -f mdsh
            fi
            
            # Remove whisper environment
            if [[ "$env_list" == *"whisper"* ]]; then
                echo "Removing whisper environment..."
                pyenv uninstall -f whisper
            fi
            
            # Ask about removing Python versions too
            read -p "Remove Python versions installed by pyenv? (y/n): " remove_python
            if [[ "$remove_python" =~ ^[Yy]$ ]]; then
                echo "Removing Python versions..."
                if pyenv versions --bare | grep -q "3.12.7"; then
                    pyenv uninstall -f 3.12.7
                fi
                if pyenv versions --bare | grep -q "3.9.9"; then
                    pyenv uninstall -f 3.9.9
                fi
            fi
            
            # Ask about removing pyenv
            read -p "Remove pyenv completely? (y/n): " remove_pyenv
            if [[ "$remove_pyenv" =~ ^[Yy]$ ]]; then
                echo "Removing pyenv..."
                rm -rf "$HOME/.pyenv"
                
                # Clean up shell configuration files
                for rcfile in "$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.bash_profile"; do
                    if [ -f "$rcfile" ]; then
                        echo "Removing pyenv references from $rcfile..."
                        sed -i'.bak' '/pyenv/d' "$rcfile"
                    fi
                done
            fi
        fi
        
        # Warn about package managers
        echo ""
        echo "Note: System packages like ffmpeg, jq, and openssl should be"
        echo "removed using your system's package manager:"
        
        if command -v brew &>/dev/null; then
            echo "  brew uninstall ffmpeg jq openssl"
        elif command -v apt-get &>/dev/null; then
            echo "  sudo apt-get remove ffmpeg jq openssl"
        elif command -v dnf &>/dev/null; then
            echo "  sudo dnf remove ffmpeg jq openssl"
        elif command -v pacman &>/dev/null; then
            echo "  sudo pacman -R ffmpeg jq openssl"
        fi
        ;;
    *)
        echo "Keeping all dependencies."
        ;;
esac

# Remove app directories
echo "Removing application files..."
rm -rf "$APP_DIR/configs"
rm -rf "$APP_DIR/dependencies"
rm -rf "$APP_DIR/cache"
rm -rf "$APP_DIR/api"

# Remove SpotDL config symlink if it exists
if [ -L "$HOME/.spotdl/config.json" ]; then
    rm "$HOME/.spotdl/config.json"
    echo "Removed SpotDL config symlink."
fi

# Offer to remove downloads
echo ""
echo "Would you like to keep downloaded songs and lyrics? (y/n)"
read -p "> " keep_downloads

if [[ "$keep_downloads" =~ ^[Nn]$ ]]; then
    echo "What is your download directory?"
    echo "1) Default location (script directory)"
    echo "2) Custom location"
    echo "3) Skip removing downloads"
    read -p "Choose option (1-3): " download_option
    
    case $download_option in
        1)
            echo "Removing downloads from script directory..."
            rm -f "$APP_DIR"/*.mp3
            rm -f "$APP_DIR"/*.flac
            rm -f "$APP_DIR"/*.m4a
            rm -f "$APP_DIR"/*.wav
            rm -f "$APP_DIR"/*.opus
            rm -f "$APP_DIR"/*.lrc
            rm -f "$APP_DIR"/*.srt
            rm -f "$APP_DIR"/*.txt
            ;;
        2)
            read -p "Enter the full path to your download directory: " download_dir
            if [ -d "$download_dir" ]; then
                echo "This will remove all audio and lyrics files from $download_dir"
                read -p "Are you sure? (y/n): " remove_confirm
                
                if [[ "$remove_confirm" =~ ^[Yy]$ ]]; then
                    rm -f "$download_dir"/*.mp3
                    rm -f "$download_dir"/*.flac
                    rm -f "$download_dir"/*.m4a
                    rm -f "$download_dir"/*.wav
                    rm -f "$download_dir"/*.opus
                    rm -f "$download_dir"/*.lrc
                    rm -f "$download_dir"/*.srt
                    rm -f "$download_dir"/*.txt
                    echo "Removed downloaded files from $download_dir"
                fi
            else
                echo "Directory not found. Skipping download removal."
            fi
            ;;
        *)
            echo "Skipping download removal."
            ;;
    esac
fi

# Remove the main script
echo "Removing main script..."
rm -f "$APP_DIR/mr-magic-downloader.sh"

# Remove the uninstall script itself as the final step
echo "Creating self-destruct script..."
# Create a temporary script to remove the uninstaller itself
cat > "$APP_DIR/cleanup.sh" << 'CLEANUP'
#!/bin/bash
# Wait for parent process to exit
sleep 1
# Remove the uninstaller
rm -f "$0"
rm -f "$(dirname "$0")/uninstall.sh"
# Check if APP_DIR is empty and can be removed
if [ -z "$(ls -A "$(dirname "$0")")" ]; then
    rmdir "$(dirname "$0")"
    echo "Removed empty application directory."
fi
CLEANUP

chmod +x "$APP_DIR/cleanup.sh"
"$APP_DIR/cleanup.sh" &

echo ""
echo "Mr. Magic has been uninstalled successfully."
echo "Thank you for using Mr. Magic!"
exit 0
EOF

    chmod +x "$uninstall_script"
    echo "Created uninstall script at $uninstall_script"
}

# =====DIRECTORY FUNCTIONS=====

# Define app directory structure
APP_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
CONFIG_DIR="$APP_DIR/configs"
PRESETS_DIR="$CONFIG_DIR/presets"
DEPENDENCIES_DIR="$APP_DIR/dependencies"
CACHE_DIR="$APP_DIR/cache"
API_DIR="$APP_DIR/api"
CURRENT_CONFIG="$CONFIG_DIR/current_config.json"

# Default settings
DEBUG_MODE=false
DEBUG_FILE="$CACHE_DIR/debug.log"
OUTPUT_DIR=""
ACTIVE_CONFIG="default"

# Create directory structure if it doesn't exist
if [ "$DEBUG_MODE" = true ]; then
    mkdir -p "$CONFIG_DIR" "$PRESETS_DIR" "$DEPENDENCIES_DIR" "$CACHE_DIR" "$API_DIR"
else
    mkdir -p "$CONFIG_DIR" "$PRESETS_DIR" "$DEPENDENCIES_DIR" "$CACHE_DIR" "$API_DIR" 2>/dev/null
fi

# Function to validate and expand directory paths
validate_directory() {
    local dir="$1"
    
    # Expand tilde and variables
    dir=$(eval echo "$dir")
    
    # Create directory if it doesn't exist
    if [ ! -d "$dir" ]; then
        # Fix: Add proper prompt with -p flag
        read -p "Directory does not exist. Create it? (y/n): " create_dir
        if [[ "$create_dir" =~ ^[Yy]$ ]]; then
            mkdir -p "$dir" || { echo "Failed to create directory."; return 1; }
            echo "Directory created."
        else
            echo "Directory not created."
            return 1
        fi
    fi
    
    # Check if directory is writable
    if [ ! -w "$dir" ]; then
        echo "Directory is not writable."
        return 1
    fi
    
    # Return the expanded, validated directory path
    echo "$dir"
    return 0
}

# Function to set output directory with proper return values
set_output_directory() {
    echo "Where would you like to save your files?"
    echo ""
    echo "1) Default location (script folder): $APP_DIR"
    echo "2) Desktop (~/Desktop/Magic Output)"
    echo "3) Downloads folder (~/Downloads)"
    echo "4) Enter custom directory path"
    echo "5) Go back to previous menu"
    echo "6) Cancel"
    read -p "Enter your choice (1-6): " choice
    debug_log "User selected directory choice: $choice"
    
    local dir=""
    case $choice in
        1)
            dir="$APP_DIR"
            echo "Selected directory: $dir"
            ;;
        2)
            dir="$HOME/Desktop/Magic Output"
            echo "Selected directory: $dir"
            # Create directory if it doesn't exist
            if [ ! -d "$dir" ]; then
                mkdir -p "$dir" || { echo "Failed to create directory."; return 1; }
                echo "Desktop folder created."
            fi
            ;;
        3)
            dir="$HOME/Downloads"
            echo "Selected directory: $dir"
            # Ensure directory exists
            if [ ! -d "$dir" ]; then
                mkdir -p "$dir" || { echo "Failed to create directory."; return 1; }
            fi
            ;;
        4)
            read -p "Enter the directory path (supports ~, relative paths) or 'c' to cancel: " custom_dir
            if [ "$custom_dir" = "c" ]; then
                echo "Operation cancelled."
                return 1
            fi
            
            # Expand tilde and variables
            dir=$(eval echo "$custom_dir")
            
            # Create directory if it doesn't exist
            if [ ! -d "$dir" ]; then
                read -p "Directory does not exist. Create it? (y/n): " create_dir
                if [[ "$create_dir" =~ ^[Yy]$ ]]; then
                    mkdir -p "$dir" || { echo "Failed to create directory."; return 1; }
                    echo "Directory created."
                else
                    echo "Directory not created."
                    return 1
                fi
            fi
            
            # Check if directory is writable
            if [ ! -w "$dir" ]; then
                echo "Directory is not writable."
                return 1
            fi
            
            echo "Selected directory: $dir"
            ;;
        5)
            echo "Returning to previous menu."
            return 1
            ;;
        6)
            echo "Operation cancelled."
            return 1
            ;;
        *)
            echo "Invalid choice. Operation cancelled."
            return 1
            ;;
    esac
    
    # Confirm the directory selection
    echo ""
    echo "You have selected: $dir"
    read -p "Confirm this directory? (y/n): " confirm
    
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo "Directory selection cancelled."
        return 1
    fi
    
    OUTPUT_DIR="$dir"
    
    # Update the current config with new output directory
    jq ".output = \"$OUTPUT_DIR/{artists} - {title}.{output-ext}\"" "$CURRENT_CONFIG" > "$CURRENT_CONFIG.tmp" && mv "$CURRENT_CONFIG.tmp" "$CURRENT_CONFIG"
    
    debug_log "Output directory set to: $OUTPUT_DIR"
    
    # Ensure the directory has proper permissions
    chmod 755 "$OUTPUT_DIR"
    
    # Make sure the cache directory is also correct and writable
    local cache_dir="$HOME/.mr-magic/cache"
    if [ "$DEBUG_MODE" = true ]; then
        mkdir -p "$cache_dir/.spotipy"
        chmod -R 755 "$cache_dir"
    else
        mkdir -p "$cache_dir/.spotipy" 2>/dev/null
        chmod -R 755 "$cache_dir" 2>/dev/null
    fi
    
    # Update cache path in config
    jq ".cache_path = \"$cache_dir/.spotipy\"" "$CURRENT_CONFIG" > "$CURRENT_CONFIG.tmp" && mv "$CURRENT_CONFIG.tmp" "$CURRENT_CONFIG"
    
    # Now sync to make sure spotDL uses this directory
    sync_with_spotdl_config
    
    return 0
}

# Function to open directory in Finder/Explorer
open_directory() {
    local dir="$1"
    if [ -d "$dir" ]; then
        echo -e "\nOpening directory: $dir"
        if [[ "$OSTYPE" == "darwin"* ]]; then
            # macOS
            open "$dir"
        elif [[ "$OSTYPE" == "msys" || "$OSTYPE" == "win32" ]]; then
            # Windows
            explorer "$dir"
        elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
            # Linux
            if command -v xdg-open &> /dev/null; then
                xdg-open "$dir"
            else
                echo "Cannot open directory: xdg-open command not found"
            fi
        else
            echo "Cannot open directory: Unsupported operating system"
        fi
    else
        echo "Error: Cannot open directory: $dir"
    fi
}


# =====INITIALIZATION FUNCTIONS=====

# Function to initialize app versioning
initialize_app_versioning() {
    # --- Determine the script's own directory ---
    # This finds the absolute path to the directory where the script itself resides.
    local SCRIPT_DIR # Make SCRIPT_DIR local to the function if preferred
    SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

    # --- Construct full path to CHANGELOG.md ---
    local CHANGELOG_FILE="$SCRIPT_DIR/CHANGELOG.md"

    # --- Extract version and year from CHANGELOG.md if it exists ---
    if [ -f "$CHANGELOG_FILE" ]; then
        # Read the first matching header line (most recent release)
        local CHANGELOG_HEADER # Make local if preferred
        CHANGELOG_HEADER=$(grep -m 1 '^## \[' "$CHANGELOG_FILE")

        if [ -n "$CHANGELOG_HEADER" ]; then
            # Extract Version
            VERSION=$(echo "$CHANGELOG_HEADER" | sed -E 's/^## \[(.*)\].*/\1/')
            # Extract Year
            VERSION_YEAR=$(echo "$CHANGELOG_HEADER" | grep -o -E '20[0-9]{2}' | head -n 1)

            # Trim potential whitespace/hidden characters
            VERSION=$(echo "$VERSION" | tr -d '[:space:]\r\n')
            VERSION_YEAR=$(echo "$VERSION_YEAR" | tr -d '[:space:]\r\n')
        fi
    else
        # Optionally add a warning if the changelog isn't found
        # echo "Warning: CHANGELOG.md not found at $CHANGELOG_FILE" >&2
        : # No operation, variables remain empty
    fi
}

# Function to initialize app settings
initialize_app_settings() {
    local app_settings_file="$CONFIG_DIR/app_settings.json"
    
    # Create app settings file if it doesn't exist
    if [ ! -f "$app_settings_file" ]; then
        cat > "$app_settings_file" << EOF
{
    "sync_method": "copy",
    "app_version": "0.2",
    "last_directory": "$HOME/Music",
    "default_ai_provider": "openai",
    "default_ai_models": {
        "openai": "gpt-3.5-turbo",
        "anthropic": "claude-3-7-sonnet-20250219"
    }
}
EOF
        debug_log "Created app settings file: $app_settings_file"
    fi
    
    # Make sure the default SpotDL config has LRC generation enabled
    local default_config="$CONFIG_DIR/default.json"
    if [ -f "$default_config" ]; then
        local lrc_enabled=$(jq -r '.generate_lrc // false' "$default_config")
        if [ "$lrc_enabled" != "true" ]; then
            jq '.generate_lrc = true' "$default_config" > "$default_config.tmp" && mv "$default_config.tmp" "$default_config"
            debug_log "Enabled LRC generation in default config"
        fi
    fi
}

# Initialize or update the credentials file
initialize_credentials() {
    local credentials_file="$API_DIR/credentials.json"
    
    if [ ! -f "$credentials_file" ]; then
        # Create a template credentials file
        cat > "$credentials_file" << EOF
{
  "ai_models": {
    "openai": {
      "api_key": "",
      "default_model": "gpt-3.5-turbo",
      "api_url": "https://api.openai.com/v1/chat/completions",
      "parameters": {
        "temperature": 0.3,
        "max_tokens": 4000,
        "top_p": 1.0,
        "frequency_penalty": 0.0,
        "presence_penalty": 0.0
      }
    },
    "anthropic": {
      "api_key": "",
      "default_model": "claude-3-7-sonnet-20250219",
      "api_url": "https://api.anthropic.com/v1/messages",
      "parameters": {
        "temperature": 0.3,
        "max_tokens": 32000,
        "top_p": 1.0,
        "use_extended_context": true,
        "anthropic_version": "2023-06-01"
      },
      "available_models": [
        "claude-3-7-sonnet-20250219",
        "claude-3-5-sonnet-20241022",
        "claude-3-5-haiku-20241022",
        "claude-3-opus-20240229",
        "claude-3-sonnet-20240229",
        "claude-3-haiku-20240307"
      ]
    },
    "custom": {
      "enabled": false,
      "provider_name": "Custom Provider",
      "api_key": "",
      "api_url": "",
      "default_model": "",
      "parameters": {
        "temperature": 0.7,
        "max_tokens": 4000
      }
    }
  },
  "default_ai_provider": "openai",
  "genius": {
    "client_id": "",
    "client_secret": "",
    "api_token": ""
  },
  "credentials_encrypted": false,
  "last_used_timestamp": "$(date +%Y-%m-%d)"
}
EOF
        chmod 600 "$credentials_file"  # Secure the credentials file
        echo "Created template credentials file at $credentials_file"
        debug_log "Created template credentials file"
    fi
}

# Add this function to detect non-Latin characters
detect_non_latin() {
    local file="$1"
    if [ -f "$file" ]; then
        # Use grep with Unicode character ranges for East Asian scripts only
        # This specifically targets:
        # - Hangul (Korean): \u3131-\u318E, \uAC00-\uD7A3
        # - CJK Unified Ideographs (Chinese, Japanese, Korean): \u4E00-\u9FFF
        # - Hiragana (Japanese): \u3040-\u309F
        # - Katakana (Japanese): \u30A0-\u30FF
        if grep -P "[\u3131-\u318E\uAC00-\uD7A3\u4E00-\u9FFF\u3040-\u309F\u30A0-\u30FF]" "$file" > /dev/null 2>&1; then
            return 0  # East Asian characters found
        fi
        
        # Fallback if grep doesn't support Unicode: try file command
        if file "$file" | grep -i "utf-8\|unicode" > /dev/null && file "$file" | grep -i "cjk\|asian\|japanese\|chinese\|korean" > /dev/null; then
            return 0  # East Asian character encoding detected
        fi
    fi
    return 1  # No East Asian characters found or file not found
}

# URL encode function
urlencode() {
    local string="$1"
    local strlen=${#string}
    local encoded=""
    local pos c o
    
    for (( pos=0; pos<strlen; pos++ )); do
        c=${string:$pos:1}
        case "$c" in
            [-_.~a-zA-Z0-9] ) o="${c}" ;;
            * )               printf -v o '%%%02x' "'$c"
        esac
        encoded+="${o}"
    done
    echo "${encoded}"
}

# =====ENCRYPTION FUNCTIONS=====

# Check required dependencies before using encryption functions
check_encryption_dependencies() {
    if ! command -v openssl &> /dev/null; then
        echo "OpenSSL is required for API key encryption but is not installed."
        echo "Would you like to install OpenSSL now? (y/n): "
        read install_openssl
        
        if [[ "$install_openssl" =~ ^[Yy]$ ]]; then
            # Install OpenSSL based on OS
            if [[ "$OSTYPE" == "darwin"* ]]; then
                # macOS
                if command -v brew &> /dev/null; then
                    brew install openssl
                else
                    echo "Homebrew not found. Please install Homebrew first:"
                    echo "/bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
                    return 1
                fi
            elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
                # Linux
                if command -v apt-get &> /dev/null; then
                    sudo apt-get update && sudo apt-get install -y openssl
                elif command -v dnf &> /dev/null; then
                    sudo dnf install -y openssl
                elif command -v pacman &> /dev/null; then
                    sudo pacman -S openssl
                else
                    echo "Unsupported Linux distribution. Please install OpenSSL manually."
                    return 1
                fi
            elif [[ "$OSTYPE" == "msys" || "$OSTYPE" == "win32" ]]; then
                # Windows
                echo "Please install OpenSSL manually on Windows from:"
                echo "https://slproweb.com/products/Win32OpenSSL.html"
                return 1
            fi
            
            # Check if installation was successful
            if ! command -v openssl &> /dev/null; then
                echo "Failed to install OpenSSL. Please install it manually."
                return 1
            fi
        else
            echo "OpenSSL installation skipped. Encryption features will not be available."
            return 1
        fi
    fi
    
    return 0
}

# Function to encrypt a file using openssl
encrypt_file() {
    local file="$1"
    local encrypted_file="${file}.enc"
    local password="$2"
    
    # Check if openssl is available
    if ! command -v openssl &> /dev/null; then
        echo "Error: openssl is required for encryption."
        return 1
    fi
    
    # Encrypt the file
    if echo "$password" | openssl enc -aes-256-cbc -salt -pbkdf2 -in "$file" -out "$encrypted_file" -pass stdin; then
        # If successful, remove the original file
        rm "$file"
        echo "File encrypted successfully."
        return 0
    else
        echo "Error: Failed to encrypt file."
        return 1
    fi
}

# Function to decrypt a file using openssl
decrypt_file() {
    local encrypted_file="$1"
    local output_file="${encrypted_file%.enc}"
    local password="$2"
    
    # Check if openssl is available
    if ! command -v openssl &> /dev/null; then
        echo "Error: openssl is required for decryption."
        return 1
    fi
    
    # Decrypt the file
    if echo "$password" | openssl enc -d -aes-256-cbc -pbkdf2 -in "$encrypted_file" -out "$output_file" -pass stdin; then
        echo "File decrypted successfully."
        return 0
    else
        echo "Error: Failed to decrypt file. Incorrect password?"
        return 1
    fi
}

# Function to prompt for password and encrypt credentials
encrypt_credentials() {
    local credentials_file="$API_DIR/credentials.json"
    
    if [ ! -f "$credentials_file" ]; then
        echo "No credentials file found to encrypt."
        return 1
    fi
    
    # Check if openssl is available
    if ! command -v openssl &> /dev/null; then
        echo "Error: openssl is required for encryption."
        return 1
    fi
    
    # Prompt for password (hidden input)
    read -s -p "Enter password to encrypt API keys: " password
    echo ""
    read -s -p "Confirm password: " password_confirm
    echo ""
    
    if [ -z "$password" ]; then
        echo "No password entered. Skipping encryption."
        return 1
    fi
    
    if [ "$password" != "$password_confirm" ]; then
        echo "Passwords do not match. Skipping encryption."
        return 1
    fi
    
    # Try to encrypt
    if encrypt_file "$credentials_file" "$password"; then
        echo "API keys successfully encrypted."
        return 0
    else
        echo "Failed to encrypt API keys."
        return 1
    fi
}

# Function to prompt for password and decrypt credentials
decrypt_credentials() {
    local encrypted_file="$API_DIR/credentials.json.enc"
    
    if [ ! -f "$encrypted_file" ]; then
        echo "No encrypted credentials found."
        return 1
    fi
    
    # Check if openssl is available
    if ! command -v openssl &> /dev/null; then
        echo "Error: openssl is required for decryption."
        return 1
    fi
    
    # Prompt for password (hidden input)
    read -s -p "Enter password to decrypt API keys: " password
    echo ""
    
    if [ -z "$password" ]; then
        echo "No password entered. Skipping decryption."
        return 1
    fi
    
    # Try to decrypt
    if decrypt_file "$encrypted_file" "$password"; then
        echo "API keys successfully decrypted."
        return 0
    else
        echo "Failed to decrypt API keys."
        return 1
    fi
}

# Function to check if credentials are encrypted
are_credentials_encrypted() {
    if [ -f "$API_DIR/credentials.json.enc" ] && [ ! -f "$API_DIR/credentials.json" ]; then
        return 0  # true
    else
        return 1  # false
    fi
}

# Check for encrypted credentials on startup
check_encrypted_credentials() {
    local encrypted_file="$API_DIR/credentials.json.enc"
    local credentials_file="$API_DIR/credentials.json"
    
    if [ -f "$encrypted_file" ] && [ ! -f "$credentials_file" ]; then
        clear
        echo "=== Mr. Magic - Encrypted API Keys ==="
        echo "Your AI API keys are password-protected."
        echo ""
        echo "Options:"
        echo "1) Enter password to decrypt API keys"
        echo "2) Skip for now (AI features will be limited)"
        echo ""
        echo "Note: You can decrypt keys later from the AI API settings menu."
        read -p "Choose an option (1-2): " decrypt_choice
        
        case $decrypt_choice in
            1)
                # Check if openssl is available
                if ! command -v openssl &> /dev/null; then
                    echo "OpenSSL not found. Cannot decrypt keys."
                    echo "Creating default credentials file instead."
                    initialize_credentials
                else
                    # Try to decrypt
                    decrypt_credentials
                    if [ ! -f "$credentials_file" ]; then
                        echo "Creating default credentials file."
                        initialize_credentials
                    fi
                fi
                ;;
            *)
                echo "Skipping decryption. Creating default credentials file."
                initialize_credentials
                ;;
        esac
        read -p "Press Enter to continue..." dummy
    fi
}

# Function to encrypt API keys on exit
encrypt_keys_on_exit() {
    local credentials_file="$API_DIR/credentials.json"
    local encrypted_file="$API_DIR/credentials.json.enc"
    
    # Check if credentials exist and are not already encrypted
    if [ -f "$credentials_file" ] && [ ! -f "$encrypted_file" ]; then
        # Check if there are any API keys stored
        local has_keys=$(jq '.ai_models | (.openai.api_key != "" or .anthropic.api_key != "" or .custom.api_key != "")' "$credentials_file")
        
        if [ "$has_keys" = "true" ]; then
            echo "API keys detected. Would you like to encrypt them before exiting?"
            echo "1) Yes, encrypt my API keys"
            echo "2) No, leave them in plain text"
            echo "3) Wipe all keys for security"
            read -p "Choose an option (1-3): " encrypt_choice
            
            case $encrypt_choice in
                1)
                    encrypt_credentials
                    ;;
                2)
                    echo "API keys left unencrypted."
                    ;;
                3)
                    echo "Wiping all API keys..."
                    rm "$credentials_file"
                    if [ -f "$encrypted_file" ]; then
                        rm "$encrypted_file"
                    fi
                    echo "All API keys have been wiped."
                    ;;
                *)
                    echo "Invalid choice. API keys left unencrypted."
                    ;;
            esac
        fi
    fi
}


# =====CONFIG FUNCTIONS=====

# Function to create default config if it doesn't exist
create_default_config() {
    if [ ! -f "$CONFIG_DIR/default.json" ]; then
        debug_log "Creating default config file"
        cat > "$CONFIG_DIR/default.json" << EOF
{
    "client_id": "",
    "client_secret": "",
    "auth_token": null,
    "user_auth": false,
    "headless": false,
    "cache_path": "$HOME/.mr-magic/cache/.spotipy",
    "no_cache": false,
    "max_retries": 3,
    "use_cache_file": false,
    "audio_providers": [
        "youtube-music"
    ],
    "lyrics_providers": [
        "musixmatch",
        "azlyrics",
        "synced"
    ],
    "playlist_numbering": false,
    "scan_for_songs": false,
    "m3u": null,
    "output": "{artists} - {title}.{output-ext}",
    "overwrite": "skip",
    "search_query": null,
    "ffmpeg": "ffmpeg",
    "bitrate": "320k",
    "ffmpeg_args": null,
    "format": "mp3",
    "save_file": null,
    "filter_results": true,
    "album_type": null,
    "threads": 4,
    "cookie_file": null,
    "restrict": null,
    "print_errors": false,
    "sponsor_block": false,
    "preload": false,
    "archive": null,
    "load_config": true,
    "log_level": "INFO",
    "simple_tui": false,
    "fetch_albums": false,
    "id3_separator": "/",
    "ytm_data": false,
    "add_unavailable": false,
    "generate_lrc": true,
    "force_update_metadata": false,
    "only_verified_results": false,
    "sync_without_deleting": false,
    "max_filename_length": null,
    "yt_dlp_args": null
}
EOF
    fi
    
    # Copy default to current if current doesn't exist
    if [ ! -f "$CURRENT_CONFIG" ]; then
        cp "$CONFIG_DIR/default.json" "$CURRENT_CONFIG"
    else
        # Ensure current config has LRC generation enabled
        local lrc_enabled=$(jq -r '.generate_lrc // false' "$CURRENT_CONFIG")
        if [ "$lrc_enabled" != "true" ]; then
            jq '.generate_lrc = true' "$CURRENT_CONFIG" > "$CURRENT_CONFIG.tmp" && mv "$CURRENT_CONFIG.tmp" "$CURRENT_CONFIG"
            debug_log "Enabled LRC generation in current config"
        fi
        
        # Ensure format is set to mp3 to match default bitrate
        local current_format=$(jq -r '.format // "mp3"' "$CURRENT_CONFIG")
        local current_bitrate=$(jq -r '.bitrate // "320k"' "$CURRENT_CONFIG")
        if [ "$current_format" != "mp3" ] && [ "$current_bitrate" = "320k" ]; then
            jq '.format = "mp3"' "$CURRENT_CONFIG" > "$CURRENT_CONFIG.tmp" && mv "$CURRENT_CONFIG.tmp" "$CURRENT_CONFIG"
            debug_log "Updated format to mp3 to match default bitrate"
        fi
        
        # Ensure synced is in lyrics_providers
        local has_synced=$(jq '.lyrics_providers | any(. == "synced")' "$CURRENT_CONFIG")
        if [ "$has_synced" != "true" ]; then
            jq '.lyrics_providers += ["synced"]' "$CURRENT_CONFIG" > "$CURRENT_CONFIG.tmp" && mv "$CURRENT_CONFIG.tmp" "$CURRENT_CONFIG"
            debug_log "Added 'synced' to lyrics providers in current config"
        fi
    fi
}

# Function to edit the current config
edit_config() {
    local param="$1"
    local value="$2"
    
    if [[ -z "$param" || -z "$value" ]]; then
        echo "Available parameters to edit:"
        jq -r 'keys[]' "$CURRENT_CONFIG" | sort | while read -r key; do
            value=$(jq -r ".$key" "$CURRENT_CONFIG")
            echo "  $key: $value"
        done
        
        read -p "Enter parameter to edit (or 'c' to cancel): " param
        
        if [ "$param" = "c" ]; then
            echo "Operation cancelled."
            return 1
        fi
        
        # Get the type of parameter for better guidance
        if jq -e "has(\"$param\")" "$CURRENT_CONFIG" > /dev/null; then
            local type=$(jq -r ".$param | type" "$CURRENT_CONFIG")
            local current_value=$(jq -r ".$param" "$CURRENT_CONFIG")
            
            echo "Parameter: $param"
            echo "Current value: $current_value"
            echo "Type: $type"
            
            case "$type" in
                "string")
                    echo "Enter new value (text - no quotes needed):"
                    ;;
                "number")
                    echo "Enter new value (numeric only - no quotes):"
                    ;;
                "boolean")
                    echo "Enter new value (true or false - no quotes):"
                    ;;
                "array")
                    echo "Enter new value (comma-separated list OR valid JSON array):"
                    echo "Examples:"
                    echo "  - Simple list: item1,item2,item3"
                    echo "  - JSON array: [\"item1\",\"item2\",\"item3\"]"
                    ;;
                "object")
                    echo "Enter new value (valid JSON object):"
                    echo "Example: {\"key1\":\"value1\",\"key2\":\"value2\"}"
                    ;;
                "null")
                    echo "Enter new value (any type will be accepted):"
                    ;;
            esac
        fi
        
        read -p "Value (or 'c' to cancel): " value
        
        if [ "$value" = "c" ]; then
            echo "Operation cancelled."
            return 1
        fi
    fi
    
    # Make sure the parameter exists
    if jq -e "has(\"$param\")" "$CURRENT_CONFIG" > /dev/null; then
        # Get the current type of the parameter
        local type=$(jq -r ".$param | type" "$CURRENT_CONFIG")
        
        case "$type" in
            "string")
                jq ".$param = \"$value\"" "$CURRENT_CONFIG" > "$CURRENT_CONFIG.tmp" && mv "$CURRENT_CONFIG.tmp" "$CURRENT_CONFIG"
                ;;
            "number")
                if [[ "$value" =~ ^[+-]?[0-9]*\.?[0-9]+$ ]]; then
                    jq ".$param = $value" "$CURRENT_CONFIG" > "$CURRENT_CONFIG.tmp" && mv "$CURRENT_CONFIG.tmp" "$CURRENT_CONFIG"
                else
                    echo "Error: Numeric parameter requires a number value."
                    return 1
                fi
                ;;
            "boolean")
                if [[ "$value" == "true" || "$value" == "false" ]]; then
                    jq ".$param = $value" "$CURRENT_CONFIG" > "$CURRENT_CONFIG.tmp" && mv "$CURRENT_CONFIG.tmp" "$CURRENT_CONFIG"
                else
                    echo "Error: Boolean parameter requires 'true' or 'false' value."
                    return 1
                fi
                ;;
            "array")
                # Check if value starts with [ - assume it's a proper JSON array
                if [[ "$value" == \[* ]]; then
                    # Validate JSON array
                    if echo "$value" | jq empty &>/dev/null; then
                        jq ".$param = $value" "$CURRENT_CONFIG" > "$CURRENT_CONFIG.tmp" && mv "$CURRENT_CONFIG.tmp" "$CURRENT_CONFIG"
                    else
                        echo "Error: Invalid JSON array format."
                        return 1
                    fi
                else
                    # Convert comma-separated string to array
                    jq ".$param = \"$value\" | split(\",\")" "$CURRENT_CONFIG" > "$CURRENT_CONFIG.tmp" && mv "$CURRENT_CONFIG.tmp" "$CURRENT_CONFIG"
                fi
                ;;
            "object")
                # Validate JSON object
                if echo "$value" | jq empty &>/dev/null; then
                    jq ".$param = $value" "$CURRENT_CONFIG" > "$CURRENT_CONFIG.tmp" && mv "$CURRENT_CONFIG.tmp" "$CURRENT_CONFIG"
                else
                    echo "Error: Invalid JSON object format."
                    return 1
                fi
                ;;
            "null")
                # Try to determine the type and set accordingly
                if [[ "$value" == "true" || "$value" == "false" ]]; then
                    jq ".$param = $value" "$CURRENT_CONFIG" > "$CURRENT_CONFIG.tmp" && mv "$CURRENT_CONFIG.tmp" "$CURRENT_CONFIG"
                elif [[ "$value" =~ ^[0-9]+$ ]]; then
                    jq ".$param = $value" "$CURRENT_CONFIG" > "$CURRENT_CONFIG.tmp" && mv "$CURRENT_CONFIG.tmp" "$CURRENT_CONFIG"
                else
                    jq ".$param = \"$value\"" "$CURRENT_CONFIG" > "$CURRENT_CONFIG.tmp" && mv "$CURRENT_CONFIG.tmp" "$CURRENT_CONFIG"
                fi
                ;;
            *)
                echo "Error: Unsupported parameter type: $type"
                return 1
                ;;
        esac
        
        echo "Updated $param = $value"
        debug_log "Updated config parameter $param = $value"
        sync_with_spotdl_config
    else
        echo "Error: Parameter '$param' does not exist in the config."
        return 1
    fi
}

# Function to delete a config preset
delete_config_preset() {
    # Get the presets as an array
    presets=()
    if [ -d "$PRESETS_DIR" ]; then
        for preset in "$PRESETS_DIR"/*.json; do
            if [ -f "$preset" ]; then
                preset_name=$(basename "$preset" .json)
                presets+=("$preset_name")
            fi
        done
    fi
    
    if [ ${#presets[@]} -eq 0 ]; then
        echo "No custom presets found to delete."
        return 1
    fi
    
    # Display presets with numbers
    echo "Available presets to delete:"
    for i in "${!presets[@]}"; do
        echo "$((i+1))) ${presets[$i]}"
    done
    
    read -p "Enter preset number, name to delete, or 'c' to cancel: " preset_choice
    
    if [ "$preset_choice" = "c" ]; then
        echo "Operation cancelled."
        return 1
    elif [[ "$preset_choice" =~ ^[0-9]+$ ]] && [ "$preset_choice" -ge 1 ] && [ "$preset_choice" -le "${#presets[@]}" ]; then
        # User selected a number, convert to preset name
        selected_preset="${presets[$((preset_choice-1))]}"
        preset_file="$PRESETS_DIR/$selected_preset.json"
    else
        # User entered a preset name directly
        preset_file="$PRESETS_DIR/$preset_choice.json"
    fi
    
    # Check if the file exists
    if [ ! -f "$preset_file" ]; then
        echo "Preset file not found: $preset_file"
        return 1
    fi
    
    # Confirm deletion
    read -p "Are you sure you want to delete preset '$selected_preset'? (y/n): " confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        rm "$preset_file"
        echo "Preset '$selected_preset' deleted."
        
        # If the active config was the deleted preset, switch to default
        if [ "$ACTIVE_CONFIG" = "$selected_preset" ]; then
            load_config "default"
            echo "Active config switched to default."
        fi
        return 0
    else
        echo "Deletion cancelled."
        return 1
    fi
}

# Function to list available config presets
list_config_presets() {
    echo "Available config presets:"
    echo "- default"
    
    if [ -d "$PRESETS_DIR" ]; then
        for preset in "$PRESETS_DIR"/*.json; do
            if [ -f "$preset" ]; then
                preset_name=$(basename "$preset" .json)
                echo "- $preset_name"
            fi
        done
    fi
    
    echo "Currently active: $ACTIVE_CONFIG"
}

# Function to save current config as a preset with cancel option
save_config_preset() {
    read -p "Enter a name for this preset (or 'c' to cancel): " preset_name
    
    # Check for cancel request
    if [ "$preset_name" = "c" ]; then
        echo "Operation cancelled."
        return 1
    fi
    
    # Validate preset name (alphanumeric and underscore only)
    if [[ ! "$preset_name" =~ ^[a-zA-Z0-9_]+$ ]]; then
        echo "Error: Preset name must contain only letters, numbers, and underscores."
        return 1
    fi
    
    local preset_file="$PRESETS_DIR/$preset_name.json"
    
    # Check if preset already exists
    if [ -f "$preset_file" ]; then
        read -p "Preset '$preset_name' already exists. Overwrite? (y/n/c to cancel): " confirm
        if [ "$confirm" = "c" ]; then
            echo "Operation cancelled."
            return 1
        elif [[ ! "$confirm" =~ ^[Yy]$ ]]; then
            echo "Operation cancelled."
            return 1
        fi
    fi
    
    # Save current config to preset
    cp "$CURRENT_CONFIG" "$preset_file"
    ACTIVE_CONFIG="$preset_name"
    echo "Config saved as preset: $preset_name"
    debug_log "Saved current config as preset: $preset_name to $preset_file"
    
    # Sync with SpotDL config
    sync_with_spotdl_config
}

# Function to load a config preset
load_config() {
    local preset="$1"
    local preset_file
    
    if [ "$preset" = "default" ]; then
        preset_file="$CONFIG_DIR/default.json"
    else
        preset_file="$PRESETS_DIR/$preset.json"
    fi
    
    if [ -f "$preset_file" ]; then
        cp "$preset_file" "$CURRENT_CONFIG"
        ACTIVE_CONFIG="$preset"
        echo "Loaded config preset: $preset"
        debug_log "Loaded config preset: $preset from $preset_file"
        
        # Sync with SpotDL config
        sync_with_spotdl_config
    else
        echo "Error: Config preset '$preset' not found."
        debug_log "Error: Config preset '$preset' not found at $preset_file"
        return 1
    fi
}

# Function to sync current config with SpotDL config
sync_with_spotdl_config() {
    debug_log "Syncing config with SpotDL"
    
    # Ensure SpotDL config directory exists
    if [ "$DEBUG_MODE" = true ]; then
        mkdir -p "$HOME/.spotdl"
    else
        mkdir -p "$HOME/.spotdl" 2>/dev/null
    fi
    
    # Read the app settings to see if we should copy or symlink
    local app_settings_file="$CONFIG_DIR/app_settings.json"
    local sync_method="copy"
    
    if [ -f "$app_settings_file" ]; then
        sync_method=$(jq -r '.sync_method // "copy"' "$app_settings_file")
    fi
    
    if [ "$sync_method" = "symlink" ]; then
        # Remove existing config or symlink
        rm -f "$HOME/.spotdl/config.json"
        
        # Create a symbolic link
        ln -sf "$CURRENT_CONFIG" "$HOME/.spotdl/config.json"
        debug_log "Created symlink to SpotDL config"
    else
        # Copy the current config to SpotDL config
        cp "$CURRENT_CONFIG" "$HOME/.spotdl/config.json"
        debug_log "Copied config to SpotDL config"
    fi
}

# Function to set config sync method
set_sync_method() {
    local app_settings_file="$CONFIG_DIR/app_settings.json"
    
    # Create app settings file if it doesn't exist
    if [ ! -f "$app_settings_file" ]; then
        echo '{"sync_method": "copy"}' > "$app_settings_file"
    fi
    
    # Get current sync method
    local current_method=$(jq -r '.sync_method // "copy"' "$app_settings_file")
    
    echo "SpotDL expects its config file at ~/.spotdl/config.json"
    echo "Choose how to sync your config presets with SpotDL:"
    echo "1) Copy method (copy the current config to SpotDL's location)"
    echo "2) Symlink method (create a symbolic link from SpotDL's location to your current config)"
    echo ""
    echo "Current method: $current_method"
    read -p "Select method (1-2 or 'c' to cancel): " method_choice
    
    if [ "$method_choice" = "c" ]; then
        echo "Operation cancelled."
        return 1
    fi
    
    case "$method_choice" in
        1)
            jq '.sync_method = "copy"' "$app_settings_file" > "$app_settings_file.tmp" && mv "$app_settings_file.tmp" "$app_settings_file"
            echo "Config sync method set to 'copy'"
            ;;
        2)
            jq '.sync_method = "symlink"' "$app_settings_file" > "$app_settings_file.tmp" && mv "$app_settings_file.tmp" "$app_settings_file"
            echo "Config sync method set to 'symlink'"
            ;;
        *)
            echo "Invalid choice. Keeping current method: $current_method"
            ;;
    esac
}


# =====DOWNLOAD FUNCTIONS=====

# Function to provide a step-by-step wizard for downloading
download_wizard() {
    local current_step=1
    local max_steps=6  # Max number of steps in the wizard
    local return_to_summary=false
    local wizard_choices=()
    local download_type=""
    local media_type=""
    local format=""
    local bitrate=""
    local lyrics_method=""
    local downloaded_file=""
    local lyrics_files=()
    local post_processing_type=""
    
    # Function to allow going back a step
    go_back_step() {
        current_step=$((current_step - 1))
        if [ $current_step -lt 1 ]; then
            current_step=1
        fi
    }
    
    # Function for audio format selection
    handle_audio_format_selection() {
        echo "Select audio format:"
        echo "1) MP3 (compressed, good compatibility)"
        echo "2) FLAC (lossless, high quality)"
        echo "3) M4A (AAC, efficient compression)"
        echo "4) OPUS (best compression ratio)"
        echo "5) WAV (uncompressed, largest files)"
        echo "6) Enter custom format"
        read -p "Enter format choice (1-6): " format_choice
        
        local format="mp3"
        case $format_choice in
            2) 
                format="flac"
                wizard_choices+=("Audio format: FLAC (lossless)")
                # For FLAC, use compression level instead of bitrate
                jq '.bitrate = null' "$CURRENT_CONFIG" > "$CURRENT_CONFIG.tmp" && mv "$CURRENT_CONFIG.tmp" "$CURRENT_CONFIG"
                # Set FLAC-specific parameters
                jq '.ffmpeg_args = ["-compression_level", "5"]' "$CURRENT_CONFIG" > "$CURRENT_CONFIG.tmp" && mv "$CURRENT_CONFIG.tmp" "$CURRENT_CONFIG"
                echo "Note: FLAC is lossless, so bitrate will be determined automatically."
                echo "Set compression level to default (5)."
                wizard_choices+=("FLAC compression: Level 5 (default)")
                ;;
            3) 
                format="m4a"
                wizard_choices+=("Audio format: M4A (AAC)")
                # For AAC, we offer different bitrate options later
                ;;
            4) 
                format="opus"
                wizard_choices+=("Audio format: OPUS")
                # For OPUS, we offer different bitrate options later
                ;;
            5) 
                format="wav"
                wizard_choices+=("Audio format: WAV (uncompressed)")
                # For WAV, bitrate is fixed by bit depth and sample rate
                jq '.bitrate = null' "$CURRENT_CONFIG" > "$CURRENT_CONFIG.tmp" && mv "$CURRENT_CONFIG.tmp" "$CURRENT_CONFIG"
                echo "Note: WAV is uncompressed, so bitrate will be determined by bit depth/sample rate."
                local sample_options=("44.1kHz (CD quality)" "48kHz (standard)" "96kHz (high resolution)")
                local bit_depth_options=("16-bit (CD quality)" "24-bit (studio quality)")
                
                echo "Select sample rate:"
                for i in "${!sample_options[@]}"; do
                    echo "$((i+1))) ${sample_options[$i]}"
                done
                read -p "Enter choice (1-3): " sample_choice
                
                local sample_rate="44100"
                case $sample_choice in
                    2) sample_rate="48000" ;;
                    3) sample_rate="96000" ;;
                    *) sample_rate="44100" ;;
                esac
                
                echo "Select bit depth:"
                for i in "${!bit_depth_options[@]}"; do
                    echo "$((i+1))) ${bit_depth_options[$i]}"
                done
                read -p "Enter choice (1-2): " bit_choice
                
                local bit_depth="16"
                [ "$bit_choice" = "2" ] && bit_depth="24"
                
                # Set WAV-specific parameters
                jq ".ffmpeg_args = [\"-ar\", \"$sample_rate\", \"-sample_fmt\", \"s${bit_depth}\"]" "$CURRENT_CONFIG" > "$CURRENT_CONFIG.tmp" && mv "$CURRENT_CONFIG.tmp" "$CURRENT_CONFIG"
                
                wizard_choices+=("WAV format: ${bit_depth}-bit/${sample_rate}Hz")
                ;;
            6)
                echo "Available formats include: mp3, flac, m4a, opus, wav, ogg, etc."
                read -p "Enter custom format: " custom_format
                if [ -n "$custom_format" ]; then
                    format="$custom_format"
                    wizard_choices+=("Audio format: $format (custom)")
                else
                    format="mp3"
                    wizard_choices+=("Audio format: MP3 (default - custom empty)")
                fi
                ;;
            *)
                wizard_choices+=("Audio format: MP3 (default)")
                ;;
        esac
        
        # Update config with selected format
        jq ".format = \"$format\"" "$CURRENT_CONFIG" > "$CURRENT_CONFIG.tmp" && mv "$CURRENT_CONFIG.tmp" "$CURRENT_CONFIG"
        
        # Return the selected format so we can use it in the bitrate selection
        echo "$format"
    }
    
    # Function for format-specific bitrate selection
    handle_bitrate_selection() {
        local format="$1"
        
        # If format is FLAC or WAV, we don't need to set bitrate
        if [[ "$format" == "flac" || "$format" == "wav" ]]; then
            echo "Bitrate is automatically determined for $format format."
            return
        fi
        
        echo "Select audio bitrate for $format format:"
        
        case $format in
            "mp3")
                echo "1) 128k (smaller file, adequate quality)"
                echo "2) 192k (balanced quality and size)"
                echo "3) 256k (high quality)"
                echo "4) 320k (highest quality, larger file)"
                echo "5) Enter custom bitrate"
                
                read -p "Enter bitrate choice (1-5): " bitrate_choice
                
                local bitrate="320k"
                case $bitrate_choice in
                    1) bitrate="128k"; wizard_choices+=("MP3 bitrate: 128k") ;;
                    2) bitrate="192k"; wizard_choices+=("MP3 bitrate: 192k") ;;
                    3) bitrate="256k"; wizard_choices+=("MP3 bitrate: 256k") ;;
                    4) bitrate="320k"; wizard_choices+=("MP3 bitrate: 320k (highest quality)") ;;
                    5)
                        echo "Enter custom bitrate (e.g., 160k, 224k)"
                        echo "Format should be a number followed by 'k'"
                        read -p "Custom bitrate: " custom_bitrate
                        if [[ "$custom_bitrate" =~ ^[0-9]+k$ ]]; then
                            bitrate="$custom_bitrate"
                            wizard_choices+=("MP3 bitrate: $bitrate (custom)")
                        else
                            echo "Invalid format. Using default 320k."
                            bitrate="320k"
                            wizard_choices+=("MP3 bitrate: 320k (default - invalid custom)")
                        fi
                        ;;
                    *) wizard_choices+=("MP3 bitrate: 320k (default)") ;;
                esac
                ;;
                
            "m4a")
                echo "1) 128k (good quality, smaller file)"
                echo "2) 192k (high quality)"
                echo "3) 256k (very high quality, equivalent to 320k MP3)"
                echo "4) 320k (maximum quality, larger file)"
                echo "5) Enter custom bitrate"
                
                read -p "Enter bitrate choice (1-5): " bitrate_choice
                
                local bitrate="256k"
                case $bitrate_choice in
                    1) bitrate="128k"; wizard_choices+=("AAC bitrate: 128k") ;;
                    2) bitrate="192k"; wizard_choices+=("AAC bitrate: 192k") ;;
                    3) bitrate="256k"; wizard_choices+=("AAC bitrate: 256k (recommended)") ;;
                    4) bitrate="320k"; wizard_choices+=("AAC bitrate: 320k (maximum)") ;;
                    5)
                        echo "Enter custom bitrate (e.g., 160k, 224k)"
                        echo "Format should be a number followed by 'k'"
                        read -p "Custom bitrate: " custom_bitrate
                        if [[ "$custom_bitrate" =~ ^[0-9]+k$ ]]; then
                            bitrate="$custom_bitrate"
                            wizard_choices+=("AAC bitrate: $bitrate (custom)")
                        else
                            echo "Invalid format. Using default 256k."
                            bitrate="256k"
                            wizard_choices+=("AAC bitrate: 256k (default - invalid custom)")
                        fi
                        ;;
                    *) wizard_choices+=("AAC bitrate: 256k (default)") ;;
                esac
                ;;
                
            "opus")
                echo "1) 96k (good quality, very small file)"
                echo "2) 128k (high quality, equivalent to 192k MP3)"
                echo "3) 160k (very high quality)"
                echo "4) 192k (transparent quality, equivalent to 320k MP3)"
                echo "5) Enter custom bitrate"
                
                read -p "Enter bitrate choice (1-5): " bitrate_choice
                
                local bitrate="128k"
                case $bitrate_choice in
                    1) bitrate="96k"; wizard_choices+=("OPUS bitrate: 96k") ;;
                    2) bitrate="128k"; wizard_choices+=("OPUS bitrate: 128k (recommended)") ;;
                    3) bitrate="160k"; wizard_choices+=("OPUS bitrate: 160k") ;;
                    4) bitrate="192k"; wizard_choices+=("OPUS bitrate: 192k (highest quality)") ;;
                    5)
                        echo "Enter custom bitrate (e.g., 64k, 144k)"
                        echo "Format should be a number followed by 'k'"
                        read -p "Custom bitrate: " custom_bitrate
                        if [[ "$custom_bitrate" =~ ^[0-9]+k$ ]]; then
                            bitrate="$custom_bitrate"
                            wizard_choices+=("OPUS bitrate: $bitrate (custom)")
                        else
                            echo "Invalid format. Using default 128k."
                            bitrate="128k"
                            wizard_choices+=("OPUS bitrate: 128k (default - invalid custom)")
                        fi
                        ;;
                    *) wizard_choices+=("OPUS bitrate: 128k (default)") ;;
                esac
                ;;
                
            *)
                # Generic bitrate options for other formats
                echo "1) 128k (lower quality, smaller file)"
                echo "2) 192k (medium quality)"
                echo "3) 256k (high quality)"
                echo "4) 320k (highest quality, larger file)"
                echo "5) Enter custom bitrate"
                
                read -p "Enter bitrate choice (1-5): " bitrate_choice
                
                local bitrate="256k"
                case $bitrate_choice in
                    1) bitrate="128k"; wizard_choices+=("Bitrate: 128k") ;;
                    2) bitrate="192k"; wizard_choices+=("Bitrate: 192k") ;;
                    3) bitrate="256k"; wizard_choices+=("Bitrate: 256k") ;;
                    4) bitrate="320k"; wizard_choices+=("Bitrate: 320k") ;;
                    5)
                        echo "Enter custom bitrate (e.g., 160k, 224k)"
                        echo "Format should be a number followed by 'k'"
                        read -p "Custom bitrate: " custom_bitrate
                        if [[ "$custom_bitrate" =~ ^[0-9]+k$ ]]; then
                            bitrate="$custom_bitrate"
                            wizard_choices+=("Bitrate: $bitrate (custom)")
                        else
                            echo "Invalid format. Using default 256k."
                            bitrate="256k"
                            wizard_choices+=("Bitrate: 256k (default - invalid custom)")
                        fi
                        ;;
                    *) wizard_choices+=("Bitrate: 256k (default)") ;;
                esac
                ;;
        esac
        
        # Update config with selected bitrate
        jq ".bitrate = \"$bitrate\"" "$CURRENT_CONFIG" > "$CURRENT_CONFIG.tmp" && mv "$CURRENT_CONFIG.tmp" "$CURRENT_CONFIG"
    }
    
    # Function to handle lyrics post-processing options
    handle_lyrics_postprocessing() {
        local lyrics_files=("$@")
        
        # Check for non-Latin characters in saved lyrics files
        has_non_latin=false
        non_latin_file=""
        for file in "${lyrics_files[@]}"; do
            if [ -f "$file" ] && detect_non_latin "$file"; then
                has_non_latin=true
                non_latin_file="$file"
                break
            fi
        done
        
        echo "Step 5: Lyrics Post-Processing Options"
        echo ""
        
        # Modify post-processing options if non-Latin characters are detected
        if [ "$has_non_latin" = true ]; then
            echo "⚠️ Non-Latin characters detected in lyrics."
            echo "Select post-processing options for lyrics (you can select multiple):"
            echo "1) Skip post-processing"
            echo "2) Convert LRC to SRT format"
            echo "3) Romanize lyrics (RECOMMENDED for non-English lyrics)"  # Emphasize this option
            echo "4) Format lyrics (remove timestamps)"
            echo "5) Go back to previous step"
            echo "6) Cancel wizard"
            
            # Highlight the romanization option more prominently
            echo ""
            echo "Note: Romanization (option 3) is highly recommended for the detected non-Latin text"
            echo "      to make lyrics more readable in English characters."
        else
            echo "Select post-processing options for lyrics (you can select multiple):"
            echo "1) Skip post-processing"
            echo "2) Convert LRC to SRT format"
            echo "3) Romanize lyrics (for non-English lyrics)"
            echo "4) Format lyrics (remove timestamps)"
            echo "5) Go back to previous step"
            echo "6) Cancel wizard"
        fi
        
        read -p "Enter your choices (comma-separated, e.g. 2,3,4): " post_choices
        
        if [ "$post_choices" = "5" ]; then
            return 5  # Go back signal
        elif [ "$post_choices" = "6" ]; then
            return 6  # Cancel signal
        elif [ "$post_choices" = "1" ] || [ -z "$post_choices" ]; then
            # Only add "lyric_" to differentiate from audio post-processing
            post_processing_type="${post_processing_type}lyric_none,"
            wizard_choices+=("Lyrics post-processing: None")
            return 0
        else
            IFS=',' read -ra CHOICES <<< "$post_choices"
            for choice in "${CHOICES[@]}"; do
                case $choice in
                    2)  # Convert LRC to SRT
                        wizard_choices+=("Lyrics post-processing: Convert LRC to SRT")
                        post_processing_type="${post_processing_type}lyric_lrc2srt,"
                        ;;
                    3)  # Romanize lyrics
                        wizard_choices+=("Lyrics post-processing: Romanize lyrics")
                        post_processing_type="${post_processing_type}lyric_romanize,"
                        ;;
                    4)  # Format lyrics
                        wizard_choices+=("Lyrics post-processing: Format lyrics")
                        post_processing_type="${post_processing_type}lyric_format,"
                        ;;
                esac
            done
            return 0
        fi
    }
    
    # Loop through wizard steps
    while [ $current_step -le $max_steps ]; do
        clear
        echo "=== Mr. Magic - Download Wizard ==="
        echo "Step $current_step of $max_steps"
        echo ""
        
        case $current_step in
            1)  # Output Directory
                echo "Step 1: Set Output Directory"
                echo ""
                
                if [ -z "$OUTPUT_DIR" ]; then
                    echo "No output directory currently set."
                    set_output_directory
                    
                    # Explicitly capture the return status
                    local dir_status=$?
                    debug_log "set_output_directory returned status: $dir_status"
                    
                    if [ $dir_status -eq 0 ]; then
                        # Successfully set the directory
                        wizard_choices+=("Output directory: $OUTPUT_DIR")
                        debug_log "Moving to step 2"
                        current_step=$((current_step + 1))
                    else
                        # User cancelled the operation
                        echo "Wizard cancelled."
                        return 1
                    fi
                else
                    echo "Current output directory: $OUTPUT_DIR"
                    echo "Would you like to change it?"
                    echo "1) Keep current directory"
                    echo "2) Change directory"
                    echo "3) Cancel wizard"
                    read -p "Enter choice (1-3): " dir_choice
                    
                    case $dir_choice in
                        2)
                            set_output_directory
                            
                            # Explicitly capture the return status
                            local dir_status=$?
                            debug_log "set_output_directory returned status: $dir_status"
                            
                            if [ $dir_status -eq 0 ]; then
                                # Successfully changed the directory
                                wizard_choices+=("Output directory: $OUTPUT_DIR")
                                debug_log "Moving to step 2"
                                current_step=$((current_step + 1))
                            else
                                echo "Directory selection cancelled."
                                read -p "Go back to previous step? (y/n): " go_back
                                if [[ "$go_back" =~ ^[Yy]$ ]]; then
                                    go_back_step
                                    continue
                                else
                                    echo "Wizard cancelled."
                                    return 1
                                fi
                            fi
                            ;;
                        3)
                            echo "Wizard cancelled."
                            return 1
                            ;;
                        *)
                            wizard_choices+=("Output directory: $OUTPUT_DIR (unchanged)")
                            debug_log "Moving to step 2"
                            current_step=$((current_step + 1))
                            ;;
                    esac
                fi

                # Check if we should return to summary
                if [ "$return_to_summary" = true ]; then
                    return_to_summary=false
                    current_step=6  # Return to summary step
                fi
                ;;

            2)  # Download Type Selection
                echo "Step 2: What would you like to download?"
                echo "1) Music only"
                echo "2) Lyrics only"
                echo "3) Both music and lyrics"
                echo "4) Go back to previous step"
                echo "5) Cancel wizard"
                read -p "Enter your choice (1-5): " dl_choice
                
                case $dl_choice in
                    1)
                        download_type="music"
                        wizard_choices+=("Download type: Music only")
                        ;;
                    2)
                        download_type="lyrics"
                        wizard_choices+=("Download type: Lyrics only")
                        ;;
                    3)
                        download_type="both"
                        wizard_choices+=("Download type: Both music and lyrics")
                        ;;
                    4)
                        go_back_step
                        continue
                        ;;
                    5|*)
                        echo "Wizard cancelled."
                        return 1
                        ;;
                esac
                
                current_step=$((current_step + 1))
                
                # Skip to lyrics step if lyrics-only selected
                if [ "$download_type" = "lyrics" ]; then
                    current_step=4
                fi

                # Check if we should return to summary
                if [ "$return_to_summary" = true ]; then
                    return_to_summary=false
                    current_step=6  # Return to summary step
                fi
                ;;
                
           3)  # Media Type and Music Config (for music or both)
                if [[ "$download_type" == "music" || "$download_type" == "both" ]]; then
                    echo "Step 3: Music Download Configuration"
                    echo ""
                    
                    # First, select what to download
                    echo "What would you like to download?"
                    echo "1) Single Song"
                    echo "2) Album"
                    echo "3) Playlist"
                    echo "4) Artist (all songs)"
                    echo "5) Liked Songs"
                    echo "6) Go back to previous step"
                    echo "7) Cancel wizard"
                    read -p "Enter your choice (1-7): " media_choice
                    
                    case $media_choice in
                        1)
                            media_type="song"
                            wizard_choices+=("Media type: Single Song")
                            ;;
                        2)
                            media_type="album"
                            wizard_choices+=("Media type: Album")
                            ;;
                        3)
                            media_type="playlist"
                            wizard_choices+=("Media type: Playlist")
                            ;;
                        4)
                            media_type="artist"
                            wizard_choices+=("Media type: Artist (all songs)")
                            ;;
                        5)
                            media_type="liked"
                            wizard_choices+=("Media type: Liked Songs")
                            ;;
                        6)
                            go_back_step
                            continue
                            ;;
                        7|*)
                            echo "Wizard cancelled."
                            return 1
                            ;;
                    esac
                    
                    # Now show current config and offer to edit
                    echo ""
                    echo "Current configuration:"
                    echo "Format: $(jq -r '.format // "mp3"' "$CURRENT_CONFIG")"
                    echo "Bitrate: $(jq -r '.bitrate // "320k"' "$CURRENT_CONFIG")"
                    echo ""
                    
                    echo "Would you like to edit any settings?"
                    echo "1) Continue with current settings"  # Now first choice
                    echo "2) Change audio format"
                    echo "3) Change bitrate"
                    echo "4) Edit other settings"
                    echo "5) Show help for common parameters"
                    echo "6) Go back to previous step"
                    echo "7) Cancel wizard"
                    read -p "Enter your choice (1-7): " config_choice
                    
                    case $config_choice in
                        1)  # Continue with current settings (moved to option 1)
                            wizard_choices+=("Config: Using current settings")
                            format=$(jq -r '.format // "mp3"' "$CURRENT_CONFIG")
                            bitrate=$(jq -r '.bitrate // "320k"' "$CURRENT_CONFIG")
                            
                            # Make sure LRC generation is enabled for lyrics if needed
                            if [ "$download_type" = "both" ]; then
                                local lrc_enabled=$(jq -r '.generate_lrc // false' "$CURRENT_CONFIG")
                                if [ "$lrc_enabled" != "true" ]; then
                                    jq '.generate_lrc = true' "$CURRENT_CONFIG" > "$CURRENT_CONFIG.tmp" && mv "$CURRENT_CONFIG.tmp" "$CURRENT_CONFIG"
                                    echo "LRC generation automatically enabled for lyrics."
                                    wizard_choices+=("LRC generation: Enabled for lyrics")
                                fi
                            fi
                            
                            # Sync with SpotDL config
                            sync_with_spotdl_config
                            
                            # Add audio post-processing options
                            echo ""
                            echo "=== Audio Post-Processing Options ==="
                            echo "Would you like to enable any audio post-processing? (Select multiple with comma-separated numbers)"
                            echo "1) Skip audio post-processing"
                            echo "2) Export metadata to text file"
                            echo "3) Generate YouTube tags for song"
                            read -p "Enter your choices (comma-separated, e.g. 2,3): " audio_post_choices

                            if [ -z "$audio_post_choices" ] || [ "$audio_post_choices" = "1" ]; then
                                wizard_choices+=("Audio post-processing: None")
                            else
                                IFS=',' read -ra AP_CHOICES <<< "$audio_post_choices"
                                for choice in "${AP_CHOICES[@]}"; do
                                    case $choice in
                                        2)
                                            wizard_choices+=("Audio post-processing: Export metadata")
                                            post_processing_type="${post_processing_type}metadata,"
                                            ;;
                                        3)
                                            wizard_choices+=("Audio post-processing: Generate YouTube tags")
                                            post_processing_type="${post_processing_type}tags,"
                                            ;;
                                    esac
                                done
                            fi
                            
                            # Proceed to next step
                            current_step=$((current_step + 1))
                            ;;
                            
                        2)  # Change audio format (was option 1)
                            local selected_format=$(handle_audio_format_selection)
                            format="$selected_format"
                            
                            # Return to the config menu
                            current_step=3
                            continue
                            ;;
                            
                        3)  # Change bitrate (was option 2)
                            local current_format=$(jq -r '.format // "mp3"' "$CURRENT_CONFIG")
                            handle_bitrate_selection "$current_format"
                            
                            # Return to the config menu
                            current_step=3
                            continue
                            ;;
                            
                        4)  # Edit other settings (was option 3)
                            echo "Enter parameter name to edit (see available parameters below)"
                            echo "Common parameters:"
                            echo "  threads: Number of download threads (default: 4)"
                            echo "  audio_providers: Sources to search for audio [youtube-music, youtube]"
                            echo "  lyrics_providers: Sources for lyrics [musixmatch, azlyrics, others]"
                            echo "  generate_lrc: Whether to generate LRC files (true/false)"
                            echo "  output: Output filename template"
                            echo ""
                            echo "All available parameters:"
                            jq -r 'keys[]' "$CURRENT_CONFIG" | sort | while read -r key; do
                                value=$(jq -r ".$key" "$CURRENT_CONFIG")
                                echo "  $key: $value"
                            done
                            read -p "Parameter name (or 'c' to cancel): " param
                            
                            if [ "$param" = "c" ]; then
                                # Return to the config menu
                                current_step=3
                                continue
                            fi
                            
                            # Check if parameter exists
                            if jq -e "has(\"$param\")" "$CURRENT_CONFIG" > /dev/null; then
                                # Get current value
                                local current_value=$(jq -r ".$param" "$CURRENT_CONFIG")
                                local type=$(jq -r ".$param | type" "$CURRENT_CONFIG")
                                
                                echo "Parameter: $param"
                                echo "Current value: $current_value"
                                echo "Type: $type"
                                
                                # Display hint based on type
                                case "$type" in
                                    "string")
                                        echo "Enter new text value:"
                                        echo "Example values for common parameters:"
                                        echo "  format: mp3, flac, m4a, opus, wav"
                                        echo "  bitrate: 128k, 192k, 320k, 96k"
                                        echo "  output: {artists} - {title}.{output-ext}"
                                        ;;
                                    "number")
                                        echo "Enter new numeric value:"
                                        echo "Example values for common parameters:"
                                        echo "  threads: 1-8 (higher = faster downloads but more CPU usage)"
                                        echo "  max_retries: 1-10 (number of retries on failure)"
                                        ;;
                                    "boolean")
                                        echo "Enter true or false:"
                                        echo "Example parameters:"
                                        echo "  generate_lrc: true = create LRC files, false = don't"
                                        echo "  user_auth: true = use Spotify authentication, false = don't"
                                        ;;
                                    "array")
                                        echo "Enter comma-separated values or JSON array:"
                                        echo "Example for audio_providers: youtube-music,youtube"
                                        echo "Example for lyrics_providers: synced,musixmatch,azlyrics"
                                        ;;
                                    *)
                                        echo "Enter new value:"
                                        ;;
                                esac
                                
                                read -p "New value: " new_value
                                
                                # Update the config based on type
                                case "$type" in
                                    "string")
                                        jq ".$param = \"$new_value\"" "$CURRENT_CONFIG" > "$CURRENT_CONFIG.tmp" && mv "$CURRENT_CONFIG.tmp" "$CURRENT_CONFIG"
                                        ;;
                                    "number")
                                        if [[ "$new_value" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
                                            jq ".$param = $new_value" "$CURRENT_CONFIG" > "$CURRENT_CONFIG.tmp" && mv "$CURRENT_CONFIG.tmp" "$CURRENT_CONFIG"
                                        else
                                            echo "Error: Not a valid number."
                                        fi
                                        ;;
                                    "boolean")
                                        if [[ "$new_value" == "true" || "$new_value" == "false" ]]; then
                                            jq ".$param = $new_value" "$CURRENT_CONFIG" > "$CURRENT_CONFIG.tmp" && mv "$CURRENT_CONFIG.tmp" "$CURRENT_CONFIG"
                                        else
                                            echo "Error: Must be 'true' or 'false'."
                                        fi
                                        ;;
                                    "array")
                                        if [[ "$new_value" == \[* ]]; then
                                            # Assume JSON array
                                            if echo "$new_value" | jq empty 2>/dev/null; then
                                                jq ".$param = $new_value" "$CURRENT_CONFIG" > "$CURRENT_CONFIG.tmp" && mv "$CURRENT_CONFIG.tmp" "$CURRENT_CONFIG"
                                            else
                                                echo "Error: Invalid JSON array format."
                                            fi
                                        else
                                            # Convert comma-separated to array
                                            array_json=$(echo "$new_value" | tr ',' '\n' | jq -R . | jq -s .)
                                            jq ".$param = $array_json" "$CURRENT_CONFIG" > "$CURRENT_CONFIG.tmp" && mv "$CURRENT_CONFIG.tmp" "$CURRENT_CONFIG"
                                        fi
                                        ;;
                                    *)
                                        echo "Unsupported type. Please edit the config file directly."
                                        ;;
                                esac
                                
                                wizard_choices+=("Config: Updated $param = $new_value")
                                echo "Parameter $param updated."
                            fi
                            
                            read -p "Press Enter to continue..."
                            
                            # Return to the config menu
                            current_step=3
                            continue
                            ;;
                            
                        5)  # Show help guide (was option 4)
                            clear
                            echo "=== SpotDL Configuration Parameter Guide ==="
                            echo ""
                            echo "Audio Parameters:"
                            echo "  format - Output format (mp3, flac, m4a, opus, wav, ogg)"
                            echo "  bitrate - Audio quality (varies by format)"
                            echo "    MP3: 96k-320k (320k = highest quality)"
                            echo "    M4A/AAC: 96k-320k (256k ~= 320k MP3)"
                            echo "    OPUS: 64k-192k (128k ~= 192k MP3)"
                            echo "    FLAC: Lossless (uses compression level 0-8 instead of bitrate)"
                            echo "    WAV: Uncompressed (bitrate determined by bit depth/sample rate)"
                            echo "  ffmpeg_args - Advanced encoding parameters"
                            echo ""
                            echo "Download Sources:"
                            echo "  audio_providers - Sources to check for audio files"
                            echo "    [youtube-music, youtube, soundcloud, bandcamp]"
                            echo ""
                            echo "Lyrics:"
                            echo "  lyrics_providers - Sources for lyrics"
                            echo "    [musixmatch, azlyrics, synced]"
                            echo "  generate_lrc - Create LRC lyric files (true/false)"
                            echo ""
                            echo "Output Format:"
                            echo "  output - Template for output filenames"
                            echo "    Example: {artists} - {title}.{output-ext}"
                            echo "    Example with folders: {artists}/{album}/{track-number} - {title}.{output-ext}"
                            echo ""
                            echo "Authentication:"
                            echo "  user_auth - Use Spotify account (true/false)"
                            echo "  client_id/client_secret - Spotify API credentials"
                            echo ""
                            echo "Performance:"
                            echo "  threads - Number of concurrent downloads (1-8)"
                            echo "  max_retries - Number of retry attempts (1-10)"
                            echo ""
                            read -p "Press Enter to return to the config menu..."
                            current_step=3
                            continue
                            ;;
                            
                        6)  # Go back to previous step
                            go_back_step
                            continue
                            ;;
                            
                        7|*)  # Cancel wizard
                            echo "Wizard cancelled."
                            return 1
                            ;;
                    esac
                else
                    # Skip to next step if not downloading music
                    current_step=$((current_step + 1))
                fi

                # Check if we should return to summary
                if [ "$return_to_summary" = true ]; then
                    return_to_summary=false
                    current_step=6  # Return to summary step
                fi
                ;;

            4)  # Lyrics Options (for lyrics or both)
                if [[ "$download_type" == "lyrics" || "$download_type" == "both" ]]; then
                    echo "Step 4: Lyrics Options"
                    echo ""
                    
                    echo "Select lyrics search method:"
                    echo "1) Auto Search (try all methods)"
                    echo "2) LRCLIB Search (lyrics database)"
                    echo "3) SpotDL Search (Spotify sources)"
                    echo "4) AI Transcribe (using OpenAI Whisper)"
                    echo "5) Go back to previous step"
                    echo "6) Cancel wizard"
                    read -p "Enter your choice (1-6): " lyrics_choice
                    
                    case $lyrics_choice in
                        1)
                            lyrics_method="auto"
                            wizard_choices+=("Lyrics search method: Auto (try all)")
                            ;;
                        2)
                            lyrics_method="lrclib"
                            wizard_choices+=("Lyrics search method: LRCLIB")
                            ;;
                        3)
                            lyrics_method="spotdl"
                            wizard_choices+=("Lyrics search method: SpotDL")
                            ;;
                        4)
                            lyrics_method="whisper"
                            wizard_choices+=("Lyrics search method: OpenAI Whisper")
                            ;;
                        5)
                            go_back_step
                            continue
                            ;;
                        6|*)
                            echo "Wizard cancelled."
                            return 1
                            ;;
                    esac
                    
                    # If using whisper without a file, ask for a file
                    if [ "$lyrics_method" = "whisper" ] && [ "$download_type" = "lyrics" ]; then
                        echo ""
                        echo "AI transcription requires an audio file."
                        read -p "Enter path to audio file (or 'c' to cancel): " transcribe_file
                        
                        if [ "$transcribe_file" = "c" ]; then
                            # Return to lyrics options
                            current_step=4
                            continue
                        elif [ -n "$transcribe_file" ] && [ -f "$transcribe_file" ]; then
                            downloaded_file="$transcribe_file"
                            wizard_choices+=("Transcription file: $(basename "$downloaded_file")")
                        else
                            echo "File not found. Please try again."
                            read -p "Press Enter to continue..."
                            # Return to lyrics options
                            current_step=4
                            continue
                        fi
                    fi
                    
                    current_step=$((current_step + 1))
                else
                    # Skip to execution step if not handling lyrics
                    current_step=6
                fi

                # Check if we should return to summary
                if [ "$return_to_summary" = true ]; then
                    return_to_summary=false
                    current_step=6  # Return to summary step
                fi
                ;;

            5)  # Post-processing options for lyrics
                if [[ "$download_type" == "lyrics" || "$download_type" == "both" ]]; then
                    echo "Step 5: Lyrics Post-Processing Options"
                    echo ""
                    
                    # Use the new handler function for lyrics post-processing
                    handle_lyrics_postprocessing "${lyrics_files[@]}"
                    post_result=$?
                    
                    if [ $post_result -eq 5 ]; then
                        # Go back to previous step
                        go_back_step
                        continue
                    elif [ $post_result -eq 6 ]; then
                        # Cancel wizard
                        echo "Wizard cancelled."
                        return 1
                    fi
                    
                    current_step=$((current_step + 1))
                else
                    # Skip to execution step if not handling lyrics
                    current_step=6
                fi
                
                # Check if we should return to summary
                if [ "$return_to_summary" = true ]; then
                    return_to_summary=false
                    current_step=6  # Return to summary step
                fi
                ;;

            6)  # Review and Execute
                echo "Step 6: Review and Execute"
                echo ""
                
                # Show summary of wizard choices organized by step
                echo "=== Wizard Summary ==="
                
                # Group choices by step
                echo "Step 1 - Output Directory:"
                for choice in "${wizard_choices[@]}"; do
                    if [[ "$choice" == "Output directory:"* ]]; then
                        echo "  - $choice"
                    fi
                done
                
                echo "Step 2 - Download Type:"
                for choice in "${wizard_choices[@]}"; do
                    if [[ "$choice" == "Download type:"* ]]; then
                        echo "  - $choice"
                    fi
                done
                
                echo "Step 3 - Music Configuration:"
                for choice in "${wizard_choices[@]}"; do
                    if [[ "$choice" == "Media type:"* || "$choice" == "Config:"* || 
                        "$choice" == "Audio format:"* || "$choice" == "Audio bitrate:"* ||
                        "$choice" == "Audio post-processing:"* ]]; then
                        echo "  - $choice"
                    fi
                done
                
                echo "Step 4 - Lyrics Search Method:"
                for choice in "${wizard_choices[@]}"; do
                    if [[ "$choice" == "Lyrics search method:"* ]]; then
                        echo "  - $choice"
                    fi
                done
                
                echo "Step 5 - Lyrics Post-Processing:"
                for choice in "${wizard_choices[@]}"; do
                    if [[ "$choice" == "Lyrics post-processing:"* ]]; then
                        echo "  - $choice"
                    fi
                done
                
                echo ""
                echo "Ready to proceed with your selections."
                echo "1) Proceed and execute"
                echo "2) Save current config as preset"
                echo "3) Edit Step 1 - Output Directory"
                echo "4) Edit Step 2 - Download Type"
                echo "5) Edit Step 3 - Music Configuration"
                echo "6) Edit Step 4 - Lyrics Search Method"
                echo "7) Edit Step 5 - Lyrics Post-Processing"
                echo "8) Start over"
                echo "9) Cancel wizard"
                read -p "Enter your choice (1-9): " execute_choice
                
                # Store current step to return after editing
                local return_to_summary=false
                
                case $execute_choice in
                    1)  # Execute
                        echo ""
                        echo "=== Executing Download Process ==="
                        
                        # STEP 1: Download music if needed
                        if [[ "$download_type" == "music" || "$download_type" == "both" ]]; then
                            # VPN notice
                            echo -e "\n⚠️  Important Note: YouTube downloads may require a VPN in certain countries"
                            echo "If downloads fail, consider using a VPN service to bypass regional restrictions."
                            echo ""
                            read -p "Press Enter to continue with download..." dummy
                            
                            echo -e "\nDownloading music..."
                            
                            # Build SpotDL command based on media type
                            local query=""
                            case $media_type in
                                "song")
                                    read -p "Enter song URL or search query: " query
                                    if [ -z "$query" ]; then
                                        echo "No query provided. Cancelling download."
                                        return 1
                                    fi
                                    # IMPORTANT: Don't use --config flag, we've already synced the config
                                    local spotdl_cmd="spotdl download \"$query\""
                                    ;;
                                "album")
                                    read -p "Enter album URL: " query
                                    if [ -z "$query" ]; then
                                        echo "No URL provided. Cancelling download."
                                        return 1
                                    fi
                                    # Don't use --config flag
                                    local spotdl_cmd="spotdl download \"$query\""
                                    ;;
                                "playlist")
                                    read -p "Enter playlist URL: " query
                                    if [ -z "$query" ]; then
                                        echo "No URL provided. Cancelling download."
                                        return 1
                                    fi
                                    # Don't use --config flag
                                    local spotdl_cmd="spotdl download \"$query\""
                                    ;;
                                "artist")
                                    read -p "Enter artist URL: " query
                                    if [ -z "$query" ]; then
                                        echo "No URL provided. Cancelling download."
                                        return 1
                                    fi
                                    # Don't use --config flag
                                    local spotdl_cmd="spotdl download \"$query\""
                                    ;;
                                "liked")
                                    # Don't use --config flag
                                    local spotdl_cmd="spotdl download saved --user-auth"
                                    ;;
                                *)
                                    read -p "Enter URL or search query: " query
                                    if [ -z "$query" ]; then
                                        echo "No query provided. Cancelling download."
                                        return 1
                                    fi
                                    # Don't use --config flag
                                    local spotdl_cmd="spotdl download \"$query\""
                                    ;;
                            esac
                            
                            # Activate pyenv environment if available
                            if command -v pyenv &> /dev/null; then
                                debug_log "Activating pyenv environment for SpotDL"
                                eval "$(pyenv init -)"
                                pyenv activate spotdl 2>/dev/null || pyenv activate mdsh 2>/dev/null || true
                            fi
                            
                            # Execute the command
                            echo "Executing: $spotdl_cmd"
                            debug_log "SpotDL command: $spotdl_cmd"

                            # Capture both stdout and stderr to check for errors
                            echo "Executing SpotDL..."
                            eval "$spotdl_cmd"
                            local download_status=$?

                            if [[ "$download_output" == *"Couldn't write token to cache"* ]]; then
                                echo -e "\n⚠️ Permission Error: Cannot write to cache directory."
                                echo "Fixing cache directory permissions..."
                                
                                # Create a new cache directory in the user's home directory
                                if [ "$DEBUG_MODE" = true ]; then
                                    mkdir -p "$HOME/.mr-magic/cache"
                                else
                                    mkdir -p "$HOME/.mr-magic/cache" 2>/dev/null
                                fi
                                
                                # Update the config to use this cache directory
                                jq ".cache_path = \"$HOME/.mr-magic/cache/.spotipy\"" "$CURRENT_CONFIG" > "$CURRENT_CONFIG.tmp" && mv "$CURRENT_CONFIG.tmp" "$CURRENT_CONFIG"
                                
                                # Sync the updated config
                                sync_with_spotdl_config
                                
                                echo "Cache directory updated. Retrying download..."
                                # Retry with updated config
                                download_output=$(eval "$spotdl_cmd" 2>&1)
                                download_status=$?
                                echo "$download_output"
                            fi

                            if [[ "$download_output" == *"No results found for song"* || "$download_output" == *"LookupError"* ]]; then
                                echo -e "\n⚠️ Error: Song not found or not available for download."
                                download_status=1  # Force error status
                            fi

                            if [ $download_status -eq 0 ] && [[ "$download_output" != *"No results found for song"* && "$download_output" != *"LookupError"* ]]; then
                                # Find the downloaded file(s)
                                if [ "$media_type" = "song" ]; then
                                    find_cmd="find \"$OUTPUT_DIR\" -type f \( -name \"*.mp3\" -o -name \"*.flac\" -o -name \"*.m4a\" -o -name \"*.wav\" -o -name \"*.opus\" \) -mtime -1 2>/dev/null | sort -r | head -1"
                                    downloaded_file=$(eval "$find_cmd")
                                    
                                    if [ -n "$downloaded_file" ]; then
                                        echo "Download completed successfully!"
                                        echo "Downloaded file: $downloaded_file"
                                    else
                                        echo "⚠️ Error: Download command completed but no files were found."
                                        download_status=1  # Force error status
                                    fi
                                else
                                    echo "Multiple files may have been downloaded."
                                    find_cmd="find \"$OUTPUT_DIR\" -type f \( -name \"*.mp3\" -o -name \"*.flac\" -o -name \"*.m4a\" -o -name \"*.wav\" -o -name \"*.opus\" \) -mtime -1 2>/dev/null | sort -r | head -5"
                                    local recent_files=$(eval "$find_cmd")
                                    
                                    if [ -n "$recent_files" ]; then
                                        echo "Download completed successfully!"
                                        echo "Recent downloads:"
                                        echo "$recent_files"
                                    else
                                        echo "⚠️ Error: Download command completed but no files were found."
                                        download_status=1  # Force error status
                                    fi
                                fi
                            else
                                echo "⚠️ Error occurred during download."
                                download_status=1  # Force error status
                            fi

                            # If download failed, offer retry options
                            if [ $download_status -ne 0 ]; then
                                echo "Download failed. Select an option:"
                                echo "1) Try again with the same query"
                                echo "2) Try a different query"
                                echo "3) Try a different source"
                                echo "4) Skip music download and continue"
                                echo "5) Cancel the wizard"
                                read -p "Enter your choice (1-5): " retry_choice
                                
                                case $retry_choice in
                                    1)
                                        # Retry with the same query
                                        echo "Retrying download with the same query..."
                                        echo "Executing: $spotdl_cmd"
                                        eval "$spotdl_cmd"
                                        download_status=$?
                                        
                                        # Check again if files were downloaded
                                        find_cmd="find \"$OUTPUT_DIR\" -type f \( -name \"*.mp3\" -o -name \"*.flac\" -o -name \"*.m4a\" -o -name \"*.wav\" -o -name \"*.opus\" \) -mtime -1 2>/dev/null | sort -r | head -1"
                                        downloaded_file=$(eval "$find_cmd")
                                        
                                        if [ -n "$downloaded_file" ] && [ $download_status -eq 0 ]; then
                                            echo "Download completed successfully!"
                                            echo "Downloaded file: $downloaded_file"
                                        else
                                            echo "Download failed again."
                                            return 1
                                        fi
                                        ;;
                                    2)
                                        # Try with a different query
                                        read -p "Enter a new song URL or search query: " query
                                        if [ -z "$query" ]; then
                                            echo "No query provided. Cancelling download."
                                            return 1
                                        fi
                                        
                                        # Update the command with the new query
                                        spotdl_cmd="spotdl download \"$query\""
                                        echo "Executing: $spotdl_cmd"
                                        eval "$spotdl_cmd"
                                        download_status=$?
                                        
                                       # Check if files were downloaded
                                        find_cmd="find \"$OUTPUT_DIR\" -type f \( -name \"*.mp3\" -o -name \"*.flac\" -o -name \"*.m4a\" -o -name \"*.wav\" -o -name \"*.opus\" \) -mtime -1 2>/dev/null | sort -r | head -1"
                                        downloaded_file=$(eval "$find_cmd")

                                        if [ -n "$downloaded_file" ] && [ $download_status -eq 0 ]; then
                                            echo "Download completed successfully!"
                                            echo "Downloaded file: $downloaded_file"
                                            
                                            # Offer metadata and tag generation
                                            echo ""
                                            echo "Would you like to: (select multiple with comma-separated numbers)"
                                            echo "1) Export metadata to text file"
                                            echo "2) Generate YouTube tags for song"
                                            echo "3) Skip additional processing"
                                            read -p "Your choices (e.g., 1,2): " post_options

                                            if [[ "$post_options" == *"1"* ]]; then
                                                echo "Exporting metadata for: $downloaded_file"
                                                # Use Spotify URL if this was a Spotify download
                                                local spotify_url=""
                                                if [[ "$query" == *"open.spotify.com"* ]]; then
                                                    spotify_url="$query"
                                                fi
                                                export_song_metadata "$downloaded_file" "$spotify_url"
                                            fi

                                            if [[ "$post_options" == *"2"* ]]; then
                                                echo "Generating AI tags for: $downloaded_file"
                                                generate_youtube_tags "$downloaded_file"
                                            fi
                                        else
                                            echo "Download failed again."
                                            return 1
                                        fi
                                        ;;
                                    3)
                                        # Try different source by editing audio_providers in config
                                        local current_providers=$(jq -r '.audio_providers | join(", ")' "$CURRENT_CONFIG")
                                        echo "Current audio providers: $current_providers"
                                        echo "Available providers: youtube-music, youtube, soundcloud, bandcamp"
                                        read -p "Enter comma-separated providers to use: " new_providers
                                        
                                        if [ -n "$new_providers" ]; then
                                            # Convert to JSON array
                                            providers_json=$(echo "$new_providers" | tr ',' '\n' | jq -R . | jq -s .)
                                            jq ".audio_providers = $providers_json" "$CURRENT_CONFIG" > "$CURRENT_CONFIG.tmp" && mv "$CURRENT_CONFIG.tmp" "$CURRENT_CONFIG"
                                            sync_with_spotdl_config
                                            
                                            echo "Audio providers updated. Retrying download..."
                                            echo "Executing: $spotdl_cmd"
                                            eval "$spotdl_cmd"
                                            download_status=$?
                                            
                                            # Check if files were downloaded
                                            find_cmd="find \"$OUTPUT_DIR\" -type f \( -name \"*.mp3\" -o -name \"*.flac\" -o -name \"*.m4a\" -o -name \"*.wav\" -o -name \"*.opus\" \) -mtime -1 2>/dev/null | sort -r | head -1"
                                            downloaded_file=$(eval "$find_cmd")
                                            
                                            if [ -n "$downloaded_file" ] && [ $download_status -eq 0 ]; then
                                                echo "Download completed successfully!"
                                                echo "Downloaded file: $downloaded_file"
                                            else
                                                echo "Download failed again."
                                                return 1
                                            fi
                                        else
                                            echo "No providers specified. Skipping music download."
                                            return 1
                                        fi
                                        ;;
                                    4)
                                        # Skip music download
                                        echo "Skipping music download."
                                        download_status=0  # Pretend it succeeded but with no file
                                        ;;
                                    5)
                                        # Cancel wizard
                                        echo "Cancelling wizard."
                                        return 1
                                        ;;
                                esac
                            fi
                            
                            # Handle audio post-processing if needed
                            if [ $download_status -eq 0 ] && [ -n "$downloaded_file" ] && [ -f "$downloaded_file" ]; then
                                if [[ "$post_processing_type" == *"metadata"* ]]; then
                                    echo "Exporting metadata for: $downloaded_file"
                                    # Pass the Spotify URL if we have one
                                    local spotify_url=""
                                    if [[ "$query" == *"open.spotify.com"* ]]; then
                                        spotify_url="$query"
                                    fi
                                    export_song_metadata "$downloaded_file" "$spotify_url"
                                fi
                                
                                if [[ "$post_processing_type" == *"tags"* ]]; then
                                    echo "Generating AI tags for: $downloaded_file"
                                    generate_youtube_tags "$downloaded_file"
                                fi
                            fi
                        fi
                        
                        # STEP 2: Handle lyrics if needed
                        if [[ "$download_type" == "lyrics" || "$download_type" == "both" ]]; then
                            echo ""
                            echo "=== Searching for Lyrics ==="
                            
                            # Check if we have a downloaded file first
                            if [ -z "$downloaded_file" ] && [ "$download_type" == "both" ]; then
                                echo "No audio file was downloaded. Cannot search for lyrics automatically."
                                read -p "Would you like to manually enter a file path or skip lyrics? (f=file/s=skip): " lyrics_choice
                                
                                if [[ "$lyrics_choice" == "f" || "$lyrics_choice" == "F" ]]; then
                                    read -p "Enter full path to audio file: " manual_file
                                    if [ -n "$manual_file" ] && [ -f "$manual_file" ]; then
                                        downloaded_file="$manual_file"
                                    else
                                        echo "Invalid file. Skipping lyrics."
                                        continue
                                    fi
                                else
                                    echo "Skipping lyrics."
                                    continue
                                fi
                            fi
                            
                            # Call search_lyrics with the specified method and file
                            if search_lyrics "$downloaded_file" "$lyrics_method"; then
                                echo "Lyrics found successfully!"
                                
                                # Find the created lyrics files
                                if [ -n "$downloaded_file" ]; then
                                    local base_name="${downloaded_file%.*}"
                                    local found_lyrics=false
                                    
                                    for ext in srt lrc txt; do
                                        if [ -f "$base_name.$ext" ]; then
                                            lyrics_files+=("$base_name.$ext")
                                            found_lyrics=true
                                            echo "Found lyrics file: $base_name.$ext"
                                        fi
                                    done
                                    
                                    if [ "$found_lyrics" = false ]; then
                                        echo "Warning: Lyrics search completed but no files were found."
                                        
                                        read -p "Would you like to try another search method? (y/n): " try_again
                                        if [[ "$try_again" =~ ^[Yy]$ ]]; then
                                            current_step=4 # Return to Lyrics Options
                                            continue
                                        fi
                                    fi
                                else
                                    echo "Lyrics search completed, but cannot verify files due to missing audio file reference."
                                    
                                    # Look for any recently created lyrics files
                                    recent_lyrics=$(find "$OUTPUT_DIR" -type f \( -name "*.lrc" -o -name "*.srt" -o -name "*.txt" \) -mtime -1 2>/dev/null | sort -r | head -3)
                                    
                                    if [ -n "$recent_lyrics" ]; then
                                        echo "Recent lyrics files:"
                                        echo "$recent_lyrics"
                                        
                                        # Add these to our lyrics_files array
                                        while IFS= read -r lyric_file; do
                                            lyrics_files+=("$lyric_file")
                                        done <<< "$recent_lyrics"
                                    fi
                                fi
                            else
                                echo "Failed to find lyrics."
                                
                                read -p "Would you like to try another search method? (y/n): " try_again
                                if [[ "$try_again" =~ ^[Yy]$ ]]; then
                                    current_step=4 # Return to Lyrics Options
                                    continue
                                fi
                            fi
                            
                            # Check for non-Latin characters in any found lyrics files
                            if [ ${#lyrics_files[@]} -gt 0 ]; then
                                has_non_latin=false
                                non_latin_file=""
                                for file in "${lyrics_files[@]}"; do
                                    if detect_non_latin "$file"; then
                                        has_non_latin=true
                                        non_latin_file="$file"
                                        break
                                    fi
                                done
                                
                                # If non-Latin characters were detected, offer romanization
                                if [ "$has_non_latin" = true ]; then
                                    echo ""
                                    echo "⚠️ Non-Latin characters detected in lyrics."
                                    echo "Romanization is recommended for easier reading."
                                    
                                    # Override romanization setting if post_processing_type doesn't already include it
                                    if [[ ! "$post_processing_type" == *"lyric_romanize"* ]]; then
                                        read -p "Would you like to romanize these lyrics? (y/n): " add_romanize
                                        if [[ "$add_romanize" =~ ^[Yy]$ ]]; then
                                            post_processing_type="${post_processing_type}lyric_romanize,"
                                            wizard_choices+=("Lyrics post-processing: Romanize lyrics (auto-detected)")
                                        fi
                                    fi
                                fi
                            fi
                        fi
                        
                        # STEP 3: Handle lyrics post-processing if selected
                        if [[ "$post_processing_type" == *"lyric_"* ]] && [ ${#lyrics_files[@]} -gt 0 ]; then
                            echo ""
                            echo "=== Performing Lyrics Post-Processing ==="
                            
                            # Process each post-processing option
                            if [[ "$post_processing_type" == *"lyric_lrc2srt"* ]]; then
                                echo "Converting LRC to SRT format..."
                                # Find LRC files
                                for file in "${lyrics_files[@]}"; do
                                    if [[ "$file" == *".lrc" ]]; then
                                        srt_file="${file%.lrc}.srt"
                                        # Use the lrc2srt.py script
                                        if [ -f "$DEPENDENCIES_DIR/lrc2srt.py" ]; then
                                            python3 "$DEPENDENCIES_DIR/lrc2srt.py" "$file" "$srt_file"
                                            if [ -f "$srt_file" ]; then
                                                lyrics_files+=("$srt_file")
                                                echo "Converted to SRT: $srt_file"
                                            else
                                                echo "Failed to convert LRC to SRT."
                                            fi
                                        else
                                            copy_lrc2srt_script
                                            python3 "$DEPENDENCIES_DIR/lrc2srt.py" "$file" "$srt_file"
                                            if [ -f "$srt_file" ]; then
                                                lyrics_files+=("$srt_file")
                                                echo "Converted to SRT: $srt_file"
                                            else
                                                echo "Failed to convert LRC to SRT."
                                            fi
                                        fi
                                    fi
                                done
                            fi
                            
                            if [[ "$post_processing_type" == *"lyric_romanize"* ]]; then
                                echo "Romanizing lyrics..."
                                # If we have a non-Latin file, use it; otherwise use the first file
                                if [ "$has_non_latin" = true ] && [ -n "$non_latin_file" ]; then
                                    romanize_lyrics "$non_latin_file"
                                elif [ ${#lyrics_files[@]} -gt 0 ]; then
                                    romanize_lyrics "${lyrics_files[0]}"
                                else
                                    echo "No lyrics files found for romanization."
                                fi
                            fi
                            
                            if [[ "$post_processing_type" == *"lyric_format"* ]]; then
                                echo "Formatting lyrics (removing timestamps)..."
                                # Find files to format
                                for file in "${lyrics_files[@]}"; do
                                    if [[ "$file" == *".lrc" || "$file" == *".srt" ]]; then
                                        format_romanized_lyrics "$file"
                                        break  # Just do one file
                                    fi
                                done
                            fi
                        fi
                        
                        # Final success message
                        echo ""
                        echo "=== Download Process Complete ==="
                        echo "All selected operations have been completed successfully."
                        
                        # Offer to open output directory
                        if [ -n "$OUTPUT_DIR" ] && [ -d "$OUTPUT_DIR" ]; then
                            read -p "Open output directory? (y/n): " open_dir
                            if [[ "$open_dir" =~ ^[Yy]$ ]]; then
                                open_directory "$OUTPUT_DIR"
                            fi
                        fi
                        
                        read -p "Press Enter to return to the main menu..."
                        return 0
                        ;;   

                                        2)  # Save current config as preset
                        echo ""
                        echo "Enter a name for this preset (letters, numbers, and underscores only):"
                        read -p "Preset name: " preset_name
                        
                        # Validate preset name
                        if [[ ! "$preset_name" =~ ^[a-zA-Z0-9_]+$ ]]; then
                            echo "Invalid preset name. Use only letters, numbers, and underscores."
                            read -p "Press Enter to try again..."
                            continue
                        fi
                        
                        # Create presets directory if it doesn't exist
                        if [ "$DEBUG_MODE" = true ]; then
                            mkdir -p "$CONFIG_DIR/presets"
                        else
                            mkdir -p "$CONFIG_DIR/presets" 2>/dev/null
                        fi
                        
                        # Save current config as preset
                        cp "$CURRENT_CONFIG" "$CONFIG_DIR/presets/$preset_name.json"
                        
                        echo "Preset '$preset_name' saved successfully."
                        echo "You can load this preset from the main menu."
                        read -p "Press Enter to continue..."
                        continue
                        ;;
                        
                    3)  # Edit Step 1 - Output Directory
                        return_to_summary=true
                        current_step=1
                        continue
                        ;;
                        
                    4)  # Edit Step 2 - Download Type
                        return_to_summary=true
                        current_step=2
                        continue
                        ;;
                        
                    5)  # Edit Step 3 - Music Configuration
                        return_to_summary=true
                        current_step=3
                        continue
                        ;;
                        
                    6)  # Edit Step 4 - Lyrics Search Method
                        return_to_summary=true
                        current_step=4
                        continue
                        ;;
                        
                    7)  # Edit Step 5 - Lyrics Post-Processing
                        return_to_summary=true
                        current_step=5
                        continue
                        ;;
                        
                    8)  # Start over
                        # Clear wizard choices array
                        wizard_choices=()
                        download_type=""
                        media_type=""
                        format=""
                        bitrate=""
                        lyrics_method=""
                        downloaded_file=""
                        lyrics_files=()
                        post_processing_type=""
                        
                        # Reset to first step
                        current_step=1
                        continue
                        ;;
                        
                    9|*)  # Cancel wizard
                        echo "Wizard cancelled."
                        return 1
                        ;;
                esac
                ;;
                
        esac
    done
    
    return 0
}

# Function for downloading songs using spotDL
download_song() {
    # Check if output directory is set
    if [ -z "$OUTPUT_DIR" ]; then
        echo "Output directory not set."
        set_output_directory
        if [ $? -ne 0 ]; then
            echo "Failed to set output directory. Returning to main menu."
            return 1
        fi
    fi
    
    # Content Menu
    clear
    echo "=== Select Content Type ==="
    echo "1) Music"
    echo "2) Metadata Only"
    echo "3) YouTube Tags Only"
    echo "4) Cancel and Return to Previous Menu"
    
    read -p "Enter your choice (1-4): " content_type_choice
    
    case $content_type_choice in
        1)
            # Music option selected - continue to config summary
            selected_content="music"
            ;;
        2)
            # Metadata export menu - no config needed
            show_metadata_export_menu
            return $?
            ;;
        3)
            # YouTube tags menu - no config needed
            show_youtube_tags_menu
            return $?
            ;;
        4|*)
            echo "Operation cancelled."
            return 1
            ;;
    esac
    
    # If we're continuing with music download, NOW show the config summary
    if [ "$selected_content" = "music" ]; then
        clear
        echo "=== Quick Download Configuration Summary ==="
        echo "Current Settings:"
        echo "  Active Config: $ACTIVE_CONFIG"
        echo "  Output Directory: $OUTPUT_DIR"
        
        # Get current format and bitrate from config
        local format=$(jq -r '.format // "mp3"' "$CURRENT_CONFIG")
        local bitrate=$(jq -r '.bitrate // "320k"' "$CURRENT_CONFIG")
        local threads=$(jq -r '.threads // "4"' "$CURRENT_CONFIG")
        
        echo "  Format: $format"
        echo "  Bitrate: $bitrate"
        echo "  Download Threads: $threads"
        echo ""
        echo "What would you like to do?"
        echo "1) Continue with current settings"
        echo "2) Edit current configuration"
        echo "3) Load a different config preset"
        echo "4) Create a new config preset"
        echo "5) Go back to content selection"
        echo "6) Cancel operation"
        echo ""
        
        read -p "Enter your choice (1-6): " config_choice
        
        case $config_choice in
            1)
                # Continue with current settings
                ;;
            2)
                # Edit configuration
                echo "Edit configuration options:"
                echo "1) Change format"
                echo "2) Change bitrate"
                echo "3) Toggle LRC generation"
                echo "4) Change threads"
                echo "5) Edit advanced settings"
                echo "6) Return to previous menu"
                read -p "Enter your choice (1-6): " edit_choice
                
                case $edit_choice in
                    1)
                        echo "Available formats: mp3, flac, m4a, opus, wav"
                        read -p "Enter format: " new_format
                        if [ -n "$new_format" ]; then
                            jq ".format = \"$new_format\"" "$CURRENT_CONFIG" > "$CURRENT_CONFIG.tmp" && mv "$CURRENT_CONFIG.tmp" "$CURRENT_CONFIG"
                            echo "Format updated to $new_format"
                            sync_with_spotdl_config
                        fi
                        # Recursive call to show updated config
                        download_song
                        return $?
                        ;;
                    2)
                        echo "Recommended bitrates: 128k, 192k, 256k, 320k"
                        read -p "Enter bitrate: " new_bitrate
                        if [ -n "$new_bitrate" ]; then
                            jq ".bitrate = \"$new_bitrate\"" "$CURRENT_CONFIG" > "$CURRENT_CONFIG.tmp" && mv "$CURRENT_CONFIG.tmp" "$CURRENT_CONFIG"
                            echo "Bitrate updated to $new_bitrate"
                            sync_with_spotdl_config
                        fi
                        # Recursive call to show updated config
                        download_song
                        return $?
                        ;;
                    3)
                        if [ "$generate_lrc" = "true" ]; then
                            jq ".generate_lrc = false" "$CURRENT_CONFIG" > "$CURRENT_CONFIG.tmp" && mv "$CURRENT_CONFIG.tmp" "$CURRENT_CONFIG"
                            echo "LRC generation disabled"
                        else
                            jq ".generate_lrc = true" "$CURRENT_CONFIG" > "$CURRENT_CONFIG.tmp" && mv "$CURRENT_CONFIG.tmp" "$CURRENT_CONFIG"
                            echo "LRC generation enabled"
                        fi
                        sync_with_spotdl_config
                        # Recursive call to show updated config
                        download_song
                        return $?
                        ;;
                    4)
                        read -p "Enter number of threads (1-8, default 4): " new_threads
                        if [[ "$new_threads" =~ ^[1-8]$ ]]; then
                            jq ".threads = $new_threads" "$CURRENT_CONFIG" > "$CURRENT_CONFIG.tmp" && mv "$CURRENT_CONFIG.tmp" "$CURRENT_CONFIG"
                            echo "Threads updated to $new_threads"
                            sync_with_spotdl_config
                        else
                            echo "Invalid number of threads. Using default."
                        fi
                        # Recursive call to show updated config
                        download_song
                        return $?
                        ;;
                    5)
                        # Call the existing config editor
                        edit_config
                        # Recursive call to show updated config
                        download_song
                        return $?
                        ;;
                    6|*)
                        # Return to config summary
                        download_song
                        return $?
                        ;;
                esac
                ;;
            3)
                # Load a different config preset
                echo "Available config presets:"
                # Show default first
                echo "1) default"
                
                # Check for custom presets
                local preset_count=1
                local presets=()
                presets+=("default")
                
                if [ -d "$PRESETS_DIR" ]; then
                    for preset in "$PRESETS_DIR"/*.json; do
                        if [ -f "$preset" ]; then
                            preset_count=$((preset_count + 1))
                            preset_name=$(basename "$preset" .json)
                            presets+=("$preset_name")
                            echo "$preset_count) $preset_name"
                        fi
                    done
                fi
                
                read -p "Enter preset number or name (or 'c' to cancel): " preset_choice
                
                if [ "$preset_choice" = "c" ]; then
                    # Return to config summary
                    download_song
                    return $?
                elif [[ "$preset_choice" =~ ^[0-9]+$ ]] && [ "$preset_choice" -ge 1 ] && [ "$preset_choice" -le "$preset_count" ]; then
                    # User selected by number
                    preset_index=$((preset_choice - 1))
                    selected_preset="${presets[$preset_index]}"
                    load_config "$selected_preset"
                elif [ -n "$preset_choice" ]; then
                    # User entered preset name
                    load_config "$preset_choice"
                fi
                
                # Recursive call to show updated config
                download_song
                return $?
                ;;
            4)
                # Create a new config preset
                read -p "Enter name for new preset (letters, numbers, underscore only, or 'c' to cancel): " new_preset
                
                if [ "$new_preset" = "c" ]; then
                    # Return to config summary
                    download_song
                    return $?
                fi
                
                # Validate preset name
                if [[ ! "$new_preset" =~ ^[a-zA-Z0-9_]+$ ]]; then
                    echo "Invalid preset name. Use only letters, numbers, and underscores."
                    sleep 2
                    download_song
                    return $?
                fi
                
                # Save current config as new preset
                cp "$CURRENT_CONFIG" "$PRESETS_DIR/$new_preset.json"
                ACTIVE_CONFIG="$new_preset"
                echo "Config saved as preset: $new_preset"
                sync_with_spotdl_config
                
                sleep 2
                # Recursive call to show updated config
                download_song
                return $?
                ;;
            5)
                # Go back to content selection
                download_song
                return $?
                ;;
            6|*)
                # Cancel operation
                echo "Operation cancelled."
                return 1
                ;;
        esac
        
        # Now proceed to music download menu
        show_music_download_menu
    fi
    
    return 0
}

# Function to download and save lyrics
download_lyrics() {
    local response="$1"
    local index="$2"
    local output_dir="$3"
    local song_file="$4"
    local force_overwrite="$5"
    
    debug_log "Downloading lyrics for index $index to $output_dir"
    debug_log "Response length: ${#response} bytes"
    
    # Perform permissions check on output directory
    if [ ! -w "$output_dir" ]; then
        echo "Warning: Cannot write to $output_dir - permission denied"
        output_dir="$HOME/Downloads"
        [ ! -d "$output_dir" ] && mkdir -p "$output_dir"
        echo "Using alternate location: $output_dir"
    fi
    
    if command -v jq &> /dev/null; then
        # Get the artist and title from the response
        local title=$(echo "$response" | jq -r ".[$index].trackName")
        local artist=$(echo "$response" | jq -r ".[$index].artistName")
        
        # Important fix: ALWAYS use artist and title for the base filename
        # Create a sanitized base_name from artist and title
        local base_name="$(echo "$artist - $title" | tr -d '[:cntrl:]' | tr -c '[:alnum:][:blank:]' '_')"
        
        # If we have an empty base_name for some reason, use a fallback
        if [ -z "$base_name" ] || [ "$base_name" = " - " ]; then
            if [ -n "$song_file" ]; then
                base_name=$(basename "${song_file%.*}")
            else
                # Last resort fallback
                base_name="unknown_lyrics_$(date +%Y%m%d-%H%M%S)"
                echo "Warning: Could not determine proper filename. Using: $base_name"
            fi
        fi
        
        debug_log "Base filename: '$base_name'"
        
        # Check for existing lyrics files
        if [ "$force_overwrite" != "true" ] && check_existing_lyrics "$output_dir" "$base_name"; then
            echo "Lyrics files already exist for this song."
            read -p "Do you want to overwrite them? (y/n): " overwrite_choice
            debug_log "User chose to overwrite: $overwrite_choice"
            
            if [[ ! "$overwrite_choice" =~ ^[Yy]$ ]]; then
                echo "Skipping lyrics download."
                debug_log "User skipped overwriting existing lyrics"
                return 0
            fi
        fi
        
        has_synced=$(echo "$response" | jq -r ".[$index].syncedLyrics")
        
        debug_log "Selected lyrics metadata:"
        debug_log "  Artist: '$artist'"
        debug_log "  Title: '$title'"
        debug_log "  Has synced: '$has_synced'"
        debug_log "  Using filename: '$base_name'"
        
        local saved_files=()
        
        if [ "$has_synced" != "null" ]; then
            debug_log "Saving synced lyrics (LRC format)"
            # Save synced lyrics (LRC format)
            lrc_content=$(echo "$response" | jq -r ".[$index].syncedLyrics")
            lrc_file="$output_dir/$base_name.lrc"
            debug_log "Writing to file: $lrc_file"
            echo "$lrc_content" > "$lrc_file"
            saved_files+=("$lrc_file")
            echo -e "\nSaved synced lyrics to: $lrc_file"
            
            # Ask if user wants to generate SRT file
            read -p "Do you want to generate an SRT subtitle file? (y/n): " generate_srt
            debug_log "User chose to generate SRT: $generate_srt"
            
            if [[ "$generate_srt" =~ ^[Yy]$ ]]; then
                debug_log "Generating SRT file"
                # Use the Python script for conversion
                if [ -f "$DEPENDENCIES_DIR/lrc2srt.py" ]; then
                    srt_file="$output_dir/$base_name.srt"
                    python3 "$DEPENDENCIES_DIR/lrc2srt.py" "$lrc_file" "$srt_file"
                    if [ -f "$srt_file" ]; then
                        saved_files+=("$srt_file")
                        echo "Saved SRT subtitles to: $srt_file"
                    else
                        echo "Error: Failed to create SRT file."
                    fi
                else
                    debug_log "LRC2SRT script not found, recreating it"
                    copy_lrc2srt_script
                    srt_file="$output_dir/$base_name.srt"
                    python3 "$DEPENDENCIES_DIR/lrc2srt.py" "$lrc_file" "$srt_file"
                    if [ -f "$srt_file" ]; then
                        saved_files+=("$srt_file")
                        echo "Saved SRT subtitles to: $srt_file"
                    else
                        echo "Error: Failed to create SRT file."
                    fi
                fi
            fi
            
            debug_log "Successfully saved lyrics"
        else
            debug_log "Saving plain lyrics (TXT format)"
            # Save plain lyrics (TXT format)
            plain_content=$(echo "$response" | jq -r ".[$index].plainLyrics")
            txt_file="$output_dir/$base_name.txt"
            debug_log "Writing to file: $txt_file"
            echo "$plain_content" > "$txt_file"
            saved_files+=("$txt_file")
            echo -e "\nSaved plain lyrics to: $txt_file"
            debug_log "Successfully saved plain lyrics"
        fi
        
        # List all saved files and check for non-Latin characters
        if [ ${#saved_files[@]} -gt 0 ]; then
            echo -e "\nAll files saved:"
            for file in "${saved_files[@]}"; do
                echo "- $file"
            done
            
            # Check for non-Latin characters in saved lyrics
            has_non_latin=false
            non_latin_file=""
            for file in "${saved_files[@]}"; do
                if detect_non_latin "$file"; then
                    has_non_latin=true
                    non_latin_file="$file"
                    break
                fi
            done
            
            # Offer romanization if non-Latin characters are detected
            if [ "$has_non_latin" = true ]; then
                echo ""
                echo "⚠️ Non-Latin characters detected in lyrics."
                echo "Romanization recommended for easier reading."
                read -p "Would you like to romanize these lyrics? (y/n): " romanize_choice
                if [[ "$romanize_choice" =~ ^[Yy]$ ]]; then
                    romanize_lyrics "$non_latin_file"
                fi
            fi
            
            # Only offer music-related options if we have a song file
            if [ -n "$song_file" ] && [ -f "$song_file" ]; then
                # Show audio processing options in a separate block
                echo ""
                echo "Audio file options are available in the main menu."
            fi
            
            # If we saved LRC or SRT, offer to create a clean lyrics version
            if [[ "${saved_files[*]}" == *".lrc"* || "${saved_files[*]}" == *".srt"* ]]; then
                read -p "Would you like to create a clean lyrics text file (no timestamps)? (y/n): " create_clean
                if [[ "$create_clean" =~ ^[Yy]$ ]]; then
                    # Find the saved lyrics file (LRC preferred)
                    lyrics_file=""
                    for file in "${saved_files[@]}"; do
                        if [[ "$file" == *".lrc" ]]; then
                            lyrics_file="$file"
                            break
                        elif [[ "$file" == *".srt" ]]; then
                            lyrics_file="$file"
                        fi
                    done
                    
                    if [ -n "$lyrics_file" ]; then
                        format_lyrics "$lyrics_file"
                    fi
                fi
            fi
        fi
        
        return 0
    else
        echo "Please install jq for lyrics saving (brew install jq)"
        debug_log "jq not found, cannot process JSON"
        return 1
    fi
}


# =====METADATA FUNCTIONS=====

# Function to export song metadata to a text file
export_song_metadata() {
    local input_file="$1"
    local spotify_url="$2"  # Optional Spotify URL parameter
    local custom_filename="$3"  # Optional custom filename
    
    if [ -z "$input_file" ]; then
        echo "Select a song file to export metadata:"
        if [ -z "$OUTPUT_DIR" ]; then
            echo "Output directory not set."
            set_output_directory
            if [ $? -ne 0 ]; then
                echo "Failed to set output directory. Returning to previous menu."
                return 1
            fi
        fi
        
        echo "Looking for audio files in $OUTPUT_DIR..."
        audio_files=$(find "$OUTPUT_DIR" -type f \( -name "*.mp3" -o -name "*.flac" -o -name "*.m4a" -o -name "*.wav" -o -name "*.opus" \) | sort)
        
        if [ -z "$audio_files" ]; then
            echo "No audio files found in $OUTPUT_DIR."
            read -p "Enter full path to audio file (or 'c' to cancel): " custom_file
            if [ "$custom_file" = "c" ]; then
                echo "Operation cancelled."
                return 1
            fi
            
            if [ -n "$custom_file" ] && [ -f "$custom_file" ]; then
                input_file="$custom_file"
            else
                echo "Invalid file path."
                return 1
            fi
        else
            # Display list of found audio files
            echo "Found audio files:"
            count=1
            while IFS= read -r file; do
                echo "$count) $(basename "$file")"
                count=$((count + 1))
            done <<< "$audio_files"
            
            read -p "Select file number to export metadata (or 'c' to enter custom path, 'q' to cancel): " file_choice
            
            if [ "$file_choice" = "q" ] || [ "$file_choice" = "c" ]; then
                if [ "$file_choice" = "q" ]; then
                    echo "Operation cancelled."
                    return 1
                else
                    read -p "Enter full path to audio file (or 'c' to cancel): " custom_file
                    if [ "$custom_file" = "c" ]; then
                        echo "Operation cancelled."
                        return 1
                    fi
                    
                    if [ -n "$custom_file" ] && [ -f "$custom_file" ]; then
                        input_file="$custom_file"
                    else
                        echo "Invalid file path."
                        return 1
                    fi
                fi
            elif [[ "$file_choice" =~ ^[0-9]+$ ]] && [ "$file_choice" -gt 0 ] && [ "$file_choice" -lt "$count" ]; then
                input_file=$(echo "$audio_files" | sed -n "${file_choice}p")
            else
                echo "Invalid selection."
                return 1
            fi
        fi
    fi
    
    local file="$input_file"
    local output_dir="$(dirname "$file")"
    
    # Determine the output filename
    local metadata_file=""
    if [ -n "$custom_filename" ]; then
        # Use custom filename if specified
        metadata_file="$output_dir/$custom_filename"
    else
        # Default to Metadata.txt for single files
        metadata_file="$output_dir/Metadata.txt"
    fi
    
    echo "Extracting and exporting metadata from: $file"
    debug_log "Extracting and exporting metadata from file: $file"
    
    # Extract basic metadata first
    local metadata=$(extract_metadata "$file")
    if [ $? -ne 0 ]; then
        echo "Failed to extract metadata."
        return 1
    fi
    
    # Split the metadata string
    IFS='|' read -r artist title album duration featured_artist remixer <<< "$metadata"
    
    # Format duration nicely (MM:SS)
    local minutes=$((duration / 60))
    local seconds=$((duration % 60))
    local formatted_duration=$(printf "%d:%02d" "$minutes" "$seconds")
    
    # Get additional metadata using ffprobe
    local genre=""
    local additional_metadata=""
    
    if command -v ffprobe &> /dev/null; then
        # Try to get genre
        genre=$(ffprobe -v quiet -show_entries format_tags=genre -of default=noprint_wrappers=1:nokey=1 "$file" 2>/dev/null || echo "")
        
        # Try to get Spotify URL from comments or other metadata fields if not provided
        if [ -z "$spotify_url" ]; then
            local comment=$(ffprobe -v quiet -show_entries format_tags=comment -of default=noprint_wrappers=1:nokey=1 "$file" 2>/dev/null || echo "")
            # Check if comment contains a Spotify URL
            if [[ "$comment" == *"spotify.com"* ]]; then
                spotify_url=$(echo "$comment" | grep -o 'https://open.spotify.com/[^[:space:]]*' | head -1)
            fi
        fi
        
        # Get any other interesting metadata fields
        local year=$(ffprobe -v quiet -show_entries format_tags=date,year -of default=noprint_wrappers=1:nokey=1 "$file" 2>/dev/null || echo "")
        local publisher=$(ffprobe -v quiet -show_entries format_tags=publisher -of default=noprint_wrappers=1:nokey=1 "$file" 2>/dev/null || echo "")
        
        # Build additional metadata string
        if [ -n "$year" ]; then
            additional_metadata+="Year: $year\n"
        fi
        if [ -n "$publisher" ]; then
            additional_metadata+="Publisher: $publisher\n"
        fi
        if [ -n "$comment" ]; then
            additional_metadata+="Comment: $comment\n"
        fi
    fi
    
    # If no Spotify URL was found, ask the user if they want to enter one
    if [ -z "$spotify_url" ]; then
        read -p "Enter Spotify URL for this song (or press Enter to skip): " user_spotify_url
        if [ -n "$user_spotify_url" ]; then
            spotify_url="$user_spotify_url"
        fi
    fi
    
    # Generate the metadata text
    local metadata_text=""
    
    # Title and artist line with optional featuring/remix
    metadata_text+="$artist - $title"
    if [ -n "$featured_artist" ]; then
        metadata_text+=" feat. $featured_artist"
    fi
    if [ -n "$remixer" ]; then
        metadata_text+=" (${remixer} Remix)"
    fi
    metadata_text+=" (Lyrics)\n"
    
    # Duration line
    metadata_text+="$formatted_duration\n"
    
    # Album line if available
    if [ -n "$album" ]; then
        metadata_text+="Album: $album\n"
    fi
    
    # Genre line if available
    if [ -n "$genre" ]; then
        metadata_text+="Genre: $genre\n"
    fi
    
    # Spotify URL if available
    if [ -n "$spotify_url" ]; then
        metadata_text+="Spotify: $spotify_url\n"
    fi
    
    # Additional metadata if available
    if [ -n "$additional_metadata" ]; then
        metadata_text+="$additional_metadata"
    fi
    
    # Write to file
    echo -e "$metadata_text" > "$metadata_file"
    echo "Metadata exported to: $metadata_file"
    debug_log "Metadata exported to: $metadata_file"
    
    return 0
}

# Function to extract metadata from audio file
extract_metadata() {
    local file="$1"
    local artist=""
    local title=""
    local album=""
    local duration=0
    local featured_artist=""
    local remixer=""
    
    echo "Extracting metadata from: $file" >&2
    debug_log "Extracting metadata from file: $file"
    
    # Make sure the file exists and is readable
    if [ ! -f "$file" ]; then
        echo "Error: File not found: $file" >&2
        debug_log "Error: File not found: $file"
        return 1
    fi
    
    # Ensure file permissions are correct
    chmod 644 "$file"
    
    # First try with ffprobe
    if command -v ffprobe &> /dev/null; then
        debug_log "Using ffprobe for metadata extraction"
        
        # Check if ffprobe can access the file
        if ! ffprobe -v error -show_format "$file" &>/dev/null; then
            echo "Error: Cannot access file with ffprobe: $file" >&2
            debug_log "Error: Cannot access file with ffprobe: $file"
            return 1
        fi
        
        artist=$(ffprobe -v quiet -show_entries format_tags=artist -of default=noprint_wrappers=1:nokey=1 "$file" 2>/dev/null || echo "")
        title=$(ffprobe -v quiet -show_entries format_tags=title -of default=noprint_wrappers=1:nokey=1 "$file" 2>/dev/null || echo "")
        album=$(ffprobe -v quiet -show_entries format_tags=album -of default=noprint_wrappers=1:nokey=1 "$file" 2>/dev/null || echo "")
        featured_artist=$(ffprobe -v quiet -show_entries format_tags=composer,featuring,FEATURING -of default=noprint_wrappers=1:nokey=1 "$file" 2>/dev/null || echo "")
        remixer=$(ffprobe -v quiet -show_entries format_tags=remixer,REMIXER,REMIXED_BY -of default=noprint_wrappers=1:nokey=1 "$file" 2>/dev/null || echo "")
        
        # Get duration in seconds using ffprobe
        duration=$(ffprobe -v quiet -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$file" 2>/dev/null || echo "0")
        # Round to nearest integer
        duration=$(printf "%.0f" "$duration")
        
        debug_log "Metadata from ffprobe:"
        debug_log "  Artist: '$artist'"
        debug_log "  Title: '$title'"
        debug_log "  Album: '$album'"
        debug_log "  Featured Artist: '$featured_artist'"
        debug_log "  Remixer: '$remixer'"
        debug_log "  Duration: '$duration' seconds"
        
        echo "Metadata from ffprobe:" >&2
        echo "  Artist: $artist" >&2
        echo "  Title: $title" >&2
        echo "  Album: $album" >&2
        echo "  Featured Artist: $featured_artist" >&2
        echo "  Remixer: $remixer" >&2
        echo "  Duration: $duration seconds" >&2
    else
        debug_log "ffprobe not found, using filename for metadata"
        echo "ffprobe not found, using filename for metadata" >&2
    fi
    
    # If ffprobe didn't work or metadata is empty, parse from filename
    if [ -z "$artist" ] || [ -z "$title" ]; then
        debug_log "Extracting metadata from filename..."
        echo "Extracting metadata from filename..." >&2
        
        # Get filename without path and extension
        filename=$(basename "${file%.*}")
        debug_log "Filename without extension: '$filename'"
        
        # Split by hyphen if it exists, otherwise use whole filename as title
        if [[ "$filename" == *"-"* ]]; then
            # Get parts before and after the first hyphen
            artist="${filename%%-*}"
            title="${filename#*-}"
            
            # Trim whitespace
            artist=$(echo "$artist" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
            title=$(echo "$title" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
            
            # Check for featuring in title
            if [[ "$title" == *"feat"* || "$title" == *"ft"* || "$title" == *"featuring"* ]]; then
                if [[ "$title" == *"feat."* ]]; then
                    featured_artist="${title#*feat.}"
                    title="${title%%feat.*}"
                elif [[ "$title" == *"ft."* ]]; then
                    featured_artist="${title#*ft.}"
                    title="${title%%ft.*}"
                elif [[ "$title" == *"featuring"* ]]; then
                    featured_artist="${title#*featuring}"
                    title="${title%%featuring*}"
                fi
                # Clean up featured artist string
                featured_artist=$(echo "$featured_artist" | sed -e 's/^[[:space:]]*[\.:]*//' -e 's/[[:space:]]*$//')
            fi
            
            # Check for remixer in title
            if [[ "$title" == *"remix"* || "$title" == *"Remix"* ]]; then
                # Extract the remixer from patterns like "(Something Remix)" or "[Something Remix]"
                if [[ "$title" == *"("*"remix"*")"* || "$title" == *"("*"Remix"*")"* ]]; then
                    # Extract text between parentheses that contains "remix"
                    remix_part=$(echo "$title" | grep -io "([^)]*remix[^)]*)" | head -1)
                    # Remove parentheses and "remix" word to get just the remixer name
                    remixer=$(echo "$remix_part" | sed -e 's/^(//' -e 's/)$//' -e 's/ \?[Rr]emix$//')
                    # Trim whitespace
                    remixer=$(echo "$remixer" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
                fi
            fi
            
            debug_log "Metadata from filename:"
            debug_log "  Artist: '$artist'"
            debug_log "  Title: '$title'"
            debug_log "  Featured: '$featured_artist'"
            debug_log "  Remixer: '$remixer'"
            
            echo "Metadata from filename:" >&2
            echo "  Artist: $artist" >&2
            echo "  Title: $title" >&2
            echo "  Featured: $featured_artist" >&2
            echo "  Remixer: $remixer" >&2
        else
            title="$filename"
            artist="Unknown"
            debug_log "Artist not found in filename: '$filename', using 'Unknown'"
            echo "Artist not found in filename: $filename, using 'Unknown'" >&2
        fi
    fi
    
    # Check if we have the minimum required information
    if [ -z "$artist" ] || [ -z "$title" ]; then
        echo "Error: Could not extract required metadata." >&2
        debug_log "Failed to extract required metadata"
        return 1
    fi
    
    debug_log "Final metadata:"
    debug_log "  Artist: '$artist'"
    debug_log "  Title: '$title'"
    debug_log "  Album: '$album'"
    debug_log "  Featured Artist: '$featured_artist'"
    debug_log "  Remixer: '$remixer'"
    debug_log "  Duration: '$duration' seconds"
    
    # Return data as pipe-separated values
    printf "%s|%s|%s|%s|%s|%s" "$artist" "$title" "$album" "$duration" "$featured_artist" "$remixer"
    return 0
}

# Function to get duration in seconds from audio file
get_duration() {
    local file="$1"
    
    if command -v ffprobe &> /dev/null; then
        # Get duration in seconds using ffprobe
        duration=$(ffprobe -v quiet -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$file")
        # Round to nearest integer
        duration=$(printf "%.0f" "$duration")
        echo "$duration"
        return 0
    else
        echo "0"
        return 1
    fi
}


# =====LYRIC FUNCTIONS=====

# Function to check if lyrics files already exist
check_existing_lyrics() {
    local dir="$1"
    local base_name="$2"
    
    # Check if LRC, SRT, or TXT files exist
    if [ -f "$dir/$base_name.lrc" ] || [ -f "$dir/$base_name.srt" ] || [ -f "$dir/$base_name.txt" ]; then
        return 0  # Files exist
    else
        return 1  # No files exist
    fi
}

# Function to search for lyrics using various methods
search_lyrics() {
    local file="$1"
    local method="$2"
    
    # Set default method if not provided
    if [ -z "$method" ]; then
        echo "Please select a lyrics search method:"
        echo "1) Auto Search (try all methods)"
        echo "2) LRCLIB Search (lyrics database)"
        echo "3) SpotDL Search (SpotDL sources)"
        echo "4) Genius Search (lyricsgenius)"
        echo "5) AI Transcribe (using OpenAI Whisper)"
        echo "6) Cancel search"
        read -p "Enter your choice (1-6): " method_choice
        
        case $method_choice in
            1) method="auto" ;;
            2) method="lrclib" ;;
            3) method="spotdl" ;;
            4) method="genius" ;;
            5) method="whisper" ;;
            6) 
                echo "Lyrics search cancelled."
                return 1 ;;
            *)
                echo "Invalid choice. Using Auto Search."
                method="auto" ;;
        esac
    fi
    
    debug_log "Starting lyrics search with method: $method, file: $file"
    
    # If no file is provided and we're not in manual search mode, make file selection optional
    if [ -z "$file" ]; then
        # For whisper, we must have an audio file
        if [ "$method" = "whisper" ]; then
            echo "Whisper transcription requires an audio file."
            echo "What would you like to do:"
            echo "1) Select an audio file to transcribe"
            echo "2) Go back to method selection"
            echo "3) Cancel search"
            read -p "Enter your choice (1-3): " whisper_choice
            
            case $whisper_choice in
                1)
                    # This maps to option 2 in the original menu
                    file_choice=2
                    ;;
                2)
                    # Go back to method selection
                    echo "Going back to method selection..."
                    search_lyrics "" ""
                    return $?
                    ;;
                3|*)
                    # Cancel search
                    echo "Search cancelled."
                    return 1
                    ;;
            esac
        else
            # For other methods, show the full menu
            echo "No file specified. Would you like to:"
            echo "1) Search using only artist and title (no audio file needed)"
            echo "2) Select an audio file to use for searching"
            echo "3) Go back to method selection"
            echo "4) Cancel search"
            read -p "Enter your choice (1-4): " file_choice
        fi

        
        if [ "$file_choice" = "2" ]; then
            echo "Searching for audio files..."
            
            # Check if OUTPUT_DIR is set and exists - and is writable
            if [ -n "$OUTPUT_DIR" ] && [ -d "$OUTPUT_DIR" ] && [ -w "$OUTPUT_DIR" ]; then
                # Look for recent audio files in output directory
                find_cmd="find \"$OUTPUT_DIR\" -type f \( -name \"*.mp3\" -o -name \"*.flac\" -o -name \"*.m4a\" -o -name \"*.wav\" -o -name \"*.opus\" \) -mtime -1 2>/dev/null | sort -r | head -1"
                file=$(eval "$find_cmd")
                
                if [ -n "$file" ]; then
                    echo "Found recent audio file: $file"
                    debug_log "Found audio file: $file"
                else
                    echo "No audio files found in $OUTPUT_DIR."
                    
                    # Ask for manual file input
                    read -p "Enter full path to audio file (or press Enter to skip, 'c' to cancel, 'b' to go back): " manual_file
                    
                    if [ "$manual_file" = "c" ]; then
                        echo "Lyrics search cancelled."
                        debug_log "Lyrics search cancelled by user"
                        return 1
                    elif [ "$manual_file" = "b" ]; then
                        # Go back to method selection
                        search_lyrics "" ""
                        return $?
                    elif [ -n "$manual_file" ] && [ -f "$manual_file" ]; then
                        file="$manual_file"
                    else
                        echo "No valid file provided. Continuing with artist/title search only."
                        file=""
                    fi
                fi
            else
                echo "Output directory not set or doesn't exist."
                echo "What would you like to do?"
                echo "1) Set output directory now"
                echo "2) Continue with artist/title search only"
                echo "3) Cancel and go back"
                read -p "Enter your choice (1-3): " dir_choice
                
                case $dir_choice in
                    1)
                        # Call the set_output_directory function
                        set_output_directory
                        if [ $? -ne 0 ]; then
                            echo "Directory setting cancelled."
                            return 1
                        fi
                        
                        # After setting the directory, verify it and continue
                        if [ -n "$OUTPUT_DIR" ] && [ -d "$OUTPUT_DIR" ] && [ -w "$OUTPUT_DIR" ]; then
                            echo "Output directory successfully set to: $OUTPUT_DIR"
                            echo "Continuing with lyrics search..."
                            # Continue with artist/title search since there's no file
                            file=""
                        else
                            echo "Output directory not properly set. Cancelling search."
                            return 1
                        fi
                        ;;
                    2)
                        # Continue with artist/title search only
                        file=""
                        ;;
                    3|*)
                        echo "Operation cancelled."
                        return 1
                        ;;
                esac
            fi
        elif [ "$file_choice" = "3" ]; then
            # Go back to method selection
            echo "Going back to method selection..."
            search_lyrics "" ""
            return $?
        elif [ "$file_choice" = "4" ]; then
            # Cancel search
            echo "Search cancelled."
            return 1
        elif [ "$file_choice" = "1" ]; then
            echo "Continuing with artist/title search only."
            file=""
        else
            echo "Invalid choice. Cancelling search."
            return 1
        fi
    fi
    
    # If we have a file, extract metadata from it
    local artist=""
    local title=""
    
    if [ -n "$file" ]; then
        # Extract artist and title from file
        if command -v ffprobe &> /dev/null; then
            artist=$(ffprobe -loglevel error -show_entries format_tags=artist -of default=noprint_wrappers=1:nokey=1 "$file" 2>/dev/null | head -n 1)
            title=$(ffprobe -loglevel error -show_entries format_tags=title -of default=noprint_wrappers=1:nokey=1 "$file" 2>/dev/null | head -n 1)
            
            debug_log "Extracted metadata - Artist: $artist, Title: $title"
        fi
        
        # If metadata extraction failed, try to extract from filename
        if [ -z "$artist" ] || [ -z "$title" ]; then
            echo "Could not extract metadata from file. Trying to parse filename..."
            
            # Try to parse artist - title format from filename
            local filename=$(basename "$file")
            local filename_noext="${filename%.*}"
            
            if [[ "$filename_noext" == *" - "* ]]; then
                artist="${filename_noext%% - *}"
                title="${filename_noext#* - }"
                echo "Parsed from filename - Artist: $artist, Title: $title"
                debug_log "Parsed from filename - Artist: $artist, Title: $title"
            else
                echo "Could not parse artist and title from filename."
                artist=""
                title=""
            fi
        fi
    fi
    
    # If we still don't have artist and title, ask for manual input
    if [ -z "$artist" ] || [ -z "$title" ]; then
        echo "Please enter song details manually (or 'c' to cancel, 'b' to go back):"
        read -p "Artist: " artist_input
        
        if [ "$artist_input" = "c" ]; then
            echo "Operation cancelled."
            return 1
        elif [ "$artist_input" = "b" ]; then
            # Go back to file selection
            search_lyrics "" "$method"
            return $?
        fi
        
        artist="$artist_input"
        
        read -p "Title: " title_input
        if [ "$title_input" = "c" ]; then
            echo "Operation cancelled."
            return 1
        elif [ "$title_input" = "b" ]; then
            # Go back to artist entry
            search_lyrics "" "$method"
            return $?
        fi
        
        title="$title_input"
        
        if [ -z "$artist" ] || [ -z "$title" ]; then
            echo "Artist and title are required for lyrics search."
            debug_log "Lyrics search failed - missing artist/title"
            return 1
        fi
    fi
    
    # Metadata confirmation step
    echo ""
    echo "Ready to search for lyrics with the following details:"
    echo "Artist: $artist"
    echo "Title: $title"
    echo ""
    echo "1) Continue with these details"
    echo "2) Edit artist name"
    echo "3) Edit title"
    echo "4) Cancel search"
    read -p "Choose an option (1-4): " confirm_choice
    
    case $confirm_choice in
        2)
            read -p "Enter artist name: " new_artist
            if [ -n "$new_artist" ]; then
                artist="$new_artist"
                # Show confirmation again with updated info
                echo ""
                echo "Updated details:"
                echo "Artist: $artist"
                echo "Title: $title"
                echo ""
                read -p "Continue with these details? (y/n): " continue_choice
                if [[ ! "$continue_choice" =~ ^[Yy]$ ]]; then
                    echo "Search cancelled."
                    return 1
                fi
            fi
            ;;
        3)
            read -p "Enter title: " new_title
            if [ -n "$new_title" ]; then
                title="$new_title"
                # Show confirmation again with updated info
                echo ""
                echo "Updated details:"
                echo "Artist: $artist"
                echo "Title: $title"
                echo ""
                read -p "Continue with these details? (y/n): " continue_choice
                if [[ ! "$continue_choice" =~ ^[Yy]$ ]]; then
                    echo "Search cancelled."
                    return 1
                fi
            fi
            ;;
        4)
            echo "Search cancelled."
            return 1
            ;;
        *)
            # Continue with search using provided metadata
            ;;
    esac
    
    # Based on method, try different lyrics sources
    local search_result=1
    
    case $method in
        "auto")
            echo "Trying all lyrics search methods..."
            debug_log "Starting auto lyrics search"
            
            # Try LRCLIB first
            search_lrclib_lyrics "$artist" "$title" "$file"
            search_result=$?
            
            # If LRCLIB succeeded, don't try other methods
            if [ $search_result -eq 0 ]; then
                echo "Lyrics found via LRCLIB. Stopping search."
                return 0
            fi
            
            # If LRCLIB failed, show enhanced options menu
            echo -e "\nLRCLIB search did not find lyrics. What would you like to do?"
            echo "1) Try again with different artist/title metadata"
            echo "2) Try SpotDL search instead"
            echo "3) Try Genius search instead"
            echo "4) Go back to search method selection"
            echo "5) Cancel search completely"
            read -p "Enter your choice (1-5): " retry_choice
            
            case $retry_choice in
                1)
                    # Allow user to edit metadata and retry
                    echo "Please update the song details:"
                    read -p "Artist [$artist]: " new_artist
                    artist=${new_artist:-$artist}
                    read -p "Title [$title]: " new_title
                    title=${new_title:-$title}
                    echo -e "\nRetrying LRCLIB search with: $artist - $title"
                    
                    # Retry with LRCLIB directly - don't restart the whole search process
                    search_lrclib_lyrics "$artist" "$title" "$file"
                    search_result=$?
                    
                    # If LRCLIB still failed, show the options menu again
                    if [ $search_result -ne 0 ]; then
                        # Show the menu again but don't restart the whole search
                        echo -e "\nLRCLIB search still did not find lyrics. What would you like to do?"
                        echo "1) Try again with different artist/title metadata"
                        echo "2) Try Genius search instead"  # Change this line
                        echo "3) Try SpotDL search instead"  # Add this line
                        echo "4) Go back to search method selection"  # Update number
                        echo "5) Cancel search completely"  # Update number
                        read -p "Enter your choice (1-5): " retry_choice_again  # Update max choice
                        
                        case $retry_choice_again in
                            1)
                                # Try one more time with different metadata
                                echo "Please update the song details:"
                                read -p "Artist [$artist]: " new_artist
                                artist=${new_artist:-$artist}
                                read -p "Title [$title]: " new_title
                                title=${new_title:-$title}
                                echo -e "\nRetrying LRCLIB search with: $artist - $title"
                                search_lrclib_lyrics "$artist" "$title" "$file"
                                search_result=$?
                                
                                if [ $search_result -ne 0 ]; then
                                    echo "Still no lyrics found. Trying SpotDL search..."
                                    search_spotdl_lyrics "$artist" "$title" "$file"
                                    return $?
                                else
                                    return 0
                                fi
                                ;;
                            2)
                                # Try SpotDL
                                search_spotdl_lyrics "$artist" "$title" "$file"
                                search_result=$?
                                
                                # If SpotDL succeeded, don't try other methods
                                if [ $search_result -eq 0 ]; then
                                    echo "Lyrics found via SpotDL. Stopping search."
                                    return 0
                                fi
                                
                                # If SpotDL failed, offer Genius
                                echo "SpotDL search did not find lyrics. Would you like to try Genius search? (y/n)"
                                read -p "> " try_genius
                                
                                if [[ "$try_genius" =~ ^[Yy]$ ]]; then
                                    search_genius_lyrics "$artist" "$title" "$file"
                                    search_result=$?
                                    
                                    # If Genius still failed and we have a file, offer Whisper
                                    if [ $search_result -ne 0 ] && [ -n "$file" ]; then
                                        echo "Genius search did not find lyrics. Would you like to try AI transcription with Whisper? (y/n)"
                                        read -p "> " use_whisper
                                        
                                        if [[ "$use_whisper" =~ ^[Yy]$ ]]; then
                                            transcribe_with_whisper "$file"
                                            search_result=$?
                                        fi
                                    fi
                                fi
                                return $search_result
                                ;;
                            3)
                                # Try Genius
                                search_genius_lyrics "$artist" "$title" "$file"
                                search_result=$?
                                
                                # If Genius succeeded, don't try other methods
                                if [ $search_result -eq 0 ]; then
                                    echo "Lyrics found via Genius. Stopping search."
                                    return 0
                                fi
                                
                                # If Genius failed and we have a file, offer Whisper
                                if [ -n "$file" ]; then
                                    echo "Genius search did not find lyrics. Would you like to try AI transcription with Whisper? (y/n)"
                                    read -p "> " use_whisper
                                    
                                    if [[ "$use_whisper" =~ ^[Yy]$ ]]; then
                                        transcribe_with_whisper "$file"
                                        search_result=$?
                                    fi
                                fi
                                return $search_result
                                ;;
                            4)
                                # Go back to method selection
                                search_lyrics "$file" ""
                                return $?
                                ;;
                            5|*)
                                # Cancel search completely
                                echo "Search cancelled."
                                return 1
                                ;;
                        esac
                    else
                        return 0
                    fi
                    ;;
                2)
                    # Try SpotDL
                    search_spotdl_lyrics "$artist" "$title" "$file"
                    search_result=$?
                    
                    # If SpotDL succeeded, don't try other methods
                    if [ $search_result -eq 0 ]; then
                        echo "Lyrics found via SpotDL. Stopping search."
                        return 0
                    fi
                    
                    # If SpotDL failed, offer Genius
                    echo "SpotDL search did not find lyrics. Would you like to try Genius search? (y/n)"
                    read -p "> " try_genius
                    
                    if [[ "$try_genius" =~ ^[Yy]$ ]]; then
                        search_genius_lyrics "$artist" "$title" "$file"
                        search_result=$?
                        
                        # If Genius still failed and we have a file, offer Whisper
                        if [ $search_result -ne 0 ] && [ -n "$file" ]; then
                            echo "Genius search did not find lyrics. Would you like to try AI transcription with Whisper? (y/n)"
                            read -p "> " use_whisper
                            
                            if [[ "$use_whisper" =~ ^[Yy]$ ]]; then
                                transcribe_with_whisper "$file"
                                search_result=$?
                            fi
                        fi
                    fi
                    return $search_result
                    ;;
                3)
                    # Try Genius
                    search_genius_lyrics "$artist" "$title" "$file"
                    search_result=$?
                    
                    # If Genius succeeded, don't try other methods
                    if [ $search_result -eq 0 ]; then
                        echo "Lyrics found via Genius. Stopping search."
                        return 0
                    fi
                    
                    # If Genius failed and we have a file, offer Whisper
                    if [ -n "$file" ]; then
                        echo "Genius search did not find lyrics. Would you like to try AI transcription with Whisper? (y/n)"
                        read -p "> " use_whisper
                        
                        if [[ "$use_whisper" =~ ^[Yy]$ ]]; then
                            transcribe_with_whisper "$file"
                            search_result=$?
                        fi
                    fi
                    return $search_result
                    ;;
                4)
                    # Go back to method selection
                    search_lyrics "$file" ""
                    return $?
                    ;;
                5|*)
                    # Cancel search completely
                    echo "Search cancelled."
                    return 1
                    ;;
            esac
            ;;
            
        "lrclib")
            search_lrclib_lyrics "$artist" "$title" "$file"
            search_result=$?
            ;;
              
        "spotdl")
            search_spotdl_lyrics "$artist" "$title" "$file"
            search_result=$?
            ;;
        
        "genius")
            search_genius_lyrics "$artist" "$title" "$file"
            search_result=$?
            ;; 

        "whisper")
            if [ -n "$file" ]; then
                transcribe_with_whisper "$file"
                search_result=$?
            else
                echo "Error: Whisper transcription requires an audio file."
                debug_log "Whisper transcription failed - no file"
                search_result=1
            fi
            ;;
            
        *)
            echo "Unknown search method: $method"
            debug_log "Unknown search method: $method"
            search_result=1
            ;;
    esac
    
    if [ $search_result -eq 0 ]; then
        echo "Lyrics search completed successfully."
        debug_log "Lyrics search successful"
        return 0
    else
        echo "Lyrics search failed."
        debug_log "Lyrics search failed"
        return 1
    fi
}

# Function to search for lyrics using LRCLIB
search_lrclib_lyrics() {
    local artist="$1"
    local title="$2"
    local file="$3"
    local output_path=""
    
    echo -e "\nSearching for lyrics using LRCLIB..."
    debug_log "LRCLIB search for Artist: '$artist', Title: '$title'"
    
    # Determine output path and base name
    if [ -n "$file" ]; then
        output_path="$(dirname "$file")"
        local base_name="$(basename "${file%.*}")"
        local output_file="${file%.*}.lrc"
    else
        output_path="$OUTPUT_DIR"
        if [ -z "$output_path" ] || [ ! -d "$output_path" ]; then
            # Provide options when output directory is not set
            echo "No valid output directory set."
            echo "What would you like to do?"
            echo "1) Set output directory now"
            echo "2) Use ~/Downloads for this operation only"
            echo "3) Go back"
            read -p "Enter your choice (1-3): " dir_choice
            
            case $dir_choice in
                1)
                    # Call the set_output_directory function
                    set_output_directory
                    if [ $? -ne 0 ]; then
                        echo "Directory setting cancelled."
                        return 1
                    fi
                    # Update output_path with the newly set directory
                    output_path="$OUTPUT_DIR"
                    ;;
                2)
                    # Use Downloads as a temporary directory
                    output_path="$HOME/Downloads"
                    echo "Using $output_path for this operation."
                    ;;
                3|*)
                    echo "Operation cancelled."
                    return 1
                    ;;
            esac
        fi
        # Create a sanitized filename
        local base_name="$(echo "$artist - $title" | tr -d '[:cntrl:]' | tr -c '[:alnum:][:blank:]' '_')"
        local output_file="$output_path/$base_name.lrc"
    fi
    
    # Perform permissions check on output directory
    if [ ! -w "$output_path" ]; then
        echo "Warning: Cannot write to $output_path - permission denied"
        output_path="$HOME/Downloads"
        [ ! -d "$output_path" ] && mkdir -p "$output_path"
        echo "Using alternate location: $output_path"
        # Need to update output_file as well
        if [ -n "$file" ]; then
            local base_name="$(basename "${file%.*}")"
            output_file="$output_path/$base_name.lrc"
        else
            local base_name="$(echo "$artist - $title" | tr -d '[:cntrl:]' | tr -c '[:alnum:][:blank:]' '_')"
            output_file="$output_path/$base_name.lrc"
        fi
    fi
    
    # Encode query parameters - using jq for better encoding if available
    local artist_encoded=""
    local title_encoded=""
    if command -v jq &> /dev/null; then
        artist_encoded=$(printf "%s" "$artist" | jq -sRr @uri)
        title_encoded=$(printf "%s" "$title" | jq -sRr @uri)
    else
        artist_encoded=$(urlencode "$artist")
        title_encoded=$(urlencode "$title")
    fi
    
    # Call LRCLIB API to search for lyrics
    local search_url="https://lrclib.net/api/search?track_name=$title_encoded&artist_name=$artist_encoded"
    debug_log "LRCLIB API search URL: $search_url"
    
    # Search for lyrics using the API
    if command -v curl &> /dev/null; then
        local search_result=$(curl -s "$search_url")
        
        # Check if we got valid JSON
        if echo "$search_result" | jq empty &>/dev/null; then
            # Check if we got an empty array
            if [ "$(echo "$search_result" | jq 'length')" = "0" ]; then
                echo "No results found on LRCLIB."
                debug_log "LRCLIB returned empty results array"
                return 1
            fi
            
            # We have results, display them for selection
            echo -e "\nFound $(echo "$search_result" | jq 'length') results on LRCLIB:"
            
            local count=1
            echo "$search_result" | jq -r '.[] | "\(."trackName") - \(."artistName") \(if .syncedLyrics then "[Synced]" else "[Plain]" end)"' | 
            while read -r line; do
                echo "$count) $line"
                count=$((count+1))
            done
            
            # Ask user to select a result with clearer instructions
            echo ""
            echo "OPTIONS:"
            echo "• To download a result: Enter a number (1-$(($count-1)))"
            echo "• To preview a result: Type 'p' followed by the number (e.g., 'p3' to preview #3)"
            echo "• To cancel: Type 'c'"
            read -p "Your choice: " select_choice
            
            if [ "$select_choice" = "c" ]; then
                echo "LRCLIB search cancelled."
                return 1
            elif [[ "$select_choice" == p* ]]; then
                # Extract the number after 'p'
                local preview_num="${select_choice#p}"
                
                if [[ "$preview_num" =~ ^[0-9]+$ ]] && 
                   [ "$preview_num" -gt 0 ] && 
                   [ "$preview_num" -le "$(echo "$search_result" | jq 'length')" ]; then
                    local preview_index=$((preview_num-1))
                    
                    # Show which result is being previewed
                    local preview_title=$(echo "$search_result" | jq -r ".[$preview_index].trackName")
                    local preview_artist=$(echo "$search_result" | jq -r ".[$preview_index].artistName")
                    echo -e "\n===== PREVIEW OF RESULT #$preview_num ====="
                    echo "Title: $preview_title"
                    echo "Artist: $preview_artist"
                    echo "======================================="
                    
                    # Check if it has synced or plain lyrics
                    local has_synced=$(echo "$search_result" | jq -r ".[$preview_index].syncedLyrics != null")
                    
                    if [ "$has_synced" = "true" ]; then
                        # Show first few lines of synced lyrics
                        echo -e "\nSynced lyrics preview (first 10 lines):"
                        echo "$search_result" | jq -r ".[$preview_index].syncedLyrics" | head -10
                    else
                        # Show first few lines of plain lyrics
                        echo -e "\nPlain lyrics preview (first 10 lines):"
                        echo "$search_result" | jq -r ".[$preview_index].plainLyrics" | head -10
                    fi
                    
                    echo -e "\n...(more lines)..."
                    
                    # Ask if they want to download this
                    echo ""
                    echo "OPTIONS:"
                    echo "1) Download these lyrics"
                    echo "2) Preview a different result"
                    echo "3) Return to result list"
                    echo "4) Cancel search"
                    read -p "Choose an option (1-4): " preview_choice
                    
                    case $preview_choice in
                        1)
                            # Download the selected lyrics
                            download_lyrics "$search_result" "$preview_index" "$output_path" "$file" "false"
                            return $?
                            ;;
                        2)
                            # Ask for another preview
                            echo ""
                            read -p "Enter result number to preview (1-$(($count-1))): " new_preview
                            select_choice="p$new_preview"
                            # Loop back to preview handling by using recursion
                            search_lrclib_lyrics "$artist" "$title" "$file"
                            return $?
                            ;;
                        3)
                            # Return to selection
                            search_lrclib_lyrics "$artist" "$title" "$file"
                            return $?
                            ;;
                        4)
                            echo "LRCLIB search cancelled."
                            return 1
                            ;;
                        *)
                            echo "Invalid choice. Returning to results."
                            search_lrclib_lyrics "$artist" "$title" "$file"
                            return $?
                            ;;
                    esac
                else
                    echo "Invalid selection. Please use format 'p1', 'p2', etc."
                    search_lrclib_lyrics "$artist" "$title" "$file"
                    return $?
                fi
            elif [[ "$select_choice" =~ ^[0-9]+$ ]] && 
                 [ "$select_choice" -gt 0 ] && 
                 [ "$select_choice" -le "$(echo "$search_result" | jq 'length')" ]; then
                # Download the selected lyrics directly
                local select_index=$((select_choice-1))
                
                # Show which result was selected
                local selected_title=$(echo "$search_result" | jq -r ".[$select_index].trackName")
                local selected_artist=$(echo "$search_result" | jq -r ".[$select_index].artistName")
                echo -e "\nSelected result #$select_choice:"
                echo "Title: $selected_title"
                echo "Artist: $selected_artist"
                echo ""
                
                # Ask for confirmation before downloading
                read -p "Confirm download of these lyrics? (y/n): " confirm_download
                if [[ "$confirm_download" =~ ^[Yy]$ ]]; then
                    download_lyrics "$search_result" "$select_index" "$output_path" "$file" "false"
                    return $?
                else
                    echo "Download cancelled. Returning to results."
                    search_lrclib_lyrics "$artist" "$title" "$file"
                    return $?
                fi
            else
                echo "Invalid selection. Please enter a number between 1 and $(($count-1)), or 'p' followed by a number."
                read -p "Press Enter to try again..." dummy
                search_lrclib_lyrics "$artist" "$title" "$file"
                return $?
            fi
        else
            echo "Invalid JSON response from LRCLIB."
            debug_log "Invalid JSON response from LRCLIB"
            return 1
        fi
    else
        echo "curl is not installed. Cannot search LRCLIB."
        return 1
    fi
}

# Function to search for lyrics using Genius API
search_genius_lyrics() {
    local artist="$1"
    local title="$2"
    local file="$3"
    local output_path=""
    local python_env=""
    
    echo -e "\nSearching for lyrics using Genius..."
    debug_log "Genius search for Artist: '$artist', Title: '$title'"
    
    # Determine output path
    if [ -n "$file" ]; then
        output_path="$(dirname "$file")"
        local base_name="$(basename "${file%.*}")"
        # Don't set output_file yet - we'll set it after getting the actual song details
    else
        output_path="$OUTPUT_DIR"
        if [ -z "$output_path" ] || [ ! -d "$output_path" ]; then
            # Provide options when output directory is not set
            echo "No valid output directory set."
            echo "What would you like to do?"
            echo "1) Set output directory now"
            echo "2) Use ~/Downloads for this operation only"
            echo "3) Go back"
            read -p "Enter your choice (1-3): " dir_choice
            
            case $dir_choice in
                1)
                    # Call the set_output_directory function
                    set_output_directory
                    if [ $? -ne 0 ]; then
                        echo "Directory setting cancelled."
                        return 1
                    fi
                    # Update output_path with the newly set directory
                    output_path="$OUTPUT_DIR"
                    ;;
                2)
                    # Use Downloads as a temporary directory
                    output_path="$HOME/Downloads"
                    echo "Using $output_path for this operation."
                    ;;
                3|*)
                    echo "Operation cancelled."
                    return 1
                    ;;
            esac
        fi
        # Don't set output_file yet - we'll set it after getting the actual song details
    fi
    
    # Perform permissions check on output directory
    if [ ! -w "$output_path" ]; then
        echo "Warning: Cannot write to $output_path - permission denied"
        output_path="$HOME/Downloads"
        [ ! -d "$output_path" ] && mkdir -p "$output_path"
        echo "Using alternate location: $output_path"
        # We'll update output_file after we get song details
    fi
    
    # Get Genius API token from credentials
    local credentials_file="$API_DIR/credentials.json"
    local api_token=""
    
    if [ -f "$credentials_file" ]; then
        api_token=$(jq -r '.genius.api_token // ""' "$credentials_file" 2>/dev/null)
    fi
    
    if [ -z "$api_token" ] || [ "$api_token" = "null" ]; then
        echo "Genius API token not found in credentials."
        echo "Would you like to set it up now? (y/n)"
        read -p "> " setup_genius
        
        if [[ "$setup_genius" =~ ^[Yy]$ ]]; then
            echo "Please enter your Genius API token:"
            read -s -p "Token: " api_token
            echo ""
            
            if [ -n "$api_token" ]; then
                # Make sure the structure exists
                if ! jq -e '.genius' "$credentials_file" > /dev/null 2>&1; then
                    jq '. += {"genius": {}}' "$credentials_file" > "$credentials_file.tmp" && 
                        mv "$credentials_file.tmp" "$credentials_file"
                fi
                
                # Save the token
                jq ".genius.api_token = \"$api_token\"" "$credentials_file" > "$credentials_file.tmp" && 
                    mv "$credentials_file.tmp" "$credentials_file"
                
                echo "Genius API token saved."
            else
                echo "No token provided. Cannot use Genius search."
                return 1
            fi
        else
            echo "Genius setup skipped. Cannot use Genius search."
            return 1
        fi
    fi
    
    # Check if lyricsgenius is installed
    if ! check_lyricsgenius_installed; then
        echo "lyricsgenius Python package is not installed."
        echo "Would you like to install it now? (y/n)"
        read -p "> " install_lyricsgenius
        
        if [[ "$install_lyricsgenius" =~ ^[Yy]$ ]]; then
            echo "Installing lyricsgenius..."
            
            # Check if we should install in a virtualenv or globally
            echo "Where would you like to install lyricsgenius?"
            echo "1) Global installation (requires permissions)"
            echo "2) User installation (recommended)"
            echo "3) pyenv environment (if available)"
            read -p "Choose installation type (1-3): " install_type
            
            case $install_type in
                1)
                    echo "Installing globally..."
                    pip3 install lyricsgenius
                    ;;
                2)
                    echo "Installing for current user..."
                    pip3 install --user lyricsgenius
                    ;;
                3)
                    if command -v pyenv &> /dev/null; then
                        echo "Available pyenv environments:"
                        pyenv versions
                        read -p "Enter environment name (or 'c' to cancel): " env_name
                        
                        if [ "$env_name" = "c" ]; then
                            echo "Installation cancelled."
                            return 1
                        fi
                        
                        if pyenv versions --bare | grep -q "$env_name"; then
                            echo "Installing in pyenv environment $env_name..."
                            eval "$(pyenv init -)"
                            pyenv activate "$env_name"
                            pip install lyricsgenius
                            pyenv deactivate
                            
                            # Store the environment name for later use
                            python_env="$env_name"
                            
                            # Also save to cache for future sessions
                            echo "$env_name" > "$CACHE_DIR/lyricsgenius_env.txt"
                        else
                            echo "Environment not found. Installing for current user..."
                            pip3 install --user lyricsgenius
                        fi
                    else
                        echo "pyenv not found. Installing for current user..."
                        pip3 install --user lyricsgenius
                    fi
                    ;;
            esac
            
            # Check if installation was successful
            if [ "$install_type" = "3" ]; then
                # For pyenv installation, check if we can import using that environment's Python
                if command -v pyenv &> /dev/null; then
                    eval "$(pyenv init -)"
                    if ! pyenv shell "$env_name" && python -c "import lyricsgenius" &> /dev/null; then
                        pyenv shell --unset  # Reset back
                        echo "Failed to import lyricsgenius from pyenv environment. Please check installation."
                        return 1
                    fi
                    pyenv shell --unset  # Reset back
                else
                    echo "pyenv not found. Checking with system Python..."
                    if ! python3 -c "import lyricsgenius" &> /dev/null; then
                        echo "Failed to install lyricsgenius. Please install it manually."
                        return 1
                    fi
                fi
            else
                # For global or user installation, check with system Python
                if ! python3 -c "import lyricsgenius" &> /dev/null; then
                    echo "Failed to install lyricsgenius. Please install it manually."
                    return 1
                fi
            fi
        else
            echo "lyricsgenius installation skipped. Cannot use Genius search."
            return 1
        fi
    else
        # If it's already installed, find out where
        if [ -f "$CACHE_DIR/lyricsgenius_env.txt" ]; then
            python_env=$(cat "$CACHE_DIR/lyricsgenius_env.txt")
            debug_log "Found lyricsgenius in pyenv environment: $python_env"
        fi
    fi
    
    # Use Python and lyricsgenius to search for lyrics
    echo "Searching Genius for: $artist - $title..."
    
    # Create a temporary Python script to search for lyrics
local tmp_script=$(mktemp)
cat > "$tmp_script" << PYTHON
#!/usr/bin/env python3
import sys
import json
from lyricsgenius import Genius

try:
    # Initialize Genius API
    token = "$api_token"
    genius = Genius(token)
    genius.verbose = False  # Turn off status messages
    genius.remove_section_headers = True  # Remove section headers like [Chorus], [Verse]
    
    # Search for the song
    artist = "$artist"
    title = "$title"
    
    # Try to get the song
    song = genius.search_song(title, artist)
    
    if song:
        # Output JSON with all the song details
        output = {
            "success": True,
            "title": song.title,
            "artist": song.artist,
            "lyrics": song.lyrics,
            "url": song.url
        }
        print(json.dumps(output))
    else:
        # Try a more general search
        print(json.dumps({"success": False, "error": "Song not found"}))
except Exception as e:
    print(json.dumps({"success": False, "error": str(e)}))
PYTHON

    chmod +x "$tmp_script"
    
    # Run the script and capture output
    local genius_result=""
    if [ -n "$python_env" ] && command -v pyenv &> /dev/null; then
        # Use the detected/saved pyenv environment
        debug_log "Running genius search with pyenv environment: $python_env"
        genius_result=$(run_python_script "$tmp_script" "$python_env")
    else
        # Otherwise use system Python
        debug_log "Running genius search with system Python"
        genius_result=$(python3 "$tmp_script")
    fi
    rm "$tmp_script"  # Clean up
    
    # Parse the JSON result
    if [ -n "$genius_result" ] && echo "$genius_result" | jq empty &>/dev/null; then
        local success=$(echo "$genius_result" | jq -r '.success')
        
        if [ "$success" = "true" ]; then
            local lyrics=$(echo "$genius_result" | jq -r '.lyrics')
            local song_title=$(echo "$genius_result" | jq -r '.title')
            local song_artist=$(echo "$genius_result" | jq -r '.artist')
            local song_url=$(echo "$genius_result" | jq -r '.url')
            
            echo "Found lyrics for: $song_artist - $song_title"
            
            # Format the output filename based on context
            if [ -n "$file" ]; then
                # If we have a file, use its base name
                output_file="${file%.*}.txt"
            else
                # Otherwise create a consistently formatted lyrics file
                output_file="$output_path/$song_artist - $song_title Lyrics.txt"
            fi
            
            # Save lyrics to file
            echo "$lyrics" > "$output_file"
            echo "Lyrics saved to: $output_file"
            
            return 0
        else
            local error=$(echo "$genius_result" | jq -r '.error')
            echo "Error: $error"
            return 1
        fi
    else
        echo "Error: Failed to parse response from Genius API."
        return 1
    fi
}

# Function to search for lyrics using SpotDL
search_spotdl_lyrics() {
    local artist="$1"
    local title="$2"
    local file="$3"
    local output_path=""
    local query="$artist - $title"
    
    echo -e "\nSearching for lyrics using SpotDL..."
    debug_log "SpotDL search for: $query"
    
    # Determine output path
    if [ -n "$file" ]; then
        output_path="$(dirname "$file")"
        local base_name="$(basename "${file%.*}")"
    else
        output_path="$OUTPUT_DIR"
        if [ -z "$output_path" ] || [ ! -d "$output_path" ]; then
            # Use home directory as fallback
            output_path="$HOME/Downloads"
            [ ! -d "$output_path" ] && mkdir -p "$output_path"
            echo "Warning: No valid output directory set. Using $output_path"
        fi
        # Create a sanitized filename
        local base_name="$(echo "$artist - $title" | tr -d '[:cntrl:]' | tr -c '[:alnum:][:blank:]' '_')"
    fi
    
    # Check if SpotDL is installed
    if ! command -v spotdl &> /dev/null; then
        echo "SpotDL is not installed. Please install dependencies first."
        return 1
    fi
    
    # Perform permissions check on output directory
    if [ ! -w "$output_path" ]; then
        echo "Warning: Cannot write to $output_path - permission denied"
        output_path="$HOME/Downloads"
        [ ! -d "$output_path" ] && mkdir -p "$output_path"
        echo "Using alternate location: $output_path"
    fi
    
    # Make sure the config has generate_lrc set to true
    local current_lrc_setting=$(jq -r '.generate_lrc // false' "$CURRENT_CONFIG")
    if [ "$current_lrc_setting" != "true" ]; then
        echo "Enabling LRC generation in SpotDL config..."
        jq '.generate_lrc = true' "$CURRENT_CONFIG" > "$CURRENT_CONFIG.tmp" && mv "$CURRENT_CONFIG.tmp" "$CURRENT_CONFIG"
        sync_with_spotdl_config
    fi
    
    # Activate pyenv environment for SpotDL if available
    if command -v pyenv &> /dev/null; then
        debug_log "Activating pyenv environment for SpotDL"
        eval "$(pyenv init -)"
        pyenv activate spotdl 2>/dev/null || pyenv activate mdsh 2>/dev/null || true
    fi
    
    # Modify command to use the correct syntax for SpotDL
    local spotdl_cmd=""
    if [ -n "$file" ]; then
        # If we have a file, search for lyrics for this file only
        spotdl_cmd="spotdl download \"$query\" --generate-lrc --output \"$output_path\" --overwrite metadata"
    else
        echo "Would you like to:"
        echo "1) Search for lyrics only (no music download)"
        echo "2) Download song with lyrics"
        read -p "Enter choice (1-2): " dl_choice
        
        if [ "$dl_choice" = "1" ]; then
            # Use the search function to find lyrics without downloading
            spotdl_cmd="spotdl download \"$query\" --generate-lrc --output \"$output_path\" --print-errors"
            echo "Note: SpotDL requires downloading metadata to get lyrics. Only LRC files will be kept."
        else
            spotdl_cmd="spotdl download \"$query\" --generate-lrc --output \"$output_path\""
        fi
    fi
    
    echo "Executing: $spotdl_cmd"
    debug_log "SpotDL command: $spotdl_cmd"
    
    # Capture output to check for errors
    local lyrics_output
    lyrics_output=$(eval "$spotdl_cmd" 2>&1)
    local lyrics_status=$?
    
    # Display output
    echo "$lyrics_output"
    
    # Check for specific errors
    if [[ "$lyrics_output" == *"Couldn't write token to cache"* ]]; then
        echo -e "\n⚠️ Permission Error: Cannot write to cache directory."
        echo "Fixing cache directory permissions..."
        
        # Create a new cache directory in the user's home directory
        if [ "$DEBUG_MODE" = true ]; then
            mkdir -p "$HOME/.mr-magic/cache"
            chmod 755 "$HOME/.mr-magic/cache"
        else
            mkdir -p "$HOME/.mr-magic/cache" 2>/dev/null
            chmod 755 "$HOME/.mr-magic/cache"
        fi
        
        # Update the config to use this cache directory
        jq ".cache_path = \"$HOME/.mr-magic/cache/.spotipy\"" "$CURRENT_CONFIG" > "$CURRENT_CONFIG.tmp" && mv "$CURRENT_CONFIG.tmp" "$CURRENT_CONFIG"
        
        # Sync the updated config
        sync_with_spotdl_config
        
        echo "Cache directory updated. Retrying lyrics search..."
        lyrics_output=$(eval "$spotdl_cmd" 2>&1)
        lyrics_status=$?
        echo "$lyrics_output"
    fi
    
    # If we chose "lyrics only" mode, remove any downloaded audio files but keep the LRC
    if [ "$dl_choice" = "1" ] && [ $lyrics_status -eq 0 ]; then
        # Remove any audio files that might have been downloaded
        find "$output_path" -maxdepth 1 -name "*.mp3" -o -name "*.flac" -o -name "*.m4a" -o -name "*.wav" -o -name "*.opus" -mtime -1 -delete 2>/dev/null
        echo "Removed any downloaded audio files, keeping only lyrics."
    fi
    
    # Deactivate pyenv environment if it was activated
    if command -v pyenv &> /dev/null; then
        pyenv deactivate 2>/dev/null || true
    fi
    
    # Check if lyrics were downloaded successfully
    if [ $lyrics_status -eq 0 ]; then
        # Try to find the generated LRC file
        if [ -n "$file" ]; then
            local lrc_file="${file%.*}.lrc"
            
            if [ -f "$lrc_file" ]; then
                echo "Found lyrics file: $lrc_file"
                return 0
            else
                # Look for any LRC files in the same directory
                local alt_lrc=$(find "$(dirname "$file")" -maxdepth 1 -name "*.lrc" -mtime -1 2>/dev/null | head -1)
                
                if [ -n "$alt_lrc" ]; then
                    echo "Found lyrics file: $alt_lrc"
                    return 0
                else
                    echo "No lyrics file found after search."
                    return 1
                fi
            fi
        else
            # For lyrics-only mode, check if an LRC file was created in output dir
            local lrc_search=$(find "$output_path" -maxdepth 1 -name "*.lrc" -mtime -1 2>/dev/null | head -1)
            
            if [ -n "$lrc_search" ]; then
                echo "Found lyrics file: $lrc_search"
                return 0
            else
                echo "No lyrics file found after search."
                return 1
            fi
        fi
    else
        echo "Failed to get lyrics from SpotDL."
        return 1
    fi
}

# Function to update manage_lyrics with proper grouping
manage_lyrics() {
    clear
    echo "=== Mr. Magic - Lyrics Management ==="
    echo "1) Search for lyrics"
    echo "2) Convert LRC to SRT subtitle format"   # File conversion first
    echo "3) Romanize Korean lyrics"               # Swapped with format lyrics
    echo "4) Format lyrics (remove timestamps)"    # Renamed from "Format romanized lyrics"
    echo "5) Return to previous menu"              # Removed metadata option
    echo ""
    read -p "Enter your choice (1-5) or 'c' to cancel: " lyrics_choice
    
    if [ "$lyrics_choice" = "c" ]; then
        echo "Operation cancelled."
        return 0
    fi
    
    case $lyrics_choice in
        1)
            search_lyrics
            read -p "Press Enter to continue..."
            ;;
        2)
            convert_lrc_to_srt_file
            read -p "Press Enter to continue..."
            ;;
        3)
            romanize_lyrics
            read -p "Press Enter to continue..."
            ;;
        4)
            format_lyrics
            read -p "Press Enter to continue..."
            ;;
        5)
            return
            ;;
        *)
            echo "Invalid choice."
            read -p "Press Enter to try again..."
            ;;
    esac
    
    manage_lyrics
}

# Function to convert LRC to SRT file
convert_lrc_to_srt_file() {
    local input_file="$1"
    local output_file="$2"
    
    # If no input file specified, ask user to select one
    if [ -z "$input_file" ]; then
        echo "Select an LRC file to convert to SRT:"
        if [ -z "$OUTPUT_DIR" ]; then
            echo "Output directory not set."
            set_output_directory
            if [ $? -ne 0 ]; then
                echo "Failed to set output directory. Returning to previous menu."
                return 1
            fi
        fi
        
        echo "Looking for LRC files in $OUTPUT_DIR..."
        lrc_files=$(find "$OUTPUT_DIR" -type f -name "*.lrc" | sort)
        
        if [ -z "$lrc_files" ]; then
            echo "No LRC files found in $OUTPUT_DIR."
            read -p "Enter full path to LRC file (or 'c' to cancel): " custom_file
            if [ "$custom_file" = "c" ]; then
                echo "Operation cancelled."
                return 1
            fi
            
            if [ -n "$custom_file" ] && [ -f "$custom_file" ]; then
                input_file="$custom_file"
            else
                echo "Invalid file path."
                return 1
            fi
        else
            # Display list of found LRC files
            echo "Found LRC files:"
            count=1
            while IFS= read -r file; do
                echo "$count) $(basename "$file")"
                count=$((count + 1))
            done <<< "$lrc_files"
            
            read -p "Select file number to convert (or 'c' to enter custom path, 'q' to cancel): " file_choice
            
            if [ "$file_choice" = "q" ] || [ "$file_choice" = "c" ]; then
                if [ "$file_choice" = "q" ]; then
                    echo "Operation cancelled."
                    return 1
                else
                    read -p "Enter full path to LRC file (or 'c' to cancel): " custom_file
                    if [ "$custom_file" = "c" ]; then
                        echo "Operation cancelled."
                        return 1
                    fi
                    
                    if [ -n "$custom_file" ] && [ -f "$custom_file" ]; then
                        input_file="$custom_file"
                    else
                        echo "Invalid file path."
                        return 1
                    fi
                fi
            elif [[ "$file_choice" =~ ^[0-9]+$ ]] && [ "$file_choice" -gt 0 ] && [ "$file_choice" -lt "$count" ]; then
                input_file=$(echo "$lrc_files" | sed -n "${file_choice}p")
            else
                echo "Invalid selection."
                return 1
            fi
        fi
    fi
    
    # If input file doesn't end with .lrc, warn the user
    if [[ ! "$input_file" == *.lrc ]]; then
        echo "Warning: Input file doesn't have .lrc extension."
        read -p "Continue anyway? (y/n): " continue_anyway
        if [[ ! "$continue_anyway" =~ ^[Yy]$ ]]; then
            echo "Operation cancelled."
            return 1
        fi
    fi
    
    # If no output file specified, create one
    if [ -z "$output_file" ]; then
        output_file="${input_file%.lrc}.srt"
    fi
    
    # If output file already exists, ask for confirmation
    if [ -f "$output_file" ]; then
        read -p "Output file already exists. Overwrite? (y/n): " overwrite
        if [[ ! "$overwrite" =~ ^[Yy]$ ]]; then
            echo "Operation cancelled."
            return 1
        fi
    fi
    
    # Check if the conversion script exists
    if [ ! -f "$DEPENDENCIES_DIR/lrc2srt.py" ]; then
        echo "LRC to SRT conversion script not found."
        echo "Re-creating the script..."
        copy_lrc2srt_script
    fi
    
    # Convert LRC to SRT using the Python script
    echo "Converting $input_file to SRT format..."
    if python3 "$DEPENDENCIES_DIR/lrc2srt.py" "$input_file" "$output_file"; then
        echo "Successfully converted to: $output_file"
        return 0
    else
        echo "Error: Conversion failed."
        return 1
    fi
}

# Function to create the whisper script
create_whisper_script() {
    local whisper_script="$DEPENDENCIES_DIR/whisper_transcribe.py"
    
    cat > "$whisper_script" << 'EOF'
#!/usr/bin/env python
# Whisper Transcription Script for Mr. Magic

import os
import sys
import argparse
import whisper

def transcribe_audio(audio_file, output_dir=None, model_name="small", output_format="srt"):
    """Transcribe audio file using Whisper and save the results."""
    
    # Validate file exists
    if not os.path.exists(audio_file):
        print(f"Error: File not found: {audio_file}")
        return False
    
    # Get output directory
    if output_dir is None:
        output_dir = os.path.dirname(audio_file)
    
    # Get base name without extension
    base_name = os.path.splitext(os.path.basename(audio_file))[0]
    
    # Load model
    print(f"Loading Whisper model: {model_name}")
    model = whisper.load_model(model_name)
    
    # Transcribe
    print(f"Transcribing: {audio_file}")
    result = model.transcribe(audio_file)
    
    # Build output file path
    if output_format == "srt":
        output_file = os.path.join(output_dir, f"{base_name}.srt")
        
        # Generate SRT content
        with open(output_file, "w", encoding="utf-8") as f:
            for i, segment in enumerate(result["segments"]):
                start_time = format_timestamp(segment["start"])
                end_time = format_timestamp(segment["end"])
                text = segment["text"].strip()
                
                f.write(f"{i+1}\n")
                f.write(f"{start_time} --> {end_time}\n")
                f.write(f"{text}\n\n")
        
        print(f"SRT file saved to: {output_file}")
    
    elif output_format == "txt":
        output_file = os.path.join(output_dir, f"{base_name}.txt")
        
        # Generate plain text content
        with open(output_file, "w", encoding="utf-8") as f:
            f.write(result["text"])
        
        print(f"Text file saved to: {output_file}")
    
    elif output_format == "lrc":
        output_file = os.path.join(output_dir, f"{base_name}.lrc")
        
        # Generate LRC content
        with open(output_file, "w", encoding="utf-8") as f:
            for segment in result["segments"]:
                start_time = format_lrc_timestamp(segment["start"])
                text = segment["text"].strip()
                
                f.write(f"[{start_time}]{text}\n")
        
        print(f"LRC file saved to: {output_file}")
    
    else:
        print(f"Unsupported output format: {output_format}")
        return False
    
    return True

def format_timestamp(seconds):
    """Format seconds as HH:MM:SS,mmm for SRT files."""
    hours = int(seconds) // 3600
    minutes = (int(seconds) % 3600) // 60
    seconds_int = int(seconds) % 60
    milliseconds = int((seconds - int(seconds)) * 1000)
    return f"{hours:02d}:{minutes:02d}:{seconds_int:02d},{milliseconds:03d}"

def format_lrc_timestamp(seconds):
    """Format seconds as MM:SS.xx for LRC files."""
    minutes = int(seconds) // 60
    seconds_int = int(seconds) % 60
    centiseconds = int((seconds - int(seconds)) * 100)
    return f"{minutes:02d}:{seconds_int:02d}.{centiseconds:02d}"

def main():
    parser = argparse.ArgumentParser(description="Transcribe audio using OpenAI Whisper")
    parser.add_argument("audio_file", help="Path to the audio file to transcribe")
    parser.add_argument("--model", default="small", choices=["tiny", "base", "small", "medium", "large"],
                        help="Whisper model to use (default: small)")
    parser.add_argument("--output_dir", help="Directory to save the output files")
    parser.add_argument("--output_format", default="srt", choices=["srt", "txt", "lrc"],
                        help="Output format (default: srt)")
    
    args = parser.parse_args()
    
    success = transcribe_audio(
        args.audio_file,
        output_dir=args.output_dir,
        model_name=args.model,
        output_format=args.output_format
    )
    
    return 0 if success else 1

if __name__ == "__main__":
    sys.exit(main())
EOF

    chmod +x "$whisper_script"
    echo "Created Whisper transcription script at $whisper_script"
}

# Function to transcribe audio using Whisper
search_whisper_transcribe() {
    local file="$1"
    
    echo -e "\nTranscribing audio using OpenAI Whisper..."
    debug_log "Transcribing with Whisper: $file"
    
    # Check if whisper is installed
    if ! is_whisper_installed; then
        echo "OpenAI Whisper is not installed."
        read -p "Would you like to install it now? (y/n): " install_whisper
        if [[ "$install_whisper" =~ ^[Yy]$ ]]; then
            install_whisper
            if [ $? -ne 0 ]; then
                echo "Failed to install Whisper. Please install dependencies first."
                return 1
            fi
        else
            echo "Whisper installation skipped. Cannot transcribe audio."
            return 1
        fi
    fi
    
    # Check if file exists
    if [ ! -f "$file" ]; then
        echo "Error: Audio file not found: $file"
        return 1
    fi
    
    # Get file info
    local file_dir="$(dirname "$file")"
    local file_name="$(basename "$file")"
    local base_name="${file_name%.*}"
    
    # Activate pyenv environment for Whisper
    echo "Activating Whisper environment..."
    eval "$(pyenv init -)"
    pyenv activate whisper 2>/dev/null
    
    if [ $? -ne 0 ]; then
        echo "Failed to activate Whisper environment. Please check your installation."
        return 1
    fi
    
    # Run whisper transcription
    echo "Running Whisper transcription... This may take a while."
    echo "Transcribing: $file_name"
    
    # Build the whisper command
    local whisper_cmd="whisper \"$file\" --model small --output_dir \"$file_dir\" --output_format srt"
    
    # Execute the command
    echo "Executing: $whisper_cmd"
    debug_log "Whisper command: $whisper_cmd"
    
    # Capture output and status
    output=$(eval "$whisper_cmd" 2>&1)
    local status=$?
    
    # Log the output
    debug_log "Whisper output: $output"
    
    # Check if SRT file was created
    if [ -f "$file_dir/$base_name.srt" ]; then
        echo "Transcription successful!"
        echo "Saved SRT file to: $file_dir/$base_name.srt"
        
        # Deactivate pyenv environment
        pyenv deactivate 2>/dev/null || true
        
        return 0
    else
        echo "Failed to create transcription."
        echo "Whisper output: $output"
        
        # Deactivate pyenv environment
        pyenv deactivate 2>/dev/null || true
        
        return 1
    fi
}

# Function to transcribe audio to lyrics using Whisper
transcribe_with_whisper() {
    local file="$1"
    
    # Check if Whisper is installed first
    if ! is_whisper_installed; then
        echo "Whisper is not installed. Would you like to install it now? (y/n)"
        read -p "> " install_whisper_now
        
        if [[ "$install_whisper_now" =~ ^[Yy]$ ]]; then
            install_whisper
            # Check if installation was successful
            if ! is_whisper_installed; then
                echo "Failed to install Whisper. Please try installing manually."
                return 1
            fi
        else
            echo "Whisper installation skipped. Cannot transcribe audio."
            return 1
        fi
    fi
    
    # If no file is provided, ask user to select one
    if [ -z "$file" ]; then
        echo "Please select an audio file to transcribe:"
        if [ -z "$OUTPUT_DIR" ]; then
            echo "Output directory not set."
            set_output_directory
            if [ $? -ne 0 ]; then
                echo "Failed to set output directory. Returning to previous menu."
                return 1
            fi
        fi
        
        echo "Looking for audio files in $OUTPUT_DIR..."
        audio_files=$(find "$OUTPUT_DIR" -type f \( -name "*.mp3" -o -name "*.flac" -o -name "*.m4a" -o -name "*.wav" -o -name "*.opus" \) | sort)
        
        if [ -z "$audio_files" ]; then
            echo "No audio files found in $OUTPUT_DIR."
            read -p "Enter full path to audio file (or 'c' to cancel): " custom_file
            if [ "$custom_file" = "c" ]; then
                echo "Operation cancelled."
                return 1
            fi
            
            if [ -n "$custom_file" ] && [ -f "$custom_file" ]; then
                file="$custom_file"
            else
                echo "Invalid file path."
                return 1
            fi
        else
            # Display list of found audio files
            echo "Found audio files:"
            count=1
            while IFS= read -r found_file; do
                echo "$count) $(basename "$found_file")"
                count=$((count + 1))
            done <<< "$audio_files"
            
            read -p "Select file number (or 'c' to enter custom path, 'q' to cancel): " file_choice
            
            if [ "$file_choice" = "q" ] || [ "$file_choice" = "c" ]; then
                if [ "$file_choice" = "q" ]; then
                    echo "Operation cancelled."
                    return 1
                else
                    read -p "Enter full path to audio file (or 'c' to cancel): " custom_file
                    if [ "$custom_file" = "c" ]; then
                        echo "Operation cancelled."
                        return 1
                    fi
                    
                    if [ -n "$custom_file" ] && [ -f "$custom_file" ]; then
                        file="$custom_file"
                    else
                        echo "Invalid file path."
                        return 1
                    fi
                fi
            elif [[ "$file_choice" =~ ^[0-9]+$ ]] && [ "$file_choice" -gt 0 ] && [ "$file_choice" -lt "$count" ]; then
                file=$(echo "$audio_files" | sed -n "${file_choice}p")
            else
                echo "Invalid selection."
                return 1
            fi
        fi
    fi
    
    # Now that we have a file, call the actual transcription function
    search_whisper_transcribe "$file"
    return $?
}

# Function to format lyrics without timestamps
format_lyrics() {
    local input_file="$1"
    local format_method="${2:-simple}"  # Default to simple timestamp removal if not specified
    
    if [ -z "$input_file" ]; then
        echo "Select a lyrics file to format (remove timestamps):"
        if [ -z "$OUTPUT_DIR" ]; then
            echo "Output directory not set."
            set_output_directory
            if [ $? -ne 0 ]; then
                echo "Failed to set output directory. Returning to previous menu."
                return 1
            fi
        fi
        
        echo "Looking for lyrics files in $OUTPUT_DIR..."
        lyrics_files=$(find "$OUTPUT_DIR" -type f \( -name "*.lrc" -o -name "*.srt" -o -name "*.txt" \) | sort)
        
        if [ -z "$lyrics_files" ]; then
            echo "No lyrics files found in $OUTPUT_DIR."
            read -p "Enter full path to lyrics file (or 'c' to cancel): " custom_file
            if [ "$custom_file" = "c" ]; then
                echo "Operation cancelled."
                return 1
            fi
            
            if [ -n "$custom_file" ] && [ -f "$custom_file" ]; then
                input_file="$custom_file"
            else
                echo "Invalid file path."
                return 1
            fi
        else
            # Display list of found lyrics files
            echo "Found lyrics files:"
            count=1
            while IFS= read -r file; do
                echo "$count) $(basename "$file")"
                count=$((count + 1))
            done <<< "$lyrics_files"
            
            read -p "Select file number to format (or 'c' to enter custom path, 'q' to cancel): " file_choice
            
            if [ "$file_choice" = "q" ] || [ "$file_choice" = "c" ]; then
                if [ "$file_choice" = "q" ]; then
                    echo "Operation cancelled."
                    return 1
                else
                    read -p "Enter full path to lyrics file (or 'c' to cancel): " custom_file
                    if [ "$custom_file" = "c" ]; then
                        echo "Operation cancelled."
                        return 1
                    fi
                    
                    if [ -n "$custom_file" ] && [ -f "$custom_file" ]; then
                        input_file="$custom_file"
                    else
                        echo "Invalid file path."
                        return 1
                    fi
                fi
            elif [[ "$file_choice" =~ ^[0-9]+$ ]] && [ "$file_choice" -gt 0 ] && [ "$file_choice" -lt "$count" ]; then
                input_file=$(echo "$lyrics_files" | sed -n "${file_choice}p")
            else
                echo "Invalid selection."
                return 1
            fi
        fi
        
        # Ask the user to select the formatting method
        echo ""
        echo "Select formatting method:"
        echo "1) Simple (just remove timestamps, fastest)"
        echo "2) AI-assisted (use AI to improve formatting, requires API key)"
        echo "3) Cancel"
        read -p "Enter your choice (1-3): " method_choice
        
        case $method_choice in
            1) format_method="simple" ;;
            2) format_method="ai" ;;
            3) 
                echo "Operation cancelled."
                return 1
                ;;
            *)
                echo "Invalid choice. Using simple method."
                format_method="simple"
                ;;
        esac
    fi
    
    local file="$input_file"
    local output_dir="$(dirname "$file")"
    local base_name="${file%.*}"
    local filename_only="$(basename "$base_name")"
    
    echo "Formatting lyrics from: $file"
    debug_log "Formatting lyrics from: $file using method: $format_method"
    
    # Determine file type
    local file_ext="${file##*.}"
    
    # Check if the file is an appropriate format
    if [[ "$file_ext" != "srt" && "$file_ext" != "lrc" && "$file_ext" != "txt" ]]; then
        echo "Error: File must be .srt, .lrc, or .txt format."
        return 1
    fi
    
    # Extract metadata to get proper filename
    local orig_audio_file=""
    # Try to find corresponding audio file in the same directory
    for audio_ext in mp3 flac m4a wav opus; do
        potential_file="$output_dir/$filename_only.$audio_ext"
        if [ -f "$potential_file" ]; then
            orig_audio_file="$potential_file"
            break
        fi
    done
    
    local output_filename=""
    if [ -n "$orig_audio_file" ]; then
        # Use audio file metadata for naming
        local metadata=$(extract_metadata "$orig_audio_file")
        if [ $? -eq 0 ]; then
            IFS='|' read -r artist title album duration featured_artist remixer <<< "$metadata"
            output_filename="$artist - $title"
            
            # Add featuring if found
            if [ -n "$featured_artist" ]; then
                output_filename+=" feat $featured_artist"
            fi
            
            # Add remixer if found
            if [ -n "$remixer" ]; then
                output_filename+=" (${remixer} Remix)"
            fi
            
            output_filename+=" (Lyrics).txt"
        else
            # Fallback to base filename
            output_filename="$filename_only.txt"
        fi
    else
        # Just use the basename if no audio file found
        output_filename="$filename_only.txt"
    fi
    
    output_file="$output_dir/$output_filename"
    
    # Ask for confirmation before overwriting
    if [ -f "$output_file" ]; then
        read -p "Output file '$output_filename' already exists. Overwrite? (y/n/c to cancel): " overwrite
        if [ "$overwrite" = "c" ]; then
            echo "Operation cancelled."
            return 1
        elif [[ ! "$overwrite" =~ ^[Yy]$ ]]; then
            # Ask for a new filename
            read -p "Enter new output filename (or 'c' to cancel): " new_filename
            if [ "$new_filename" = "c" ]; then
                echo "Operation cancelled."
                return 1
            fi
            output_file="$output_dir/$new_filename"
            if [ ! "${output_file##*.}" = "txt" ]; then
                output_file="$output_file.txt"
            fi
        fi
    fi
    
    # Process the file based on formatting method
    if [ "$format_method" = "simple" ]; then
        # Simple timestamp removal based on file type
        local clean_lyrics=""
        
        if [ "$file_ext" = "srt" ]; then
            # SRT format - remove timestamps and numbering
            clean_lyrics=$(awk '!/^[0-9]+$/ && !/^[0-9:.,-]+ --> [0-9:.,-]+$/ && !/^$/' "$file")
        elif [ "$file_ext" = "lrc" ]; then
            # LRC format - remove timestamps
            clean_lyrics=$(sed -E 's/\[[0-9:.]*\]//g' "$file" | grep -v "^\s*$")
        else
            # Assume it's a text file that may already be formatted
            # Just remove any obvious timestamp patterns
            clean_lyrics=$(sed -E 's/\[[0-9:.]*\]//g' "$file" | sed -E 's/^[0-9]+:[0-9]+.[0-9]+ --> [0-9]+:[0-9]+.[0-9]+ //g' | grep -v "^\s*$")
        fi
        
        # Write to output file
        echo "$clean_lyrics" > "$output_file"
        echo "Formatted lyrics saved to: $output_file"
        debug_log "Formatted lyrics saved to: $output_file"
    elif [ "$format_method" = "ai" ]; then
        # AI-assisted formatting using AI APIs
        # Check if we have credentials
        local api_provider=""
        local model_name=""
        local api_key=""
        local api_url=""
        
        # Load the credentials from the file
        local credentials_file="$API_DIR/credentials.json"
        
        # Ask the user to select an AI provider
        echo "Select AI provider for formatting:"
        api_provider=$(select_ai_provider)
        if [ $? -ne 0 ]; then
            echo "Provider selection cancelled. Falling back to simple formatting method."
            format_method="simple"
            # Recursively call with simple method
            format_lyrics "$file" "simple"
            return $?
        fi

        # Now get the model and API details for the selected provider
        model_name=$(jq -r --arg provider "$api_provider" '.ai_models[$provider].default_model // ""' "$credentials_file" 2>/dev/null)
        api_key=$(jq -r --arg provider "$api_provider" '.ai_models[$provider].api_key // ""' "$credentials_file" 2>/dev/null)
        api_url=$(jq -r --arg provider "$api_provider" '.ai_models[$provider].api_url // ""' "$credentials_file" 2>/dev/null)

        
        if [ -z "$api_key" ] || [ "$api_key" = "null" ]; then
            echo "Error: No AI API key found. Falling back to simple formatting method."
            format_method="simple"
            # Recursively call with simple method
            format_lyrics "$file" "simple"
            return $?
        fi
        
        # Read the lyrics file
        local lyrics_content=$(cat "$file")
        
        if [ -z "$lyrics_content" ]; then
            echo "Error: Lyrics file is empty."
            return 1
        fi
        
        # Prepare temp files
        local temp_output=$(mktemp)
        local temp_result=$(mktemp)
        
        # Format using AI based on provider
        case "$api_provider" in
            "anthropic")
                echo "Using Anthropic's Claude to format lyrics..."
                
                # Create the prompt for Claude
                cat > "$temp_output" << EOF
<request>
Please format the following lyrics text by:
1. Removing all timestamps, line numbers, and technical markers
2. Preserving the actual lyrics text and line breaks
3. Combining parts of the same line that might have been split
4. Preserving empty lines between verses or sections
5. Don't add any commentary or explanation

Here are the lyrics to format:

${lyrics_content}
</request>
EOF
                
                # Call the Anthropic API
                curl -s "$api_url" \
                    -H "content-type: application/json" \
                    -H "x-api-key: $api_key" \
                    -H "anthropic-version: 2023-06-01" \
                    --data @- > "$temp_result" << EOF
{
    "model": "$model_name",
    "max_tokens": 4000,
    "messages": [
        {
            "role": "user",
            "content": $(cat "$temp_output" | jq -Rs .)
        }
    ]
}
EOF
                
                # Extract the response
                if [ -f "$temp_result" ]; then
                    local response=$(jq -r '.content[0].text // ""' "$temp_result" 2>/dev/null)
                    
                    if [ -n "$response" ] && [ "$response" != "null" ]; then
                        # Save the formatted lyrics
                        echo "$response" > "$output_file"
                        echo "AI-formatted lyrics saved to: $output_file"
                        
                        # Clean up
                        rm -f "$temp_output" "$temp_result"
                        return 0
                    else
                        local error=$(jq -r '.error.message // "Unknown error"' "$temp_result" 2>/dev/null)
                        echo "Error: Failed to format lyrics using AI. $error"
                        echo "Falling back to simple formatting method."
                        
                        # Clean up
                        rm -f "$temp_output" "$temp_result"
                        
                        # Try simple method instead
                        format_lyrics "$file" "simple"
                        return $?
                    fi
                else
                    echo "Error: No response from API."
                    echo "Falling back to simple formatting method."
                    
                    # Clean up
                    rm -f "$temp_output" "$temp_result"
                    
                    # Try simple method instead
                    format_lyrics "$file" "simple"
                    return $?
                fi
                ;;
                
            "openai")
                echo "Using OpenAI to format lyrics..."
                
                # Create the prompt for OpenAI
                cat > "$temp_output" << EOF
Please format the following lyrics text by:
1. Removing all timestamps, line numbers, and technical markers
2. Preserving the actual lyrics text and line breaks
3. Combining parts of the same line that might have been split
4. Preserving empty lines between verses or sections
5. Don't add any commentary or explanation

Here are the lyrics to format:

${lyrics_content}
EOF
                
                # Call the OpenAI API
                curl -s "$api_url" \
                    -H "Content-Type: application/json" \
                    -H "Authorization: Bearer $api_key" \
                    --data @- > "$temp_result" << EOF
{
    "model": "$model_name",
    "messages": [
        {
            "role": "user",
            "content": $(cat "$temp_output" | jq -Rs .)
        }
    ],
    "temperature": 0.3
}
EOF
                
                # Extract the response
                if [ -f "$temp_result" ]; then
                    local response=$(jq -r '.choices[0].message.content // ""' "$temp_result" 2>/dev/null)
                    
                    if [ -n "$response" ] && [ "$response" != "null" ]; then
                        # Save the formatted lyrics
                        echo "$response" > "$output_file"
                        echo "AI-formatted lyrics saved to: $output_file"
                        
                        # Clean up
                        rm -f "$temp_output" "$temp_result"
                        return 0
                    else
                        local error=$(jq -r '.error.message // "Unknown error"' "$temp_result" 2>/dev/null)
                        echo "Error: Failed to format lyrics using AI. $error"
                        echo "Falling back to simple formatting method."
                        
                        # Clean up
                        rm -f "$temp_output" "$temp_result"
                        
                        # Try simple method instead
                        format_lyrics "$file" "simple"
                        return $?
                    fi
                else
                    echo "Error: No response from API."
                    echo "Falling back to simple formatting method."
                    
                    # Clean up
                    rm -f "$temp_output" "$temp_result"
                    
                    # Try simple method instead
                    format_lyrics "$file" "simple"
                    return $?
                fi
                ;;
                
            *)
                echo "Error: Unsupported AI provider: $api_provider. Falling back to simple formatting method."
                format_lyrics "$file" "simple"
                return $?
                ;;
        esac
    else
        echo "Error: Unknown formatting method. Please use 'simple' or 'ai'."
        return 1
    fi
    
    return 0
}

# Function to romanize lyrics (best-effort, AI-assisted when credentials exist)
romanize_lyrics() {
    local input_file="$1"

    if [ -z "$input_file" ]; then
        echo "Select a lyrics file to romanize:"
        if [ -z "$OUTPUT_DIR" ]; then
            echo "Output directory not set."
            set_output_directory || return 1
        fi

        local lyrics_files
        lyrics_files=$(find "$OUTPUT_DIR" -type f \( -name "*.lrc" -o -name "*.srt" -o -name "*.txt" \) | sort)

        if [ -z "$lyrics_files" ]; then
            echo "No lyrics files found in $OUTPUT_DIR."
            read -p "Enter full path to lyrics file (or 'c' to cancel): " custom_file
            [ "$custom_file" = "c" ] && return 1
            [ -f "$custom_file" ] || { echo "Invalid file path."; return 1; }
            input_file="$custom_file"
        else
            local count=1
            while IFS= read -r file; do
                echo "$count) $(basename "$file")"
                count=$((count + 1))
            done <<< "$lyrics_files"

            read -p "Select file number (or 'c' to cancel): " file_choice
            [ "$file_choice" = "c" ] && return 1
            if [[ "$file_choice" =~ ^[0-9]+$ ]] && [ "$file_choice" -gt 0 ] && [ "$file_choice" -lt "$count" ]; then
                input_file=$(echo "$lyrics_files" | sed -n "${file_choice}p")
            else
                echo "Invalid selection."
                return 1
            fi
        fi
    fi

    [ -f "$input_file" ] || { echo "Error: File not found: $input_file"; return 1; }

    local output_dir
    output_dir="$(dirname "$input_file")"
    local base_name
    base_name="${input_file%.*}"
    local output_file
    output_file="$output_dir/$(basename "$base_name") (Romanized).txt"

    local credentials_file="$API_DIR/credentials.json"
    if [ ! -f "$credentials_file" ]; then
        echo "AI credentials not configured. Falling back to plain formatting."
        format_lyrics "$input_file" "simple"
        return $?
    fi

    local provider
    provider=$(jq -r '.default_ai_provider // ""' "$credentials_file" 2>/dev/null)
    local model_name
    model_name=$(jq -r --arg provider "$provider" '.ai_models[$provider].default_model // ""' "$credentials_file" 2>/dev/null)
    local api_key
    api_key=$(jq -r --arg provider "$provider" '.ai_models[$provider].api_key // ""' "$credentials_file" 2>/dev/null)
    local api_url
    api_url=$(jq -r --arg provider "$provider" '.ai_models[$provider].api_url // ""' "$credentials_file" 2>/dev/null)

    if [ -z "$provider" ] || [ -z "$api_key" ] || [ "$api_key" = "null" ]; then
        echo "No usable AI provider configured. Falling back to plain formatting."
        format_lyrics "$input_file" "simple"
        return $?
    fi

    local lyrics_content
    lyrics_content=$(cat "$input_file")
    [ -n "$lyrics_content" ] || { echo "Error: Lyrics file is empty."; return 1; }

    local prompt
    prompt=$(cat <<EOF_PROMPT
Romanize the following lyrics into Latin characters while preserving line breaks and section spacing.

Rules:
1) Keep original lyric order and line structure.
2) Do not add commentary, headers, or explanations.
3) If text is already Latin, keep it as-is.
4) Remove timestamps/numbering if present.

Lyrics:
$lyrics_content
EOF_PROMPT
)

    local temp_result
    temp_result=$(mktemp)

    case "$provider" in
        "anthropic")
            curl -s "$api_url" \
                -H "content-type: application/json" \
                -H "x-api-key: $api_key" \
                -H "anthropic-version: 2023-06-01" \
                --data @- > "$temp_result" <<EOF
{
  "model": "$model_name",
  "max_tokens": 4000,
  "messages": [
    {
      "role": "user",
      "content": $(printf "%s" "$prompt" | jq -Rs .)
    }
  ]
}
EOF
            romanized=$(jq -r '.content[0].text // ""' "$temp_result" 2>/dev/null)
            ;;
        "openai")
            curl -s "$api_url" \
                -H "Content-Type: application/json" \
                -H "Authorization: Bearer $api_key" \
                --data @- > "$temp_result" <<EOF
{
  "model": "$model_name",
  "messages": [
    {
      "role": "user",
      "content": $(printf "%s" "$prompt" | jq -Rs .)
    }
  ],
  "temperature": 0.2
}
EOF
            romanized=$(jq -r '.choices[0].message.content // ""' "$temp_result" 2>/dev/null)
            ;;
        *)
            echo "Provider '$provider' is not supported for romanization yet."
            rm -f "$temp_result"
            format_lyrics "$input_file" "simple"
            return $?
            ;;
    esac

    rm -f "$temp_result"

    if [ -z "$romanized" ] || [ "$romanized" = "null" ]; then
        echo "Romanization failed. Falling back to plain formatting."
        format_lyrics "$input_file" "simple"
        return $?
    fi

    echo "$romanized" > "$output_file"
    echo "Romanized lyrics saved to: $output_file"
    return 0
}

# =====AI FUNCTIONS=====

# Function to set up or update AI API credentials
configure_ai_credentials() {
    local credentials_file="$API_DIR/credentials.json"
    local app_settings_file="$CONFIG_DIR/app_settings.json"
    initialize_credentials
    
    # Check if credentials are encrypted and decrypt if needed
    if are_credentials_encrypted; then
        if ! decrypt_credentials; then
            echo "Cannot configure AI without decrypting credentials first."
            read -p "Press Enter to continue..."
            return 1
        fi
    fi
    
    # Get current default provider and models for each provider
    local current_provider=$(jq -r '.default_ai_provider // "openai"' "$credentials_file")
    local openai_model=$(jq -r '.ai_models.openai.default_model // "Not set"' "$credentials_file")
    local anthropic_model=$(jq -r '.ai_models.anthropic.default_model // "Not set"' "$credentials_file")
    local custom_enabled=$(jq -r '.ai_models.custom.enabled // false' "$credentials_file")
    local custom_model="Not enabled"
    if [ "$custom_enabled" = "true" ]; then
        custom_model=$(jq -r '.ai_models.custom.default_model // "Not set"' "$credentials_file")
    fi
    
    # Get global default provider and model
    local global_provider=$(jq -r '.default_ai_provider // "openai"' "$app_settings_file" 2>/dev/null || echo "$current_provider")
    local global_model=""
    if [ -n "$global_provider" ]; then
        global_model=$(jq -r ".default_ai_models.$global_provider // \"Not set\"" "$app_settings_file" 2>/dev/null || echo "Not set")
    fi
    
    echo "=== AI Model Configuration ==="
    echo "Current session provider: $current_provider"
    echo "Current session model: $(jq -r ".ai_models.$current_provider.default_model // \"Not set\"" "$credentials_file")"
    echo ""
    echo "Global default provider: $global_provider"
    echo "Global default model: $global_model"
    echo ""
    echo "Provider-Specific Models:"
    echo "  OpenAI Model: $openai_model"
    echo "  Anthropic AI Model: $anthropic_model"
    echo "  Custom Model: $custom_model"
    echo ""
    echo "1) Configure OpenAI API"
    echo "2) Configure Anthropic AI API"
    echo "3) Configure Custom Provider"
    echo "4) Set Default Provider for Current Session"
    echo "5) Set Global Default Provider and Model"
    echo "6) Configure AI Parameters"
    echo "7) Encrypt API Keys"
    echo "8) Wipe All API Keys"
    echo "9) Return to previous menu"
    
    read -p "Select an option (1-9 or 'c' to cancel): " option
    
    if [ "$option" = "c" ]; then
        echo "Operation cancelled."
        return 1
    fi
    
    case $option in
        1)
            echo ""
            echo "=== OpenAI API Configuration ==="
            echo "Get your API key at: https://platform.openai.com/account/api-keys"
            read -s -p "Enter your OpenAI API key (input will be hidden, or 'c' to cancel): " api_key
            echo ""
            
            if [ "$api_key" = "c" ]; then
                echo "Operation cancelled."
                configure_ai_credentials
                return 0
            fi
            
            if [ -n "$api_key" ]; then
                jq ".ai_models.openai.api_key = \"$api_key\"" "$credentials_file" > "$credentials_file.tmp" && mv "$credentials_file.tmp" "$credentials_file"
                echo "OpenAI API key updated"
                
                # Fetch available models
                echo "Fetching available models from OpenAI API..."
                models_response=$(curl -s "https://api.openai.com/v1/models" \
                    -H "Authorization: Bearer $api_key")
                
                # Check for errors
                if [[ "$models_response" == *"error"* ]]; then
                    error_message=$(echo "$models_response" | jq -r '.error.message')
                    echo "API Error: $error_message"
                else
                    # Extract model IDs
                    echo "Available OpenAI models:"
                    echo "$models_response" | jq -r '.data[].id' | sort | grep -v "^ada-|^babbage-|^curie-|^davinci-|^text-|^whisper-|^audio-|^tts-|^embeddings-" | grep "gpt\|instruct" | nl
                    
                    read -p "Enter model number or name (default: gpt-3.5-turbo, or 'c' to cancel): " model_choice
                    
                    if [ "$model_choice" = "c" ]; then
                        echo "Model selection cancelled."
                    elif [[ "$model_choice" =~ ^[0-9]+$ ]]; then
                        # User entered a number, get the model name from the list
                        selected_model=$(echo "$models_response" | jq -r '.data[].id' | sort | grep -v "^ada-|^babbage-|^curie-|^davinci-|^text-|^whisper-|^audio-|^tts-|^embeddings-" | grep "gpt\|instruct" | sed -n "${model_choice}p")
                        if [ -n "$selected_model" ]; then
                            jq ".ai_models.openai.default_model = \"$selected_model\"" "$credentials_file" > "$credentials_file.tmp" && mv "$credentials_file.tmp" "$credentials_file"
                            echo "OpenAI model set to $selected_model"
                            
                            # Ask about making this the global default
                            read -p "Make this your global default model? (y/n): " set_global
                            if [[ "$set_global" =~ ^[Yy]$ ]]; then
                                # Ensure default_ai_models structure exists
                                if ! jq -e '.default_ai_models' "$app_settings_file" > /dev/null 2>&1; then
                                    jq '. += {"default_ai_models": {}}' "$app_settings_file" > "$app_settings_file.tmp" && 
                                        mv "$app_settings_file.tmp" "$app_settings_file"
                                fi
                                
                                # Update global default
                                jq ".default_ai_provider = \"openai\" | .default_ai_models.openai = \"$selected_model\"" "$app_settings_file" > "$app_settings_file.tmp" && 
                                    mv "$app_settings_file.tmp" "$app_settings_file"
                                echo "Set as global default model."
                            fi
                        else
                            echo "Invalid selection. Using default model."
                        fi
                    elif [ -n "$model_choice" ]; then
                        # User entered a model name directly
                        jq ".ai_models.openai.default_model = \"$model_choice\"" "$credentials_file" > "$credentials_file.tmp" && mv "$credentials_file.tmp" "$credentials_file"
                        echo "OpenAI model set to $model_choice"
                        
                        # Ask about making this the global default
                        read -p "Make this your global default model? (y/n): " set_global
                        if [[ "$set_global" =~ ^[Yy]$ ]]; then
                            # Ensure default_ai_models structure exists
                            if ! jq -e '.default_ai_models' "$app_settings_file" > /dev/null 2>&1; then
                                jq '. += {"default_ai_models": {}}' "$app_settings_file" > "$app_settings_file.tmp" && 
                                    mv "$app_settings_file.tmp" "$app_settings_file"
                            fi
                            
                            # Update global default
                            jq ".default_ai_provider = \"openai\" | .default_ai_models.openai = \"$model_choice\"" "$app_settings_file" > "$app_settings_file.tmp" && 
                                mv "$app_settings_file.tmp" "$app_settings_file"
                            echo "Set as global default model."
                        fi
                    fi
                fi
            fi
            ;;
        2)
            echo ""
            echo "=== Anthropic AI API Configuration ==="
            echo "Get your API key at: https://console.anthropic.com/settings/keys"
            read -s -p "Enter your Anthropic API key (input will be hidden, or 'c' to cancel): " api_key
            echo ""
            
            if [ "$api_key" = "c" ]; then
                echo "Operation cancelled."
                configure_ai_credentials
                return 0
            fi
            
            if [ -n "$api_key" ]; then
                jq ".ai_models.anthropic.api_key = \"$api_key\"" "$credentials_file" > "$credentials_file.tmp" && mv "$credentials_file.tmp" "$credentials_file"
                echo "Anthropic API key updated"
                
                # Fetch available models
                echo "Fetching available models from Anthropic API..."
                models_response=$(curl -s "https://api.anthropic.com/v1/models" \
                    -H "x-api-key: $api_key" \
                    -H "anthropic-version: 2023-06-01")
                
                # Check for errors
                if [[ "$models_response" == *"error"* ]]; then
                    error_message=$(echo "$models_response" | jq -r '.error.message // .error.type')
                    echo "API Error: $error_message"
                else
                    # Extract model IDs and display names
                    echo "Available Anthropic models:"
                    echo "$models_response" | jq -r '.data[] | "\(.id) (\(.display_name))"' | nl
                    
                    # Update available_models in config
                    jq ".ai_models.anthropic.available_models = $(echo "$models_response" | jq '[.data[].id]')" "$credentials_file" > "$credentials_file.tmp" && mv "$credentials_file.tmp" "$credentials_file"
                    
                    read -p "Enter model number or name (default: claude-3-7-sonnet-20250219, or 'c' to cancel): " model_choice
                    
                    if [ "$model_choice" = "c" ]; then
                        echo "Model selection cancelled."
                    elif [[ "$model_choice" =~ ^[0-9]+$ ]]; then
                        # User entered a number, get the model name from the list
                        selected_model=$(echo "$models_response" | jq -r '.data[].id' | sed -n "${model_choice}p")
                        if [ -n "$selected_model" ]; then
                            jq ".ai_models.anthropic.default_model = \"$selected_model\"" "$credentials_file" > "$credentials_file.tmp" && mv "$credentials_file.tmp" "$credentials_file"
                            echo "Anthropic model set to $selected_model"
                            
                            # Ask about making this the global default
                            read -p "Make this your global default model? (y/n): " set_global
                            if [[ "$set_global" =~ ^[Yy]$ ]]; then
                                # Ensure default_ai_models structure exists
                                if ! jq -e '.default_ai_models' "$app_settings_file" > /dev/null 2>&1; then
                                    jq '. += {"default_ai_models": {}}' "$app_settings_file" > "$app_settings_file.tmp" && 
                                        mv "$app_settings_file.tmp" "$app_settings_file"
                                fi
                                
                                # Update global default
                                jq ".default_ai_provider = \"anthropic\" | .default_ai_models.anthropic = \"$selected_model\"" "$app_settings_file" > "$app_settings_file.tmp" && 
                                    mv "$app_settings_file.tmp" "$app_settings_file"
                                echo "Set as global default model."
                            fi
                        else
                            echo "Invalid selection. Using default model."
                        fi
                    elif [ -n "$model_choice" ]; then
                        # User entered a model name directly
                        jq ".ai_models.anthropic.default_model = \"$model_choice\"" "$credentials_file" > "$credentials_file.tmp" && mv "$credentials_file.tmp" "$credentials_file"
                        echo "Anthropic model set to $model_choice"
                        
                        # Ask about making this the global default
                        read -p "Make this your global default model? (y/n): " set_global
                        if [[ "$set_global" =~ ^[Yy]$ ]]; then
                            # Ensure default_ai_models structure exists
                            if ! jq -e '.default_ai_models' "$app_settings_file" > /dev/null 2>&1; then
                                jq '. += {"default_ai_models": {}}' "$app_settings_file" > "$app_settings_file.tmp" && 
                                    mv "$app_settings_file.tmp" "$app_settings_file"
                            fi
                            
                            # Update global default
                            jq ".default_ai_provider = \"anthropic\" | .default_ai_models.anthropic = \"$model_choice\"" "$app_settings_file" > "$app_settings_file.tmp" && 
                                mv "$app_settings_file.tmp" "$app_settings_file"
                            echo "Set as global default model."
                        fi
                    fi
                fi
            fi
            ;;
        3)
            echo ""
            echo "=== Custom Provider Configuration ==="
            read -p "Do you want to enable a custom AI provider? (y/n/c to cancel): " use_custom
            
            if [ "$use_custom" = "c" ]; then
                echo "Operation cancelled."
                configure_ai_credentials
                return 0
            fi
            
            if [[ "$use_custom" =~ ^[Yy]$ ]]; then
                jq ".ai_models.custom.enabled = true" "$credentials_file" > "$credentials_file.tmp" && mv "$credentials_file.tmp" "$credentials_file"
                
                read -p "Enter provider name (or 'c' to cancel): " provider_name
                if [ "$provider_name" = "c" ]; then
                    echo "Operation cancelled."
                    configure_ai_credentials
                    return 0
                fi
                
                if [ -n "$provider_name" ]; then
                    jq ".ai_models.custom.provider_name = \"$provider_name\"" "$credentials_file" > "$credentials_file.tmp" && mv "$credentials_file.tmp" "$credentials_file"
                fi
                
                read -p "Enter API URL (or 'c' to cancel): " api_url
                if [ "$api_url" = "c" ]; then
                    echo "Operation cancelled."
                    configure_ai_credentials
                    return 0
                fi
                
                if [ -n "$api_url" ]; then
                    jq ".ai_models.custom.api_url = \"$api_url\"" "$credentials_file" > "$credentials_file.tmp" && mv "$credentials_file.tmp" "$credentials_file"
                fi
                
                read -s -p "Enter API key (input will be hidden, or 'c' to cancel): " api_key
                echo ""
                if [ "$api_key" = "c" ]; then
                    echo "Operation cancelled."
                    configure_ai_credentials
                    return 0
                fi
                
                if [ -n "$api_key" ]; then
                    jq ".ai_models.custom.api_key = \"$api_key\"" "$credentials_file" > "$credentials_file.tmp" && mv "$credentials_file.tmp" "$credentials_file"
                fi
                
                read -p "Enter model name (or 'c' to cancel): " model
                if [ "$model" = "c" ]; then
                    echo "Operation cancelled."
                    configure_ai_credentials
                    return 0
                fi
                
                if [ -n "$model" ]; then
                    jq ".ai_models.custom.default_model = \"$model\"" "$credentials_file" > "$credentials_file.tmp" && mv "$credentials_file.tmp" "$credentials_file"
                    
                    # Ask about making this the global default
                    read -p "Make this your global default model? (y/n): " set_global
                    if [[ "$set_global" =~ ^[Yy]$ ]]; then
                        # Ensure default_ai_models structure exists
                        if ! jq -e '.default_ai_models' "$app_settings_file" > /dev/null 2>&1; then
                            jq '. += {"default_ai_models": {}}' "$app_settings_file" > "$app_settings_file.tmp" && 
                                mv "$app_settings_file.tmp" "$app_settings_file"
                        fi
                        
                        # Update global default
                        jq ".default_ai_provider = \"custom\" | .default_ai_models.custom = \"$model\"" "$app_settings_file" > "$app_settings_file.tmp" && 
                            mv "$app_settings_file.tmp" "$app_settings_file"
                        echo "Set as global default model."
                    fi
                fi
                
                echo "Custom provider configured"
            else
                jq ".ai_models.custom.enabled = false" "$credentials_file" > "$credentials_file.tmp" && mv "$credentials_file.tmp" "$credentials_file"
                echo "Custom provider disabled"
            fi
            ;;
        4)
            echo "=== Set Default Provider for Current Session ==="
            echo "Available providers:"
            echo "1) openai"
            echo "2) anthropic"
            
            # Only show custom if enabled
            is_custom_enabled=$(jq -r '.ai_models.custom.enabled // false' "$credentials_file")
            if [ "$is_custom_enabled" = "true" ]; then
                provider_name=$(jq -r '.ai_models.custom.provider_name // "Custom Provider"' "$credentials_file")
                echo "3) custom ($provider_name)"
            fi
            
            read -p "Select provider number or name (or 'c' to cancel): " provider_choice
            
            if [ "$provider_choice" = "c" ]; then
                echo "Operation cancelled."
                configure_ai_credentials
                return 0
            fi
            
            # Process numeric choice
            if [[ "$provider_choice" =~ ^[0-9]+$ ]]; then
                case $provider_choice in
                    1) provider_choice="openai" ;;
                    2) provider_choice="anthropic" ;;
                    3) 
                        if [ "$is_custom_enabled" = "true" ]; then
                            provider_choice="custom"
                        else
                            echo "Custom provider is not enabled."
                            read -p "Press Enter to continue..."
                            configure_ai_credentials
                            return 0
                        fi
                        ;;
                    *) 
                        echo "Invalid selection."
                        read -p "Press Enter to continue..."
                        configure_ai_credentials
                        return 0
                        ;;
                esac
            fi
            
            # Validate provider exists
            if ! jq -e ".ai_models.$provider_choice" "$credentials_file" > /dev/null; then
                echo "Provider '$provider_choice' not found."
                read -p "Press Enter to continue..."
                configure_ai_credentials
                return 0
            fi
            
            # Check if it's custom and enabled
            if [ "$provider_choice" = "custom" ]; then
                if [ "$is_custom_enabled" != "true" ]; then
                    echo "Custom provider is not enabled."
                    read -p "Press Enter to continue..."
                    configure_ai_credentials
                    return 0
                fi
            fi
            
            # Get the model for the selected provider
            model=$(jq -r ".ai_models.$provider_choice.default_model" "$credentials_file")
            
            # Update the current session provider
            jq ".default_ai_provider = \"$provider_choice\"" "$credentials_file" > "$credentials_file.tmp" && mv "$credentials_file.tmp" "$credentials_file"
            echo "Current session provider set to $provider_choice ($model)"
            ;;
        5)
            echo "=== Set Global Default Provider and Model ==="
            echo "This setting will apply to all new sessions."
            echo ""
            echo "Available providers:"
            echo "1) openai"
            echo "2) anthropic"
            
            # Only show custom if enabled
            is_custom_enabled=$(jq -r '.ai_models.custom.enabled // false' "$credentials_file")
            if [ "$is_custom_enabled" = "true" ]; then
                provider_name=$(jq -r '.ai_models.custom.provider_name // "Custom Provider"' "$credentials_file")
                echo "3) custom ($provider_name)"
            fi
            
            read -p "Select provider number or name for global default (or 'c' to cancel): " provider_choice
            
            if [ "$provider_choice" = "c" ]; then
                echo "Operation cancelled."
                configure_ai_credentials
                return 0
            fi
            
            # Process numeric choice
            if [[ "$provider_choice" =~ ^[0-9]+$ ]]; then
                case $provider_choice in
                    1) provider_choice="openai" ;;
                    2) provider_choice="anthropic" ;;
                    3) 
                        if [ "$is_custom_enabled" = "true" ]; then
                            provider_choice="custom"
                        else
                            echo "Custom provider is not enabled."
                            read -p "Press Enter to continue..."
                            configure_ai_credentials
                            return 0
                        fi
                        ;;
                    *) 
                        echo "Invalid selection."
                        read -p "Press Enter to continue..."
                        configure_ai_credentials
                        return 0
                        ;;
                esac
            fi
            
            # Validate provider exists
            if ! jq -e ".ai_models.$provider_choice" "$credentials_file" > /dev/null; then
                echo "Provider '$provider_choice' not found."
                read -p "Press Enter to continue..."
                configure_ai_credentials
                return 0
            fi
            
            # Get available models for selected provider
            if [ "$provider_choice" = "openai" ]; then
                api_key=$(jq -r ".ai_models.openai.api_key" "$credentials_file")
                if [ -n "$api_key" ] && [ "$api_key" != "null" ]; then
                    echo "Fetching OpenAI models..."
                    models_response=$(curl -s "https://api.openai.com/v1/models" \
                        -H "Authorization: Bearer $api_key")
                    
                    echo "Available OpenAI models:"
                    models=$(echo "$models_response" | jq -r '.data[].id' | sort | grep -v "^ada-|^babbage-|^curie-|^davinci-|^text-|^whisper-|^audio-|^tts-|^embeddings-" | grep "gpt\|instruct")
                    echo "$models" | nl
                    
                    read -p "Enter model number or name (or 'c' to cancel): " model_choice
                    
                    if [ "$model_choice" = "c" ]; then
                        echo "Operation cancelled."
                        configure_ai_credentials
                        return 0
                    fi
                    
                    if [[ "$model_choice" =~ ^[0-9]+$ ]]; then
                        model=$(echo "$models" | sed -n "${model_choice}p")
                    else
                        model="$model_choice"
                    fi
                else
                    read -p "Enter model name (e.g. gpt-3.5-turbo, or 'c' to cancel): " model
                    if [ "$model" = "c" ]; then
                        echo "Operation cancelled."
                        configure_ai_credentials
                        return 0
                    fi
                fi
            elif [ "$provider_choice" = "anthropic" ]; then
                models=$(jq -r ".ai_models.anthropic.available_models[]" "$credentials_file" 2>/dev/null)
                if [ -n "$models" ]; then
                    echo "Available Anthropic models:"
                    echo "$models" | nl
                    
                    read -p "Enter model number or name (or 'c' to cancel): " model_choice
                    
                    if [ "$model_choice" = "c" ]; then
                        echo "Operation cancelled."
                        configure_ai_credentials
                        return 0
                    fi
                    
                    if [[ "$model_choice" =~ ^[0-9]+$ ]]; then
                        model=$(echo "$models" | sed -n "${model_choice}p")
                    else
                        model="$model_choice"
                    fi
                else
                    read -p "Enter model name (e.g. claude-3-7-sonnet-20250219, or 'c' to cancel): " model
                    if [ "$model" = "c" ]; then
                        echo "Operation cancelled."
                        configure_ai_credentials
                        return 0
                    fi
                fi
            else
                # Custom provider
                read -p "Enter model name (or 'c' to cancel): " model
                if [ "$model" = "c" ]; then
                    echo "Operation cancelled."
                    configure_ai_credentials
                    return 0
                fi
            fi
            
            # Ensure the app_settings.json file exists
            if [ ! -f "$app_settings_file" ]; then
                echo '{"sync_method": "copy", "app_version": "0.2"}' > "$app_settings_file"
            fi
            
            # Ensure default_ai_models structure exists
            if ! jq -e '.default_ai_models' "$app_settings_file" > /dev/null 2>&1; then
                jq '. += {"default_ai_models": {}}' "$app_settings_file" > "$app_settings_file.tmp" && 
                    mv "$app_settings_file.tmp" "$app_settings_file"
            fi
            
            # Update global defaults
            jq ".default_ai_provider = \"$provider_choice\" | .default_ai_models.$provider_choice = \"$model\"" "$app_settings_file" > "$app_settings_file.tmp" && 
                mv "$app_settings_file.tmp" "$app_settings_file"
            
            echo "Global default set to $provider_choice ($model)"
            
            # Ask if user wants to also apply this setting to the current session
            read -p "Also use this as the current session provider? (y/n): " apply_current
            if [[ "$apply_current" =~ ^[Yy]$ ]]; then
                jq ".default_ai_provider = \"$provider_choice\" | .ai_models.$provider_choice.default_model = \"$model\"" "$credentials_file" > "$credentials_file.tmp" && 
                    mv "$credentials_file.tmp" "$credentials_file"
                echo "Current session updated to use $provider_choice ($model)"
            fi
            ;;
        6)
            configure_ai_parameters
            ;;
        7)
            if ! are_credentials_encrypted; then
                echo "=== Encrypt API Keys ==="
                echo "This will encrypt your API keys with a password."
                echo "You'll need to enter this password each time you use AI features."
                read -p "Continue with encryption? (y/n/c to cancel): " confirm_encrypt
                
                if [ "$confirm_encrypt" = "c" ]; then
                    echo "Operation cancelled."
                    configure_ai_credentials
                    return 0
                fi
                
                if [[ "$confirm_encrypt" =~ ^[Yy]$ ]]; then
                    encrypt_credentials
                fi
            else
                echo "API keys are already encrypted."
                read -p "Would you like to decrypt them permanently? (y/n/c to cancel): " decrypt_perm
                
                if [ "$decrypt_perm" = "c" ]; then
                    echo "Operation cancelled."
                    configure_ai_credentials
                    return 0
                fi
                
                if [[ "$decrypt_perm" =~ ^[Yy]$ ]]; then
                    if decrypt_credentials; then
                        echo "API keys are now stored in plain text."
                    fi
                fi
            fi
            ;;
        8)
            echo "=== DANGER: Wipe All API Keys ==="
            echo "This will permanently delete all your API keys and reset configurations."
            echo "Type 'WIPE ALL KEYS' (all caps) to confirm, or 'c' to cancel:"
            read -p "> " wipe_confirm
            
            if [ "$wipe_confirm" = "c" ]; then
                echo "Operation cancelled."
                configure_ai_credentials
                return 0
            fi
            
            if [ "$wipe_confirm" = "WIPE ALL KEYS" ]; then
                # Remove both the regular and encrypted files
                if [ -f "$credentials_file" ]; then
                    rm "$credentials_file"
                fi
                if [ -f "$credentials_file.enc" ]; then
                    rm "$credentials_file.enc"
                fi
                
                # Reinitialize with defaults
                initialize_credentials
                echo "All API keys have been wiped and reset to defaults."
            else
                echo "Operation cancelled. Keys not wiped."
            fi
            ;;
        9)
            return
            ;;
        *)
            echo "Invalid option"
            ;;
    esac
    
    read -p "Press Enter to continue..."
    configure_ai_credentials
}

# Function to configure AI model parameters
configure_ai_parameters() {
    local provider="$1"
    local credentials_file="$API_DIR/credentials.json"
    
    if [ -z "$provider" ]; then
        # Get default provider
        provider=$(jq -r '.default_ai_provider // "openai"' "$credentials_file")
        
        # List available providers
        echo "Available AI providers:"
        jq -r '.ai_models | keys[] | "  " + .' "$credentials_file"
        echo ""
        read -p "Choose provider to configure (default: $provider): " chosen_provider
        provider=${chosen_provider:-$provider}
    fi
    
    # Validate provider
    if ! jq -e ".ai_models.$provider" "$credentials_file" > /dev/null; then
        echo "Error: Provider '$provider' not found in credentials."
        return 1
    fi
    
    echo "=== AI Parameters for $provider ==="
    
    # Show current parameters
    echo "Current parameters:"
    jq -r ".ai_models.$provider.parameters | to_entries[] | \"  \" + .key + \": \" + (.value|tostring)" "$credentials_file"
    echo ""
    
    # Provider-specific parameter configuration
    case $provider in
        "openai")
            echo "Available parameters to configure:"
            echo "1) temperature (0.0-2.0, lower is more deterministic)"
            echo "2) max_tokens (context length, 1-8000 depending on model)"
            echo "3) top_p (nucleus sampling parameter, 0.0-1.0)"
            echo "4) frequency_penalty (prevents repetition, -2.0 to 2.0)"
            echo "5) presence_penalty (encourages topic diversity, -2.0 to 2.0)"
            echo "6) Return to previous menu"
            ;;
        "anthropic")
            echo "Available parameters to configure:"
            echo "1) temperature (0.0-1.0, lower is more deterministic)"
            echo "2) max_tokens (output length, 1-128000 depending on model)"
            echo "3) top_p (nucleus sampling parameter, 0.0-1.0)"
            echo "4) use_extended_context (enable 128K token output for Claude 3.7, true/false)"
            echo "5) anthropic_version (API version, e.g. 2023-06-01)"
            echo "6) Select model"
            echo "7) Return to previous menu"
            ;;
        "custom")
            echo "Available parameters to configure:"
            echo "1) temperature (sampling temperature)"
            echo "2) max_tokens (context length)"
            echo "3) Add custom parameter"
            echo "4) Return to previous menu"
            ;;
    esac
    
    read -p "Choose a parameter to configure: " param_choice
    
    local param_name=""
    local param_description=""
    local param_range=""
    
    case $provider in
        "openai")
            case $param_choice in
                1)
                    param_name="temperature"
                    param_description="temperature (0.0-2.0, lower is more deterministic)"
                    param_range="0.0-2.0"
                    ;;
                2)
                    param_name="max_tokens"
                    param_description="max_tokens (context length, 1-8000 depending on model)"
                    param_range="1-8000"
                    ;;
                3)
                    param_name="top_p"
                    param_description="top_p (nucleus sampling parameter, 0.0-1.0)"
                    param_range="0.0-1.0"
                    ;;
                4)
                    param_name="frequency_penalty"
                    param_description="frequency_penalty (prevents repetition, -2.0 to 2.0)"
                    param_range="-2.0-2.0"
                    ;;
                5)
                    param_name="presence_penalty"
                    param_description="presence_penalty (encourages topic diversity, -2.0 to 2.0)"
                    param_range="-2.0-2.0"
                    ;;
                6)
                    return
                    ;;
                *)
                    echo "Invalid choice."
                    return 1
                    ;;
            esac
            ;;
        "anthropic")
            case $param_choice in
                1)
                    param_name="temperature"
                    param_description="temperature (0.0-1.0, lower is more deterministic)"
                    param_range="0.0-1.0"
                    ;;
                2)
                    param_name="max_tokens"
                    param_description="max_tokens (output length, 1-128000 for Claude 3.7)"
                    param_range="1-128000"
                    ;;
                3)
                    param_name="top_p"
                    param_description="top_p (nucleus sampling parameter, 0.0-1.0)"
                    param_range="0.0-1.0"
                    ;;
                4)
                    param_name="use_extended_context"
                    param_description="use_extended_context (enable 128K token output for Claude 3.7, true/false)"
                    param_range="true/false"
                    
                    # Boolean parameter requires special handling
                    current_value=$(jq -r ".ai_models.$provider.parameters.use_extended_context // false" "$credentials_file")
                    echo "Current value: $current_value"
                    
                    read -p "Enable extended context? (true/false): " new_value
                    if [[ "$new_value" == "true" || "$new_value" == "false" ]]; then
                        jq ".ai_models.$provider.parameters.use_extended_context = $new_value" "$credentials_file" > "$credentials_file.tmp" && 
                            mv "$credentials_file.tmp" "$credentials_file"
                        echo "Parameter use_extended_context updated to $new_value"
                    else
                        echo "Invalid value. Must be true or false."
                    fi
                    read -p "Press Enter to continue..."
                    configure_ai_parameters "$provider"
                    return
                    ;;
                5)
                    param_name="anthropic_version"
                    param_description="anthropic_version (API version, e.g. 2023-06-01)"
                    param_range="string"
                    ;;
                6)
                    # Special case for model selection
                    echo "Available Claude models:"
                    jq -r ".ai_models.anthropic.available_models[]" "$credentials_file" | cat -n
                    
                    current_model=$(jq -r ".ai_models.anthropic.default_model" "$credentials_file")
                    echo "Current model: $current_model"
                    
                    read -p "Enter model number to select: " model_num
                    if [[ "$model_num" =~ ^[0-9]+$ ]]; then
                        selected_model=$(jq -r ".ai_models.anthropic.available_models[$((model_num-1))] // \"\"" "$credentials_file")
                        if [ -n "$selected_model" ] && [ "$selected_model" != "null" ]; then
                            jq ".ai_models.anthropic.default_model = \"$selected_model\"" "$credentials_file" > "$credentials_file.tmp" && 
                                mv "$credentials_file.tmp" "$credentials_file"
                            echo "Model updated to $selected_model"
                            
                            # If using Claude 3.7, suggest enabling extended context
                            if [[ "$selected_model" == *"3-7"* ]]; then
                                echo "Note: You're using Claude 3.7 Sonnet which supports extended 128K token output."
                                read -p "Enable extended context? (y/n): " enable_ext
                                if [[ "$enable_ext" =~ ^[Yy]$ ]]; then
                                    jq ".ai_models.anthropic.parameters.use_extended_context = true" "$credentials_file" > "$credentials_file.tmp" && 
                                        mv "$credentials_file.tmp" "$credentials_file"
                                    echo "Extended context enabled"
                                fi
                            fi
                        else
                            echo "Invalid model number."
                        fi
                    else
                        echo "Invalid input. Please enter a number."
                    fi
                    read -p "Press Enter to continue..."
                    configure_ai_parameters "$provider"
                    return
                    ;;
                7)
                    return
                    ;;
                *)
                    echo "Invalid choice."
                    return 1
                    ;;
            esac
            ;;
        "custom")
            case $param_choice in
                1)
                    param_name="temperature"
                    param_description="temperature (sampling temperature)"
                    param_range="custom"
                    ;;
                2)
                    param_name="max_tokens"
                    param_description="max_tokens (context length)"
                    param_range="custom"
                    ;;
                3)
                    read -p "Enter parameter name: " param_name
                    param_description="$param_name (custom parameter)"
                    param_range="custom"
                    ;;
                4)
                    return
                    ;;
                *)
                    echo "Invalid choice."
                    return 1
                    ;;
            esac
            ;;
    esac
    
    if [ -n "$param_name" ]; then
        # Get current value
        current_value=$(jq -r ".ai_models.$provider.parameters.$param_name // \"not set\"" "$credentials_file")
        
        echo "Configuring: $param_description"
        echo "Current value: $current_value"
        if [ "$param_range" != "custom" ] && [ "$param_range" != "string" ]; then
            echo "Recommended range: $param_range"
        fi
        
        read -p "Enter new value (or press Enter to keep current): " new_value
        
        if [ -n "$new_value" ]; then
            # Validate numeric input if applicable
            if [[ "$param_name" == "temperature" || 
                  "$param_name" == "top_p" || 
                  "$param_name" == "frequency_penalty" || 
                  "$param_name" == "presence_penalty" ]]; then
                if [[ ! "$new_value" =~ ^[+-]?[0-9]*\.?[0-9]+$ ]]; then
                    echo "Error: Parameter value must be a number."
                    return 1
                fi
                
                # Set with numeric value (without quotes)
                jq ".ai_models.$provider.parameters.$param_name = $new_value" "$credentials_file" > "$credentials_file.tmp" && 
                    mv "$credentials_file.tmp" "$credentials_file"
            elif [[ "$param_name" == "max_tokens" ]]; then
                if [[ ! "$new_value" =~ ^[0-9]+$ ]]; then
                    echo "Error: max_tokens must be a positive integer."
                    return 1
                fi
                
                # Set with numeric value (without quotes)
                jq ".ai_models.$provider.parameters.$param_name = $new_value" "$credentials_file" > "$credentials_file.tmp" && 
                    mv "$credentials_file.tmp" "$credentials_file"
            else
                # Set with string value (with quotes)
                jq ".ai_models.$provider.parameters.$param_name = \"$new_value\"" "$credentials_file" > "$credentials_file.tmp" && 
                    mv "$credentials_file.tmp" "$credentials_file"
            fi
            
            echo "Parameter $param_name updated to $new_value"
        else
            echo "Value unchanged."
        fi
    fi
    
    read -p "Press Enter to continue..."
    configure_ai_parameters "$provider"
}

# Function to generate YouTube tags
generate_youtube_tags() {
    local file="$1"
    local custom_filename="$2"  # Optional custom filename
    local credentials_file="$API_DIR/credentials.json"  # Define the path explicitly
    
    if [ -z "$file" ] || [ ! -f "$file" ]; then
        echo "Error: File not found or not specified."
        return 1
    fi
    
    echo "Generating YouTube tags for: $file"
    
    # Extract metadata first
    local metadata=$(extract_metadata "$file")
    if [ $? -ne 0 ]; then
        echo "Failed to extract metadata."
        return 1
    fi
    
    # Split the metadata string
    IFS='|' read -r artist title album duration featured_artist remixer <<< "$metadata"
    
    # Get available AI providers
    provider=$(select_ai_provider)
    if [ $? -ne 0 ]; then
        echo "Cancelled."
        return 1
    fi
    
    # Get API details
    local model_name=""
    local api_key=""
    local api_url=""
    
    model_name=$(jq -r --arg provider "$provider" '.ai_models[$provider].default_model // ""' "$credentials_file" 2>/dev/null)
    api_key=$(jq -r --arg provider "$provider" '.ai_models[$provider].api_key // ""' "$credentials_file" 2>/dev/null)
    api_url=$(jq -r --arg provider "$provider" '.ai_models[$provider].api_url // ""' "$credentials_file" 2>/dev/null)
    
    if [ -z "$api_key" ] || [ "$api_key" = "null" ]; then
        echo "Error: No API key set for $provider."
        read -p "Would you like to configure it now? (y/n): " configure
        
        if [[ "$configure" =~ ^[Yy]$ ]]; then
            configure_ai_credentials
            # Try again after setting credentials
            generate_youtube_tags "$file" "$custom_filename"
            return $?
        else
            return 1
        fi
    fi
    
    echo "Generating YouTube tags using $provider ($model_name) for: $artist - $title"
    
    # Prepare temp files for API request and response
    local temp_output=$(mktemp)
    local temp_result=$(mktemp)
    
    # Prepare paths
    local dir_path="$(dirname "$file")"
    local base_name="$(basename "${file%.*}")"
    
    # Determine the output filename
    local tags_file=""
    if [ -n "$custom_filename" ]; then
        # Use custom filename if specified
        tags_file="$dir_path/$custom_filename"
    else
        # Default to "Tags.txt" for single files
        tags_file="Tags.txt"
    fi
    
    # Create the API request based on provider
    case "$provider" in
        "anthropic")
            # Prepare prompt for Claude
            cat > "$temp_output" << EOF
<request>
Please analyze this song and generate YouTube tags for it. Include genres, moods, energy level, era, instruments, vocal characteristics, and any other relevant descriptors for use on YouTube.

Artist: $artist
Title: $title
${album:+Album: $album}
${featured_artist:+Featured Artists: $featured_artist}
${remixer:+Remixer: $remixer}
${duration:+Duration: $duration seconds}

Format the tags as a simple list, separated by comma and a space on one line, with no explanations. These should be optimized for YouTube SEO.
Then generate 10-15 hashtags as a simple list on a new line, separated by a space, with no explanations, comprised of at least 2-3 trending search phrases or popular lyrics from the song that people are likely to search for and the following mandatory tags:
#$artist #$title #[genre] #7clouds
</request>
EOF
            
            # Safely escape the API request
            local prompt_content=$(cat "$temp_output" | jq -Rs .)
            
            # Call the API
            curl -s "$api_url" \
                -H "content-type: application/json" \
                -H "x-api-key: $api_key" \
                -H "anthropic-version: 2023-06-01" \
                --data "{\"model\":\"$model_name\",\"max_tokens\":1000,\"messages\":[{\"role\":\"user\",\"content\":$prompt_content}]}" > "$temp_result"
            ;;
            
        "openai")
            # Prepare prompt for OpenAI
            cat > "$temp_output" << EOF
Please analyze this song and generate YouTube tags for it. Include genres, moods, energy level, era, instruments, vocal characteristics, and any other relevant descriptors for use on YouTube.

Artist: $artist
Title: $title
${album:+Album: $album}
${featured_artist:+Featured Artists: $featured_artist}
${remixer:+Remixer: $remixer}
${duration:+Duration: $duration seconds}

Format the tags as a simple list, separated by comma and a space on one line, with no explanations. These should be optimized for YouTube SEO.
Then generate 10-15 hashtags as a simple list on a new line, separated by a space, with no explanations, comprised of at least 2-3 trending search phrases or popular lyrics from the song that people are likely to search for and the following mandatory tags:
#$artist #$title #[genre] #7clouds
EOF
            
            # Safely escape the API request
            local prompt_content=$(cat "$temp_output" | jq -Rs .)
            
            # Call the API
            curl -s "$api_url" \
                -H "Content-Type: application/json" \
                -H "Authorization: Bearer $api_key" \
                --data "{\"model\":\"$model_name\",\"messages\":[{\"role\":\"user\",\"content\":$prompt_content}],\"temperature\":0.3}" > "$temp_result"
            ;;
            
        *)
            echo "Error: Unsupported AI provider."
            rm -f "$temp_output" "$temp_result"
            return 1
            ;;
    esac
    
    # Process the response
    if [ -f "$temp_result" ]; then
        local api_response=""
        
        case "$provider" in
            "anthropic")
                api_response=$(jq -r '.content[0].text // ""' "$temp_result" 2>/dev/null)
                ;;
            "openai")
                api_response=$(jq -r '.choices[0].message.content // ""' "$temp_result" 2>/dev/null)
                ;;
        esac
        
        if [ -n "$api_response" ] && [ "$api_response" != "null" ]; then
            # Save tags to file
            echo "# YouTube Tags for $artist - $title" > "$tags_file"
            echo "$api_response" >> "$tags_file"
            echo -e "\nYouTube tags saved to: $tags_file"
            
            # Clean up
            rm -f "$temp_output" "$temp_result"
            return 0
        else
            # Check for error
            local error=$(jq -r '.error.message // "Unknown error"' "$temp_result" 2>/dev/null)
            echo "API Error: $error"
            
            # Clean up
            rm -f "$temp_output" "$temp_result"
            return 1
        fi
    else
        echo "Error: No response from API."
        
        # Clean up
        rm -f "$temp_output" "$temp_result"
        return 1
    fi
}


# =====WRAPPER & HELPER FUNCTIONS=====

# Function to process metadata for query/collection
process_metadata_for_query() {
    local query="$1"
    local query_type="$2"
    
    echo "=== Processing Metadata for $query_type: $query ==="
    
    # Check if query is for a single song or collection
    if [[ "$query_type" == "song" || "$query_type" == "search" || "$query_type" == "youtube_spotify" ]]; then
        # For single song, we first need to find the local file
        echo "Looking for matching local files..."
        
        # Extract meaningful search terms from the query
        local search_term=""
        if [[ "$query" == *"open.spotify.com"* ]]; then
            # Get track information from Spotify API
            # (We'll use spotdl save for this)
            echo "Fetching track information from Spotify..."
            
            local temp_dir=$(mktemp -d)
            local spotdl_cmd="spotdl save \"$query\" --save-file \"$temp_dir/track.spotdl\" --no-cache"
            
            echo "Executing: $spotdl_cmd"
            
            # Activate pyenv environment if available
            local pyenv_activated=false
            if command -v pyenv &> /dev/null; then
                debug_log "Activating pyenv environment for SpotDL"
                eval "$(pyenv init -)"
                if pyenv activate spotdl 2>/dev/null || pyenv activate mdsh 2>/dev/null; then
                    pyenv_activated=true
                    debug_log "Successfully activated pyenv environment"
                else
                    debug_log "Failed to activate pyenv environment, continuing anyway"
                fi
            fi
            
            if eval "$spotdl_cmd" 2>/dev/null; then
                if [ -f "$temp_dir/track.spotdl" ]; then
                    # Parse the JSON to get artist and title
                    local artist=$(cat "$temp_dir/track.spotdl" | jq -r '.[0].artists[0]' 2>/dev/null)
                    local title=$(cat "$temp_dir/track.spotdl" | jq -r '.[0].name' 2>/dev/null)
                    
                    if [ -n "$artist" ] && [ -n "$title" ]; then
                        search_term="$artist $title"
                        echo "Found song: $artist - $title"
                        
                        # Skip the lengthy file search process if user wants to
                        read -p "Would you like to export metadata directly from Spotify? (y/n): " direct_metadata
                        if [[ "$direct_metadata" =~ ^[Yy]$ ]]; then
                            # Create a suitable filename based on artist and title
                            local metadata_filename="$artist - $title Metadata.txt"
                            local metadata_file="$OUTPUT_DIR/$metadata_filename"
                            
                            echo "Creating metadata without local file: $metadata_filename"
                            
                            # Create basic metadata text
                            local metadata_text=""
                            metadata_text+="$artist - $title"
                            
                            # Add featured artists if present in the title
                            if [[ "$title" == *"feat."* || "$title" == *"ft."* || "$title" == *"(feat."* ]]; then
                                metadata_text+=" (Lyrics)\n"
                            else
                                metadata_text+=" (Lyrics)\n"
                            fi
                            
                            # Add Spotify link
                            metadata_text+="Spotify: $query\n"
                            
                            # Try to extract more info from spotDL JSON if available
                            if [ -f "$temp_dir/track.spotdl" ]; then
                                local album=$(jq -r '.[0].album_name' "$temp_dir/track.spotdl" 2>/dev/null)
                                if [ -n "$album" ] && [ "$album" != "null" ]; then
                                    metadata_text+="Album: $album\n"
                                fi
                                
                                # Try to get release year
                                local year=$(jq -r '.[0].date' "$temp_dir/track.spotdl" 2>/dev/null | cut -d"-" -f1)
                                if [ -n "$year" ] && [ "$year" != "null" ]; then
                                    metadata_text+="Year: $year\n"
                                fi
                                
                                # Try to get duration
                                local duration_ms=$(jq -r '.[0].duration_ms' "$temp_dir/track.spotdl" 2>/dev/null)
                                if [ -n "$duration_ms" ] && [ "$duration_ms" != "null" ]; then
                                    local duration_sec=$(echo "$duration_ms/1000" | bc)
                                    local minutes=$((duration_sec / 60))
                                    local seconds=$((duration_sec % 60))
                                    local formatted_duration=$(printf "%d:%02d" "$minutes" "$seconds")
                                    metadata_text+="Duration: $formatted_duration\n"
                                fi
                            fi
                            
                            # Write to file
                            echo -e "$metadata_text" > "$metadata_file"
                            echo "Metadata exported to: $metadata_file"
                            return 0
                        fi
                    fi
                fi
                rm -rf "$temp_dir"
            else
                echo "Failed to fetch track information from Spotify."
                echo "This could be due to SpotDL not being properly installed or configured."
                rm -rf "$temp_dir"
            fi
            
            # Deactivate pyenv environment if it was activated
            if [ "$pyenv_activated" = true ] && command -v pyenv &> /dev/null; then
                debug_log "Deactivating pyenv environment"
                pyenv deactivate 2>/dev/null || true
                debug_log "Pyenv deactivation completed"
            fi
            
            # If we couldn't get info from Spotify, use generic search
            if [ -z "$search_term" ]; then
                search_term=$(echo "$query" | sed 's/.*spotify.com\/track\///g' | sed 's/\?.*//')
            fi
        else
            # For non-Spotify URLs or search queries, use as is
            search_term="$query"
        fi
        
        echo "Searching for files matching: $search_term"
        
        # Look for files in OUTPUT_DIR
        local found_files=""
        if [ -n "$search_term" ]; then
            # Split search term into words
            IFS=' ' read -ra search_words <<< "$search_term"
            
            # Start with a base find command
            local find_cmd="find \"$OUTPUT_DIR\" -type f \( -name \"*.mp3\" -o -name \"*.flac\" -o -name \"*.m4a\" -o -name \"*.wav\" -o -name \"*.opus\" \)"
            
            # Add conditions for each search word
            for word in "${search_words[@]}"; do
                if [ -n "$word" ] && [ ${#word} -gt 2 ]; then  # Ignore very short words
                    find_cmd+=" -and -name \"*$word*\""
                fi
            done
            
            # Execute the find command
            found_files=$(eval "$find_cmd" | sort)
        fi
        
        if [ -n "$found_files" ]; then
            echo "Found matching files:"
            local count=1
            while IFS= read -r file; do
                echo "$count) $(basename "$file")"
                count=$((count + 1))
            done <<< "$found_files"
            
            # Ask user to select a file
            read -p "Select file number (or 'c' to cancel): " file_choice
            
            if [ "$file_choice" = "c" ]; then
                echo "Operation cancelled."
                return 1
            elif [[ "$file_choice" =~ ^[0-9]+$ ]] && [ "$file_choice" -gt 0 ] && [ "$file_choice" -lt "$count" ]; then
                local selected_file=$(echo "$found_files" | sed -n "${file_choice}p")
                echo "Selected file: $(basename "$selected_file")"
                
                # Process metadata for a single file - use just "Metadata.txt"
                export_song_metadata "$selected_file" "$query" "Metadata.txt"
            else
                echo "Invalid selection."
                return 1
            fi
       else
            echo "No matching files found."
            echo "What would you like to do?"
            echo "1) Select a file manually"
            echo "2) Generate tags using Spotify metadata directly"
            echo "3) Cancel operation"
            read -p "Enter your choice (1-3): " no_file_choice
            
            case $no_file_choice in
                1)
                    read -p "Enter full path to file (or 'c' to cancel): " manual_file
                    
                    if [ "$manual_file" = "c" ]; then
                        echo "Operation cancelled."
                        return 1
                    elif [ -f "$manual_file" ]; then
                        echo "Selected file: $(basename "$manual_file")"
                        # For single song processing, use default filename pattern
                        generate_youtube_tags "$manual_file"
                    else
                        echo "File not found: $manual_file"
                        return 1
                    fi
                    ;;
                2)
                    # We should have artist and title from Spotify by now
                    if [ -n "$artist" ] && [ -n "$title" ]; then
                        # Create a suitable filename based on artist and title
                        local tags_filename="$artist - $title YouTube Tags.txt"
                        local tags_file="$OUTPUT_DIR/$tags_filename"
                        
                        echo "Generating YouTube tags without local file: $tags_filename"
                        # Call helper function for generating tags without a file
                        generate_tags_without_file "$artist" "$title" "$tags_file"
                    else
                        echo "Error: Could not determine artist and title from Spotify metadata."
                        return 1
                    fi
                    ;;
                3|*)
                    echo "Operation cancelled."
                    return 1
                    ;;
            esac
        fi
    else
        # For collections (album, playlist, artist), we need to get all tracks
        echo "Processing collection of songs..."
        
        # Use spotdl save to get track info
        local temp_dir=$(mktemp -d)
        local spotdl_cmd="spotdl save \"$query\" --save-file \"$temp_dir/tracks.spotdl\" --no-cache"
        
        echo "Executing: $spotdl_cmd"
        
        # Activate pyenv environment if available
        local pyenv_activated=false
        if command -v pyenv &> /dev/null; then
            debug_log "Activating pyenv environment for SpotDL"
            eval "$(pyenv init -)"
            if pyenv activate spotdl 2>/dev/null || pyenv activate mdsh 2>/dev/null; then
                pyenv_activated=true
                debug_log "Successfully activated pyenv environment"
            else
                debug_log "Failed to activate pyenv environment, continuing anyway"
            fi
        fi
        
        if eval "$spotdl_cmd"; then
            if [ -f "$temp_dir/tracks.spotdl" ]; then
                echo "Found track information for collection."
                local track_count=$(jq length "$temp_dir/tracks.spotdl")
                echo "Number of tracks found: $track_count"
                
                # Process each track
                for (( i=0; i<$track_count; i++ )); do
                    local artist=$(jq -r ".[$i].artists[0]" "$temp_dir/tracks.spotdl")
                    local title=$(jq -r ".[$i].name" "$temp_dir/tracks.spotdl")
                    local url=$(jq -r ".[$i].url" "$temp_dir/tracks.spotdl")
                    
                    echo -e "\nProcessing: $artist - $title"
                    
                    # Look for matching files
                    local find_cmd="find \"$OUTPUT_DIR\" -type f \( -name \"*$artist*\" -o -name \"*$title*\" \) \( -name \"*.mp3\" -o -name \"*.flac\" -o -name \"*.m4a\" -o -name \"*.wav\" -o -name \"*.opus\" \) | sort"
                    local matching_files=$(eval "$find_cmd")
                    
                    if [ -n "$matching_files" ]; then
                        # Found matching files
                        echo "Found matching files:"
                        local match_count=1
                        while IFS= read -r file; do
                            echo "$match_count) $(basename "$file")"
                            match_count=$((match_count + 1))
                        done <<< "$matching_files"
                        
                        if [ $match_count -eq 2 ]; then
                            # Only one file found, use it automatically
                            local file=$(echo "$matching_files" | head -1)
                            local filename=$(basename "$file")
                            echo "Automatically selected: $filename"
                            
                            # For collections, use filename-based metadata file name
                            export_song_metadata "$file" "$url" "${filename} Metadata.txt"
                        else
                            # Multiple files found, ask user to select
                            echo "Options:"
                            echo "  Enter number to select file"
                            echo "  's' to skip this track"
                            echo "  'a' to abort processing"
                            read -p "Your choice: " file_choice
                            
                            if [ "$file_choice" = "s" ]; then
                                echo "Skipping this track."
                                continue
                            elif [ "$file_choice" = "a" ]; then
                                echo "Aborting processing."
                                break
                            elif [[ "$file_choice" =~ ^[0-9]+$ ]] && [ "$file_choice" -gt 0 ] && [ "$file_choice" -lt "$match_count" ]; then
                                local file=$(echo "$matching_files" | sed -n "${file_choice}p")
                                local filename=$(basename "$file")
                                
                                # For collections, use filename-based metadata file name
                                export_song_metadata "$file" "$url" "${filename} Metadata.txt"
                            else
                                echo "Invalid selection. Skipping this track."
                            fi
                        fi
                    else
                        echo "No matching files found for this track."
                        
                        # No local file found, but we still have artist/title
                        # Create metadata file named with artist-title
                        local metadata_filename="$artist - $title Metadata.txt"
                        local metadata_file="$OUTPUT_DIR/$metadata_filename"
                        
                        echo "Creating metadata without local file: $metadata_filename"
                        
                        # Create basic metadata text
                        local metadata_text=""
                        metadata_text+="$artist - $title (Lyrics)\n"
                        metadata_text+="Spotify: $url\n"
                        
                        # Write to file
                        echo -e "$metadata_text" > "$metadata_file"
                        echo "Metadata exported to: $metadata_file"
                    fi
                done
            fi
            
            # Deactivate pyenv environment if it was activated
            if [ "$pyenv_activated" = true ] && command -v pyenv &> /dev/null; then
                debug_log "Deactivating pyenv environment"
                pyenv deactivate 2>/dev/null || true
                debug_log "Pyenv deactivation completed"
            fi
            
            rm -rf "$temp_dir"
        else
            echo "Failed to fetch track information."
            
            # Deactivate pyenv environment if it was activated
            if [ "$pyenv_activated" = true ] && command -v pyenv &> /dev/null; then
                debug_log "Deactivating pyenv environment"
                pyenv deactivate 2>/dev/null || true
                debug_log "Pyenv deactivation completed"
            fi
            
            rm -rf "$temp_dir"
            return 1
        fi
    fi
    
    return 0
}

# Function to process YouTube tags for query/collection
process_youtube_tags_for_query() {
    local query="$1"
    local query_type="$2"
    
    echo "=== Processing YouTube Tags for $query_type: $query ==="
    
    # Check if query is for a single song or collection
    if [[ "$query_type" == "song" || "$query_type" == "search" || "$query_type" == "youtube_spotify" ]]; then
        # For single song, we first need to find the local file
        echo "Looking for matching local files..."
        
        # Extract meaningful search terms from the query
        local search_term=""
        if [[ "$query" == *"open.spotify.com"* ]]; then
            # Get track information from Spotify API
            # (We'll use spotdl save for this)
            echo "Fetching track information from Spotify..."
            
            local temp_dir=$(mktemp -d)
            local spotdl_cmd="spotdl save \"$query\" --save-file \"$temp_dir/track.spotdl\" --no-cache"
            
            echo "Executing: $spotdl_cmd"
            
            # Activate pyenv environment if available
            local pyenv_activated=false
            if command -v pyenv &> /dev/null; then
                debug_log "Activating pyenv environment for SpotDL"
                eval "$(pyenv init -)"
                if pyenv activate spotdl 2>/dev/null || pyenv activate mdsh 2>/dev/null; then
                    pyenv_activated=true
                    debug_log "Successfully activated pyenv environment"
                else
                    debug_log "Failed to activate pyenv environment, continuing anyway"
                fi
            fi
            
            if eval "$spotdl_cmd" 2>/dev/null; then
                if [ -f "$temp_dir/track.spotdl" ]; then
                    # Parse the JSON to get artist and title
                    local artist=$(cat "$temp_dir/track.spotdl" | jq -r '.[0].artists[0]' 2>/dev/null)
                    local title=$(cat "$temp_dir/track.spotdl" | jq -r '.[0].name' 2>/dev/null)
                    
                if [ -n "$artist" ] && [ -n "$title" ]; then
                    search_term="$artist $title"
                    echo "Found song: $artist - $title"
                    
                    # Skip the lengthy file search process if user wants to
                    read -p "Would you like to generate tags directly from Spotify metadata? (y/n): " direct_tags
                    if [[ "$direct_tags" =~ ^[Yy]$ ]]; then
                        # Create a suitable filename based on artist and title
                        local tags_filename="$artist - $title YouTube Tags.txt"
                        local tags_file="$OUTPUT_DIR/$tags_filename"
                        
                        echo "Generating YouTube tags without local file: $tags_filename"
                        # Call helper function for generating tags without a file
                        generate_tags_without_file "$artist" "$title" "$tags_file"
                        return $?
                    fi
                fi

                fi
                rm -rf "$temp_dir"
            else
                echo "Failed to fetch track information from Spotify."
                echo "This could be due to SpotDL not being properly installed or configured."
                rm -rf "$temp_dir"
            fi
            
            # Deactivate pyenv environment if it was activated
            if [ "$pyenv_activated" = true ] && command -v pyenv &> /dev/null; then
                debug_log "Deactivating pyenv environment"
                pyenv deactivate 2>/dev/null || true
                debug_log "Pyenv deactivation completed"
            fi
            
            # If we couldn't get info from Spotify, use generic search
            if [ -z "$search_term" ]; then
                search_term=$(echo "$query" | sed 's/.*spotify.com\/track\///g' | sed 's/\?.*//')
            fi
        else
            # For non-Spotify URLs or search queries, use as is
            search_term="$query"
        fi
        
        echo "Searching for files matching: $search_term"
        
        # Look for files in OUTPUT_DIR
        local found_files=""
        if [ -n "$search_term" ]; then
            # Split search term into words
            IFS=' ' read -ra search_words <<< "$search_term"
            
            # Start with a base find command
            local find_cmd="find \"$OUTPUT_DIR\" -type f \( -name \"*.mp3\" -o -name \"*.flac\" -o -name \"*.m4a\" -o -name \"*.wav\" -o -name \"*.opus\" \)"
            
            # Add conditions for each search word
            for word in "${search_words[@]}"; do
                if [ -n "$word" ] && [ ${#word} -gt 2 ]; then  # Ignore very short words
                    find_cmd+=" -and -name \"*$word*\""
                fi
            done
            
            # Execute the find command
            found_files=$(eval "$find_cmd" | sort)
        fi
        
        if [ -n "$found_files" ]; then
            echo "Found matching files:"
            local count=1
            while IFS= read -r file; do
                echo "$count) $(basename "$file")"
                count=$((count + 1))
            done <<< "$found_files"
            
            # Ask user to select a file
            read -p "Select file number (or 'c' to cancel): " file_choice
            
            if [ "$file_choice" = "c" ]; then
                echo "Operation cancelled."
                return 1
            elif [[ "$file_choice" =~ ^[0-9]+$ ]] && [ "$file_choice" -gt 0 ] && [ "$file_choice" -lt "$count" ]; then
                local selected_file=$(echo "$found_files" | sed -n "${file_choice}p")
                echo "Selected file: $(basename "$selected_file")"
                
                # For single song processing, use default filename pattern
                generate_youtube_tags "$selected_file"
            else
                echo "Invalid selection."
                return 1
            fi
        else
            echo "No matching files found."
            read -p "Would you like to select a file manually? (y/n): " manual_choice
            
            if [[ "$manual_choice" =~ ^[Yy]$ ]]; then
                read -p "Enter full path to file (or 'c' to cancel): " manual_file
                
                if [ "$manual_file" = "c" ]; then
                    echo "Operation cancelled."
                    return 1
                elif [ -f "$manual_file" ]; then
                    echo "Selected file: $(basename "$manual_file")"
                    # For single song processing, use default filename pattern
                    generate_youtube_tags "$manual_file"
                else
                    echo "File not found: $manual_file"
                    return 1
                fi
            else
                echo "Operation cancelled."
                return 1
            fi
        fi
    else
        # For collections (album, playlist, artist), we need to get all tracks
        echo "Processing collection of songs..."
        
        # Use spotdl save to get track info
        local temp_dir=$(mktemp -d)
        local spotdl_cmd="spotdl save \"$query\" --save-file \"$temp_dir/tracks.spotdl\" --no-cache"
        
        echo "Executing: $spotdl_cmd"
        
        # Activate pyenv environment if available
        local pyenv_activated=false
        if command -v pyenv &> /dev/null; then
            debug_log "Activating pyenv environment for SpotDL"
            eval "$(pyenv init -)"
            if pyenv activate spotdl 2>/dev/null || pyenv activate mdsh 2>/dev/null; then
                pyenv_activated=true
                debug_log "Successfully activated pyenv environment"
            else
                debug_log "Failed to activate pyenv environment, continuing anyway"
            fi
        fi
        
        if eval "$spotdl_cmd"; then
            if [ -f "$temp_dir/tracks.spotdl" ]; then
                echo "Found track information for collection."
                local track_count=$(jq length "$temp_dir/tracks.spotdl")
                echo "Number of tracks found: $track_count"
                
                # Process each track
                for (( i=0; i<$track_count; i++ )); do
                    local artist=$(jq -r ".[$i].artists[0]" "$temp_dir/tracks.spotdl")
                    local title=$(jq -r ".[$i].name" "$temp_dir/tracks.spotdl")
                    
                    echo -e "\nProcessing: $artist - $title"
                    
                    # Look for matching files
                    local find_cmd="find \"$OUTPUT_DIR\" -type f \( -name \"*$artist*\" -o -name \"*$title*\" \) \( -name \"*.mp3\" -o -name \"*.flac\" -o -name \"*.m4a\" -o -name \"*.wav\" -o -name \"*.opus\" \) | sort"
                    local matching_files=$(eval "$find_cmd")
                    
                    if [ -n "$matching_files" ]; then
                        # Found matching files
                        echo "Found matching files:"
                        local match_count=1
                        while IFS= read -r file; do
                            echo "$match_count) $(basename "$file")"
                            match_count=$((match_count + 1))
                        done <<< "$matching_files"
                        
                        if [ $match_count -eq 2 ]; then
                            # Only one file found, use it automatically
                            local file=$(echo "$matching_files" | head -1)
                            local filename=$(basename "$file")
                            echo "Automatically selected: $filename"
                            
                            # For collections, use filename-based YouTube tags file name
                            generate_youtube_tags "$file" "${filename} Tags.txt"
                        else
                            # Multiple files found, ask user to select
                            echo "Options:"
                            echo "  Enter number to select file"
                            echo "  's' to skip this track"
                            echo "  'a' to abort processing"
                            read -p "Your choice: " file_choice
                            
                            if [ "$file_choice" = "s" ]; then
                                echo "Skipping this track."
                                continue
                            elif [ "$file_choice" = "a" ]; then
                                echo "Aborting processing."
                                break
                            elif [[ "$file_choice" =~ ^[0-9]+$ ]] && [ "$file_choice" -gt 0 ] && [ "$file_choice" -lt "$match_count" ]; then
                                local file=$(echo "$matching_files" | sed -n "${file_choice}p")
                                local filename=$(basename "$file")
                                
                                # For collections, use filename-based YouTube tags file name
                                generate_youtube_tags "$file" "${filename} Tags.txt"
                            else
                                echo "Invalid selection. Skipping this track."
                            fi
                        fi
                    else
                        echo "No matching files found for this track."
                        
                        # No local file found, but we still have artist/title
                        # Generate dummy metadata file without a song
                        local tags_filename="$artist - $title YouTube Tags.txt"
                        local tags_file="$OUTPUT_DIR/$tags_filename"
                        
                        echo "Creating YouTube tags without local file: $tags_filename"
                        
                        # Call helper function for generating tags without a file
                        generate_tags_without_file "$artist" "$title" "$tags_file"
                    fi
                done
            fi
            
            # Deactivate pyenv environment if it was activated
            if [ "$pyenv_activated" = true ] && command -v pyenv &> /dev/null; then
                debug_log "Deactivating pyenv environment"
                pyenv deactivate 2>/dev/null || true
                debug_log "Pyenv deactivation completed"
            fi
            
            rm -rf "$temp_dir"
        else
            echo "Failed to fetch track information."
            
            # Deactivate pyenv environment if it was activated
            if [ "$pyenv_activated" = true ] && command -v pyenv &> /dev/null; then
                debug_log "Deactivating pyenv environment"
                pyenv deactivate 2>/dev/null || true
                debug_log "Pyenv deactivation completed"
            fi
            
            rm -rf "$temp_dir"
            return 1
        fi
    fi
    
    return 0
}

# Function to display enumerated list of AI providers with their current models and handle selection
select_ai_provider() {
    local default_ai_provider="$1"  # Optional default AI provider
    local credentials_file="$API_DIR/credentials.json"
    
    # If no default AI provided, use the one from credentials
    if [ -z "$default_ai_provider" ]; then
        default_ai_provider=$(jq -r '.default_ai_provider // "anthropic"' "$credentials_file" 2>/dev/null)
    fi
    
    # Get list of providers and their models
    local providers=()
    local count=1
    
    if [ -f "$credentials_file" ]; then
        # Process each provider and add to array
        while read -r provider; do
            # Get the current model for this provider
            local model=$(jq -r --arg provider "$provider" '.ai_models[$provider].default_model // "Not set"' "$credentials_file" 2>/dev/null)
            
            # Check if custom provider is enabled before showing it
            if [ "$provider" = "custom" ]; then
                local is_enabled=$(jq -r '.ai_models.custom.enabled // false' "$credentials_file")
                local provider_name=$(jq -r '.ai_models.custom.provider_name // "Custom Provider"' "$credentials_file")
                
                if [ "$is_enabled" = "true" ]; then
                    echo "$count) $provider (Current Model: $model)"
                    providers+=("$provider")
                    count=$((count + 1))
                fi
            else
                # Capitalize the first letter of provider for display
                local display_name="$(tr '[:lower:]' '[:upper:]' <<< ${provider:0:1})${provider:1}"
                echo "$count) $display_name (Current Model: $model)"
                providers+=("$provider")
                count=$((count + 1))
            fi
        done < <(jq -r '.ai_models | keys[]' "$credentials_file" | sort)
    else
        echo "  Error: Credentials file not found at $credentials_file"
        echo "  Please configure AI credentials first."
        return 1
    fi
    
    # Ask for selection
    read -p "Choose provider number or name (default: $default_ai_provider) or 'c' to cancel: " choice
    
    if [ "$choice" = "c" ]; then
        return 1
    fi
    
    # Empty choice means use default
    if [ -z "$choice" ]; then
        echo "Using default AI provider: $default_ai_provider"
        echo "$default_ai_provider"
        return 0
    fi
    
    # Check if numeric choice
    if [[ "$choice" =~ ^[0-9]+$ ]]; then
        # Array index is 0-based, but display is 1-based
        local index=$((choice-1))
        
        if [ $index -ge 0 ] && [ $index -lt ${#providers[@]} ]; then
            local selected="${providers[$index]}"
            echo "Using provider: $selected"
            echo "$selected"
            return 0
        else
            echo "Invalid selection. Using default: $default_ai_provider"
            echo "$default_ai_provider"
            return 0
        fi
    else
        # Direct provider name entry - verify it exists
        if jq -e --arg p "$choice" '.ai_models[$p]' "$credentials_file" >/dev/null 2>&1; then
            echo "Using provider: $choice"
            echo "$choice"
            return 0
        else
            echo "Provider '$choice' not found. Using default: $default_ai_provider"
            echo "$default_ai_provider"
            return 0
        fi
    fi
}

# Helper function to generate tags without a local file
generate_tags_without_file() {
    local artist="$1"
    local title="$2"
    local output_file="$3"
    local credentials_file="$API_DIR/credentials.json"
    
    echo "Generating YouTube tags for: $artist - $title (without local file)"
    
    # Get available AI providers using the new selection function
    echo "Select AI provider for generating tags:"
    provider=$(select_ai_provider)
    if [ $? -ne 0 ]; then
        echo "Cancelled."
        return 1
    fi
    
    # Get API details
    local model_name=""
    local api_key=""
    local api_url=""
    
    model_name=$(jq -r --arg provider "$provider" '.ai_models[$provider].default_model // ""' "$credentials_file" 2>/dev/null)
    api_key=$(jq -r --arg provider "$provider" '.ai_models[$provider].api_key // ""' "$credentials_file" 2>/dev/null)
    api_url=$(jq -r --arg provider "$provider" '.ai_models[$provider].api_url // ""' "$credentials_file" 2>/dev/null)
    
    if [ -z "$api_key" ] || [ "$api_key" = "null" ]; then
        echo "Error: No API key set for $provider."
        read -p "Would you like to configure it now? (y/n): " configure
        
        if [[ "$configure" =~ ^[Yy]$ ]]; then
            configure_ai_credentials
            # Try again after setting credentials
            generate_tags_without_file "$artist" "$title" "$output_file"
            return $?
        else
            return 1
        fi
    fi
    
    echo "Generating YouTube tags using $provider ($model_name) for: $artist - $title"
    
    # Prepare temp files for API request and response
    local temp_output=$(mktemp)
    local temp_result=$(mktemp)
    
    # Create the API request based on provider
    case "$provider" in
        "anthropic")
            # Prepare prompt for Claude
            cat > "$temp_output" << EOF
<request>
Please analyze this song and generate YouTube tags for it. Include genres, moods, energy level, era, instruments, vocal characteristics, and any other relevant descriptors for use on YouTube.

Artist: $artist
Title: $title

Format the tags as a simple list, separated by comma and a space on one line, with no explanations. These should be optimized for YouTube SEO.
Then generate 10-15 hashtags as a simple list on a new line, separated by a space, with no explanations, comprised of at least 2-3 trending search phrases or popular lyrics from the song that people are likely to search for and the following mandatory tags:
#$artist #$title #[genre] #7clouds
</request>
EOF
            
            # Safely escape the API request
            local prompt_content=$(cat "$temp_output" | jq -Rs .)
            
            # Call the API
            curl -s "$api_url" \
                -H "content-type: application/json" \
                -H "x-api-key: $api_key" \
                -H "anthropic-version: 2023-06-01" \
                --data "{\"model\":\"$model_name\",\"max_tokens\":1000,\"messages\":[{\"role\":\"user\",\"content\":$prompt_content}]}" > "$temp_result"
            ;;
            
        "openai")
            # Prepare prompt for OpenAI
            cat > "$temp_output" << EOF
Please analyze this song and generate YouTube tags for it. Include genres, moods, energy level, era, instruments, vocal characteristics, and any other relevant descriptors for use on YouTube.

Artist: $artist
Title: $title

Format the tags as a simple list, separated by comma and a space on one line, with no explanations. These should be optimized for YouTube SEO.
Then generate 10-15 hashtags as a simple list on a new line, separated by a space, with no explanations, comprised of at least 2-3 trending search phrases or popular lyrics from the song that people are likely to search for and the following mandatory tags:
#$artist #$title #[genre] #7clouds
EOF
            
            # Safely escape the API request
            local prompt_content=$(cat "$temp_output" | jq -Rs .)
            
            # Call the API
            curl -s "$api_url" \
                -H "Content-Type: application/json" \
                -H "Authorization: Bearer $api_key" \
                --data "{\"model\":\"$model_name\",\"messages\":[{\"role\":\"user\",\"content\":$prompt_content}],\"temperature\":0.3}" > "$temp_result"
            ;;
            
        *)
            echo "Error: Unsupported AI provider."
            rm -f "$temp_output" "$temp_result"
            return 1
            ;;
    esac
    
    # Process the response
    if [ -f "$temp_result" ]; then
        local api_response=""
        
        case "$provider" in
            "anthropic")
                api_response=$(jq -r '.content[0].text // ""' "$temp_result" 2>/dev/null)
                ;;
            "openai")
                api_response=$(jq -r '.choices[0].message.content // ""' "$temp_result" 2>/dev/null)
                ;;
        esac
        
        if [ -n "$api_response" ] && [ "$api_response" != "null" ]; then
            # Save tags to file
            echo "# YouTube Tags for $artist - $title" > "$output_file"
            echo "$api_response" >> "$output_file"
            echo -e "\nYouTube tags saved to: $output_file"
            
            # Clean up
            rm -f "$temp_output" "$temp_result"
            return 0
        else
            # Check for error
            local error=$(jq -r '.error.message // "Unknown error"' "$temp_result" 2>/dev/null)
            echo "API Error: $error"
            
            # Clean up
            rm -f "$temp_output" "$temp_result"
            return 1
        fi
    else
        echo "Error: No response from API."
        
        # Clean up
        rm -f "$temp_output" "$temp_result"
        return 1
    fi
}

# Function to run Python with the right environment
run_python_script() {
    local script="$1"
    local env_name="$2"  # Optional pyenv environment name
    
    if [ -n "$env_name" ] && command -v pyenv &> /dev/null && pyenv versions --bare | grep -q "$env_name"; then
        # Use pyenv Python
        eval "$(pyenv init -)"
        pyenv shell "$env_name"
        python "$script"
        local result=$?
        pyenv shell --unset
        return $result
    else
        # Use system Python
        python3 "$script"
        return $?
    fi
}

# =====MENU FUNCTIONS=====

# Main menu update
show_main_menu() {
    clear

    if [ -n "$VERSION" ]; then
        echo "=== Mr. Magic - Song & Lyric Downloader v$VERSION ==="
    else
        echo "=== Mr. Magic - Song & Lyric Downloader ==="
    fi

    echo "Current Settings:"
    echo "  Active Config: $ACTIVE_CONFIG"
    echo "  Output Directory: ${OUTPUT_DIR:-"Not set"}"
    
    # Try to get format and bitrate safely
    if [ -f "$CURRENT_CONFIG" ] && command -v jq &> /dev/null; then
        echo "  Output Format: $(jq -r '.format // "Not set"' "$CURRENT_CONFIG" 2>/dev/null)"
        echo "  Bitrate: $(jq -r '.bitrate // "Not set"' "$CURRENT_CONFIG" 2>/dev/null)"
    else
        echo "  Output Format: Not set"
        echo "  Bitrate: Not set"
    fi
    
    echo "  Debug Mode: $([ "$DEBUG_MODE" = true ] && echo "ON" || echo "OFF")"
    
    # Show AI provider and model info
    if [ -f "$API_DIR/credentials.json" ] && command -v jq &> /dev/null; then
        local provider=$(jq -r '.default_ai_provider // "Not set"' "$API_DIR/credentials.json" 2>/dev/null)
        local model=$(jq -r ".ai_models.$provider.default_model // \"Not set\"" "$API_DIR/credentials.json" 2>/dev/null)
        echo "  AI Provider in Use: $provider"
        echo "  AI Model in Use: $model"
    elif [ -f "$API_DIR/credentials.json.enc" ]; then
        echo "  AI Provider in Use: [Encrypted]"
        echo "  AI Model in Use: [Encrypted]"
    else
        echo "  AI Provider in Use: Not configured"
        echo "  AI Model in Use: Not configured"
    fi
    
    echo ""
    echo "1) Download"
    echo "2) SpotDL config management"
    echo "3) AI API settings"
    echo "4) Set output directory"  # New option
    echo "5) Install/update dependencies"
    echo "6) Debug options"
    echo "7) About"
    echo "8) Exit"
    echo ""
}

# Download submenu
show_download_menu() {
    clear
    echo "=== Mr. Magic - Download Options ==="
    echo "1) Start Download Wizard"
    echo "2) Quick Download Song/Album/Playlist"
    echo "3) Quick Download Lyrics"
    echo "4) SpotDL config manager"
    echo "5) Set output directory"
    echo "6) Return to main menu"
    echo ""
    read -p "Enter your choice (1-6): " download_choice
    
    case $download_choice in
        1)
            download_wizard
            # Clear screen before showing menu again
            clear
            show_download_menu
            ;;
        2)
            download_song
            read -p "Press Enter to return to download menu..."
            # Clear screen before showing menu again
            clear
            show_download_menu
            ;;
        3)
            manage_lyrics
            # Clear screen before showing menu again
            clear
            show_download_menu
            ;;
        4)
            show_config_menu
            # Clear screen before showing menu again
            clear
            show_download_menu
            ;;
        5)
            set_output_directory
            read -p "Press Enter to return to download menu..."
            # Clear screen before showing menu again
            clear
            show_download_menu
            ;;
        6)
            return
            ;;
        *)
            echo "Invalid choice. Please try again."
            sleep 1
            show_download_menu
            ;;
    esac
}

# Music download submenu
show_music_download_menu() {
    clear
    echo "=== Download Music ==="
    echo "What would you like to download?"
    echo "1) Song (single track)"
    echo "2) Album"
    echo "3) Playlist"
    echo "4) Artist (all songs)"
    echo "5) Search query"
    echo "6) YouTube link with Spotify metadata"
    echo "7) Liked songs (requires authentication)"
    echo "8) All user playlists (requires authentication)"
    echo "9) All saved albums (requires authentication)"
    echo "10) Cancel and return to previous menu"
    
    read -p "Enter your choice (1-10): " query_type
    debug_log "User selected query type: $query_type"
    
    # Build SpotDL command based on selection
    local spotdl_cmd="spotdl"
    local query=""
    
    # For music-only flow, temporarily disable LRC generation
    local original_lrc_setting=$(jq -r '.generate_lrc // false' "$CURRENT_CONFIG")
    if [ "$original_lrc_setting" = "true" ]; then
        # Temporarily disable LRC generation for music-only flow
        jq '.generate_lrc = false' "$CURRENT_CONFIG" > "$CURRENT_CONFIG.tmp" && mv "$CURRENT_CONFIG.tmp" "$CURRENT_CONFIG"
        sync_with_spotdl_config
        debug_log "Temporarily disabled LRC generation for music-only flow"
    fi

    case $query_type in
        1) # Song
            read -p "Enter song URL or name (or 'c' to cancel): " query
            if [ "$query" = "c" ]; then
                echo "Operation cancelled."
                return 1
            fi
            spotdl_cmd="$spotdl_cmd download \"$query\""
            ;;
        2) # Album
            read -p "Enter album URL (or 'c' to cancel): " query
            if [ "$query" = "c" ]; then
                echo "Operation cancelled."
                return 1
            fi
            spotdl_cmd="$spotdl_cmd download \"$query\""
            ;;
        3) # Playlist
            read -p "Enter playlist URL (or 'c' to cancel): " query
            if [ "$query" = "c" ]; then
                echo "Operation cancelled."
                return 1
            fi
            spotdl_cmd="$spotdl_cmd download \"$query\""
            ;;
        4) # Artist
            read -p "Enter artist URL (or 'c' to cancel): " query
            if [ "$query" = "c" ]; then
                echo "Operation cancelled."
                return 1
            fi
            spotdl_cmd="$spotdl_cmd download \"$query\""
            ;;
        5) # Search
            read -p "Enter search query (or 'c' to cancel): " query
            if [ "$query" = "c" ]; then
                echo "Operation cancelled."
                return 1
            fi
            spotdl_cmd="$spotdl_cmd download \"$query\""
            ;;
        6) # YouTube with Spotify metadata
            read -p "Enter YouTube URL (or 'c' to cancel): " yt_url
            if [ "$yt_url" = "c" ]; then
                echo "Operation cancelled."
                return 1
            fi
            read -p "Enter Spotify URL for metadata (or 'c' to cancel): " spotify_url
            if [ "$spotify_url" = "c" ]; then
                echo "Operation cancelled."
                return 1
            fi
            query="$spotify_url"  # Save Spotify URL for metadata
            spotdl_cmd="$spotdl_cmd download \"$yt_url|$spotify_url\""
            ;;
        7) # Liked songs
            spotdl_cmd="$spotdl_cmd download saved --user-auth"
            ;;
        8) # All user playlists
            spotdl_cmd="$spotdl_cmd download all-user-playlists --user-auth"
            ;;
        9) # All saved albums
            spotdl_cmd="$spotdl_cmd download all-user-saved-albums --user-auth"
            ;;
        10|*)
            echo "Operation cancelled."
            return 1
            ;;
    esac
    
    # Make sure the cache directory is correct before running SpotDL
    local cache_dir="$HOME/.mr-magic/cache"
    if [ "$DEBUG_MODE" = true ]; then
        mkdir -p "$cache_dir/.spotipy"
        chmod -R 755 "$cache_dir"
    else
        mkdir -p "$cache_dir/.spotipy" 2>/dev/null
        chmod -R 755 "$cache_dir" 2>/dev/null
    fi
    
    # Make sure config is synced before running SpotDL
    sync_with_spotdl_config
    
    # VPN notice AFTER selection is made
    echo -e "\n⚠️  Important Note: YouTube downloads may require a VPN in certain countries"
    echo "If downloads fail, consider using a VPN service to bypass regional restrictions."
    echo ""
    read -p "Press Enter to continue with download..." dummy
    
    # Execute the command
    echo -e "\nDownloading music..."
    echo "Command being executed: $spotdl_cmd"
    debug_log "Starting download with command: $spotdl_cmd"
    
    # Activate pyenv environment if available
    local pyenv_activated=false
    if command -v pyenv &> /dev/null; then
        debug_log "Activating pyenv environment for SpotDL"
        eval "$(pyenv init -)"
        if pyenv activate spotdl 2>/dev/null || pyenv activate mdsh 2>/dev/null; then
            pyenv_activated=true
            debug_log "Successfully activated pyenv environment"
        else
            debug_log "Failed to activate pyenv environment, continuing anyway"
        fi
    fi
    
    # Execute the command to see live output, but also capture final status
    echo "Executing SpotDL..."
    eval "$spotdl_cmd"
    local download_status=$?
    
    # Check for cache directory issues
    if [ $download_status -ne 0 ] && grep -q "Couldn't write token to cache" <(eval "$spotdl_cmd" 2>&1 | head -10); then
        echo -e "\n⚠️ Permission Error: Cannot write to cache directory."
        echo "Fixing cache directory permissions..."
        
        # Update to a more reliable cache location
        cache_dir="$HOME/.mr-magic/cache"
        if [ "$DEBUG_MODE" = true ]; then
            mkdir -p "$cache_dir/.spotipy"
            chmod -R 755 "$cache_dir"
        else
            mkdir -p "$cache_dir/.spotipy" 2>/dev/null
            chmod -R 755 "$cache_dir" 2>/dev/null
        fi
        
        # Update the config to use this cache directory
        jq ".cache_path = \"$cache_dir/.spotipy\"" "$CURRENT_CONFIG" > "$CURRENT_CONFIG.tmp" && mv "$CURRENT_CONFIG.tmp" "$CURRENT_CONFIG"
        
        # Sync the updated config
        sync_with_spotdl_config
        
        echo "Cache directory updated. Retrying download..."
        # Retry with updated config
        eval "$spotdl_cmd"
        download_status=$?
    fi
    
    # Set permissions on the output directory
    chmod -R 755 "$OUTPUT_DIR"
    
    # Check if the download was successful
    if [ $download_status -eq 0 ]; then
        echo -e "\nDownload completed successfully!"
        echo "Song saved to the configured output directory"
        debug_log "Download successful"
        
        # Find the downloaded file (most recent music file in the output directory)
        debug_log "Searching for downloaded file"
        find_cmd="find \"$OUTPUT_DIR\" -type f \( -name \"*.mp3\" -o -name \"*.flac\" -o -name \"*.m4a\" -o -name \"*.wav\" -o -name \"*.opus\" \) -mmin -5 2>/dev/null | sort -r | head -1"
        debug_log "Find command: $find_cmd"
        downloaded_file=$(eval "$find_cmd")
        
        if [ -n "$downloaded_file" ]; then
            # Make sure file has proper permissions
            chmod 644 "$downloaded_file"
            
            echo "Found downloaded file: $downloaded_file"
            debug_log "Found downloaded file: $downloaded_file"
            
            # Restore original LRC setting if it was changed
            if [ "$original_lrc_setting" = "true" ]; then
                jq '.generate_lrc = true' "$CURRENT_CONFIG" > "$CURRENT_CONFIG.tmp" && mv "$CURRENT_CONFIG.tmp" "$CURRENT_CONFIG"
                sync_with_spotdl_config
                debug_log "Restored original LRC generation setting"
            fi

            # Ask if user wants to export metadata
            read -p "Would you like to export song metadata to a text file? (y/n): " export_metadata_choice
            debug_log "User chose to export metadata: $export_metadata_choice"
            
            if [[ "$export_metadata_choice" =~ ^[Yy]$ ]]; then
                # Extract Spotify URL from the original query if it was a Spotify URL
                local spotify_url=""
                if [[ "$query" == *"open.spotify.com"* ]]; then
                    spotify_url="$query"
                fi
                export_song_metadata "$downloaded_file" "$spotify_url"
            fi
            
            # Ask if user wants to generate YouTube tags
            read -p "Would you like to generate YouTube tags for this song? (y/n): " generate_tags_choice
            debug_log "User chose to generate YouTube tags: $generate_tags_choice"
            
            if [[ "$generate_tags_choice" =~ ^[Yy]$ ]]; then
                generate_youtube_tags "$downloaded_file"
            fi
        else
            echo "Could not find downloaded file."
            debug_log "Failed to find downloaded file"
        fi
        
        # Open the directory - this should happen regardless of whether we found the specific file
        output_dir_from_config=$(jq -r '.output' "$CURRENT_CONFIG" | awk -F'{' '{print $1}')
        if [ -n "$output_dir_from_config" ] && [ -d "$output_dir_from_config" ]; then
            open_directory "$output_dir_from_config"
        else
            open_directory "$OUTPUT_DIR"
        fi
    else
        echo -e "\nError occurred during download."
        debug_log "Error occurred during download with status: $download_status"
    fi
    
    # Deactivate pyenv environment if it was activated
    if [ "$pyenv_activated" = true ] && command -v pyenv &> /dev/null; then
        debug_log "Deactivating pyenv environment"
        pyenv deactivate 2>/dev/null || true
        debug_log "Pyenv deactivation completed"
    fi
    
    read -p "Press Enter to return to download menu..."
    return 0
}

# Metadata export submenu
show_metadata_export_menu() {
    clear
    echo "=== Export Metadata ==="
    echo "What would you like to process metadata for?"
    echo "1) Song (single track)"
    echo "2) Album"
    echo "3) Playlist"
    echo "4) Artist (all songs)"
    echo "5) Search query"
    echo "6) YouTube link with Spotify metadata"
    echo "7) Liked songs (requires authentication)"
    echo "8) All user playlists (requires authentication)"
    echo "9) All saved albums (requires authentication)"
    echo "10) Cancel and return to previous menu"
    
    read -p "Enter your choice (1-10): " query_type
    debug_log "User selected metadata export type: $query_type"
    
    local query=""
    
    case $query_type in
        1) # Song
            read -p "Enter song URL or name (or 'c' to cancel): " query
            if [ "$query" = "c" ]; then
                echo "Operation cancelled."
                return 1
            fi
            process_metadata_for_query "$query" "song"
            ;;
        2) # Album
            read -p "Enter album URL (or 'c' to cancel): " query
            if [ "$query" = "c" ]; then
                echo "Operation cancelled."
                return 1
            fi
            process_metadata_for_query "$query" "album"
            ;;
        3) # Playlist
            read -p "Enter playlist URL (or 'c' to cancel): " query
            if [ "$query" = "c" ]; then
                echo "Operation cancelled."
                return 1
            fi
            process_metadata_for_query "$query" "playlist"
            ;;
        4) # Artist
            read -p "Enter artist URL (or 'c' to cancel): " query
            if [ "$query" = "c" ]; then
                echo "Operation cancelled."
                return 1
            fi
            process_metadata_for_query "$query" "artist"
            ;;
        5) # Search
            read -p "Enter search query (or 'c' to cancel): " query
            if [ "$query" = "c" ]; then
                echo "Operation cancelled."
                return 1
            fi
            process_metadata_for_query "$query" "search"
            ;;
        6) # YouTube with Spotify metadata
            read -p "Enter YouTube URL (or 'c' to cancel): " yt_url
            if [ "$yt_url" = "c" ]; then
                echo "Operation cancelled."
                return 1
            fi
            read -p "Enter Spotify URL for metadata (or 'c' to cancel): " spotify_url
            if [ "$spotify_url" = "c" ]; then
                echo "Operation cancelled."
                return 1
            fi
            process_metadata_for_query "$yt_url|$spotify_url" "youtube_spotify"
            ;;
        7) # Liked songs
            process_metadata_for_query "saved" "liked"
            ;;
        8) # All user playlists
            process_metadata_for_query "all-user-playlists" "user_playlists"
            ;;
        9) # All saved albums
            process_metadata_for_query "all-user-saved-albums" "saved_albums"
            ;;
        10|*)
            echo "Operation cancelled."
            return 1
            ;;
    esac
    
    return 0
}

# YouTube tags submenu
show_youtube_tags_menu() {
    clear
    echo "=== Export YouTube Tags ==="
    echo "What would you like to create YouTube tags for?"
    echo "1) Song (single track)"
    echo "2) Album"
    echo "3) Playlist"
    echo "4) Artist (all songs)"
    echo "5) Search query"
    echo "6) YouTube link with Spotify metadata"
    echo "7) Liked songs (requires authentication)"
    echo "8) All user playlists (requires authentication)"
    echo "9) All saved albums (requires authentication)"
    echo "10) Cancel and return to previous menu"
    
    read -p "Enter your choice (1-10): " query_type
    debug_log "User selected YouTube tags type: $query_type"
    
    local query=""
    
    case $query_type in
        1) # Song
            read -p "Enter song URL or name (or 'c' to cancel): " query
            if [ "$query" = "c" ]; then
                echo "Operation cancelled."
                return 1
            fi
            process_youtube_tags_for_query "$query" "song"
            ;;
        2) # Album
            read -p "Enter album URL (or 'c' to cancel): " query
            if [ "$query" = "c" ]; then
                echo "Operation cancelled."
                return 1
            fi
            process_youtube_tags_for_query "$query" "album"
            ;;
        3) # Playlist
            read -p "Enter playlist URL (or 'c' to cancel): " query
            if [ "$query" = "c" ]; then
                echo "Operation cancelled."
                return 1
            fi
            process_youtube_tags_for_query "$query" "playlist"
            ;;
        4) # Artist
            read -p "Enter artist URL (or 'c' to cancel): " query
            if [ "$query" = "c" ]; then
                echo "Operation cancelled."
                return 1
            fi
            process_youtube_tags_for_query "$query" "artist"
            ;;
        5) # Search
            read -p "Enter search query (or 'c' to cancel): " query
            if [ "$query" = "c" ]; then
                echo "Operation cancelled."
                return 1
            fi
            process_youtube_tags_for_query "$query" "search"
            ;;
        6) # YouTube with Spotify metadata
            read -p "Enter YouTube URL (or 'c' to cancel): " yt_url
            if [ "$yt_url" = "c" ]; then
                echo "Operation cancelled."
                return 1
            fi
            read -p "Enter Spotify URL for metadata (or 'c' to cancel): " spotify_url
            if [ "$spotify_url" = "c" ]; then
                echo "Operation cancelled."
                return 1
            fi
            process_youtube_tags_for_query "$yt_url|$spotify_url" "youtube_spotify"
            ;;
        7) # Liked songs
            process_youtube_tags_for_query "saved" "liked"
            ;;
        8) # All user playlists
            process_youtube_tags_for_query "all-user-playlists" "user_playlists"
            ;;
        9) # All saved albums
            process_youtube_tags_for_query "all-user-saved-albums" "saved_albums"
            ;;
        10|*)
            echo "Operation cancelled."
            return 1
            ;;
    esac
    
    return 0
}

# Configuration menu
show_config_menu() {
    clear
    echo "=== Mr. Magic - Configuration Management ==="
    echo "Current active config: $ACTIVE_CONFIG"
    echo "Config directory: $CONFIG_DIR"
    echo "SpotDL config: ~/.spotdl/config.json"
    echo ""
    echo "1) Edit current configuration"
    echo "2) Save current config as preset"
    echo "3) Load config preset"
    echo "4) List available config presets"
    echo "5) Create new config preset"
    echo "6) Delete config preset"  # New option
    echo "7) Set SpotDL config sync method"
    echo "8) Open config directory in file explorer"
    echo "9) Open current config file in text editor"
    echo "10) Open SpotDL config directory"
    echo "11) Return to main menu"  # Changed from 10 to 11
    echo ""
    read -p "Enter your choice (1-11): " config_choice  # Updated range
    
    case $config_choice in
        1)
            edit_config
            read -p "Press Enter to continue..."
            show_config_menu
            ;;
        2)
            save_config_preset
            read -p "Press Enter to continue..."
            show_config_menu
            ;;
        3)
            list_config_presets
            # Get the presets as an array
            presets=("default")
            if [ -d "$PRESETS_DIR" ]; then
                for preset in "$PRESETS_DIR"/*.json; do
                    if [ -f "$preset" ]; then
                        preset_name=$(basename "$preset" .json)
                        presets+=("$preset_name")
                    fi
                done
            fi

            # Display presets with numbers
            echo "Available presets by number:"
            for i in "${!presets[@]}"; do
                echo "$((i+1))) ${presets[$i]}"
            done

            read -p "Enter preset number, name, or 'c' to cancel: " preset_choice

            if [ "$preset_choice" = "c" ]; then
                echo "Operation cancelled."
            elif [[ "$preset_choice" =~ ^[0-9]+$ ]] && [ "$preset_choice" -ge 1 ] && [ "$preset_choice" -le "${#presets[@]}" ]; then
                # User selected a number, convert to preset name
                selected_preset="${presets[$((preset_choice-1))]}"
                load_config "$selected_preset"
            elif [ -n "$preset_choice" ]; then
                # User entered a preset name directly
                load_config "$preset_choice"
            fi
            read -p "Press Enter to continue..."
            show_config_menu
            ;;
        4)
            list_config_presets
            read -p "Press Enter to continue..."
            show_config_menu
            ;;
        5)
            # Let user create a preset from scratch or based on default
            echo "Create new config preset:"
            echo "1) Start from default config"
            echo "2) Start from current config"
            read -p "Choose an option (1-2 or 'c' to cancel): " create_option
            
            case $create_option in
                1)
                    cp "$CONFIG_DIR/default.json" "$CURRENT_CONFIG"
                    save_config_preset
                    ;;
                2)
                    save_config_preset
                    ;;
                c)  # Just use 'c' for cancellation
                    echo "Operation cancelled."
                    ;;
                *)
                    echo "Invalid choice."
                    ;;
            esac
            read -p "Press Enter to continue..."
            show_config_menu
            ;;
        6)
            delete_config_preset
            read -p "Press Enter to continue..."
            show_config_menu
            ;;
        7)
            set_sync_method
            read -p "Press Enter to continue..."
            show_config_menu
            ;;
        8)
            # Open config directory in file explorer
            echo "Opening config directory: $CONFIG_DIR"
            if [[ "$OSTYPE" == "darwin"* ]]; then
                # macOS
                open "$CONFIG_DIR"
            elif [[ "$OSTYPE" == "msys" || "$OSTYPE" == "win32" ]]; then
                # Windows
                explorer "$CONFIG_DIR"
            elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
                # Linux
                if command -v xdg-open &> /dev/null; then
                    xdg-open "$CONFIG_DIR"
                elif command -v nautilus &> /dev/null; then
                    nautilus "$CONFIG_DIR"
                elif command -v dolphin &> /dev/null; then
                    dolphin "$CONFIG_DIR"
                else
                    echo "Cannot find a suitable file manager."
                fi
            else
                echo "Unsupported operating system."
            fi
            read -p "Press Enter to continue..."
            show_config_menu
            ;;
        9)
            # Open config file in text editor
            echo "Opening config file: $CURRENT_CONFIG"
            if [[ "$OSTYPE" == "darwin"* ]]; then
                # macOS
                open -t "$CURRENT_CONFIG"
            elif [[ "$OSTYPE" == "msys" || "$OSTYPE" == "win32" ]]; then
                # Windows
                notepad "$CURRENT_CONFIG"
            elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
                # Linux
                if command -v xdg-open &> /dev/null; then
                    xdg-open "$CURRENT_CONFIG"
                elif command -v gedit &> /dev/null; then
                    gedit "$CURRENT_CONFIG"
                elif command -v kate &> /dev/null; then
                    kate "$CURRENT_CONFIG"
                elif command -v nano &> /dev/null; then
                    nano "$CURRENT_CONFIG"
                else
                    echo "Cannot find a suitable text editor."
                fi
            else
                echo "Unsupported operating system."
            fi
            read -p "Press Enter to continue..."
            show_config_menu
            ;;
        10)
            # Open SpotDL config directory
            local spotdl_config_dir="$HOME/.spotdl"
            echo "Opening SpotDL config directory: $spotdl_config_dir"
            
            # Create the directory if it doesn't exist
            if [ ! -d "$spotdl_config_dir" ]; then
                mkdir -p "$spotdl_config_dir"
            fi
            
            if [[ "$OSTYPE" == "darwin"* ]]; then
                # macOS
                open "$spotdl_config_dir"
            elif [[ "$OSTYPE" == "msys" || "$OSTYPE" == "win32" ]]; then
                # Windows
                explorer "$spotdl_config_dir"
            elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
                # Linux
                if command -v xdg-open &> /dev/null; then
                    xdg-open "$spotdl_config_dir"
                elif command -v nautilus &> /dev/null; then
                    nautilus "$spotdl_config_dir"
                elif command -v dolphin &> /dev/null; then
                    dolphin "$spotdl_config_dir"
                else
                    echo "Cannot find a suitable file manager."
                fi
            else
                echo "Unsupported operating system."
            fi
            read -p "Press Enter to continue..."
            show_config_menu
            ;;
        11)
            return
            ;;
        *)
            echo "Invalid choice. Press Enter to try again..."
            read
            show_config_menu
            ;;
    esac
}

# Function to show debug options menu
show_debug_menu() {
    clear
    echo "=== Mr. Magic - Debug Options ==="
    echo "1) Toggle debug mode (currently $([ "$DEBUG_MODE" = true ] && echo "ON" || echo "OFF"))"
    echo "2) View debug log"
    echo "3) Return to main menu"
    echo ""
    read -p "Enter your choice (1-3): " debug_choice
    
    case $debug_choice in
        1)
            toggle_debug_mode
            read -p "Press Enter to continue..."
            show_debug_menu
            ;;
        2)
            view_debug_log
            read -p "Press Enter to continue..."
            show_debug_menu
            ;;
        3)
            return
            ;;
        *)
            echo "Invalid choice. Please try again."
            sleep 1
            show_debug_menu
            ;;
    esac
}

# Function to display about information
show_about() {
    clear

    if [ -n "$VERSION" ]; then
        echo "=== About Mr. Magic - Song & Lyric Downloader v$VERSION ==="
    else
        echo "=== About Mr. Magic - Song & Lyric Downloader ==="
    fi

    echo ""
    echo "A comprehensive tool for downloading songs and lyrics using spotDL, LRCLIB, and Genius"

    if [ -n "$VERSION_YEAR" ]; then
        echo "Copyright © $VERSION_YEAR Kenyatta Naji Johnson-Adams"
    else
        echo "Copyright © Kenyatta Naji Johnson-Adams"
    fi

    echo "Licensed under the MIT License"
    echo ""
    echo "Developer:"
    echo "Kenyatta Naji Johnson-Adams"
    echo "Website: https://github.com/mrnajiboy"
    echo "Email: hello@naji.land"
    echo ""
    echo "Dependencies:"
    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo "- Homebrew: macOS package manager (https://brew.sh)"
    fi
    echo "- pyenv: Python environment management (https://opencollective.com/pyenv)"
    echo "- Python 3.12.7: Core programming language (https://python.org)"
    echo "- spotDL v4: Music download library (https://spotdl.readthedocs.io/en/latest/)"
    echo "- LRCLIB API: Synced lyrics database (https://lrclib.net/docs)"
    echo "- Genius API: Extensive lyrics database (https://docs.genius.com/)"
    echo "- lyricsgenius: Python client for Genius API (https://github.com/johnwmillr/LyricsGenius)"
    echo "- ffmpeg: Media processing library (https://ffmpeg.org)"
    echo "- jq: JSON processing utility (https://jqlang.org/)"
    echo "- OpenSSL: Encryption for API key security (https://www.openssl.org/)"
    echo ""
    echo "AI Providers:"
    echo "- OpenAI ChatGPT: OpenAI's language model (https://openai.org)"
    echo "- OpenAI Whisper: Speech recognition for lyrics transcription (https://github.com/openai/whisper)"
    echo "- Claude: Anthropic's language model (https://www.anthropic.com/)"
    echo ""
    echo "Features:"
    echo "- Download songs from Spotify, YouTube and other sources"
    echo "- Advanced configuration management with presets"
    echo "- Multi-source lyrics search (LRCLIB, SpotDL, Genius, Whisper)"
    echo "- Synchronized lyrics (LRC) and SRT subtitle support"
    echo "- Korean lyrics romanization using AI"
    echo "- Multi-AI provider support with enumerated selection"
    echo "- Password-protected API key storage"
    echo "- Song metadata extraction and export with Spotify links"
    echo "- YouTube tag generation for songs"
    echo "- Batch processing for playlists and albums"
    echo "- Romanized lyrics formatting with AI assistance"
    echo "- Smart config management with SpotDL integration"
    echo "- Multiple config sync methods (copy or symlink)"
    echo "- Hierarchical menu system for different content types"
    echo ""
    echo "Credits:"
    echo "- Original concept and development: Kenyatta Naji Johnson-Adams with AI assistance"
    echo "- spotDL: Thanks to the spotDL development team (https://github.com/spotDL/spotify-downloader)"
    echo "- LRCLIB: Thanks to the LRCLIB team for their API"
    echo "- Genius: Thanks to the Genius team for their lyrics API"
    echo "- LyricsGenius: Thanks to John Miller for the Python library"
    echo "- LRC2SRT conversion: Adapted from @Urenko (https://github.com/URenko/lrc2srt)"
    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo "- Homebrew: macOS package management by the Homebrew team (https://brew.sh)"
    fi
    echo "- pyenv: Python version management by pyenv team"
    echo "- jq: JSON processing by the jq team"
    echo "- OpenSSL: Encryption by the OpenSSL team"
    echo "- OpenAI: AI features powered by OpenAI"
    echo "- Anthropic: AI features powered by Anthropic's Claude models"
    echo ""
    if [ -n "$VERSION" ]; then
        echo "Release Notes for v$VERSION:"
    else
        echo "Release Notes"
    fi
    echo "- Complete rewrite with improved folder structure"
    echo "- New hierarchical menu system for different content types"
    echo "- Enhanced configuration options with preset management"
    echo "- Added metadata export with Spotify link support"
    echo "- Integrated YouTube tag generation using AI"
    echo "- Improved batch processing for playlists and albums"
    echo "- Added support for Korean lyrics romanization via AI"
    echo "- Multi-AI provider support with enumerated selections"
    echo "- Password-protected API key storage for improved security"
    echo "- Improved error handling and user experience"
    echo "- Enhanced lyrics formatting options (AI-assisted or simple)"
    echo "- Added Genius lyrics search integration"
    echo "- Prioritized synced lyrics sources for better results"
    echo "- Automated dependency installation"
    echo ""
    read -p "Press Enter to return to main menu..."
}


# =====DEBUG FUNCTIONS=====

# Debug function for logging
debug_log() {
    if [ "$DEBUG_MODE" = true ]; then
        echo -e "[DEBUG] $(date +%H:%M:%S): $1" >> "$DEBUG_FILE"
    fi
}

# Function to toggle debug mode
toggle_debug_mode() {
    if [ "$DEBUG_MODE" = true ]; then
        DEBUG_MODE=false
        echo "Debug mode: OFF"
    else
        DEBUG_MODE=true
        echo "Debug mode: ON"
        # Initialize new debug log
        echo "=== Debug Log Started $(date) ===" > "$DEBUG_FILE"
        chmod 600 "$DEBUG_FILE"  # Secure the debug file
    fi
}

# Function to view debug log
view_debug_log() {
    if [ ! -f "$DEBUG_FILE" ]; then
        echo "Debug log file does not exist yet."
        return 1
    fi
    
    if command -v less &> /dev/null; then
        less "$DEBUG_FILE"
    else
        cat "$DEBUG_FILE"
    fi
    
    return 0
}


# =====RUN FUNCTIONS=====

# Main function
main() {
    # Display welcome message
    clear
   
    # Initialize app versioning
    initialize_app_versioning

    if [ -n "$VERSION" ]; then
        echo "=== Welcome to Mr. Magic - Song & Lyric Downloader v$VERSION ==="
    else
        echo "=== Welcome to Mr. Magic - Song & Lyric Downloader ==="
    fi

    echo "The cool tool for downloading songs and lyrics~"
    echo ""
    
    # Create initial directory structure and files 
    if [ "$DEBUG_MODE" = true ]; then
        mkdir -p "$CONFIG_DIR" "$PRESETS_DIR" "$DEPENDENCIES_DIR" "$CACHE_DIR" "$API_DIR"
    else
        mkdir -p "$CONFIG_DIR" "$PRESETS_DIR" "$DEPENDENCIES_DIR" "$CACHE_DIR" "$API_DIR" 2>/dev/null
    fi
    
    # Create and ensure cache directories are writable
    if [ "$DEBUG_MODE" = true ]; then
        mkdir -p "$CACHE_DIR/.spotipy"
        chmod -R 755 "$CACHE_DIR"
    else
        mkdir -p "$CACHE_DIR/.spotipy" 2>/dev/null
        chmod -R 755 "$CACHE_DIR"
    fi

    # If using an external drive for cache, make sure the config reflects that
    jq ".cache_path = \"$CACHE_DIR/.spotipy\"" "$CURRENT_CONFIG" > "$CURRENT_CONFIG.tmp" && mv "$CURRENT_CONFIG.tmp" "$CURRENT_CONFIG"
    
    # Create default config if it doesn't exist
    create_default_config
    
    # Initialize app settings
    initialize_app_settings
    
    # Sync with SpotDL config on startup
    sync_with_spotdl_config
    
    # Check for encrypted credentials
    if [ -f "$API_DIR/credentials.json.enc" ] && [ ! -f "$API_DIR/credentials.json" ]; then
        check_encrypted_credentials
    else
        # Initialize credentials file if it doesn't exist
        initialize_credentials
    fi
    
    # Copy the LRC2SRT script to dependencies directory
    copy_lrc2srt_script

    # Call this function when initializing the app in main()
    create_uninstall_script

    # Check for required tools
    echo "Checking for required tools..."
    if ! command -v jq &> /dev/null; then
        echo "Warning: jq is not installed. Lyrics functionality will be limited."
        echo "Select 'Install/update dependencies' from the main menu to install required tools."
    fi
    
    if ! command -v ffprobe &> /dev/null; then
        echo "Warning: ffprobe is not installed. Duration and metadata extraction will be limited."
        echo "Select 'Install/update dependencies' from the main menu to install required tools."
    fi
    
    if ! command -v spotdl &> /dev/null; then
        echo "Warning: spotdl is not installed. Please install it through the dependencies menu."
    fi
    
    if ! command -v openssl &> /dev/null; then
        echo "Warning: OpenSSL is not installed. API key encryption will not be available."
        echo "Select 'Install/update dependencies' from the main menu to install required tools."
    fi
    
    # Prompt user to set output directory if not set
    echo ""
    echo "Let's set up your output directory where downloaded files will be saved."
    if [ -z "$OUTPUT_DIR" ]; then
        set_output_directory
        if [ $? -ne 0 ]; then
            echo "Using default directory for now. You can set it later from the main menu."
            OUTPUT_DIR="$APP_DIR"
        fi
    else
        echo "Current output directory: $OUTPUT_DIR"
        read -p "Would you like to change it? (y/n): " change_dir
        if [[ "$change_dir" =~ ^[Yy]$ ]]; then
            set_output_directory
        fi
    fi
    
    # "Let's get started" message
    echo ""
    echo "Great! Let's get started with Mr. Magic!"
    echo ""
    read -p "Press Enter to continue to main menu..." dummy
    
    # Main menu loop
    while true; do
        show_main_menu
        read -p "Enter your choice (1-8): " main_choice
        
        case $main_choice in
            1)
                show_download_menu
                ;;
            2)
                show_config_menu
                ;;
            3)
                configure_ai_credentials
                ;;
            4)
                set_output_directory
                read -p "Press Enter to return to main menu..."
                ;;
            5)
                install_dependencies
                read -p "Press Enter to return to main menu..."
                ;;
            6)
                show_debug_menu
                ;;
            7)
                show_about
                ;;
            8)
                echo "Exiting Downloader..."
                encrypt_keys_on_exit
                echo "Thank you for using Mr. Magic!"
                # Deactivate pyenv environment if it was activated
                if command -v pyenv &> /dev/null; then
                    pyenv deactivate 2>/dev/null || true
                fi
                exit 0
                ;;
            *)
                echo "Invalid choice. Please try again."
                sleep 1
                ;;
        esac
    done
}

# Run the main function
main
