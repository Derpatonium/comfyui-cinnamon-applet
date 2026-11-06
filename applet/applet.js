const Applet = imports.ui.applet;
const PopupMenu = imports.ui.popupMenu;
const St = imports.gi.St;
const GLib = imports.gi.GLib;
const ByteArray = imports.byteArray;

class ComfyUIApplet extends Applet.IconApplet {
    constructor(metadata, orientation, panel_height, instance_id) {
        super(orientation, panel_height, instance_id);

        this._appletPath = GLib.get_home_dir() +
            "/.local/share/cinnamon/applets/" + metadata.uuid;

        this.set_applet_icon_path(
            this._appletPath + "/comfyui-docker-icon.png"
        );

        this.set_applet_tooltip("ComfyUI Docker");

        this._helperPath = this._appletPath +
            "/scripts/comfyui-applet.sh";

        // Persistent status dot beside the applet icon.
        this._statusIndicator = new St.Label({
            text: "●",
            style: "color: #808080; font-size: 12px; padding-left: 2px;"
        });
        this.actor.add(this._statusIndicator);

        this._updateStatus();
        this._statusTimer = GLib.timeout_add_seconds(
            GLib.PRIORITY_DEFAULT,
            2,
            () => {
                this._updateStatus();
                return true;
            }
        );

        this._applet_context_menu.connect(
            "open-state-changed",
            (menu, isOpen) => {
                if (isOpen)
                    this._rebuildContextMenu();
            }
        );
    }

    _updateStatus() {
        try {
            let [success, stdout, stderr] =
                GLib.spawn_command_line_sync(
                    "bash " + this._helperPath + " status"
                );

            let status = success ? ByteArray.toString(stdout).trim() : "stopped";
            let colors = {
                starting: "#2ecc71",
                running: "#f2c94c",
                stopped: "#808080"
            };
            let labels = {
                starting: "Starting",
                running: "Running",
                stopped: "Stopped"
            };

            if (!colors[status])
                status = "stopped";

            this._statusIndicator.set_style(
                "color: " + colors[status] +
                "; font-size: 12px; padding-left: 2px;"
            );
            this.set_applet_tooltip("ComfyUI Docker — " + labels[status]);
        } catch (e) {
            global.logError(e);
        }
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

            return output.split("\n").filter(line => line.includes("|")).map(line => {
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
            let title = window.title || "ComfyUI window";

            menu.addAction(
                title,
                () => this._runHelper("focus-window", window.id)
            );
        }

        if (windows.length > 0)
            menu.addMenuItem(new PopupMenu.PopupSeparatorMenuItem());

        menu.addAction(
            "Open ComfyUI",
            () => this._runHelper("open-comfyui")
        );

        menu.addAction(
            "Open Terminator",
            () => this._runHelper("open-terminator")
        );

        menu.addAction(
            "Close ComfyUI",
            () => this._runHelper("close-comfyui")
        );
    }

    on_applet_clicked() {
        this._runHelper("click");
    }
}

function main(metadata, orientation, panel_height, instance_id) {
    return new ComfyUIApplet(metadata, orientation, panel_height, instance_id);
}
