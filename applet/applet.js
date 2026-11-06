const Applet = imports.ui.applet;
const PopupMenu = imports.ui.popupMenu;
const GLib = imports.gi.GLib;
const ByteArray = imports.byteArray;

class ComfyUIApplet extends Applet.IconApplet {
    constructor(metadata, orientation, panel_height, instance_id) {
        super(orientation, panel_height, instance_id);

        this._appletPath =
            GLib.get_home_dir() +
            "/.local/share/cinnamon/applets/" + metadata.uuid;

        this.set_applet_icon_path(
            this._appletPath + "/comfyui-docker-icon.png"
        );

        this.set_applet_tooltip("ComfyUI Docker");

        // Preserve Cinnamon's native icon sizing.
        this.actor.set_style(
            "box-shadow: inset 0 -2px 0 #f2c94c;"
        );

        this._helperPath = this._appletPath +
            "/scripts/comfyui-applet.sh";

        this._applet_context_menu.connect(
            "open-state-changed",
            (menu, isOpen) => {
                if (isOpen)
                    this._rebuildContextMenu();
            }
        );
    }

    _runHelper(action, argument = "") {
        try {
            let command = "bash " + this._helperPath + " " + action;
            if (argument)
                command += " " + argument;

            GLib.spawn_command_line_async(command);
        } catch (e) {
            global.logError(e);
        }
    }

    _getWindows() {
        try {
            let [success, stdout, stderr] =
                GLib.spawn_command_line_sync(
                    "bash " + this._helperPath + " list-windows"
                );

            if (!success)
                return [];

            let output = ByteArray.toString(stdout);

            return output.split("\n")
                .filter(line => line.includes("|"))
                .map(line => {
                    let separator = line.indexOf("|");
                    return {
                        id: line.substring(0, separator),
                        title: line.substring(separator + 1).trim()
                    };
                });
        } catch (e) {
            global.logError(e);
            return [];
        }
    }

    _rebuildContextMenu() {
        let menu = this._applet_context_menu;
        menu.removeAll();

        let windows = this._getWindows();

        for (let window of windows) {
            menu.addAction(
                window.title || "ComfyUI window",
                () => this._runHelper("focus-window", window.id)
            );
        }

        if (windows.length > 0)
            menu.addMenuItem(
                new PopupMenu.PopupSeparatorMenuItem()
            );

        menu.addAction(
            "Open ComfyUI",
            () => this._runHelper("open-comfyui")
        );

        menu.addAction(
            "Open Terminator",
            () => this._runHelper("open-terminator")
        );
    }

    on_applet_clicked() {
        this._runHelper("click");
    }
}

function main(metadata, orientation, panel_height, instance_id) {
    return new ComfyUIApplet(
        metadata, orientation, panel_height, instance_id
    );
}
