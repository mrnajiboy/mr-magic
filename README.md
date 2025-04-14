# Mr. Magic - Song & Lyric Downloader

*The cool tool for downloading songs and lyrics~*

## Overview

Mr. Magic is a comprehensive Bash tool for downloading songs, lyrics, and generating metadata with AI assistance. It integrates with spotDL for music downloads and various services for lyrics, while providing an easy-to-use menu-based interface.

## Features

- **Hierarchical Menu System**
  - Content type selection (Music, Metadata, YouTube Tags)
  - Intuitive navigation with consistent "back" options
  - Separate flows for different content types

- **Music Downloads**
  - Download songs, albums, playlists, and more from Spotify
  - Multiple audio format support (MP3, FLAC, M4A, OPUS, WAV)
  - Configurable quality settings with easy presets

- **Lyrics Management**
  - Multi-source lyrics search with fallback options
  - LRCLIB API for high-quality synced lyrics
  - SpotDL integration for Spotify-based lyrics
  - Genius API support for extensive lyrics database
  - Download synchronized lyrics (LRC format)
  - Convert formats (LRC to SRT)
  - Romanize non-Latin lyrics with AI assistance
  - Format lyrics to remove timestamps
  - Option for AI-assisted or simple formatting

- **Metadata & Tags**
  - Export song metadata with Spotify links
  - Generate YouTube-optimized tags using AI
  - Batch processing for playlists and albums
  - Consistent file naming conventions

- **AI Integration**
  - Multi-provider support with enumerated selection UI
  - OpenAI, Claude, and custom provider options
  - Configurable AI parameters per provider
  - Password-protected API key storage
  - Whisper transcription for audio files

- **Configuration Management**
  - Save and load configuration presets
  - Edit advanced SpotDL settings
  - Set output directory with presets
  - Multiple config sync options

## Installation

### Prerequisites

- **Bash shell environment**
- (Optional) [Genius API Access](https://docs.genius.com/) for extensive lyrics database
- (Optional) OpenAI or Claude API keys for AI transcription, youtube tag generation

### Setup

1. Clone the repository:
```bash
git clone https://github.com/yourusername/mr-magic.git
cd mr-magic
```

2. Make the script executable:
```
chmod +x mr-magic-downloader.sh
```

3. Run the application:
./mr-magic-downloader.sh


4. Use the built-in dependency installer on first run to set up all required components.
   - Options for installing Python globally or in virtual environment only
   - Automatic detection of OS and appropriate package installation

## Configuration

On first run, the app creates a default configuration and directory structure:
```
App/
├── mr-magic-downloader.sh # Main script
├── configs/ # Config file storage
│ ├── default.json # Default configuration
│ └── presets/ # User-created presets
├── dependencies/ # Supporting scripts and tools
│ └── lrc2srt.py # LRC to SRT conversion script
├── cache/ # Temporary files and cache
└── api/ # API credentials and related files
└── credentials.json # API tokens and authentication info
```
Use the configuration menu to set up spotDL options, output directory, and other preferences.

## Usage

1. Start the application:
```
./mr-magic-downloader.sh
```

2. Set your output directory when prompted

3. Navigate through the menu to:
  - Download music
  - Export metadata
  - Generate YouTube tags
  - Download lyrics
  - Configure settings

2. From the main menu, you can:
   - **Download**: Access the download submenu with options for:
     - Download Wizard (guided process)
     - Quick Download Song/Album/Playlist
     - Quick Download Lyrics
     - SpotDL config manager
     - Set output directory
   - **SpotDL config management**: Create and manage config presets
   - **AI API settings**: Configure AI providers and models
   - **Install/update dependencies**: Manage required software
   - **Debug options**: Toggle debug mode and view logs
   - **About**: View app information and credits
   - **Exit**: Close the application

3. When downloading from YouTube, note that some countries may require a VPN to bypass regional restrictions.

## AI Features Setup

To use AI features like romanization and tag generation:

1. Select "AI API settings" from the main menu
2. Configure your preferred AI provider (OpenAI, Claude, or custom)
3. Enter your API key (from [OpenAI](https://platform.openai.com/account/api-keys) or [Claude](https://console.anthropic.com/settings/keys))
4. Select from available models retrieved directly from the provider's API
5. (Optional) Configure additional parameters like temperature and max tokens
6. (Optional) Encrypt your API keys with a password for added security

## Dependencies

- **Homebrew** (macOS): Package manager for macOS (https://brew.sh)
- **spotDL v4**: For downloading music from Spotify and other sources (https://spotdl.readthedocs.io/en/latest/)
- **ffmpeg**: For audio conversion and metadata extraction (https://ffmpeg.org)
- **jq**: For JSON processing (https://jqlang.org/)
- **pyenv** 2+: Python version and environment management ([OpenCollective](https://opencollective.com/pyenv))
- **Python** 3.9.9 & 3.12.7: Required for script and dependencies ([Python.org](https://python.org))
- **LRCLIB API**: For finding and downloading lyrics (https://lrclib.net/docs)
- **lyricsgenius**: For Genius lyric searching.
- **whisper**: For AI lyric transcription
- **lrc2srt.py**: For LRC to SRT file conversion, Based on work by [@Urenko](https://github.com/URenko/lrc2srt)
- **OpenSSL**: For API key encryption and security (https://www.openssl.org/)

## AI Providers

- **ChatGPT**: OpenAI's language model for lyrics romanization and tag generation (https://openai.org)
- **Claude**: Anthropic's language model for lyrics romanization and tag generation (https://www.anthropic.com/)

## Uninstallation

To uninstall Mr. Magic:

1. Run the included uninstaller script:
```
./uninstall.sh
```

2. Follow the prompts to:
   - Remove application files and configurations
   - Choose whether to remove dependencies
   - Decide whether to keep or remove downloaded content
   - Remove script files completely

## License

[MIT License](LICENSE)

Copyright (c) 2025 Kenyatta Naji Johnson-Adams


## Acknowledgments

- [SpotDL Team](https://github.com/spotDL/spotify-downloader) for the amazing music downloader
- [LRCLIB](https://lrclib.net) for their very generous free lyrics database
- [@Urenko](https://github.com/URenko/lrc2srt) for the original LRC2SRT script
- Contributors and reddit users who have provided feedback and suggestions

## Coming Soon
- Gemini API integration
- User-customizable tag library for prompts
- Interactive tag editing in YouTube tag generation
- Cool shit