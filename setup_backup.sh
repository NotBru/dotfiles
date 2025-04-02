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
