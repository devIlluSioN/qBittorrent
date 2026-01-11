# Dockerfile pour qBittorrent-nox avec webui (multi-arch: amd64 et arm64)
FROM ubuntu:22.04 AS builder

ENV DEBIAN_FRONTEND=noninteractive

# Installer les dépendances de compilation
RUN apt-get update && apt-get install -y \
    build-essential \
    cmake \
    ninja-build \
    git \
    pkg-config \
    libboost-dev \
    libssl-dev \
    zlib1g-dev \
    qt6-base-dev \
    qt6-base-dev-tools \
    qt6-tools-dev \
    python3 \
    && rm -rf /var/lib/apt/lists/*

# Cloner et compiler libtorrent
WORKDIR /tmp
RUN git clone --branch v2.0.20 --depth 1 --recurse-submodules \
    https://github.com/arvidn/libtorrent.git && \
    cd libtorrent && \
    cmake -B build \
        -G "Ninja" \
        -DBUILD_SHARED_LIBS=OFF \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_CXX_STANDARD=20 \
        -Ddeprecated-functions=OFF && \
    cmake --build build && \
    cmake --install build

# Copier le code source et compiler qBittorrent
WORKDIR /build
COPY . /build

RUN cmake -B build \
    -G "Ninja" \
    -DCMAKE_BUILD_TYPE=Release \
    -DGUI=OFF \
    -DWEBUI=ON && \
    cmake --build build && \
    cmake --install build --prefix /opt/qbittorrent

# Image finale
FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# Installer uniquement les dépendances runtime
RUN apt-get update && apt-get install -y \
    libboost-system1.74.0 \
    libssl3 \
    zlib1g \
    qt6-base-private \
    python3 \
    && rm -rf /var/lib/apt/lists/*

# Copier les binaires depuis le builder
COPY --from=builder /opt/qbittorrent /opt/qbittorrent

# Créer un utilisateur non-root
RUN useradd -m -u 1000 qbittorrent && \
    mkdir -p /home/qbittorrent/.config/qBittorrent && \
    mkdir -p /home/qbittorrent/.local/share/qBittorrent && \
    chown -R qbittorrent:qbittorrent /home/qbittorrent

USER qbittorrent
WORKDIR /home/qbittorrent

# Exposer le port du webui (par défaut 8080)
EXPOSE 8080

# Point d'entrée
ENTRYPOINT ["/opt/qbittorrent/bin/qbittorrent-nox"]
CMD ["--webui-port=8080"]

