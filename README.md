# Parallel Vision / 并行视觉

A Claude Code skill for routing screenshot understanding through a separate vision-capable model while keeping the current main model unchanged.

The skill saves a Windows clipboard image to a temp file, sends it to a configurable vision-capable Anthropic-compatible model, and returns an ASCII-safe text description to the current Claude Code conversation.

## Why

Some third-party Claude Code model routes accept text but reject image input. It can also be wasteful to send screenshots directly to an expensive reasoning model.

Parallel Vision lets you keep your main model unchanged, such as Opus, DeepSeek, Mimo Pro, or another coding model, while a separate cheaper vision-capable model handles screenshot understanding. The main model receives only the generated text description.

The project name is `parallel-vision`. The installed Claude Code skill is still named `pasteimg`, and the slash command is still `/pasteimg`.

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

## Configure The Vision Model

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
/pasteimg describe this screenshot
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

## Test Without Clipboard

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\pasteimg\scripts\pasteimg.ps1" -Describe -ImagePath "C:\path\to\image.png"
```
