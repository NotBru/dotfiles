from os import system
from os.path import join, expanduser
from sys import argv
import re
import subprocess

def get_sink_data() -> tuple[int, bool, int, str]:
    p = subprocess.Popen(
        ['pulsemixer', '--list-sinks'],
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
    )

    id_, name, mute, vol = re.search(
            r'ID: sink-(\d+), Name: (.*?), Mute: (\d).*?(\d+)%.*?Default',
        str(p.stdout.read(), encoding="utf8")
    ).groups()

    return id_, mute == "1", int(vol), name

if __name__ == "__main__":
    if len(argv) == 1:
        _, mute, vol, name = get_sink_data()
        print(f"{vol: 3} " + ("𝄽 " if mute else "𝅘𝅥𝅮 ") + f"{name} ")
    else:
        id_, _, _, _ = get_sink_data()
        what_do = argv[1]
        if what_do in {"+", "-"}:
            key, value = "volume", f"{what_do}5%"
        else:
            key = "mute"
            if what_do == "toggle":
                value = "toggle"
            else:
                value = "1" if what_do == "mute" else "0"
        subprocess.Popen(["pactl", f"set-sink-{key}", id_, value])
        subprocess.Popen(['pkill', '-SIGRTMIN+2', 'i3blocks'])
