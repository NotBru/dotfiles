#!/bin/bash
echo "This script is just for documenting my process. It's specialized to Ubuntu 22.04, x86_64."
exit
if [[ -z "$(which nvcc)" ]]; then
  if [[ ! -f '/etc/apt/preferences.d/cuda-repository-pin-600' ]]; then
    wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/x86_64/cuda-ubuntu2204.pin
    sudo mv cuda-ubuntu2204.pin /etc/apt/preferences.d/cuda-repository-pin-600
  fi
  if [[ ! -f 'cuda-repo-ubuntu2204-12-6-local_12.6.0-560.28.03-1_amd64.deb' ]]; then
    wget -c https://developer.download.nvidia.com/compute/cuda/12.6.0/local_installers/cuda-repo-ubuntu2204-12-6-local_12.6.0-560.28.03-1_amd64.deb
  fi
  sudo dpkg -i cuda-repo-ubuntu2204-12-6-local_12.6.0-560.28.03-1_amd64.deb
  sudo cp /var/cuda-repo-ubuntu2204-12-6-local/cuda-*-keyring.gpg /usr/share/keyrings/
  sudo apt-get update
  sudo apt-get -y install cuda-toolkit-12-6 \
    && rm cuda-repo-ubuntu2204-12-6-local_12.6.0-560.28.03-1_amd64.deb

  echo 'export PATH="$PATH:/usr/local/cuda/bin"' >> ~/.bashrc
  echo 'export PATH="$PATH:/usr/local/cuda/bin"' >> ~/.profile
fi
