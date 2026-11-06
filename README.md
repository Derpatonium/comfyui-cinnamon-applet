# ComfyUI Cinnamon Applet

A Cinnamon panel applet for launching and managing a ComfyUI instance
running through Docker Compose.

**Status: Experimental.**

## AI-assisted development disclosure

This project was created through AI-assisted vibe coding, with ChatGPT
(OpenAI) as the primary coding assistant.

The project owner defined the requirements, directed the design,
tested the implementation, identified problems, and guided development
through an iterative process with ChatGPT.

Code was generated, modified, and debugged interactively with AI
assistance. This project is not presented as independently hand-written
software or as professionally engineered or audited software.

The project is shared openly and honestly, including its AI-assisted
development process. Users should review the code and test it in their
own environment before relying on it.

## Features

- Panel status indicator showing starting, running, or stopped.
- Left-click cycles through detected ComfyUI browser windows.
- Right-click menu provides window selection and launch actions.
- Starts the configured Docker Compose project.
- Opens ComfyUI in a dedicated browser app window.
- Opens and manages a dedicated Terminator window.
- Stops the ComfyUI service when the dedicated browser window has
  remained closed for 30 seconds.
- Provides an explicit Close ComfyUI action.

## Requirements

- Cinnamon desktop running an X11 session.
- Docker Engine with the Docker Compose plugin.
- Python 3.
- `wmctrl`, `xprop`, and `flock`.
- A browser supporting the `--app` command-line option.
- Terminator.

The applet has primarily been tested on Linux Mint 22.3 with
Cinnamon 6.6.9 under X11.

## Installation

1. Clone or download this repository.
2. Run `./install.sh`.
3. Edit the configuration file created at
   `~/.config/comfyui-cinnamon-applet/config`
   (or the corresponding XDG configuration directory).
4. Set `PROJECT_DIR` to the directory containing your ComfyUI
   Docker Compose file.
5. Adjust the URL, browser, window class, and terminal settings
   for your system.
6. Enable **ComfyUI Docker** in Cinnamon's Applets settings.
7. Reload Cinnamon.

The installer copies the applet and helper into your local Cinnamon
applets directory. It does not install Docker, ComfyUI, a browser,
or Terminator.

## Configuration

The example configuration is in `config/config.example`.

- `PROJECT_DIR`: Docker Compose project directory.
- `COMFYUI_URL`: URL used to access ComfyUI.
- `BROWSER`: Browser executable.
- `APP_WM_CLASS`: WM_CLASS used to identify the ComfyUI app window.
- `TERMINAL`: Terminal executable.
- `TERMINAL_WM_CLASS`: WM_CLASS used to identify terminal windows.
- `TERMINAL_ROLE`: Window role used to identify the dedicated terminal.
- `TERMINAL_LAYOUT`: Terminator layout to open.
- `TERMINAL_GEOMETRY`: Optional terminal geometry. Leave empty to
  let the window manager position the window.

Machine-specific configuration is stored outside this repository.

## Development

- `applet/` contains the Cinnamon applet and its icon.
- `scripts/` contains the helper script.
- `config/` contains an example configuration.
- `install.sh` installs the applet for the current user.

## Limitations

- Window detection relies on X11 window information and WM_CLASS values.
- Individual browser tabs cannot be enumerated; detection is based on
  browser windows.
- The automatic shutdown watcher monitors the specific browser window
  opened or selected during startup.
- Compatibility with Wayland, other distributions, and other Cinnamon
  versions has not been established.

## Contributions

Bug reports, suggestions, testing, and improvements are welcome.
This is an experimental AI-assisted project.
