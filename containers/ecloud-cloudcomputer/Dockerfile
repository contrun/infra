FROM ubuntu:20.04

ENV DEBIAN_FRONTEND=noninteractive

# 1. 配置国内镜像源 (USTC) - Focal 20.04
# 先使用 http 安装 ca-certificates 以避免证书验证错误
RUN echo "deb http://mirrors.ustc.edu.cn/ubuntu/ focal main restricted universe multiverse" > /etc/apt/sources.list && \
    echo "deb http://mirrors.ustc.edu.cn/ubuntu/ focal-security main restricted universe multiverse" >> /etc/apt/sources.list && \
    echo "deb http://mirrors.ustc.edu.cn/ubuntu/ focal-updates main restricted universe multiverse" >> /etc/apt/sources.list && \
    echo "deb http://mirrors.ustc.edu.cn/ubuntu/ focal-backports main restricted universe multiverse" >> /etc/apt/sources.list && \
    apt-get update && apt-get install -y ca-certificates && \
    # 安装完证书后切换回 https
    echo "deb https://mirrors.ustc.edu.cn/ubuntu/ focal main restricted universe multiverse" > /etc/apt/sources.list && \
    echo "deb https://mirrors.ustc.edu.cn/ubuntu/ focal-security main restricted universe multiverse" >> /etc/apt/sources.list && \
    echo "deb https://mirrors.ustc.edu.cn/ubuntu/ focal-updates main restricted universe multiverse" >> /etc/apt/sources.list && \
    echo "deb https://mirrors.ustc.edu.cn/ubuntu/ focal-backports main restricted universe multiverse" >> /etc/apt/sources.list && \
    echo "deb http://mirrors.ustc.edu.cn/ubuntu/ focal-proposed main restricted universe multiverse" >> /etc/apt/sources.list && \
    echo "deb-src http://mirrors.ustc.edu.cn/ubuntu/ focal-proposed main restricted universe multiverse" >> /etc/apt/sources.list

# 2. 安装 GUI 依赖
ENV PIP_INDEX_URL=https://pypi.mirrors.ustc.edu.cn/simple/
ENV PIP_TRUSTED_HOST=pypi.mirrors.ustc.edu.cn

RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
    locales \
    ca-certificates \
    sudo \
    vim \
    procps \
    libcap2-bin \
    lsb-release \
    dmidecode \
    libgtk-3-0 \
    libnotify4 \
    libnss3 \
    libxss1 \
    libxtst6 \
    xdg-utils \
    libatspi2.0-0 \
    libuuid1 \
    libsecret-1-0 \
    libappindicator3-1 \
    libqt5printsupport5 \
    libqt5multimedia5 \
    libqt5multimedia5-plugins \
    libqt5svg5 \
    libqt5xml5 \
    libqt5concurrent5 \
    libpulse0 \
    libpulse-mainloop-glib0 \
    libva2 \
    libvdpau1 \
    libva-drm2 \
    libva-x11-2 \
    x11-apps \
    libgl1 \
    libgl1-mesa-dri \
    fonts-wqy-microhei \
    fonts-wqy-zenhei \
    dbus-x11 \
    libasound2 \
    libatk-bridge2.0-0 \
    # 虚拟显示组件
    xvfb \
    x11vnc \
    openbox \
    supervisor \
    # noVNC 依赖
    git \
    python3 \
    python3-numpy \
    curl \
    libjpeg62 \
    # 自动化依赖
    python3-xlib \
    xclip \
    x11-utils \
    python3-pip \
    iw \
    python3-tk \
    # VDI 核心解码与重定向依赖 2.18.27版本增加
    libwebpmux3 \
    libsnappy1v5 \
    libzvbi0 \
    libaom0 \
    libgsm1 \
    libshine3 \
    libx264-155 \
    libxvidcore4 \
    libnuma1 \
    libsdl2-2.0-0 \
    libjsoncpp1 \
    libtinyxml2-6a \
    && rm -rf /var/lib/apt/lists/*

# 2.1 Set up Chinese locale
RUN sed -i -e 's/# zh_CN.UTF-8 UTF-8/zh_CN.UTF-8 UTF-8/' /etc/locale.gen && \
    locale-gen
ENV LANG=zh_CN.UTF-8
ENV LANGUAGE=zh_CN:zh
ENV LC_ALL=zh_CN.UTF-8

# Install python dependencies
ENV PLAYWRIGHT_DOWNLOAD_HOST=https://npmmirror.com/mirrors/playwright
RUN pip3 install --no-cache-dir --default-timeout=100 -i http://mirrors.aliyun.com/pypi/simple/ --trusted-host mirrors.aliyun.com playwright==1.44.0 pyautogui==0.9.54 websocket-client==1.8.0 && \
    playwright install chromium

# 3. 安装 noVNC 和 websockify (从 GitHub)
ARG GH_PROXY=https://gh-proxy.org/
RUN git clone --depth 1 ${GH_PROXY}https://github.com/novnc/noVNC.git /opt/novnc && \
    git clone --depth 1 ${GH_PROXY}https://github.com/novnc/websockify.git /opt/novnc/utils/websockify && \
    rm -rf /opt/novnc/.git && \
    rm -rf /opt/novnc/utils/websockify/.git && \
    ln -s /opt/novnc/vnc.html /opt/novnc/index.html

RUN curl https://eos-shanghai-2.cmecloud.cn/cmss-program/Ecloud_CloudComputer_UOS_x86_V3.7.6.deb --output /tmp/vdi_client.deb && \
    dpkg -i /tmp/vdi_client.deb && \
    rm -rf /tmp/vdi_client.deb

# Set root password to resolve 'unlocked state' error (Code 90020129)
RUN echo "root:root" | chpasswd

# Create a non-root user 'uos' with sudo privileges
RUN useradd -m -s /bin/bash uos && \
    echo "uos ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Set up audio and dialout groups for hardware access (USB/Serial)
RUN usermod -aG audio uos && \
    usermod -aG dialout uos && \
    usermod -aG dialout root || true

# 3. Organize Application Files
WORKDIR /app

# Copy supervisor config
COPY supervisord.conf /etc/supervisor/supervisord.conf

# Copy application code
COPY scripts /app/scripts

# Install fake systemctl
COPY systemctl /usr/bin/systemctl

# Create directories for logs and runtime config
RUN mkdir -p /var/log/supervisor /config

# Expose noVNC port
EXPOSE 6080 5900

ENV X_RESOLUTION=1920x1080x24
ENV VNC_PASSWORD=your_secure_password

# Run as root for anti-detection capabilities
# The VDI app itself will be started by supervisor
ENTRYPOINT ["/app/scripts/entrypoint.sh"]
