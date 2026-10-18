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

# Java 21 — quint verify が使う Apalache が要求する（class file 65.0）
RUN curl -sL https://api.adoptium.net/v3/binary/latest/21/ga/linux/x64/jre/hotspot/normal/eclipse -o /tmp/jre.tgz \
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
