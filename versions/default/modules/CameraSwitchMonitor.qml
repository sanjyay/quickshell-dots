import QtQuick
import Quickshell.Io

Item {
    id: monitor

    // Lenovo LOQ camera privacy switch:
    //   MSC_SCAN 0x10d + KEY_UNKNOWN value 1 => camera disabled / blocked
    //   MSC_SCAN 0x10c + KEY_UNKNOWN value 1 => camera enabled / unblocked
    // KEY_UNKNOWN value 0 is only the release event and must be ignored.
    //
    // If opening the Ideapad input device fails with Permission denied, allow
    // access by adding the user to the input group or by creating a udev rule
    // for the "Ideapad extra buttons" input device.
    readonly property int cameraDisabledScanCode: 0x10d
    readonly property int cameraEnabledScanCode: 0x10c

    property string monitorVersion: "camera-monitor-v5-loaded"
    property bool opened: false
    property bool known: false
    property bool stateKnown: known
    property bool cameraEnabled: false
    property string devicePath: ""
    property string lastScanCode: ""
    property string lastScanCodeHex: ""
    property int rawEvents: 0
    property int keyEvents: 0
    property string lastEvent: ""
    property string error: ""
    property string lastError: error
    readonly property bool ready: opened

    Component.onCompleted: console.log("CameraSwitchMonitor loaded version=" + monitorVersion)

    function applyLine(line) {
        var t = String(line || "").trim()
        if (t.length === 0) return

        if (t.indexOf("STATE") === 0) {
            var parts = t.split("\t")
            for (var i = 1; i < parts.length; i++) {
                var kv = parts[i].split("=")
                if (kv.length < 2) continue
                var key = kv[0]
                var value = kv.slice(1).join("=")
                if (key === "device") devicePath = value
                else if (key === "opened") opened = value === "1"
                else if (key === "known") known = value === "1"
                else if (key === "enabled") cameraEnabled = value === "1"
                else if (key === "scan") lastScanCode = value
                else if (key === "scanHex") lastScanCodeHex = value
                else if (key === "rawEvents") rawEvents = parseInt(value) || 0
                else if (key === "keyEvents") keyEvents = parseInt(value) || 0
                else if (key === "lastEvent") lastEvent = value
                else if (key === "error") error = value
            }
        } else if (t.indexOf("WARN ") === 0) {
            console.warn("CameraSwitchMonitor: " + t.substring(5))
        } else if (t.indexOf("INFO ") === 0) {
            console.log("CameraSwitchMonitor: " + t.substring(5))
        } else if (t.indexOf("RAW ") === 0) {
            console.log("CameraSwitchMonitor: " + t)
        }
    }

    Process {
        id: eventReader
        running: true
        command: ["python3", "-u", "-c",
            "import errno, os, signal, struct, sys, time\n" +
            "TARGET_NAME = 'Ideapad extra buttons'\n" +
            "HARDCODED_FALLBACK = '/dev/input/event16'\n" +
            "EV_MSC = 0x04\n" +
            "EV_KEY = 0x01\n" +
            "MSC_SCAN = 0x04\n" +
            "KEY_UNKNOWN = 240\n" +
            "SCAN_CAMERA_DISABLED = 0x10d\n" +
            "SCAN_CAMERA_ENABLED = 0x10c\n" +
            "EVENT = struct.Struct('llHHi')\n" +
            "running = True\n" +
            "fd = None\n" +
            "device = ''\n" +
            "opened = False\n" +
            "known = False\n" +
            "enabled = False\n" +
            "last_scan = None\n" +
            "raw_events = 0\n" +
            "key_events = 0\n" +
            "last_event = ''\n" +
            "last_error = ''\n" +
            "def emit(s): print(s, flush=True)\n" +
            "def scan_text(): return '' if last_scan is None else ('0x%x' % last_scan)\n" +
            "def state():\n" +
            "    emit('STATE\\tdevice=%s\\topened=%d\\tknown=%d\\tenabled=%d\\tscan=%s\\tscanHex=%s\\trawEvents=%d\\tkeyEvents=%d\\tlastEvent=%s\\terror=%s' % (device, 1 if opened else 0, 1 if known else 0, 1 if enabled else 0, scan_text(), scan_text(), raw_events, key_events, last_event, last_error.replace('\\t', ' ')))\n" +
            "def close_fd():\n" +
            "    global fd, opened\n" +
            "    if fd is not None:\n" +
            "        try: os.close(fd)\n" +
            "        except OSError: pass\n" +
            "    fd = None\n" +
            "    opened = False\n" +
            "def stop(signum, frame):\n" +
            "    global running\n" +
            "    running = False\n" +
            "    close_fd()\n" +
            "signal.signal(signal.SIGTERM, stop)\n" +
            "signal.signal(signal.SIGINT, stop)\n" +
            "def name_matches(name):\n" +
            "    n = (name or '').lower()\n" +
            "    return n == 'ideapad extra buttons' or ('ideapad' in n and 'extra' in n)\n" +
            "def read_event_name(path):\n" +
            "    base = os.path.basename(os.path.realpath(path))\n" +
            "    try:\n" +
            "        return open('/sys/class/input/%s/device/name' % base, 'r', encoding='utf-8', errors='replace').read().strip()\n" +
            "    except OSError as e:\n" +
            "        emit('WARN cannot read name for %s (%s): %s' % (path, base, e))\n" +
            "        return ''\n" +
            "def proc_device():\n" +
            "    try:\n" +
            "        blocks = open('/proc/bus/input/devices', 'r', encoding='utf-8', errors='replace').read().split('\\n\\n')\n" +
            "    except OSError as e:\n" +
            "        emit('WARN cannot read /proc/bus/input/devices: %s' % e)\n" +
            "        return ''\n" +
            "    for block in blocks:\n" +
            "        block_l = block.lower()\n" +
            "        if 'ideapad extra buttons' not in block_l and not ('ideapad' in block_l and 'extra' in block_l):\n" +
            "            continue\n" +
            "        emit('INFO matched /proc/bus/input/devices block for Ideapad extra buttons')\n" +
            "        handlers = ''\n" +
            "        for line in block.splitlines():\n" +
            "            if line.startswith('H: Handlers='):\n" +
            "                handlers = line.split('=', 1)[1]\n" +
            "                break\n" +
            "        for h in handlers.split():\n" +
            "            if h.startswith('event'):\n" +
            "                return '/dev/input/' + h\n" +
            "        emit('WARN found %s but no event handler in: %s' % (TARGET_NAME, handlers))\n" +
            "    return ''\n" +
            "def scan_event_devices():\n" +
            "    try:\n" +
            "        entries = sorted(os.listdir('/dev/input'))\n" +
            "    except OSError as e:\n" +
            "        emit('WARN cannot list /dev/input: %s' % e)\n" +
            "        return ''\n" +
            "    for entry in entries:\n" +
            "        if not entry.startswith('event'):\n" +
            "            continue\n" +
            "        path = '/dev/input/' + entry\n" +
            "        name = read_event_name(path)\n" +
            "        emit('INFO scanned %s name=%s' % (path, name or '<unknown>'))\n" +
            "        if name_matches(name):\n" +
            "            return path\n" +
            "    return ''\n" +
            "def scan_by_path_links():\n" +
            "    root = '/dev/input/by-path'\n" +
            "    try:\n" +
            "        entries = sorted(os.listdir(root))\n" +
            "    except OSError as e:\n" +
            "        emit('WARN cannot list %s: %s' % (root, e))\n" +
            "        return ''\n" +
            "    for entry in entries:\n" +
            "        if 'event' not in entry:\n" +
            "            continue\n" +
            "        path = os.path.join(root, entry)\n" +
            "        target = os.path.realpath(path)\n" +
            "        name = read_event_name(path)\n" +
            "        emit('INFO by-path %s -> %s name=%s' % (path, target, name or '<unknown>'))\n" +
            "        if name_matches(name):\n" +
            "            return target\n" +
            "    return ''\n" +
            "def find_device():\n" +
            "    global last_error\n" +
            "    path = proc_device()\n" +
            "    if path:\n" +
            "        return path\n" +
            "    emit('WARN /proc discovery failed; scanning /dev/input/event*')\n" +
            "    path = scan_event_devices()\n" +
            "    if path:\n" +
            "        return path\n" +
            "    emit('WARN event scan failed; scanning /dev/input/by-path/*event*')\n" +
            "    path = scan_by_path_links()\n" +
            "    if path:\n" +
            "        return path\n" +
            "    last_error = 'device discovery failed'\n" +
            "    state()\n" +
            "    emit('WARN using hardcoded fallback /dev/input/event16')\n" +
            "    return HARDCODED_FALLBACK\n" +
            "emit('INFO initial camera switch state unknown; waiting for first scan')\n" +
            "emit('INFO reader pid=%d event struct size=%d format=llHHi' % (os.getpid(), EVENT.size))\n" +
            "emit('INFO scanning /proc/bus/input/devices for device name: %s' % TARGET_NAME)\n" +
            "state()\n" +
            "while running:\n" +
            "    if not device:\n" +
            "        device = find_device()\n" +
            "        if device:\n" +
            "            emit('INFO input device resolved: %s' % device)\n" +
            "        else:\n" +
            "            last_error = 'device discovery failed'\n" +
            "            emit('WARN %s' % last_error)\n" +
            "            state(); time.sleep(2); continue\n" +
            "    emit('INFO opening input device: %s' % device)\n" +
            "    try:\n" +
            "        fd = os.open(device, os.O_RDONLY)\n" +
            "        opened = True\n" +
            "        last_error = ''\n" +
            "        emit('INFO open succeeded: %s' % device)\n" +
            "        emit('INFO starting raw input_event reads from %s' % device)\n" +
            "        state()\n" +
            "    except OSError as e:\n" +
            "        opened = False\n" +
            "        if e.errno == errno.EACCES:\n" +
            "            last_error = 'permission denied: %s' % e\n" +
            "            emit('WARN permission denied opening %s: %s' % (device, e))\n" +
            "            emit('WARN fix permissions: add the user to the input group or create a udev rule for \"Ideapad extra buttons\"')\n" +
            "        else:\n" +
            "            last_error = '%s: %s' % (e.__class__.__name__, e)\n" +
            "            emit('WARN open failed for %s: %s' % (device, e))\n" +
            "        state(); time.sleep(2); continue\n" +
            "    try:\n" +
            "        while running:\n" +
            "            data = os.read(fd, EVENT.size)\n" +
            "            if len(data) != EVENT.size:\n" +
            "                raise OSError('short read: %d bytes' % len(data))\n" +
            "            sec, usec, etype, code, value = EVENT.unpack(data)\n" +
            "            raw_events += 1\n" +
            "            before_scan = scan_text()\n" +
            "            before_enabled = enabled\n" +
            "            before_known = known\n" +
            "            last_event = '%d/%d/%d' % (etype, code, value)\n" +
            "            if etype == EV_MSC and code == MSC_SCAN:\n" +
            "                last_scan = value\n" +
            "                emit('INFO parsed scan code: 0x%x' % last_scan)\n" +
            "                state()\n" +
            "            elif etype == EV_KEY and code == KEY_UNKNOWN:\n" +
            "                key_events += 1\n" +
            "                if value == 0:\n" +
            "                    emit('INFO ignoring KEY_UNKNOWN release for scan %s' % scan_text())\n" +
            "                    state()\n" +
            "                    emit('RAW type=%d code=%d value=%d lastScanCodeBefore=%s lastScanCodeAfter=%s cameraEnabledBefore=%s cameraEnabledAfter=%s stateKnownBefore=%s stateKnownAfter=%s rawEvents=%d keyEvents=%d' % (etype, code, value, before_scan, scan_text(), before_enabled, enabled, before_known, known, raw_events, key_events))\n" +
            "                    continue\n" +
            "                if value != 1:\n" +
            "                    emit('WARN ignoring KEY_UNKNOWN unexpected value %d for scan %s' % (value, scan_text()))\n" +
            "                    state()\n" +
            "                    emit('RAW type=%d code=%d value=%d lastScanCodeBefore=%s lastScanCodeAfter=%s cameraEnabledBefore=%s cameraEnabledAfter=%s stateKnownBefore=%s stateKnownAfter=%s rawEvents=%d keyEvents=%d' % (etype, code, value, before_scan, scan_text(), before_enabled, enabled, before_known, known, raw_events, key_events))\n" +
            "                    continue\n" +
            "                if last_scan == SCAN_CAMERA_DISABLED:\n" +
            "                    known = True; enabled = False\n" +
            "                    emit('INFO scan 0x10d -> cameraEnabled=false')\n" +
            "                    state()\n" +
            "                elif last_scan == SCAN_CAMERA_ENABLED:\n" +
            "                    known = True; enabled = True\n" +
            "                    emit('INFO scan 0x10c -> cameraEnabled=true')\n" +
            "                    state()\n" +
            "                else:\n" +
            "                    emit('WARN ignored KEY_UNKNOWN press with unhandled scan %s' % scan_text())\n" +
            "                    state()\n" +
            "            else:\n" +
            "                state()\n" +
            "            emit('RAW type=%d code=%d value=%d lastScanCodeBefore=%s lastScanCodeAfter=%s cameraEnabledBefore=%s cameraEnabledAfter=%s stateKnownBefore=%s stateKnownAfter=%s rawEvents=%d keyEvents=%d' % (etype, code, value, before_scan, scan_text(), before_enabled, enabled, before_known, known, raw_events, key_events))\n" +
            "    except OSError as e:\n" +
            "        if running:\n" +
            "            last_error = '%s: %s' % (e.__class__.__name__, e)\n" +
            "            emit('WARN read failed on %s: %s; reconnecting' % (device, e))\n" +
            "    finally:\n" +
            "        close_fd(); state()\n" +
            "        if running:\n" +
            "            device = ''\n" +
            "            time.sleep(1)\n"
        ]
        stdout: SplitParser {
            onRead: function(line) { monitor.applyLine(line) }
        }
        onExited: function(code) {
            monitor.opened = false
            if (code !== 0) console.warn("CameraSwitchMonitor exited with code " + code)
        }
    }
}
