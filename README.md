# TextRewriter

A macOS menu bar app that rewrites selected text using AI (Claude API).

## Features

- Select any text in any app → floating "Help me rewrite" button appears
- AI rewrites the text with grammar, spelling, and phrasing fixes
- Tone options: Professional, Casual, Enthusiastic, Informational, Funny
- **Replace** — replaces the original selected text in-place
- **Copy** — copies the rewritten text to clipboard
- **Regenerate** — generates a new variation
- Runs as a background app (menu bar only, no Dock icon)

## Installation

### Download (recommended)

1. Go to [Releases](../../releases) and download the latest `TextRewriter-x.x.x.zip`
2. Unzip and move `TextRewriter.app` to your `/Applications` folder

### First launch (bypass Gatekeeper)

Because the app is not notarized by Apple, macOS will block it on the first open:

1. **Right-click** `TextRewriter.app` → **Open**
2. Click **Open** in the dialog that appears
3. The app will launch and show a sparkles icon (✦) in your menu bar

> After the first launch you can open it normally by double-clicking.

### Grant Accessibility permission

TextRewriter needs Accessibility access to detect selected text across apps:

1. Open **System Settings → Privacy & Security → Accessibility**
2. Enable **TextRewriter**

### Configure your API key

1. Click the ✦ icon in the menu bar → **Settings**
2. Enter your **Claude API key** (get one at [console.anthropic.com](https://console.anthropic.com))
3. Choose your preferred model

## Usage

1. Select any text in any app (browser, email, Slack, Notes, etc.)
2. A **"Help me rewrite"** button appears near your cursor — click it
3. Wait a moment for the AI to generate a suggestion
4. Choose an action:
   - **Replace** — overwrites your original selection with the rewritten text
   - **Copy** — copies the result to your clipboard
   - **Regenerate** — generates a new variation
   - Tone pills (Professional / Casual / etc.) — rewrite with a specific tone

## Requirements

- macOS 13 Ventura or later
- Apple Silicon or Intel Mac
- Claude API key

## Build from source

```bash
git clone <this-repo>
cd TextRewriter
bash build.sh
open dist/TextRewriter.app
```

To create a distributable ZIP:

```bash
bash release.sh 1.0.0   # produces dist/TextRewriter-1.0.0.zip
```

## Project Structure

```
Sources/TextRewriter/
├── main.swift                    # App entry point
├── AppDelegate.swift             # Menu bar setup, monitor wiring
├── SelectionMonitor.swift        # AX-based text selection detection
├── FloatingButtonPanel.swift     # "Help me rewrite" popup button
├── ResultPanel.swift             # AI result panel (Replace / Copy / Rewrite)
├── AIService.swift               # Claude API integration
└── SettingsWindowController.swift
Assets/
├── AppIcon.icns                  # App icon
└── TextRewriter.entitlements     # Code signing entitlements
build.sh                          # Build → dist/TextRewriter.app
release.sh                        # Build + sign + zip for distribution
```
