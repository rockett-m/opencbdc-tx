#!/bin/bash

echo "Setting up build environment..."

green="\033[0;32m"
cyan="\033[0;36m"
end="\033[0m"

set -e

SUDO=''
if (( $EUID != 0 )); then
    echo -e "non-root user, sudo required"
    SUDO='sudo'
fi

if [[ "$OSTYPE" == "darwin"* ]]; then
  CPUS=$(sysctl -n hw.ncpu)
  # ensure development environment is set correctly for clang
  $SUDO xcode-select -switch /Library/Developer/CommandLineTools
  brew install llvm googletest google-benchmark lcov make wget cmake curl
  CLANG_TIDY=/usr/local/bin/clang-tidy
  if [ ! -L "$CLANG_TIDY" ]; then
    $SUDO ln -s $(brew --prefix)/opt/llvm/bin/clang-tidy /usr/local/bin/clang-tidy
  fi
  GMAKE=/usr/local/bin/gmake
  if [ ! -L "$GMAKE" ]; then
    $SUDO ln -s $(xcode-select -p)/usr/bin/gnumake /usr/local/bin/gmake
  fi
fi

if [[ "$OSTYPE" == "linux-gnu"* ]]; then
  $SUDO apt update -y
  $SUDO apt install -y build-essential wget cmake libgtest-dev libbenchmark-dev lcov git software-properties-common rsync unzip

  # Add LLVM GPG key (apt-key is deprecated in Ubuntu 21.04+ so using gpg)
  wget -qO - https://apt.llvm.org/llvm-snapshot.gpg.key | \
    gpg --dearmor -o /usr/share/keyrings/llvm-archive-keyring.gpg
  echo "deb [signed-by=/usr/share/keyrings/llvm-archive-keyring.gpg] http://apt.llvm.org/focal/ llvm-toolchain-focal main" | \
    $SUDO tee /etc/apt/sources.list.d/llvm.list

  $SUDO apt update -y
  $SUDO apt install -y clang-format clang-tidy
  $SUDO ln -sf $(which clang-format) /usr/local/bin/clang-format
  $SUDO ln -sf $(which clang-tidy) /usr/local/bin/clang-tidy
fi

PYTHON_TIDY=/usr/local/bin/run-clang-tidy.py
if [ ! -f "${PYTHON_TIDY}" ]; then
  echo -e "${green}Copying run-clang-tidy to /usr/local/bin${end}"
  wget https://raw.githubusercontent.com/llvm/llvm-project/main/clang-tools-extra/clang-tidy/tool/run-clang-tidy.py
  $SUDO mv run-clang-tidy.py /usr/local/bin
fi
