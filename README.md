# ComfyUI Cinnamon Applet

A Cinnamon panel applet for launching a Docker Compose ComfyUI instance
and managing its browser windows.

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

- Left-click cycles through detected ComfyUI windows.
- Starts the Docker Compose service if it is not already running.
- Opens a dedicated browser app window when necessary.
- Opens a configured Terminator layout on cold start.
- Right-click lists detected ComfyUI windows and provides launch actions.

## Requirements

- Linux Mint or another Cinnamon desktop.
- X11 session.
- Docker Engine with Docker Compose.
- Python 3.
- `wmctrl` and `xprop`.
- A Chromium-based browser supporting the configured app-window options.
- Terminator for the optional terminal layout.

## Installation

1. Clone or download this repository.
2. Run `./install.sh`.
3. Edit the configuration file created at
   `~/.config/comfyui-cinnamon-applet/config`
   (or the corresponding XDG configuration directory).
4. Enable the applet in Cinnamon's Applets settings.
5. Reload Cinnamon.

## Configuration

The configuration file controls the Docker Compose project directory,
ComfyUI URL, browser command and window classes, and terminal layout.

`TERMINAL_GEOMETRY` can be left empty to let the window manager position
the terminal automatically.

## Development

- `applet/` contains the Cinnamon applet.
- `scripts/` contains the helper script.
- `config/` contains an example configuration.

Machine-specific configuration is stored outside this repository.

## Limitations

- Window detection uses X11 window titles and WM_CLASS values.
- Individual browser tabs cannot be enumerated; detection is based on
  browser-window titles.
- Testing has primarily been performed on Linux Mint 22.3 with
  Cinnamon 6.6.9 under X11.
- Compatibility with other distributions and Cinnamon versions has
  not yet been established.

## Contributions

Bug reports, suggestions, testing, and improvements are welcome.
This is an experimental AI-assisted project.
