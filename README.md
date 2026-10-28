# HarborKit

The shared Swift package behind the **Harbor** apps ([Inlet](https://kaandis.github.io/inlet/), [Ferry](https://kaandis.github.io/ferry/) and the [Harbor](https://kaandis.github.io/harbor/) hub): one design language and one way to share settings.

| | |
|---|---|
| `Theme`, `Palette`, `Accent`, `HarborSurface` | Cream design tokens, Liquid Glass palette, highlight colours, the floating surface |
| `Keycap`, `PressableStyle`, `HarborButtonStyle`, `AccentPicker`, `TileGrid` | Small shared components |
| `PanelMotion` | Present and dismiss a panel with Core Animation springs, so content is drawn once |
| `AppLanguage` | In-app English / Turkish picker |
| `SettingsSchema` | The `settings-schema.json` every Harbor app ships, describing its preferences |
| `SettingsBridge`, `HarborLink` | How Harbor writes an app's settings and tells it, and how apps open Harbor |

## How settings travel

1. Each app keeps its preferences as plain `UserDefaults` keys and describes them in `Resources/settings-schema.json`.
2. Harbor reads that schema from the installed app, draws a settings screen, and writes changes straight into the app's own preferences domain.
3. Harbor then posts the distributed notification `app.harbor.settingsChanged` with the app's bundle identifier.
4. The app, having called `SettingsBridge.listen()` at launch, re-announces it as `UserDefaults.didChangeNotification`, so its existing observers and `@AppStorage` views update live.

## Use

```swift
.package(url: "https://github.com/Kaandis/harbor-kit", from: "0.1.0")
```

macOS 15 or later. MIT licensed.
