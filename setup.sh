#!/bin/bash
read -p "Username: " USERNAME
echo $USERNAME

PWD="$(pwd)"

setxkbmap -layout us -variant altgr-intl

if [ ! -f $HOME/.ssh/id_ed25519 ]; then
  ssh-keygen -t ed25519 -N '' -f $HOME/.ssh/id_ed25519
fi

mkdir -p $HOME/is/ $HOME/is/git

### MANUALLY INSTALLED WITHOUT REQS
if [[ -z "$(which nvim)" ]]; then
  curl -LO https://github.com/neovim/neovim/releases/download/nightly/nvim.appimage
  chmod u+x nvim.appimage
  sudo mv nvim.appimage /usr/bin/nvim
fi

### DOCKER REPOSITORIES
if [[ -z "$(which docker)" ]]; then
# Add Docker's official GPG key:
  sudo apt install -y ca-certificates curl
  sudo install -m 0755 -d /etc/apt/keyrings
  sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
  sudo chmod a+r /etc/apt/keyrings/docker.asc

  # Add the repository to Apt sources:
  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
    $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
    sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
  sudo apt install -y 
fi


### EXTRA REPOSITORIES
if [[ -z "$(which keepassxc)" ]]; then
    sudo add-apt-repository -y ppa:phoerious/keepassxc
fi

### APT INSTALLABLES
if [[ -z "$UPDATE" ]]; then
  ESSENTIALS='git firefox keepassxc i3 i3blocks pipx compton ffmpeg gdb'
  DOCKER='docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin' # required for KMonad
  SCRIPT_DEPS='pulsemixer brightnessctl gnome-screenshot mpc feh xclip libnotify-bin'
  OTHERS='telegram-desktop'
  sudo apt update && sudo apt upgrade -y
  sudo apt install -y $ESSENTIALS $SCRIPT_DEPS $DOCKER $OTHERS
  sudo usermod -aG video $USERNAME  # required by brightnessctl
fi

if [[ -z "$(cat $HOME/.bashrc | grep 'Created by `pipx`')" ]]; then
  pipx ensurepath
fi
# Make sure it's PATHed even on first run
PATH="$PATH:/home/$USERNAME/.local/bin"


### FIREFOX'S PROFILE
## # Unused: no time to figure out how to seamlessly install a specific plugin and I
## # don't want to just replace the whole profile
## DEFAULT_PROFILE="(cat $HOME/.mozilla/firefox/profiles.ini  | grep -Pz '\[Profile0\]\n(.*?\n)*Path=\K.*')"


