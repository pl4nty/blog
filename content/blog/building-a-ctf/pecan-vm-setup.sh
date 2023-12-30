#!/bin/zsh

# idleagent can't parse these ttys
sudo systemctl mask serial-getty@ttyS0
sudo systemctl stop serial-getty@ttyS0
sudo systemctl mask getty@tty1
sudo systemctl stop getty@tty1

# idleagent requires libssl1.1, but it was removed from the repos in 2023.2
wget http://old.kali.org/kali/pool/main/o/openssl/libssl1.1_1.1.0h-4_amd64.deb
sudo dpkg -i libssl1.1_1.1.0h-4_amd64.deb
rm libssl1.1_1.1.0h-4_amd64.deb
sudo sed -i \
-e 's/^\(.*kali\.cnf\)/#\1/g' \
-e 's/^\(.*kali_wide_compatibility_providers\)/#\1/g' \
-e 's/^\(.*ssl_conf\)/#\1/g' \
/etc/ssl/openssl.cnf

sudo systemctl restart idleagent

# kali image builder overrides with rolling for some reason
sudo sed -ie 's/kali-rolling/kali-last-snapshot/g' /etc/apt/sources.list
sudo apt-get update

# kali-desktop-xfce minus network-manager-gnome, since it's not compatible with waagent
# pipewire-alsa not compatible with xfce4?
sudo apt install -y atril engrampa kali-desktop-core libspa-0.2-bluetooth lightdm mate-calc mousepad parole pipewire-alsa pipewire-pulse policykit-1-gnome qt5ct qterminal ristretto thunar-archive-plugin thunar-gtkhash wireplumber xcape xdg-user-dirs-gtk xfce4 xfce4-cpugraph-plugin xfce4-genmon-plugin xfce4-power-manager-plugins xfce4-screenshooter xfce4-taskmanager xfce4-whiskermenu-plugin
# kali-linux-everything causes shutdowns after 30 mins or so from hv_utils
sudo apt install -y kali-linux-default

# https://www.kali.org/docs/general-use/xfce-with-rdp/
# xRDP, xorg already installed? latest is 1:7.7+23
sudo apt-get install -y xrdp

sudo sysctl -w net.core.wmem_max=8388608
sudo sed -ie 's|^ *KillDisconnected=.*|KillDisconnected=true|' /etc/xrdp/sesman.ini
sudo sed -i \
-e 's|^ *#tcp_send_buffer_bytes=.*|tcp_send_buffer_bytes=4194304|' \
-e 's|^ *crypt_level=.*|crypt_level=none|' \
-e 's|^ *max_bpp=.*|max_bpp=16|' \
/etc/xrdp/xrdp.ini

xfconf-query --channel=xfwm4 --property=/general/use_compositing --type=bool --set=false --create

cat <<EOF | sudo tee /etc/polkit-1/localauthority/50-local.d/45-allow-colord.pkla
[Allow Colord all Users]
Identity=unix-user:*
Action=org.freedesktop.color-manager.create-device;org.freedesktop.color-manager.create-profile;org.freedesktop.color-manager.delete-device;org.freedesktop.color-manager.delete-profile;org.freedesktop.color-manager.modify-device;org.freedesktop.color-manager.modify-profile
ResultAny=no
ResultInactive=no
ResultActive=yes
EOF

sudo systemctl enable xrdp --now

sudo apt-get install -y torbrowser-launcher

git clone https://github.com/volatilityfoundation/volatility3.git

wget https://github.com/icsharpcode/AvaloniaILSpy/releases/latest/download/Linux.x64.Release.zip
unzip Linux.x64.Release.zip && unzip ILSpy-linux-x64-Release.zip -d AvaloniaILSpy
rm Linux.x64.Release.zip ILSpy-linux-x64-Release.zip

# https://learn.microsoft.com/en-us/azure/virtual-machines/linux/create-upload-ubuntu#manual-steps
rm -f ~/.zsh_history && kill -9 $$
