# syntax=docker/dockerfile:1

ARG ARCH_VERSION=latest
FROM archlinux:$ARCH_VERSION

RUN pacman -Syyu --noconfirm && pacman -S --noconfirm \
  base-devel \
  pacman-contrib \
  tigervnc xorg \
  wget bc sudo \
  xfce4 \
  git \
  neovim \
  firefox

ARG USER_NAME=headless HOME_DIRECTORY=/headless
RUN set -x && useradd -m -G wheel --create-home -d ${HOME_DIRECTORY} -p "$(openssl passwd -2 changeme)" ${USER_NAME} && \
  echo ${USER_NAME} "ALL=(ALL:ALL)" NOPASSWD:ALL > /etc/sudoers.d/${USER_NAME} && \
  echo %wheel "ALL=(ALL)" NOPASSWD:ALL > /etc/sudoers.d/wheel && \
  install -d -m 0755 -o ${USER_NAME} ${HOME_DIRECTORY}/.vnc

# TODO: this is x86 only
ARG DUMB_INIT_VERSION=1.2.5
RUN wget -O /usr/local/bin/dumb-init "https://github.com/Yelp/dumb-init/releases/download/v${DUMB_INIT_VERSION}/dumb-init_${DUMB_INIT_VERSION}_x86_64" && \
  chmod +x /usr/local/bin/dumb-init

USER ${USER_NAME}
RUN cd ~ && \
  git clone https://aur.archlinux.org/paru-bin.git && \
  pushd paru-bin && \
  makepkg -si --needed --noconfirm && \
  popd && \
  rm -rf .cache paru-bin/
USER 0


RUN printf '[Desktop Entry]\n\
  Version=1.0\n\
  Name=Xfce4vnc Session\n\
  Comment=Use this session to run Xfce in a virtual vnc server\n\
  Exec=startxfce4\n\
  Icon=\n\
  Type=Application\n\
  DesktopNames=XFCE4VNC' | sed 's/^\s*//g' | tee /usr/share/xsessions/xfce4vnc.desktop

COPY ./entrypoint /entrypoint
RUN chmod +x /entrypoint

ENV DISPLAY=:1 EDITOR=nvim

ENV VNC_PASSWORD=ArchVNCPW VNC_RESOLUTION=

VOLUME ${HOME_DIRECTORY}/.vnc

EXPOSE 5901 5801

USER ${USER_NAME}
ENTRYPOINT ["/usr/local/bin/dumb-init", "--"]

CMD ["/entrypoint"]
