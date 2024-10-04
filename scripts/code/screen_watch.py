from time import sleep
from pathlib import Path
import os
import re
import subprocess as sp
import sys

SCRIPTS_DIR = Path.home() / "is" / "scripts"
STATE_DIR = SCRIPTS_DIR / "state" / "screen-watch"
STATUS_PATH = STATE_DIR / "status"
SCREENS_PATH = STATE_DIR / "screens"
STATUSES = {"scanning": "🖵... ", "not scanning": ""}

def read(path: Path) -> str | None:
    if not path.exists():
        return None
    with open(path, "r") as inf:
        return inf.read()

def write(path: Path, content: str) -> None:
    with open(path, "w") as outf:
        outf.write(content)

def query_xrandr():
    stdout = str(sp.Popen(["xrandr"], stdout=sp.PIPE).stdout.read(), encoding="utf8")
    screens = re.findall(r'(.*?) connected (?:primary )?(?:(\d+)+x(\d+)\+(\d+)\+(\d+))?', stdout)
    return "\n".join(" ".join(line) for line in screens)

def reset_screens(screens: str):
    screen_names = [ line.split(" ", 1)[0] for line in screens.split("\n") ]
    commands = [
        ["xrandr", "--output", screen_names[0], "--auto"],
        *[
            ["xrandr", "--output", right, "--auto", "--right-of", left]
            for (left, right) in zip(screen_names, screen_names[1:])
        ],
        ["feh", "--bg-max", "/tmp/blame.png"],
        ["pkill", "keynav"],
    ]
    for command in commands:
        sp.Popen(command).wait()
    sp.Popen(["keynav"])
    write(SCREENS_PATH, query_xrandr())

def scan():
    if (screens := read(SCREENS_PATH)) is None:
        screens = query_xrandr()
        reset_screens(screens)
    if screens != (queried := query_xrandr()):
        print("Resetting screens")
        screens = query_xrandr()
        reset_screens(screens)

def loop():
    print("Started screen watch loop")
    while True:
        sleep(.5)
        status = read(STATUS_PATH)
        if status == STATUSES["scanning"]:
            print("Scanning")
            scan()

if __name__ == "__main__":
    with open(SCRIPTS_DIR / "pids" / "screen-watch", "w") as outf:
        outf.write(f"{os.getpid()}")
    STATE_DIR.mkdir(exist_ok=True, parents=True)
    if not STATUS_PATH.exists():
        write(STATUS_PATH, STATUSES["not scanning"])
    if len(argv := sys.argv) == 1:
        reset_screens(query_xrandr())
        loop()
    status = read(STATUS_PATH)
    if (arg := argv[1]) == "query":
        print(status)
    elif arg == "toggle":
        status = "not scanning" if status == STATUSES["scanning"] else "scanning"
        write(STATUS_PATH, STATUSES[status])
