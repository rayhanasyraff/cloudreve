# ==========================================
# Stage 1: Build Cloudreve
# ==========================================
FROM golang:1.26.5-alpine AS builder

WORKDIR /src

# Install build dependencies
RUN apk add --no-cache \
    bash \
    git \
    zip \
    nodejs \
    npm \
    python3 \
    make \
    g++

# Install Yarn Classic
RUN npm install --global yarn@1.22.22

# Download Go dependencies
COPY go.mod go.sum ./
RUN go mod download

# Copy source code, including assets submodule
COPY . .

# Build frontend and backend
RUN set -eux; \
    VERSION="$(node -p "require('./assets/package.json').version")"; \
    COMMIT_SHA="$(git rev-parse --short HEAD 2>/dev/null || echo unknown)"; \
    chmod +x .build/build-assets.sh; \
    ./.build/build-assets.sh "$VERSION"; \
    go build -a -o cloudreve \
      -ldflags "-s -w -X 'github.com/cloudreve/Cloudreve/v4/application/constants.BackendVersion=$VERSION' -X 'github.com/cloudreve/Cloudreve/v4/application/constants.LastCommit=$COMMIT_SHA'" \
      .

# ==========================================
# Stage 2: Runtime
# ==========================================
FROM alpine:3.22

WORKDIR /cloudreve

# Install Cloudreve runtime dependencies
RUN apk add --no-cache \
    tzdata \
    vips-tools \
    ffmpeg \
    libreoffice \
    aria2 \
    supervisor \
    font-noto \
    font-noto-cjk \
    libheif \
    libraw-tools \
    && cp /usr/share/zoneinfo/Asia/Kuala_Lumpur /etc/localtime \
    && echo "Asia/Kuala_Lumpur" > /etc/timezone \
    && mkdir -p ./data/temp/aria2 \
    && chmod -R 766 ./data/temp/aria2

# Cloudreve configuration
ENV CR_ENABLE_ARIA2=1 \
    CR_SETTING_DEFAULT_thumb_ffmpeg_enabled=1 \
    CR_SETTING_DEFAULT_thumb_vips_enabled=1 \
    CR_SETTING_DEFAULT_thumb_libreoffice_enabled=1 \
    CR_SETTING_DEFAULT_media_meta_ffprobe=1 \
    CR_SETTING_DEFAULT_thumb_libraw_enabled=1

# Copy runtime configuration and compiled executable
COPY .build/aria2.supervisor.conf .build/entrypoint.sh ./
COPY --from=builder /src/cloudreve ./cloudreve

RUN chmod +x ./cloudreve \
    && chmod +x ./entrypoint.sh

EXPOSE 5212 443 6888 6888/udp

VOLUME ["/cloudreve/data"]

ENTRYPOINT ["sh", "./entrypoint.sh"]
