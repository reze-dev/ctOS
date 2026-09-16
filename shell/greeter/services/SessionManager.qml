pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.greeter.config
import qs.greeter.data

Singleton {
    id: sessionManager

    property list<User> users: []
    property list<Desktop> desktops: []

    property User activeUser: sessionManager.findUser(Settings.defaultUsername) || _firstUser
    property var _firstUser: null

    property Desktop activeDesktop: sessionManager.findDesktop(Settings.defaultDesktopName) || _firstDesktop
    property var _firstDesktop: null

    Component {
        id: userFactory
        User {}
    }

    Component {
        id: desktopFactory
        Desktop {}
    }

    function findUser(value) {
        if (value === undefined || value === null) {
            return null;
        }

        const searchValue = value.toString().trim();
        if (!searchValue.length) {
            return null;
        }

        const numericValue = parseInt(searchValue);

        if (isNaN(numericValue)) {
            const usernameSearch = searchValue.toLowerCase();
            return users.find(user => user.username.toLowerCase().includes(usernameSearch)) ?? null;
        }

        const uidMatch = users.find(user => user.uid === numericValue);
        if (uidMatch) {
            return uidMatch;
        }

        return users[numericValue - 1] ?? null;
    }

    function findDesktop(value) {
        if (value === undefined || value === null) {
            return null;
        }

        const searchValue = value.toString().trim();

        if (!searchValue.length) {
            return null;
        }

        const oneBasedIdx = parseInt(searchValue);

        if (isNaN(oneBasedIdx)) {
            const desktopSearch = searchValue.toLowerCase();
            return desktops.find(desktop => desktop.name.toLowerCase().includes(desktopSearch)) ?? null;
        }

        return desktops[oneBasedIdx - 1] ?? null;
    }

    function setUser(value, saveDefault = false) {
        const found = findUser(value);

        if (!found) {
            return false;
        }

        activeUser = found;

        if (saveDefault) {
            Settings.defaultUsername = found.username;
        }

        return true;
    }

    function setDesktop(value, saveDefault = false) {
        const found = findDesktop(value);

        if (!found) {
            return false;
        }

        activeDesktop = found;

        if (saveDefault) {
            Settings.defaultDesktopName = found.name;
        }

        return true;
    }

    function cycleDesktop(saveDefault = false) {
        if (!desktops || desktops.length <= 1) {
            return;
        }
        let currentIndex = -1;
        for (let i = 0; i < desktops.length; i++) {
            if (desktops[i] === activeDesktop || desktops[i].name === activeDesktop?.name) {
                currentIndex = i;
                break;
            }
        }
        const nextIndex = (currentIndex + 1) % desktops.length;
        setDesktop(desktops[nextIndex].name, saveDefault);
    }

    function getExitCommand() {
        if (Settings.exitCommand && Settings.exitCommand.length) {
            return Settings.exitCommand;
        }

        const currentDesktop = (Quickshell.env("XDG_CURRENT_DESKTOP") || "").toLowerCase();

        if (currentDesktop.includes("hyprland")) {
            return ["hyprctl", "dispatch", "exit"];
        }

        if (currentDesktop.includes("niri")) {
            return ["niri", "msg", "action", "quit"];
        }

        return [];
    }

    function parseExec(execStr) {
        if (!execStr || typeof execStr !== "string") {
            return [];
        }

        const tokens = [];
        let current = "";
        let inDoubleQuote = false;
        let inSingleQuote = false;
        let escaped = false;

        for (let i = 0; i < execStr.length; i++) {
            const char = execStr[i];

            if (escaped) {
                current += char;
                escaped = false;
                continue;
            }

            if (char === "\\") {
                escaped = true;
                continue;
            }

            if (char === '"' && !inSingleQuote) {
                inDoubleQuote = !inDoubleQuote;
                continue;
            }

            if (char === "'" && !inDoubleQuote) {
                inSingleQuote = !inSingleQuote;
                continue;
            }

            if (/\s/.test(char) && !inDoubleQuote && !inSingleQuote) {
                if (current.length > 0) {
                    tokens.push(current);
                    current = "";
                }
                continue;
            }

            current += char;
        }

        if (current.length > 0) {
            tokens.push(current);
        }

        const result = [];
        for (const token of tokens) {
            if (/^%[a-zA-Z]$/.test(token)) {
                continue;
            }

            let processed = token.replace(/%[a-zA-Z]/g, "");
            processed = processed.replace(/%%/g, "%");

            if (processed.length > 0) {
                result.push(processed);
            }
        }

        return result;
    }

    function getLaunchCommand() {
        if (!activeDesktop || !activeDesktop.exec) {
            return [];
        }
        return parseExec(activeDesktop.exec);
    }

    Process {
        id: usersProcess
        command: ["sh", "-c", "cat /etc/passwd"]
        running: true
        stdout: SplitParser {
            onRead: data => {
                const parts = data.trim().split(":");

                if (parts.length < 7) {
                    return;
                }

                const [user, , uidStr, , , home, shell] = parts;

                const uid = parseInt(uidStr);

                const isStandard = uid >= 1000 && uid < 60000;
                const isRealUser = !shell.match(/nologin|false|sync/);
                const isNotNobody = user !== "nobody";

                if (!isStandard || !isRealUser || !isNotNobody) {
                    return;
                }

                const userObj = userFactory.createObject(sessionManager, {
                    "username": user,
                    "homeDir": home,
                    "shell": shell,
                    "uid": uid
                });

                sessionManager.users.push(userObj);
                sessionManager.usersChanged();

                if (!sessionManager._firstUser) {
                    sessionManager._firstUser = userObj;
                }
            }
        }
    }

    Process {
        id: desktopsProcess
        property var _currentEntry: ({})
        property bool _inDesktopEntry: false

        command: [
            "sh", "-c",
            "search_dirs=\"${XDG_DATA_DIRS:-/usr/local/share:/usr/share}:/run/current-system/sw/share:/usr/share:/usr/local/share\"; " +
            "old_ifs=\"$IFS\"; IFS=\":\"; seen=\"\"; " +
            "for d in $search_dirs; do " +
            "  [ -d \"$d/wayland-sessions\" ] || continue; " +
            "  for f in \"$d/wayland-sessions\"/*.desktop; do " +
            "    [ -f \"$f\" ] || continue; " +
            "    b=\"${f##*/}\"; " +
            "    case \" $seen \" in *\" $b \"*) continue ;; esac; " +
            "    seen=\"$seen $b\"; " +
            "    cat \"$f\"; " +
            "    echo \"\"; " +
            "  done; " +
            "done; " +
            "IFS=\"$old_ifs\""
        ]
        running: true

        stdout: SplitParser {
            onRead: data => {
                const line = data.trim();
                if (!line || line.startsWith("#")) {
                    return;
                }

                if (line === "[Desktop Entry]") {
                    desktopsProcess.commit();
                    desktopsProcess._inDesktopEntry = true;
                    return;
                }

                if (line.startsWith("[") && line.endsWith("]")) {
                    desktopsProcess._inDesktopEntry = false;
                    return;
                }

                if (!desktopsProcess._inDesktopEntry) {
                    return;
                }

                const splitIdx = line.indexOf("=");
                if (splitIdx === -1) {
                    return;
                }

                const key = line.slice(0, splitIdx).trim();
                const value = line.slice(splitIdx + 1).trim();

                switch (key) {
                case "Name":
                    desktopsProcess._currentEntry.name = value;
                    break;
                case "Comment":
                    desktopsProcess._currentEntry.comment = value;
                    break;
                case "Exec":
                    desktopsProcess._currentEntry.exec = value;
                    break;
                case "Type":
                    desktopsProcess._currentEntry.type = value;
                    break;
                case "DesktopNames":
                    desktopsProcess._currentEntry.desktopNames = value;
                    break;
                }
            }
        }

        onExited: {
            desktopsProcess.commit();

            const xdg = Quickshell.env("XDG_CURRENT_DESKTOP") || "";
            const env = xdg.toLowerCase();

            const detectedDesktop = sessionManager.desktops.find(d => {
                return env && (d.name.toLowerCase().includes(env) || (d.desktopNames && d.desktopNames.toLowerCase().includes(env)));
            });

            sessionManager._firstDesktop = detectedDesktop || (sessionManager.desktops.length > 0 ? sessionManager.desktops[0] : null);

            if (!sessionManager.activeDesktop && sessionManager._firstDesktop) {
                sessionManager.activeDesktop = sessionManager.findDesktop(Settings.defaultDesktopName) || sessionManager._firstDesktop;
            }
        }

        function commit() {
            const entry = desktopsProcess._currentEntry;

            if (entry.name && entry.exec) {
                const isUwsm = entry.exec.toLowerCase().includes("uwsm") || entry.name.toLowerCase().includes("uwsm");
                const isDuplicate = sessionManager.desktops.some(d => d.name.toLowerCase() === entry.name.toLowerCase());

                if (!isUwsm && !isDuplicate) {
                    const desktopObj = desktopFactory.createObject(sessionManager, entry);
                    sessionManager.desktops.push(desktopObj);
                    sessionManager.desktopsChanged();
                }
            }

            desktopsProcess._currentEntry = {};
            desktopsProcess._inDesktopEntry = false;
        }
    }
}