### PYENV
if [[ -z "$(which pyenv)" ]]; then
  curl https://pyenv.run | bash

  PYENV_EXPORT='
  export PYENV_ROOT="$HOME/.pyenv"
  [[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"
  eval "$(pyenv init -)"
  eval "$(pyenv virtualenv-init -)"'

  echo "$PYENV_EXPORT" >> $HOME/.profile
  echo "$PYENV_EXPORT" >> $HOME/.bashrc
fi

if [[ -n "$(python --version | grep 'command not found')" ]]; then
  sudo apt install -y \
    make build-essential libssl-dev zlib1g-dev libbz2-dev \
    libreadline-dev libsqlite3-dev wget curl llvm libncurses5-dev libncursesw5-dev \
    xz-utils tk-dev libffi-dev liblzma-dev python3-openssl git
  LATEST_PYTHON="$(pyenv install -l | grep -Po '  \K3\.\d+\.\d+$' | sort -V | tail -n1)"
  pyenv install $LATEST_PYTHON
  pyenv global $LATEST_PYTHON
  pip install ipython matplotlib numpy pandas polars requests  # Essentials IMHO
fi


### KMONAD
if [[ -z "$(which kmonad)" ]]; then
  if [[ -z "$(systemctl status docker.service | grep '(running)')" ]]; then
    echo 'ERROR: docker service not up. May need to restart.' 1>&2
    exit 1
  fi

  cd $HOME/is/git
  git clone https://github.com/kmonad/kmonad.git
  cd kmonad

  pwd
  sudo docker build -t kmonad-builder .
  sudo docker run --rm -it -v ${PWD}:/host/ kmonad-builder bash -c 'cp -vp /root/.local/bin/kmonad /host/'
  sudo docker rmi kmonad-builder
  
  sudo mv kmonad /usr/bin
  cd $PWD

  sudo groupadd uinput
  sudo usermod -aG input,uinput $USERNAME # required by kmonad
  echo 'KERNEL=="uinput", MODE="0660", GROUP="uinput", OPTIONS+="static_node=uinput"' | sudo tee /etc/udev/rules.d/99-kmonad.rules >/dev/null
  sudo udevadm control --reload-rules
  sudo udevadm trigger
fi

### RUST
if [[ -z "$(which rustup)" ]]; then
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
fi

### EXTRAS
# dua
if [[ -z "$(which dua)" ]]; then
  cargo install dua-cli
fi

# keynav
if [[ -z "$(which keynav)" ]]; then
  sudo apt install -y \
    libxinerama-dev libxrandr-dev libcairo2-dev libxdo-dev
  cd $HOME/is/git
  git clone https://github.com/jordansissel/keynav.git
  cd keynav
  make keynav
  sudo mv keynav /usr/bin

  cd $PWD
fi

# aws-cli
if [[ -z "$(which aws)" ]]; then
  mkdir -p /tmp/install-aws-cli
  cd /tmp/install-aws-cli
  curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
  unzip awscliv2.zip
  sudo ./aws/install
  cd $PWD
fi

if [[ -z "$(which poetry)" ]]; then
  pipx install poetry
fi


### CONFIGS AND SCRIPTS
rsync -a "$PWD/scripts/" "$HOME/is/scripts/"
rsync -a "$PWD/config/" "$HOME/.config/"

if [[ "$(cat /etc/systemd/logind.conf | grep -Po '#?HandleLidSwitch=.*')" != "HandleLidSwitch=ignore" ]]; then
  cat /etc/systemd/logind.conf \
    | sed -e 's/#\?HandleLidSwitch=.*/HandleLidSwitch=ignore/g' \
    	  -e 's/#\?HAndleLidSwitchExternalPower=.*/HandleLidSwitchExternalPower=ignore/g' \
    | sudo tee /etc/systemd/logind.conf >/dev/null
fi

### NCMPCPP
if [[ -z "$(which ncmpcpp)" ]]; then
  # From https://gist.github.com/lirenlin/f92c8e849530ebf66604
  # Slightly modified
  sudo apt install -y mpd mpc ncmpcpp

  mkdir $HOME/.mpd
  mkdir $HOME/.mpd/playlists
  touch $HOME/.mpd/{mpd.db,mpd.log,mpd.pid,mpdstate}

  mv $HOME/.config/mpd.conf $HOME/.mpd/mpd.conf
fi

### QUTEBROWSER
if [[ -z "$(which qutebrowser)" ]]; then
  cd $HOME/is/git
  git clone https://github.com/qutebrowser/qutebrowser.git
  cd qutebrowser
  python3 scripts/mkenv.py
  { echo '#!/bin/bash' && echo "$HOME/is/git/qutebrowser/.venv/bin/python3 -m qutebrowser \"\$@\""; } > $HOME/.local/bin/qutebrowser
  chmod u+x $HOME/.local/bin/qutebrowser
fi

echo 'Make sure to source `.bashrc` or re-open a terminal for updated ENV vars'
echo 'Restart computer in order to apply changes to lid switch behaviour'

if [[ -z "$(dir $HOME/.config/systemd/user)" ]]; then
  mkdir -p ~/.config/systemd
  mkdir -p ~/.config/systemd/user
fi

SEDCODE=$(echo -n "$HOME/is/scripts/code" | sed 's/\//\\\//g')
for fn in $PWD/services/*.service; do
  bn="$(basename $fn)"
  cat $fn | sed "s/\$CODE/$SEDCODE/g" | tee "$HOME/.config/systemd/user/$bn" > /dev/null
done

# TODO: find a way to check whether to run apt update
# TODO: screen DPI-dependent font size in config
# TODO: find out how to ignore lidswitch without thrashing the user login

# NOTE: These instructions only work for 64-bit Debian-based
# Linux distributions such as Ubuntu, Mint etc.

if [[ -z "$(which signal)" ]]; then
    # 1. Install our official public software signing key:
    wget -O- https://updates.signal.org/desktop/apt/keys.asc | gpg --dearmor > signal-desktop-keyring.gpg
    cat signal-desktop-keyring.gpg | sudo tee /usr/share/keyrings/signal-desktop-keyring.gpg > /dev/null

    # 2. Add our repository to your list of repositories:
    echo 'deb [arch=amd64 signed-by=/usr/share/keyrings/signal-desktop-keyring.gpg] https://updates.signal.org/desktop/apt xenial main' |\
      sudo tee /etc/apt/sources.list.d/signal-xenial.list

    # 3. Update your package database and install Signal:
    sudo apt update && sudo apt install -y signal-desktop
fi
