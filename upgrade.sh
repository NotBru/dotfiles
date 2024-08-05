## NVIM
LATEST_NEOVIM="$(curl -s https://github.com/neovim/neovim/releases/ | grep -Po 'NVIM v\d+\.\d+\.\d+.*' | head -n1)"
if [[ -n "$(which nvim)" ]]; then
  CURRENT_NEOVIM="$(nvim --version | head -n1)"
fi

if [[ "$LATEST_NEOVIM" != "$CURRENT_NEOVIM" ]]; then
  curl -LO https://github.com/neovim/neovim/releases/download/nightly/nvim.appimage
  chmod u+x nvim.appimage
  sudo mv nvim.appimage /usr/bin/nvim
fi
