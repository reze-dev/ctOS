pragma Singleton

import Quickshell
import Quickshell.Services.Greetd
import QtQuick

import qs.greeter.config
import qs.greeter.services
import qs.greeter.common

Singleton {
    id: handler

    signal ready
    signal success
    signal failed

    Logger {
        id: logger
        name: "Greetd"
    }

    Connections {
        id: connection
        target: Greetd

        function onAuthMessage(message) {
            // requesting password
            logger.info("Credentials requested.");
            handler.ready();
        }

        function onAuthFailure(message) {
            // password is wrong
            logger.info("Authentication failed.");
            handler.failed();
        }

        function onReadyToLaunch() {
            // password is correct
            logger.info("Authentication success.");
            handler.success();
        }
    }

    Connections {
        target: SessionManager

        function onActiveUserChanged() {
            if (Greetd.state === GreetdState.Authenticating) {
                logger.info(`User changed, cancelling active session.`);
                Greetd.cancelSession();
            }

            handler.start();
        }
    }

    function start() {
        sessionStarter.start();
    }

    Timer {
        id: sessionStarter
        interval: 200
        repeat: true
        onTriggered: {
            // make sure socket ready for new session
            // authenticating(1) -> inactive (0)
            if (Greetd.state !== GreetdState.Inactive) {
                return;
            }

            logger.info(`Created session (user:${SessionManager.activeUser.uid}:${SessionManager.activeUser.username})`);
            Greetd.createSession(SessionManager.activeUser.username);

            sessionStarter.stop();
        }
    }

    function respond(password) {
        if (Greetd.available) {
            Greetd.respond(password);
        } else {
            logger.debug("Failed to respond, Not available.");
        }
    }

    function finish() {
        const sessionCmd = SessionManager.getLaunchCommand();
        const launchCommand = sessionCmd && sessionCmd.length
            ? sessionCmd
            : (Settings.launchCommand?.length ? Settings.launchCommand : Env.getArray("LAUNCH_COMMAND"));
        const exitCommand = SessionManager.getExitCommand();

        logger.info(`Launching: ${launchCommand.join(" ")}`);
        logger.info(`Exiting Greeter: ${exitCommand.join(" ") || "<none>"}`);

        if (!launchCommand.length) {
            logger.critical("No desktop launch command is configured.");
            return;
        }

        // Only when there is a session to hand over from. A greeter sitting at a
        // login prompt has no running desktop, and getExitCommand() is empty.
        if (exitCommand.length) {
            // Quit the outgoing session *before* starting the next one, and wait
            // for it to let go of the DRM devices.
            //
            // The order used to be launch-then-quit, which loses a race the
            // newcomer cannot win: a compositor cannot open a GBM allocator
            // while another compositor still holds /dev/dri/card*, so it aborts
            // with "Cannot open backend: no allocator available" -- which is
            // exactly how switching into Hyprland failed.
            logger.info("Handing over from a running session; quitting it first.");
            Quickshell.execDetached(exitCommand);
            handover.launchCommand = launchCommand;
            handover.restart();
            return;
        }

        Greetd.launch(launchCommand);
    }

    // Polls until nothing holds the DRM card nodes, then launches. Bounded
    // because a session that never lets go must not strand the greeter with no
    // way to start anything.
    Process {
        id: drmProbe
        running: false
        command: ["sh", "-c", "ls -l /proc/*/fd 2>/dev/null | grep -l card >/dev/null 2>&1; echo $?"]
    }

    Timer {
        id: handover
        interval: 400
        repeat: true
        running: false

        property var launchCommand: []
        property int attempts: 0

        onTriggered: {
            handover.attempts += 1;
            drmProbe.running = true;

            // If the probe has not produced output the devices look free; give
            // up after ~10s and launch anyway rather than loop forever.
            if (handover.attempts >= 25) {
                handover.stop();
                drmProbe.running = false;
                logger.warn("DRM still held after waiting; launching anyway.");
                Greetd.launch(handover.launchCommand);
                return;
            }
        }
    }

    Connections {
        target: drmProbe
        function onExited(exitCode: int): void {
            drmProbe.running = false;
            if (handover.running && exitCode !== 0) {
                handover.stop();
                logger.info("DRM released; launching.");
                Greetd.launch(handover.launchCommand);
            }
        }
    }
}
