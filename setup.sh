#!/bin/bash
PWD="$(pwd)"
LOGS="$HOME/setup.log"

sudo echo "Running setup. Dumping to \"$LOGS\""
rm "$LOGS" 2>/dev/null

report_error_and_exit() {
  echo FAILED
  echo "Logs can be found in \"$LOGS\""
  exit 1
}

install_nvim() {
  APPIMAGE_NAME="nvim-linux-x86_64.appimage"
  # TODO: fetch architecture automatically
  curl -LO https://github.com/neovim/neovim/releases/download/nightly/$APPIMAGE_NAME
  chmod u+x $APPIMAGE_NAME
  sudo mv $APPIMAGE_NAME /usr/bin/nvim
  if [[ ! "$(nvim --version)" ]]; then
    exit 1
  fi
}

install_docker() {
  sudo apt-get update
  sudo apt-get install ca-certificates curl
  sudo install -m 0755 -d /etc/apt/keyrings
  sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
  sudo chmod a+r /etc/apt/keyrings/docker.asc
  
  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
    $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | \
    sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
  sudo apt-get update
  sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
}

install_stack() {
  curl -sSL https://get.haskellstack.org/ | sh
}

install_kmonad() {
  cd "$HOME/is/git"
  if [ ! -d "$HOME/is/git" ]; then
    git clone https://github.com/kmonad/kmonad.git
  fi
  cd kmonad

  stack install
  cd "$PWD"

  sudo groupadd uinput
  sudo usermod -aG input,uinput "$(whoami)" # required by kmonad
  echo 'KERNEL=="uinput", MODE="0660", GROUP="uinput", OPTIONS+="static_node=uinput"' | sudo tee /etc/udev/rules.d/99-kmonad.rules >/dev/null
  sudo udevadm control --reload-rules
  sudo udevadm trigger
}

apt_install() {
  sudo add-apt-repository -y ppa:phoerious/keepassxc
  ESSENTIALS='git firefox keepassxc i3 i3blocks pipx compton ffmpeg gdb'
  SCRIPT_DEPS='pulsemixer brightnessctl gnome-screenshot mpc feh xclip libnotify-bin'
  OTHERS='ncal jq'

  sudo apt update && sudo apt upgrade -y
  sudo apt install -y $ESSENTIALS $SCRIPT_DEPS $OTHER
  sudo usermod -aG video "$(whoami)"

  if [[ -z "$(cat $HOME/.bashrc | grep 'Created by `pipx`')" ]]; then
    pipx ensurepath >>"$LOGS" 2>>"$LOGS"
  fi
}

install_python() {
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
}

install_rust() {
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
  source "$HOME/.bashrc"
}

cargo_install() {
  cargo install dua-cli
}

install_ncmpcpp() {
  # From https://gist.github.com/lirenlin/f92c8e849530ebf66604
  # Slightly modified
  sudo apt install -y mpd mpc ncmpcpp

  mkdir $HOME/.mpd
  mkdir $HOME/.mpd/playlists
  touch $HOME/.mpd/{mpd.db,mpd.log,mpd.pid,mpdstate}

  cp $PWD/config/mpd.conf $HOME/.mpd/mpd.conf
}

install_telegram() {
  RESULT="$(curl -s https://api.github.com/repos/telegramdesktop/tdesktop/releases/latest | jq -r '.assets[] | select(.label=="Linux 64 bit: Binary")')"
  NAME="$(echo "$RESULT" | jq -r '.name')"
  URL="$(echo "$RESULT" | jq -r '.browser_download_url')"
  wget "$URL" -O "$NAME"
  tar xf "$NAME"
  rm "$NAME"
  sudo mv Telegram/Telegram "/usr/bin/telegram"
  sudo mv Telegram/Updater "/usr/bin/telegram-updater"
  rm -r Telegram
}

#----------------------------------------------------------------------------------------------------------------------------

## Stage: setup git dir
mkdir -p $HOME/is/git
PATH="$PATH:$HOME/.local/bin"

