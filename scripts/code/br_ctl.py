from math import log
from sys import argv
import re
import subprocess

def get_brightness():
    child = subprocess.Popen(['brightnessctl'], stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    stdout = str(child.stdout.read(), encoding="utf8")
    brightness, = re.search(r'Current brightness: (\d+)', stdout).groups()
    max_brightness, = re.search(r'Max brightness: (\d+)', stdout).groups()
    return int(brightness), int(max_brightness)

def print_brightness():
    brightness, max_brightness = get_brightness()
    brightness = str(int(brightness / max_brightness * 100))
    print(" " * (4 - len(brightness)) + brightness + " ☀")

def move_brightness(where, factor=1.15):
    brightness, max_brightness = get_brightness()
    step = max_brightness // 10

    if where == "+":
        brightness += step
    elif where == "-":
        brightness -= step

    subprocess.Popen(
        ['brightnessctl', 's', f'{brightness}'],
        stdout=subprocess.PIPE,
    )

if len(argv) == 1:
    print_brightness()
else:
    move_brightness(argv[1])
