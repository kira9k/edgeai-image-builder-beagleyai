FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN dpkg --add-architecture i386 && \
    apt-get update && apt-get install -y \
    build-essential \
    autoconf \
    automake \
    libtool \
    pkg-config \
    gettext \
    autopoint \
    m4 \
    git \
    libconfuse-dev \
    mtools \
    wget \
    curl \
    htop \
    nano \
    python3 \
    python3-pip \
    python3-setuptools \
    python3-dev \
    bc \
    bison \
    flex \
    libssl-dev \
    libncurses-dev \
    libtinfo5 \
    device-tree-compiler \
    rsync \
    unzip \
    xz-utils \
    cpio \
    file \
    sudo \
    lsb-release \
    libc6:i386 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

CMD ["bash"]