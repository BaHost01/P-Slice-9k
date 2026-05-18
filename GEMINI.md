# P-Slice Engine - Project Documentation

## Project Overview
P-Slice Engine is a specialized crossover between **Psych Engine** and newer versions of **Friday Night Funkin'** (commonly known as V-Slice). It aims to bring modern FNF features, visuals, and UI elements into the Psych Engine framework, providing a bridge for modders who want V-Slice aesthetics with Psych Engine's flexibility.

### Key Technologies
- **Language:** [Haxe](https://haxe.org/) (v4.3.6+)
- **Game Engine:** [HaxeFlixel](https://haxeflixel.com/)
- **Build System:** [Lime](https://lime.software/) / [OpenFL](https://www.openfl.org/)
- **Scripting:** [Lua](https://www.lua.org/) (via linc_luajit) and [HScript](https://github.com/HaxeFoundation/hscript) (via Iris)
- **Target Platforms:** Windows, Linux, MacOS, Android, iOS, and Web (HTML5)

---

## Building and Running

### Prerequisites
- **Git**
- **Haxe 4.3.6+**
- **C++ Compiler:**
  - **Windows:** Microsoft Visual Studio Community (with C++ components)
  - **Linux:** `g++` and VLC development libraries
  - **MacOS:** Xcode
- **Mobile SDKs:** Android NDK/SDK or Xcode (for iOS)

### Initial Setup
Before building for the first time, run the setup script for your platform located in the `setup/` directory:
- **Windows:** `setup/windows.bat`
- **Linux/Mac:** `setup/unix.sh`

### Common Commands
All build commands use `lime`. You can swap `test` with `build` to just compile without running.

| Action | Command |
| :--- | :--- |
| **Test Windows** | `lime test windows` |
| **Test Linux** | `lime test linux` |
| **Test Mac** | `lime test mac` |
| **Test Android** | `lime test android` |
| **Build HTML5** | `lime build html5` |
| **Final Release** | Add `-final` flag (e.g., `lime test windows -final`) |
| **Debug Build** | Add `-debug` flag |
| **Profiling** | Add `-DPROFILE_BUILD` (enables Tracy/Telemetry) |

---

## Architecture & Directory Structure

### Source Code (`source/`)
- **`backend/`**: Core engine components (Conductor, Paths, ClientPrefs, Highscore, etc.).
- **`objects/`**: Reusable game objects (Alphabet, Character, HealthIcon, Note, etc.).
- **`states/`**: Primary game states (PlayState, MainMenuState, FreeplayState, etc.).
- **`substates/`**: Overlays and menus (PauseSubState, GameOverSubState, etc.).
- **`mikolka/`**: P-Slice specific implementations, including V-Slice UI, custom macros, and system overrides.
- **`psychlua/`**: Integration logic for Lua scripting.
- **`mobile/`**: Backend and input systems specifically for mobile platforms.

### Configuration
- **`Project.xml`**: The central configuration file. Defines libraries, assets, window settings, and conditional defines (e.g., `MODS_ALLOWED`, `VIDEOS_ALLOWED`).
- **`source/import.hx`**: Global imports used across the project.
- **`source/Main.hx`**: Entry point of the application.

### Assets (`assets/`)
- **`shared/`**: Assets used across multiple levels or weeks.
- **`base_game/`**: Original FNF assets.
- **`mobile/`**: Assets specifically for mobile UI/controls.
- **`example_mods/`**: A template structure for creating mods without source modification.

---

## Development Conventions

### Scripting Support
Modders can extend the game using:
- **Lua**: Traditional Psych Engine style scripting (`.lua` files).
- **HScript (Iris)**: Advanced scripting with Haxe-like syntax (`.hx` files).

### Conditional Compilation
The codebase extensively uses `#if ... #end` blocks. Be mindful of:
- `mobile` vs `desktop` vs `web` targets.
- `LUA_ALLOWED` and `HSCRIPT_ALLOWED` defines.
- `debug` vs `release` builds.

### Asset Loading
Always use the `backend.Paths` class for loading assets to ensure compatibility with the modding system and different platforms.
Example: `Paths.image('myImage')` or `Paths.sound('mySound')`.

### UI Framework
While the game uses standard Flixel UI, many new menus (V-Slice style) are located in `mikolka.vslice.ui` and follow a more modern composition pattern.
