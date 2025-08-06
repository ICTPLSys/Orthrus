FROM ubuntu:20.04

WORKDIR /work

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        openssh-server \
        git \
        curl wget \
        p7zip-full \
        binutils \
        zlib1g-dev \
        lsb-release software-properties-common gnupg \
        util-linux \
        python3 python3-toolz python3-matplotlib \
        libboost-dev libboost-program-options-dev \
        pkg-config libgflags-dev

RUN add-apt-repository ppa:ubuntu-toolchain-r/test && \
    apt update && \
    apt-get install -y gcc-13 g++-13

RUN git config --global --add safe.directory '*'

# Install clang-16
RUN wget https://apt.llvm.org/llvm.sh -O /tmp/llvm.sh
RUN chmod +x /tmp/llvm.sh && /tmp/llvm.sh 16

# Install cmake
RUN wget https://github.com/Kitware/CMake/releases/download/v4.0.3/cmake-4.0.3-linux-x86_64.sh -O /tmp/cmake-installer.sh
RUN chmod +x /tmp/cmake-installer.sh && mkdir -p /usr/local/cmake && \
    /tmp/cmake-installer.sh \
        --prefix=/usr/local/cmake \
        --skip-license
ENV PATH="/usr/local/cmake/bin:${PATH}"

# Install Ninja
RUN wget https://github.com/ninja-build/ninja/releases/download/v1.13.1/ninja-linux.zip -O /tmp/ninja.zip
RUN 7z -o/tmp/ x /tmp/ninja.zip && chmod +x /tmp/ninja && mv /tmp/ninja /usr/bin/

# Install just
RUN wget https://github.com/casey/just/releases/download/1.42.4/just-1.42.4-x86_64-unknown-linux-musl.tar.gz -O /tmp/just.tar.gz
RUN tar xzf /tmp/just.tar.gz -C /tmp && mv /tmp/just /usr/bin && chmod +x /usr/bin/just

ENV DEBIAN_FRONTEND=

ENV CC=clang-16 CXX=clang++-16


