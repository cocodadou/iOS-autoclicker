# AdvancedAutoClicker

AdvancedAutoClicker is an iOS tweak that provides a simple, visual autoclicker interface for sideloaded applications. Instead of entering screen coordinates manually, you can place and drag numbered click points directly on top of the app.

Each click point can have its own timing settings, and complete layouts can be saved as named presets for quick reuse.

## Features

- Draggable click points directly on screen
- Numbered points showing the execution order
- Per-point delay after each click
- Per-point hold duration
- Per-point repeat count
- Configurable initial delay before starting
- Finite or infinite loop mode
- Floating Start/Stop control
- Movable control panel
- Automatic configuration persistence
- Five named preset slots
- Save and restore complete point layouts
- Keyboard-safe editing with a Done button
- Automatic panel repositioning when the keyboard appears

## Presets

AdvancedAutoClicker includes five preset slots.

Each preset can be given a custom name and stores the complete autoclicker configuration, including:

- Click point positions
- Delay after each point
- Hold duration
- Repeat count
- Initial delay
- Loop count

Open **Settings → Presets**, enter a name for the preset, then press **Save**.

Press **Load** at any time to restore that layout.

## Controls

### Floating toolbar

The floating toolbar contains two buttons:

- **Settings** — opens the configuration panel
- **Play / Stop** — starts or stops the click sequence

The toolbar itself can be dragged around the screen.

### Adding click points

Open the settings panel and press **+ Add point**.

A numbered point appears on screen. Drag it directly to the location you want to tap.

Tap the point itself to edit its individual settings.

### Point settings

Each point supports:

- **Wait after tap** — time to wait before moving to the next point
- **Hold duration** — how long the simulated touch remains pressed
- **Repeat count** — how many times the point is tapped before continuing

This allows every point in a sequence to use a different delay.

For example:

```text
Point 1 → tap → wait 0.5 seconds
Point 2 → tap → wait 4 seconds
Point 3 → tap → wait 1.2 seconds
Point 4 → tap → wait 10 seconds
→ repeat
```

## Building

The project is designed to be built with Theos.

The included GitHub Actions workflow can compile the tweak automatically on a GitHub-hosted macOS runner, so a local Mac is not required.

To build with GitHub Actions:

1. Fork or upload the repository to GitHub.
2. Open the **Actions** tab.
3. Select the build workflow.
4. Run the workflow.
5. Wait for the build to finish.
6. Download the generated artifact.

The artifact contains the compiled tweak files.

## Dependencies

The project uses:

- Theos
- ZSFakeTouch
- UIKit
- Foundation
- CoreGraphics
- QuartzCore
- IOKit

ZSFakeTouch is downloaded automatically by the GitHub Actions workflow during compilation.

## Installation

The compiled `.dylib` is intended for environments capable of injecting tweaks into sideloaded iOS applications.

For LiveContainer, import the compiled dylib into the Tweaks section, sign it if required by your setup, and enable it for the desired application.

Compatibility can vary depending on the target application, iOS version, injection environment, and the way the application processes touch events.

## Configuration storage

The current configuration and named presets are stored using `NSUserDefaults`.

Configurations are stored per application bundle identifier, which prevents layouts from one application from automatically replacing layouts created for another application.

## Notes

AdvancedAutoClicker generates simulated touch events inside the target application. Some applications may use custom input systems or other mechanisms that do not respond to simulated touches in the same way as standard UIKit interfaces.

Use the tweak only where automation is permitted and in accordance with the rules and terms of the applications or services you use.

## Credits

AdvancedAutoClicker uses [ZSFakeTouch](https://github.com/DYY-Studio/ZSFakeTouch) for simulated touch event generation.

ZSFakeTouch is distributed under the MIT License. Copyright and license terms of the original project remain applicable to its source files.

This project was also inspired in part by [iOS-SimpleAutoClicker](https://github.com/DYY-Studio/iOS-SimpleAutoClicker), which demonstrated the use of ZSFakeTouch in an injected iOS tweak environment.

Thanks to the developers and contributors of Theos and the related open-source iOS tweak ecosystem.

## License

MIT License
