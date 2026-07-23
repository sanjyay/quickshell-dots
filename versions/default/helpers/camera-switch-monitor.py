#!/usr/bin/env python3
import errno
import os
import signal
import struct
import sys
import time

TARGET_NAME = "Ideapad extra buttons"
HARDCODED_FALLBACK = "/dev/input/event16"
EV_MSC = 0x04
EV_KEY = 0x01
MSC_SCAN = 0x04
KEY_UNKNOWN = 240
SCAN_CAMERA_DISABLED = 0x10D
SCAN_CAMERA_ENABLED = 0x10C
EVENT = struct.Struct("llHHi")


class Monitor:
    def __init__(self):
        self.running = True
        self.fd = None
        self.device = ""
        self.opened = False
        self.known = False
        self.enabled = False
        self.last_scan = None
        self.raw_events = 0
        self.key_events = 0
        self.last_event = ""
        self.last_error = ""

    @staticmethod
    def emit(message):
        print(message, flush=True)

    def scan_text(self):
        return "" if self.last_scan is None else f"0x{self.last_scan:x}"

    def state(self):
        error = self.last_error.replace("\t", " ")
        self.emit(
            "STATE\tdevice=%s\topened=%d\tknown=%d\tenabled=%d\tscan=%s"
            "\tscanHex=%s\trawEvents=%d\tkeyEvents=%d\tlastEvent=%s\terror=%s"
            % (self.device, self.opened, self.known, self.enabled, self.scan_text(),
               self.scan_text(), self.raw_events, self.key_events, self.last_event, error)
        )

    def close(self):
        if self.fd is not None:
            try:
                os.close(self.fd)
            except OSError:
                pass
        self.fd = None
        self.opened = False

    def stop(self, _signum, _frame):
        self.running = False
        self.close()

    @staticmethod
    def name_matches(name):
        name = (name or "").lower()
        return name == "ideapad extra buttons" or ("ideapad" in name and "extra" in name)

    def read_event_name(self, path):
        event = os.path.basename(os.path.realpath(path))
        try:
            with open(f"/sys/class/input/{event}/device/name", encoding="utf-8", errors="replace") as stream:
                return stream.read().strip()
        except OSError as exc:
            self.emit(f"WARN cannot read name for {path} ({event}): {exc}")
            return ""

    def proc_device(self):
        try:
            with open("/proc/bus/input/devices", encoding="utf-8", errors="replace") as stream:
                blocks = stream.read().split("\n\n")
        except OSError as exc:
            self.emit(f"WARN cannot read /proc/bus/input/devices: {exc}")
            return ""
        for block in blocks:
            lowered = block.lower()
            if "ideapad extra buttons" not in lowered and not ("ideapad" in lowered and "extra" in lowered):
                continue
            self.emit("INFO matched /proc/bus/input/devices block for Ideapad extra buttons")
            handlers = next((line.split("=", 1)[1] for line in block.splitlines()
                             if line.startswith("H: Handlers=")), "")
            event = next((item for item in handlers.split() if item.startswith("event")), "")
            if event:
                return "/dev/input/" + event
            self.emit(f"WARN found {TARGET_NAME} but no event handler in: {handlers}")
        return ""

    def scan_event_devices(self):
        try:
            entries = sorted(os.listdir("/dev/input"))
        except OSError as exc:
            self.emit(f"WARN cannot list /dev/input: {exc}")
            return ""
        for entry in entries:
            if entry.startswith("event"):
                path = "/dev/input/" + entry
                name = self.read_event_name(path)
                self.emit(f"INFO scanned {path} name={name or '<unknown>'}")
                if self.name_matches(name):
                    return path
        return ""

    def scan_by_path_links(self):
        root = "/dev/input/by-path"
        try:
            entries = sorted(os.listdir(root))
        except OSError as exc:
            self.emit(f"WARN cannot list {root}: {exc}")
            return ""
        for entry in entries:
            if "event" in entry:
                path = os.path.join(root, entry)
                target = os.path.realpath(path)
                name = self.read_event_name(path)
                self.emit(f"INFO by-path {path} -> {target} name={name or '<unknown>'}")
                if self.name_matches(name):
                    return target
        return ""

    def find_device(self):
        for label, finder in (("/proc discovery", self.proc_device),
                              ("event scan", self.scan_event_devices),
                              ("by-path scan", self.scan_by_path_links)):
            path = finder()
            if path:
                return path
            self.emit(f"WARN {label} failed")
        self.last_error = "device discovery failed"
        self.state()
        self.emit(f"WARN using hardcoded fallback {HARDCODED_FALLBACK}")
        return HARDCODED_FALLBACK

    def apply_event(self, event_type, code, value):
        before_scan = self.scan_text()
        before_enabled = self.enabled
        before_known = self.known
        self.raw_events += 1
        self.last_event = f"{event_type}/{code}/{value}"
        if event_type == EV_MSC and code == MSC_SCAN:
            self.last_scan = value
            self.emit(f"INFO parsed scan code: 0x{value:x}")
        elif event_type == EV_KEY and code == KEY_UNKNOWN:
            self.key_events += 1
            if value == 0:
                self.emit(f"INFO ignoring KEY_UNKNOWN release for scan {self.scan_text()}")
            elif value != 1:
                self.emit(f"WARN ignoring KEY_UNKNOWN unexpected value {value} for scan {self.scan_text()}")
            elif self.last_scan == SCAN_CAMERA_DISABLED:
                self.known, self.enabled = True, False
                self.emit("INFO scan 0x10d -> cameraEnabled=false")
            elif self.last_scan == SCAN_CAMERA_ENABLED:
                self.known, self.enabled = True, True
                self.emit("INFO scan 0x10c -> cameraEnabled=true")
            else:
                self.emit(f"WARN ignored KEY_UNKNOWN press with unhandled scan {self.scan_text()}")
        self.state()
        self.emit(
            "RAW type=%d code=%d value=%d lastScanCodeBefore=%s lastScanCodeAfter=%s "
            "cameraEnabledBefore=%s cameraEnabledAfter=%s stateKnownBefore=%s "
            "stateKnownAfter=%s rawEvents=%d keyEvents=%d"
            % (event_type, code, value, before_scan, self.scan_text(), before_enabled,
               self.enabled, before_known, self.known, self.raw_events, self.key_events)
        )

    def run(self):
        signal.signal(signal.SIGTERM, self.stop)
        signal.signal(signal.SIGINT, self.stop)
        self.emit("INFO initial camera switch state unknown; waiting for first scan")
        self.emit(f"INFO reader pid={os.getpid()} event struct size={EVENT.size} format=llHHi")
        self.state()
        while self.running:
            if not self.device:
                self.device = self.find_device()
            try:
                self.fd = os.open(self.device, os.O_RDONLY)
                self.opened, self.last_error = True, ""
                self.state()
                while self.running:
                    data = os.read(self.fd, EVENT.size)
                    if len(data) != EVENT.size:
                        raise OSError(f"short read: {len(data)} bytes")
                    _sec, _usec, event_type, code, value = EVENT.unpack(data)
                    self.apply_event(event_type, code, value)
            except OSError as exc:
                if self.running:
                    self.last_error = (f"permission denied: {exc}" if exc.errno == errno.EACCES
                                       else f"{exc.__class__.__name__}: {exc}")
                    self.emit(f"WARN open/read failed for {self.device}: {exc}")
                    if exc.errno == errno.EACCES:
                        self.emit(
                            'WARN fix permissions: add the user to the input group or create a udev rule '
                            'for "Ideapad extra buttons"'
                        )
                    self.state()
                    time.sleep(2 if not self.opened else 1)
            finally:
                self.close()
                self.state()
                if self.running:
                    self.device = ""


if __name__ == "__main__":
    Monitor().run()
