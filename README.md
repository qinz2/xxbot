# xxBot - Desktop Pet & QQ Bot Integration

![Status](https://img.shields.io/badge/status-in%20development-yellow)
![License](https://img.shields.io/badge/license-GPL--3.0-blue)

## 🎉 Introduction

xxBot is an innovative integration project that combines an intelligent QQ bot with a desktop pet companion, providing users with a unique interactive experience.

### Core Features

- 🤖 **Intelligent QQ Bot**: LLM-powered conversational AI based on MaiBot
- 🎮 **Desktop Pet**: Adorable desktop companion built with Godot Engine
- 🔗 **Real-time Communication**: WebSocket-based real-time interaction between bot and pet
- 💬 **Multi-modal Messages**: Support for text, images, and mixed content
- 🎨 **Transparent Window**: Desktop pet with transparent background that blends into your desktop

## 📦 Project Structure

```
xxbot-main/
├── MaiBot/                    # QQ Bot Core
│   ├── bot.py                 # Bot main program
│   ├── plugins/               # Plugin system
│   └── src/                   # Source code
├── godotxx/                   # Godot Desktop Pet
│   ├── scene/                 # Scene files
│   ├── assest/                # Asset files
│   └── xx_client.gd           # WebSocket client
└── MaiBot-Napcat-Adapter/     # NapCat Adapter
```

## 🚀 Quick Start

### Requirements

- Python 3.10+
- Godot 4.5+
- NapCat QQ Protocol

### Installation

1. **Clone the repository**
```bash
git clone https://github.com/your-repo/xxbot-main.git
cd xxbot-main
```

2. **Configure MaiBot**
```bash
cd MaiBot
pip install -r requirements.txt
cp template/template.env .env
# Edit .env file to configure necessary parameters
```

3. **Start MaiBot**
```bash
python bot.py
```

4. **Launch Godot Desktop Pet**
- Open `godotxx/project.godot` with Godot Editor
- Click the run button to start the desktop pet

## 🔧 Configuration

### MaiBot Configuration

Configure the following parameters in `MaiBot/.env`:

- LLM API configuration
- QQ bot connection settings
- Plugin system configuration

For detailed configuration, refer to [MaiBot Documentation](https://docs.mai-mai.org)

### Godot Desktop Pet Configuration

The desktop pet connects to MaiBot via WebSocket:

- Default port: 8765
- Connection address: ws://127.0.0.1:8765/ws

## 💡 Usage

### Basic Interaction

1. After starting MaiBot, the bot will respond to messages in QQ groups
2. After launching the desktop pet, it will automatically connect to MaiBot
3. Chat with the bot in QQ groups, and the desktop pet will display messages in sync
4. Click the desktop pet to send messages to QQ groups

### Supported Message Types

- 📝 Text messages
- 🖼️ Image messages
- 📋 Mixed text and image messages

## 🎨 Features

### MaiBot Core Features

- 💭 Intelligent Dialogue System: LLM-based natural language interaction
- 🤔 Real-time Thinking System: Simulates human thought processes
- 🧠 Expression Learning: Learns speaking styles from group members
- 💝 Emotional Expression System: Emotion system with emoji support
- 🔌 Powerful Plugin System: Provides API and event system

### Godot Desktop Pet Features

- 🪟 Transparent Window: Borderless transparent window design
- 🎯 Always on Top: Always displayed in the foreground
- 🖱️ Interactive Operations: Support for clicking and dragging
- 📡 Real-time Communication: WebSocket real-time message push
- 🖼️ Image Support: Send and receive image messages

## 📚 Technical Architecture

### Communication Protocol

The project uses WebSocket protocol for real-time bidirectional communication:

```
Godot Desktop Pet (WebSocket Server)
         ↕
    WebSocket Connection
         ↕
MaiBot (WebSocket Client)
         ↕
    NapCat Adapter
         ↕
      QQ Groups
```

### Message Format

Standard message structure:

```json
{
  "message_info": {
    "platform": "godot",
    "message_id": "unique_id",
    "time": 1234567890,
    "user_info": {
      "user_id": "player_001",
      "user_nickname": "Player_001"
    },
    "format_info": {
      "content_format": ["text"],
      "accept_format": ["text", "image"]
    }
  },
  "message_segment": {
    "type": "text",
    "data": "Message content"
  }
}
```

## 🤝 Contributing

Issues and Pull Requests are welcome!

1. Fork this repository
2. Create a feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Submit a Pull Request

## 📄 License

This project is licensed under the GPL-3.0 License.

## 🙏 Acknowledgments

- [MaiBot](https://github.com/MaiM-with-u/MaiBot) - Intelligent QQ bot core
- [NapCat](https://github.com/NapNeko/NapCatQQ) - Modern NTQQ bot protocol implementation
- [Godot Engine](https://godotengine.org/) - Open-source game engine

## ⚠️ Disclaimer

> This project is an adaptation based on [MaiBot](https://github.com/MaiM-with-u/MaiBot). Please read and agree to the relevant user agreements and privacy policies before using this project.
> 
> QQ bots may face restrictions. Please understand the risks and use with caution.
> 
> Content generated by this application comes from AI models. Please carefully verify the content and do not use it for illegal purposes.

---

**Making AI companionship more heartwarming ❤️**
