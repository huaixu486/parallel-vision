# pasteimg skill for Claude Code

Paste a Windows clipboard screenshot into Claude Code even when the selected main model cannot accept image input.

The skill saves the clipboard image to a temp PNG, sends it to a configurable vision-capable Anthropic-compatible model, and returns an ASCII-safe text description to the current Claude Code conversation.

## Why

Some third-party Claude Code model routes accept text but reject image input. It can also be wasteful to send screenshots directly to an expensive reasoning model.

`pasteimg` lets you keep your main model unchanged, such as Opus, DeepSeek, Mimo Pro, or another coding model, while a separate cheaper vision-capable model handles screenshot understanding. The main model receives only the generated text description.

## Install

From this repository root:

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\install.ps1
```

Restart Claude Code after installing.

To overwrite an existing install:

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\install.ps1 -Force
```

## Configure the vision model

The vision model is independent from your current Claude Code model. Pick any model route that supports image input through an Anthropic-compatible `/v1/messages` API.

Override it with a config file:

```powershell
Copy-Item ".\pasteimg\config.example.json" "$env:USERPROFILE\.claude\skills\pasteimg\config.json"
notepad "$env:USERPROFILE\.claude\skills\pasteimg\config.json"
```

Example:

```json
{
  "visionModel": "your-low-cost-vision-model",
  "maxTokens": 2048,
  "baseUrl": "",
  "descriptionPrompt": ""
}
```

You can also use environment variables:

```powershell
$env:PASTEIMG_VISION_MODEL = "your-low-cost-vision-model"
$env:PASTEIMG_MAX_TOKENS = "2048"
```

Examples of valid choices depend on your provider. The model must support image input on your API route.

API settings are read from `~/.claude/settings.json` by default:

- `env.ANTHROPIC_BASE_URL`
- `env.ANTHROPIC_AUTH_TOKEN`

Portable installs may use:

- `PASTEIMG_ANTHROPIC_BASE_URL`
- `PASTEIMG_ANTHROPIC_AUTH_TOKEN`
- `ANTHROPIC_BASE_URL`
- `ANTHROPIC_AUTH_TOKEN`
- `ANTHROPIC_API_KEY`

Vision model resolution order:

1. `-VisionModel`
2. `PASTEIMG_VISION_MODEL`
3. `pasteimg/config.json` `visionModel`
4. `~/.claude/settings.json` `env.PASTEIMG_VISION_MODEL`
5. `~/.claude/settings.json` `env.ANTHROPIC_DEFAULT_HAIKU_MODEL`
6. `~/.claude/settings.json` `env.ANTHROPIC_MODEL`

## Usage

Copy a screenshot or image, then run in Claude Code:

```text
/pasteimg 读取这张图
```

The command returns:

```text
PASTEIMG_IMAGE_PATH: ...
PASTEIMG_VISION_MODEL: ...
PASTEIMG_DESCRIPTION_START
...
PASTEIMG_DESCRIPTION_END
```

The selected main model receives the text description and can continue the conversation without receiving image input directly.

## Test without clipboard

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\pasteimg\scripts\pasteimg.ps1" -Describe -ImagePath "C:\path\to\image.png"
```
