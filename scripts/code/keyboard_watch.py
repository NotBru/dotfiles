from colorama import Fore, Style
from logging import Logger
from pathlib import Path
from subprocess import DEVNULL, PIPE, Popen, STDOUT
from time import sleep
import os
import uuid

def read_template():
    with open(Path.home() / ".config" / "keyboard_watch" / "template.kbd", "r") as inf:
        return inf.read()


def write_pid():
    pid = os.getpid()
    with (
        open(Path().home() / "is" / "scripts" / "pids" / "keyboard_watch.pid", "w")
        as outf
    ):
        outf.write(f"{pid}")

def run():
    dev_input = Path("/dev/input/by-path")
    processes = {}

    while True:
        sleep(0.1)
        keyboards = set(filter(lambda p: p.name.endswith("-kbd"), dev_input.iterdir()))
        for kb in set(processes.keys()) - keyboards:
            print(f"{Fore.BLUE}{kb}:{Style.RESET_ALL} disconnected")
            processes.pop(kb)
        for kb, p in list(processes.items()):
            if p.poll() is not None:
                print(f"{Fore.RED}{kb}:{Style.RESET_ALL} killed:")
                stdout = str(p.stdout.read(), encoding="utf8")
                print("\n".join(f"  {l}" for l in stdout.split("\n")))
                processes.pop(kb)
        for kb in keyboards - set(processes.keys()):
            print(f"{Fore.GREEN}{kb}:{Style.RESET_ALL} remapped", end="")
            config_path = Path("/tmp") / str(uuid.uuid4())
            with open(config_path, "w") as outf:
                outf.write(read_template().format(kb, f"KMonad {len(processes)}"))
                p = Popen(["kmonad", str(config_path)], stdout=PIPE, stderr=STDOUT)
                processes[kb] = p
                print(f" (PID: {p.pid})")

run()
