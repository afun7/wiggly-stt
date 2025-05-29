# wiggly-stt 
<div align="center">
  <img src="icon.png" width="128" height="128" alt="Wiggly STT Icon">
</div>

A simple to use script created for one purpose: simply transcribe audio to text in linux and have it work with wayland/gui apps. 

## Usage 

0. Create shortcuts for `start-record` and `stop-record [-p]`; optionally also create shortcuts for `start-server` and `stop-server`. 
1. Start recording; speak for as long as you want. 
2. Invoke `stop-record` to stop recording and transcribe the text. You'll get a notification once finished and the resulting text will be put on your clipboard. (With the `-p` flag to `stop-record`, the text is also automatically pasted at the cursor)

Optionally you can also run the server to keep the model in memory for faster transcription times.

That's all. 

**P.S.** Inference is done locally, data never leaves your machine.

## Commands

```bash
# Recording
./wiggly-stt.sh start-record     # Start recording
./wiggly-stt.sh stop-record      # Stop and transcribe
./wiggly-stt.sh stop-record -p   # Stop and auto-paste

# Server (optional, for faster transcription)
./wiggly-stt.sh start-server     # Start server
./wiggly-stt.sh stop-server      # Stop server

# Status
./wiggly-stt.sh status           # Show current status
```

> **💡 Tip**: You can combine the commands to ensure you start and use the server:  
> `./wiggly-stt.sh start-server && ./wiggly-stt.sh start-record`

<details>
<summary><strong>📦 System Components</strong></summary>

- **`wiggly-stt.sh`** - Main script with simple interface
- **`wiggly-stt-daemon`** - Background recording handler
- **`wiggly-stt.conf`** - Centralized configuration file

</details>

## Dependencies

### Required
- **whisper.cpp** - Local AI transcription engine (whisper-cli and whisper-server)
- **wl-clipboard** - Wayland clipboard utilities  
- **ffmpeg** - Audio recording
- **libnotify** - Desktop notifications
- **curl** - Server communication

### Optional
- **ydotool** - Auto-paste functionality (requires setup)

## Installation

### Install Dependencies

#### Install whisper.cpp
Install whisper.cpp (preferably a version optimized for your video card/CPU/NPU) from [Source](https://github.com/ggml-org/whisper.cpp) or a package.

#### Install System Dependencies
```bash
# Arch Linux / Manjaro
sudo pacman -S ffmpeg wl-clipboard libnotify wget curl

# Ubuntu / Debian
sudo apt install ffmpeg wl-clipboard libnotify-bin wget curl

# Fedora
sudo dnf install ffmpeg wl-clipboard libnotify wget curl
```

#### Install Optional Dependencies
```bash
# For auto-paste functionality
# Arch Linux / Manjaro
sudo pacman -S ydotool

# Ubuntu / Debian
sudo apt install ydotool

# Fedora
sudo dnf install ydotool

# Enable ydotool service
systemctl --user enable --now ydotool
```

### Install Wiggly STT

#### Quick Install (Recommended)
```bash
# Clone the repository
git clone https://github.com/hansp27/wiggly-stt.git
cd wiggly-stt

# Make install script executable
chmod u+x install.sh

# Run the install script
./install.sh --user  # Install for current user
# or
./install.sh --system  # Install system-wide (requires sudo)
```

#### Manual Installation
```bash
# Clone the repository
git clone https://github.com/hansp27/wiggly-stt.git
cd wiggly-stt

# Make scripts executable
chmod +x wiggly-stt.sh wiggly-stt-daemon

# Optionally create symlinks or add to PATH
ln -s "$(pwd)/wiggly-stt.sh" ~/.local/bin/wiggly-stt
```

<details>
<summary><strong>⚙️ Configuration</strong></summary>

### Centralized Settings (`wiggly-stt.conf`)

```bash
# Model Configuration
MODEL_PATH="${HOME}/.models"
# You can find other available models below 
DEFAULT_MODEL="ggml-small.en.bin"

# Audio Configuration  
SAMPLE_RATE=16000

# Server Configuration
SERVER_HOST="127.0.0.1"
SERVER_PORT="8080"
SERVER_THREADS=4

# Auto-paste Configuration
AUTO_PASTE_FLAG=false
```

</details>

<details>
<summary><strong>🤖 Available Models</strong></summary>

Models are automatically downloaded to `~/.models/` on first use:

| Model | Size | Accuracy | Speed | Use Case |
|-------|------|----------|-------|----------|
| `ggml-tiny.en.bin` | ~39MB | Lower | Fastest | Quick notes |
| `ggml-base.en.bin` | ~142MB | Good | Fast | General use |
| `ggml-small.en.bin` | ~466MB | Better | Medium | **Default** |
| `ggml-medium.en.bin` | ~1.5GB | High | Slower | Quality dictation |
| `ggml-large-v3.bin` | ~3.1GB | Highest | Slowest | Professional use |
| `ggml-large-v3-turbo.bin` | ~3.1GB | Highest | Fast | Best of both |

</details>

<details>
<summary><strong>⚡ Performance Comparison</strong></summary>

| Mode | Model Loading | Transcription Speed | Use Case |
|------|---------------|-------------------|----------|
| **Server Mode** | Once (at startup) | Very Fast | Multiple recordings |
| **CLI Mode** | Every transcription | Slower | Single recordings |

</details>

<details>
<summary><strong>🐛 Troubleshooting</strong></summary>

### Audio Issues
```bash
# Test microphone
ffmpeg -f pulse -i default -t 3 test.wav

# List audio devices
pactl list sources short
```

### Whisper.cpp Issues
```bash
# Check installation
which whisper-cli whisper-server
whisper-cli --help

# Test manually
whisper-cli -m ~/.models/ggml-small.en.bin test.wav
```

### Server Issues
```bash
# Check if server is running
./wiggly-stt.sh status

# Check server logs
tail -f /tmp/wiggly-stt-server/server.log

# Test server manually
curl -X POST -F "file=@test.wav" -F "response_format=text" http://localhost:8080/inference
```

### Auto-paste Issues
```bash
# Check ydotool service
systemctl --user status ydotool

# Test ydotool
echo "test" | wl-copy
ydotool key 29:1 47:1 47:0 29:0  # Ctrl+V
```

### Common Error Solutions

**"No recording active"**
- Use `start-record` before `stop-record`

**"Recording already active"**
- Use `stop-record` before starting a new recording

**"Server not responding"**
- Check: `./wiggly-stt.sh status`
- Restart: `./wiggly-stt.sh stop-server && ./wiggly-stt.sh start-server`

**"ydotool not available"**
- Install: `sudo pacman -S ydotool`
- Enable: `systemctl --user enable --now ydotool`

</details>

## Privacy & Security

- **100% local processing** - no data sent to external servers
- Audio files temporarily stored in `/tmp/` and auto-cleaned
- Models cached locally after download
- No internet required after initial setup
- All transcription happens on your machine
- Server runs locally (127.0.0.1) only

## License

This project is open source. See LICENSE file for details.

## Acknowledgments

- [whisper.cpp](https://github.com/ggerganov/whisper.cpp) - Efficient local whisper implementation
- [OpenAI Whisper](https://github.com/openai/whisper) - Original AI model
- [wl-clipboard](https://github.com/bugaevc/wl-clipboard) - Wayland clipboard utilities
- [ydotool](https://github.com/ReimuNotMoe/ydotool) - Generic Linux command-line automation tool 
- claude-4-sonnet for doing the heavy lifting