#!/bin/bash
PWD="$(pwd)"

setxkbmap -layout us -variant altgr-intl

if [ ! -f $HOME/.ssh/id_ed25519 ]; then
  ssh-keygen -t ed25519 -N '' -f $HOME/.ssh/id_ed25519
fi


### APT INSTALLABLES
if [[ -z "UPDATE" ]]; then
  if [[ "$(cat /var/log/apt/history.log | grep -Pzo '(?<=Start-Date: )\d{4}-\d{2}-\d{2}(?=  \d{2}:\d{2}:\d{2}\nCommandline: apt upgrade)')" != "$(date +%Y-%m-%d)" ]]; then
    sudo add-apt-repository -y ppa:phoerious/keepassxc
    sudo apt update && sudo apt upgrade -y
    sudo apt install -y git firefox keepassxc neovim pipx
  fi
fi


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
  sudo apt-get install -y \
    make build-essential libssl-dev zlib1g-dev libbz2-dev \
    libreadline-dev libsqlite3-dev wget curl llvm libncurses5-dev libncursesw5-dev \
    xz-utils tk-dev libffi-dev liblzma-dev python3-openssl git
  LATEST_PYTHON="$(pyenv install --l | grep -Po '  \K3\.\d+\.\d+$' | sort -V | tail -n1)"
  pyenv install $LATEST_PYTHON
  pyenv global $LATEST_PYTHON
fi

### DOCKER
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
  sudo apt update

  # Apt install Docker
  sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
fi


### KMONAD
if [[ -z "$(which kmonad)" ]]; then
	if [[ -z "$(systemctl status docker.service | grep '(running)')" ]]; then
    echo 'ERROR: docker service not up. May need to restart.' 1>&2
    exit 1
  fi

  mkdir -p $HOME/is/ $HOME/is/git
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
  sudo usermod -aG input,uinput username  # This will require re-loggin
  echo 'KERNEL=="uinput", MODE="0660", GROUP="uinput", OPTIONS+="static_node=uinput"' | sudo tee /etc/udev/rules.d/99-kmonad.rules >/dev/null
  sudo udevadm control --reload-rules
  sudo udevadm trigger

  echo 'source $HOME/is/scripts/venvs/keyboard_watch/bin/activate && python $HOME/is/scripts/code/keyboard_watch.py &' >> $HOME/.profile
fi

rsync -a "$PWD/scripts/" "$HOME/is/scripts/"
rsync -a "$PWD/config/" "$HOME/.config/"

# TODO: make keyboard_watch into poetry project