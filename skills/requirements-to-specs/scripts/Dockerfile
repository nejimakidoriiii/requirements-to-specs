# quint と Alloy による仕様検証の実行環境。
# Ubuntu 24.04（glibc 2.39）ベースにすることで、quint の rust バックエンド
# （GLIBC_2.39 要求）と Apalache 同梱の z3（GLIBC_2.34 要求）が修正なしで動く。
FROM ubuntu:24.04

RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates curl xz-utils \
 && rm -rf /var/lib/apt/lists/*

# Node 22（公式バイナリを展開。noble の apt にある nodejs は古いため）
ARG NODE_VERSION=22.23.3
RUN curl -sL "https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-x64.tar.xz" -o /tmp/node.tar.xz \
 && mkdir -p /opt/node \
 && tar -xJf /tmp/node.tar.xz -C /opt/node --strip-components=1 \
 && rm /tmp/node.tar.xz
ENV PATH="/opt/node/bin:${PATH}"

# Temurin JRE 21.0.12.1+1 — quint verify が使う Apalache が要求する（class file 65.0）。
# バージョンは URL と SHA256 で固定する。更新時は Adoptium API
# （/v3/assets/latest/21/hotshot?...）の package.link と package.checksum で差し替える。
ARG TEMURIN_JRE_URL=https://github.com/adoptium/temurin21-binaries/releases/download/jdk-21.0.12.1%2B1/OpenJDK21U-jre_x64_linux_hotspot_21.0.12.1_1.tar.gz
ARG TEMURIN_JRE_SHA256=2413149700df0f7d440500a84a8f764c535f21e5a5e87d38328b64eec2c5b500
RUN curl -sL "$TEMURIN_JRE_URL" -o /tmp/jre.tgz \
 && echo "$TEMURIN_JRE_SHA256  /tmp/jre.tgz" | sha256sum -c - \
 && mkdir -p /opt/java \
 && tar -xzf /tmp/jre.tgz -C /opt/java --strip-components=1 \
 && rm /tmp/jre.tgz
ENV PATH="/opt/java/bin:${PATH}"

# Quint（検証時のバージョンに固定）
RUN npm install -g @informalsystems/quint@0.33.0

# Alloy 6.2.0（検証時のバージョンに固定）
RUN mkdir -p /opt/alloy \
 && curl -sL -o /opt/alloy/alloy.jar \
      https://github.com/AlloyTools/org.alloytools.alloy/releases/download/v6.2.0/org.alloytools.alloy.dist.jar

WORKDIR /work