## Stage: keyboard layout
echo -n "Persist layout in ~/.profile... "
if [[ -z "$(cat $HOME/.profile | grep setxkbmap)" ]]; then
  echo "setxkbmap -layout us -variant altgr-intl" >> $HOME/.profile
  setxkbmap -layout us -variant altgr-intl
  echo OK
else
  echo "OK (already)"
fi

## Stage: Key
echo -n 'Generating public ed25519 key... '
if [ ! -f $HOME/.ssh/id_ed25519 ]; then
  ssh-keygen -t ed25519 -N '' -f $HOME/.ssh/id_ed25519 >>"$LOGS" || report_error_and_exit
  echo OK
else
  echo 'OK (already)'
fi

## Stage: install nvim
echo -n 'Install nvim... '
if [[ ! "$(which nvim)" || ! "$(nvim --version)" ]]; then
  install_nvim >>"$LOGS" 2>>"$LOGS" || report_error_and_exit
  echo OK
else
  echo 'OK (already)'
fi

### Stage: install docker
#echo -n 'Install docker... '
#if [[ ! "$(which docker)" || ! "$(docker --version)" ]]; then
  #install_docker >>"$LOGS" 2>>"$LOGS" || report_error_and_exit
  #echo OK
#else
  #echo 'OK (already)'
#fi
#
### Stage: check docker service
#if [[ -z "$(systemctl status docker.service | grep '(running)')" ]]; then
  #echo 'ERROR: Docker service is not up, but a restart may fix this.'
  #exit
#fi

## Stage: install stack
echo -n "Installing stack... "
if [[ ! "$(which stack)" ]]; then
  install_stack >>"$LOGS" 2>>"$LOGS" || report_error_and_exit
  echo OK
else
  echo 'OK (already)'
fi

## Stage: install kmonad
echo -n 'Install kmonad... '
if [[ ! "$(which kmonad)" ]]; then
  install_kmonad >>"$LOGS" 2>>"$LOGS" || report_error_and_exit
  echo OK
else
  echo 'OK (already)'
fi

## Stage: apt install...
echo -n 'Run apt... '
if [[ ! "$(which keepassxc)" ]]; then
  apt_install >>"$LOGS" 2>>"$LOGS" || report_error_and_exit
  echo OK
else
  echo 'OK (already)'
fi

## Stage: install python:
echo -n "Install python... "
if [[ ! "$(which python)" ]]; then
  install_python >>"$LOGS" 2>>"$LOGS" || report_error_and_exit
  echo OK
else
  echo 'OK (already)'
fi

echo -n "Install rust... "
if [[ ! "$(which rustup)" ]]; then
  install_rust >>"$LOGS" 2>>"$LOGS" || report_error_and_exit
  echo OK
else
  echo 'OK (already)'
fi

echo -n "Cargo install... "
if [[ ! "$(which dua)" ]]; then
  cargo_install >>"$LOGS" 2>>"$LOGS" || report_error_and_exit
  echo OK
else
  echo 'OK (already)'
fi

# TODO: symlinks

echo -n "Disabling lid switch... "
if [[ "$(cat /etc/systemd/logind.conf | grep -Po '#?HandleLidSwitch=.*')" != "HandleLidSwitch=ignore" ]]; then
  cat /etc/systemd/logind.conf \
    | sed -e 's/#\?HandleLidSwitch=.*/HandleLidSwitch=ignore/g' \
    	  -e 's/#\?HAndleLidSwitchExternalPower=.*/HandleLidSwitchExternalPower=ignore/g' \
    | sudo tee /etc/systemd/logind.conf >/dev/null
  echo OK
else
  echo 'OK (already)'
fi

echo -n "Install ncmpcpp... "
if [[ ! "$(which ncmpcpp)" ]]; then
  install_ncmpcpp >>"$LOGS" 2>>"$LOGS" || report_error_and_exit
  echo OK
else
  echo 'OK (already)'
fi

echo -n "Install telegram... "
if [[ ! "$(which telegram)" ]]; then
  install_telegram >>"$LOGS" 2>>"$LOGS" || report_error_and_exit
  echo OK
else
  echo 'OK (already)'
fi
