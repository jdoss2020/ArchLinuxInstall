#!/bin/bash

set -e

# Variables
PROCESSORTYPE=x86   # x86, armfh or aarch64
VIDEOCARD=''
HOMECOUNTRY='United States'
SECONDARYCOUNTRY='Canada'
EXECUSER='root'
SLICKGREETERFILE='/etc/lightdm/slick-greeter.conf'
LIGHTDMGTKGREETERFILE='/etc/lightdm/lightdm-gtk-greeter.conf'
SLICKGREETERBACKGROUND='/usr/share/backgrounds/linuxmint-tricia/hldinh_ma_pi_leng_pass.jpg' 
LIGHTDMCONFIGURATIONFILE='/etc/lightdm/lightdm.conf'
SSHPORT=50683
SSHCONFIGURATIONFILE='/etc/ssh/sshd_config'
SLEEPINTERVAL=10
LOCALNETWORK='192.168.1.0/24'
PIANOBARUSER='xxxxxxxxxx@gmail.com'
PIANOBARPWD='xxxxxxxxx'
PIANOBARSTART='58'
X86APPS='tor-browser brave-bin timeshift asunder brasero teams'
ARMAPPS='chromium-docker'
LCLST=''
MYTMZ=''
WHITE='\033[1;37m'
BLACK='\033[0;30m'
BLUE='\033[0;34m'
LIGHT_BLUE='\033[1;34m'
GREEN='\033[0;32m'
LIGHT_GREEN='\033[1;32m'
CYAN='\033[0;36m'
LIGHT_CYAN='\033[1;36m'
RED='\033[0;31m'
LIGHT_RED='\033[1;31m'
PURPLE='\033[0;35m'
LIGHT_PURPLE='\033[1;35m'
BROWN='\033[0;33m'
YELLOW='\033[1;33m'
GRAY='\033[0;30m'
LIGHT_GRAY='\033[0;37m'
TEST='\033[38;5;206m'
TEST1='\033[38;5;081m'
RESET=`tput sgr0`


#
#
function handleErrors() {
	clear
	set -uo pipefail
	trap 's=$?; echo "$0: Error no on line "$LINENO": $BASH_COMMAND"; exit $s' ERR
	clear
}
#
#
function determineUserAndHardwareInfo() {
	PROCESSORTYPE=`uname -m | cut -c1-3`
	
	OS_VERSION=$(grep -i "PRETTY_NAME" /etc/os-release  | awk -F'=' '{print $2}' | sed 's/"//g')
    NO_CPUS=$(lscpu  | grep  '^CPU(s):' | awk -F":" '{print $2}' | sed "s/^[ \t]*//")
    TOTAL_MEM=$(grep MemTotal /proc/meminfo | awk -F":" '{print $2}' | sed "s/^[ \t]*//")

	if [ $PROCESSORTYPE == "arm" ] || [ $PROCESSORTYPE == "aar" ]; then
		VIDEOCARD=`lspci | grep -oP '(?<=PCI bridge: )[^ ]*'`
		PROCESSORTYPE='arm'
	else
		VIDEOCARD=`lspci | grep -oP '(?<=VGA compatible controller: )[^ ]*'`
	fi

	if [ "$EUID" == 0 ]; then
		EXECUSER='root'
	else
		EXECUSER=$(whoami)
	fi

	sudo timedatectl set-ntp true
	MYTMZ="$(curl -s https://ipapi.co/timezone)"

	LCLGET1=$(curl -s https://ipapi.co/languages | head -c 2)
	LCLGET2=$(curl -s https://ipapi.co/country | head -c 2)
	LCLST="${LCLGET1}"_"${LCLGET2}.UTF-8"

	#printInformation
	echo "~~~~~~~~~~~~~~~~~~~~~~"
	echo " Information Gathered "
	echo "~~~~~~~~~~~~~~~~~~~~~~"
	echo -e "User is $EXECUSER"
	echo -e "Processor is $PROCESSORTYPE"
	echo -e "Video Card is $VIDEOCARD"
	echo -e "OS Version is $OS_VERSION"
	echo -e "Number of CPUs is $NO_CPUS"
	echo -e "Total Memory is $TOTAL_MEM"
	echo -e "Time zone is $MYTMZ"
	echo -e "Locale is $LCLST"
	sleep $SLEEPINTERVAL
}
#
#
function installSlickGreeter() {
	echo -e "Begin slick-greeter software installation\n"

	yay -Sy --needed lightdm lightdm-slick-greeter lightdm-settings mint-themes mint-x-icons mint-backgrounds-tricia

	# configure slick greeter file
	echo -ne "[Greeter]\nbackground=$SLICKGREETERBACKGROUND\nicon-theme-name=Mint-X\ntheme-name=Mint-X\n" | sudo tee $SLICKGREETERFILE

	# update lightdm file
	sudo sed -i 's/#greeter-session=example-gtk-gnome/greeter-session=lightdm-slick-greeter/' $LIGHTDMCONFIGURATIONFILE
	
	#enable lightdm service
	sudo systemctl enable lightdm.service 
	sleep $SLEEPINTERVAL
}
#
#
function installLightDMGTKGreeter() {
	echo -e "Begin lightdm-greeter software installation\n"

	yay -Sy --needed lightdm lightdm-gtk-greeter lightdm-gtk-greeter-settings lightdm-settings matcha-gtk-theme papirus-maia-icon-theme mint-backgrounds-tricia
	
	# configure lightdm-gtk greeter file
	echo -ne "[greeter]\ntheme-name=Matcha-dark-sea\nicon-theme-name=Papirus-Dark-Maia\nbackground=$SLICKGREETERBACKGROUND\nscreensaver-timeout=0\n" | sudo tee $LIGHTDMGTKGREETERFILE

	#enable lightdm service
	sudo systemctl enable lightdm.service 
	sleep $SLEEPINTERVAL
}
#
#
function installMultimedia {
	local MULTIMEDIAPACKAGES="pulseaudio vlc simplescreenrecorder cdrtools gstreamer gst-libav gst-plugins-base gst-plugins-base-libs gst-plugins-good gst-plugins-bad gst-plugins-ugly gstreamer-vaapi xvidcore frei0r-plugins cdrdao dvdauthor transcode alsa-utils alsa-plugins alsa-firmware pulseaudio-alsa pulseaudio-equalizer pulseaudio-jack ffmpeg ffmpegthumbnailer libdvdcss gimp gimp-extras imagemagick inkscape flac faad2 faac mjpegtools x265 x264 lame sox mencoder scribus blender pianobar pithos dcraw kodi kodi-addon-pvr-hts"

	if [ $PROCESSORTYPE == "x86" ]; then
	    touch ~/.gnupg/gpg.conf
	    echo "keyserver pool.sks-keyservers.net" > ~/.gnupg/gpg.conf
		MULTIMEDIAPACKAGES="$MULTIMEDIAPACKAGES spotify dropbox"
	fi

	yay -Sy --needed $MULTIMEDIAPACKAGES
	
	# configure command line Pandora client
	configurePianobar
	
	sleep $SLEEPINTERVAL
}
#
#
function installSSH {
	local CHOICE
	
	yay -Sy --needed openssh
	
	# harden ssh configuration
	read -p "Harden the SSH configuration? (Y or N)" CHOICE
	if [ $CHOICE == 'y' ] || [ $CHOICE == 'Y' ]; then
			echo 'exec sed command'
	    	sudo sed -i -e  "/^#Port 22/a Protocol 2" -e "s/^#Port 22/Port ${SSHPORT}/" -e "s/^#PermitRootLogin prohibit-password/PermitRootLogin no/" -e "s/^#IgnoreRhosts yes/IgnoreRhosts no/" -e "s/^#X11Forwarding no/X11Forwarding no/" -e "s/#PasswordAuthentication yes/PasswordAuthentication no/" $SSHCONFIGURATIONFILE
    fi
	ssh-keygen -t ecdsa -b 521
	sudo systemctl enable sshd.service
	sudo systemctl start sshd.service
	sleep $SLEEPINTERVAL
}
#
#
function installXorg() {
	yay -Sy --needed xorg-apps xorg-server xorg-drivers xorg-xkill xorg-xinit xterm mesa
	sleep $SLEEPINTERVAL
}
#
#
function installNetworking() {
	local NETWORKING="b43-fwcutter net-tools networkmanager networkmanager-openvpn nm-connection-editor network-manager-applet wget curl firefox chromium thunderbird wireless_tools nfs-utils nilfs-utils dhclient dnsmasq dmraid dnsutils openvpn openssh openssl samba whois iwd filezilla avahi openresolv youtube-dl vsftpd wpa_supplicant"

	if [ $PROCESSORTYPE == "x86" ]; then
	    NETWORKING="$NETWORKING expressvpn ipw2200-fw broadcom-wl-dkms ipw2100-fw amd-ucode intel-ucode"
    fi
    
    yay -Sy --needed $NETWORKING
    
    if [ $PROCESSORTYPE == "x86" ]; then
	    sudo systemctl enable expressvpn.service
	    sudo systemctl start expressvpn.service
	fi
	sleep $SLEEPINTERVAL
}
#
#
function installFontsAndThemes() {
	yay -Sy --needed ttf-ms-fonts ttf-ubuntu-font-family ttf-dejavu ttf-bitstream-vera ttf-liberation noto-fonts ttf-roboto ttf-opensans opendesktop-fonts cantarell-fonts freetype2 ttf-font-awesome nerd-fonts-ubuntu-mono matcha-gtk-theme papirus-icon-theme papirus-maia-icon-theme culmus culmus-fancy-ttf ttf-mononoki nerd-fonts-mononoki

	sleep $SLEEPINTERVAL
}
#
#
function installOfficeTools() {
	local OFFICETOOLS="libreoffice-fresh calibre dia scribus hyphen-en hunspell-en_US mythes-en libmythes libreoffice-extension-languagetool" 
	
	if [ $PROCESSORTYPE == "x86" ]; then
		OFFICETOOLS="$OFFICETOOLS drawio-desktop bitwarden joplin"
	fi

	yay -Sy --needed $OFFICETOOLS
	sleep $SLEEPINTERVAL
}
#
#
function installPrinting() {
	yay -Sy --needed system-config-printer foomatic-db foomatic-db-engine gutenprint hplip simple-scan cups cups-pdf cups-filters cups-pk-helper ghostscript gsfonts python-pillow python-pyqt5 python-pip python-reportlab

	# enable and start printing service
	sudo systemctl enable cups.service
	sudo systemctl start cups.service
	sleep $SLEEPINTERVAL
}
#
#
function installSystemUtilities()
{
	local SYSTEMUTILITIES="vim dkms p7zip haveged pacman-contrib pkgfile git diffutils jfsutils reiserfsprogs btrfs-progs f2fs-tools logrotate man-db man-pages mdadm perl s-nail texinfo which xfsprogs lsscsi sdparm sg3_utils smartmontools fuse2 fuse3 ntfs-3g exfat-utils gvfs gvfs-afc gvfs-goa gvfs-gphoto2 gvfs-mtp gvfs-nfs gvfs-smb unrar unzip unace xz xdg-user-dirs ddrescue dd_rescue testdisk hdparm htop rsync hardinfo bash-completion geany lsb-release polkit gufw ufw bleachbit packagekit gparted qt5ct accountsservice linux-firmware neofetch htop"

	if [ $PROCESSORTYPE == "x86" ]; then
		SYSTEMUTILITIES="$SYSTEMUTILITIES linux-lts-headers balena-etcher archiso-git aic94xx-firmware wd719x-firmware"
		if [ VIDEOCARD == "NVIDIA" ]; then
			SYSTEMUTILITIES="$SYSTEMUTILITIES nvidia-lts"
		fi
	fi

	yay -Sy --needed $SYSTEMUTILITIES

 	sleep $SLEEPINTERVAL
}
#
#
function installAURPackageManager() {
	#install aur tool
	git clone https://aur.archlinux.org/yay.git 
	cd yay
	makepkg -si
	cd .. && rm -rf yay
	
	#install alternate aur tool
	yay -Sy --needed paru-bin
	

    if [ $PROCESSORTYPE == "x86" ]; then
	    touch ~/.gnupg/gpg.conf
	    echo "keyserver pool.sks-keyservers.net" > ~/.gnupg/gpg.conf
    fi

	sleep $SLEEPINTERVAL
}
#
#
function installCinnamon() {
	local CINNAMON="cinnamon cinnamon-translations mint-themes mint-x-icons mint-y-icons mint-backgrounds-tara mint-backgrounds-tessa mint-backgrounds-tricia mint-backgrounds-ulyana gnome-terminal adwaita-icon-theme adapta-gtk-theme arc-gtk-theme arc-icon-theme gtk-engine-murrine gnome-keyring nemo nemo-share xed file-roller nemo-fileroller tmux tldr deluge gnome-disk-utility gufw polkit-gnome gnome-packagekit xcursor-dmz vlc audacious audacity rhythmbox rhythmbox-plugin-alternative-toolbar celluloid clementine gnome-calculator gnome-podcasts handbrake handbrake-cli avidemux-cli avidemux-qt p7zip gnome-todo gnome-notes gnome-photos gucharmap gnome-calendar firefox drawing pix hexchat xreader gnote xviewer seahorse redshift gnome-screenshot xed system-config-printer timeshift baobab gnome-font-viewer deluge gnome-logs gufw pamac-aur foliate" 

	if [ $PROCESSORTYPE == "x86" ]; then
		CINNAMON="$CINNAMON $X86APPS"
	else
		CINNAMON="$CINNAMON $ARMAPPS"
	fi

	yay -S --needed $CINNAMON
	installSlickGreeter
	sleep $SLEEPINTERVAL
}
#
#
function installGnome() {
	local GNOME="gnome gdm gnome-control-center gnome-terminal gnome-tweaks matcha-gtk-theme papirus-icon-theme papirus-maia-icon-theme xcursor-dmz noto-fonts ttf-hack chrome-gnome-shell pacman-contrib deluge gufw gnome-disk-utility polkit-gnome gnome-packagekit evince viewnior xcursor-dmz vlc audacious audacity rhythmbox rhythmbox-plugin-alternative-toolbar celluloid clementine gnome-calculator gnome-podcasts handbrake handbrake-cli avidemux-cli avidemux-qt p7zip gnome-notes gnome-photos dconf-editor ghex gnome-builder gnome-todo gnome-sound-recorder gnome-usage sysprof gnome-nettool gnome-shell-extensions gnome-keyring"
	local GNOMEEXTENSIONS="gnome-shell-extension-arch-update gnome-shell-extension-dash-to-dock gnome-shell-extension-clipboard-indicator gnome-shell-extension-openweather-git gnome-shell-extension-screenshot-git gnome-shell-extension-installer"
	
	if [ $PROCESSORTYPE == "x86" ]; then
		GNOME="$GNOME $X86APPS"
	else
		GNOME="$GNOME $ARMAPPS"
	fi
	
	yay -Sy --needed $GNOME
	
	# still need to install radio by hand
	yay -Sy --needed $GNOMEEXTENSIONS
	
	# remove virtualization from arm implementations
	if [ $PROCESSORTYPE == "arm" ]; then
		if yay -Qi gnome-boxes >/dev/null 2>/dev/null; then
			yay -Rns gnome-boxes
		fi
	fi
	
	# replace gnome-terminal with gnome-terminal-transparancy
	yay -Sy --needed gnome-terminal-transparency
	
	# install radio extension
	gnome-shell-extension-installer 836
	
	# enable gnome extensions
	gnome-extensions enable arch-update@RaphaelRochet
	gnome-extensions enable dash-to-dock@micxgx.gmail.com
	gnome-extensions enable clipboard-indicator@tudmotu.com
	gnome-extensions enable user-theme@gnome-shell-extensions.gcampax.github.com
	gnome-extensions enable workspace-indicator@gnome-shell-extensions.gcampax.github.com
	gnome-extensions enable openweather-extension@jenslody.de
	gnome-extensions enable gnome-shell-screenshot@ttll.de
	gnome-extensions enable auto-move-windows@gnome-shell-extensions.gcampax.github.com
	gnome-extensions enable radio@hslbck.gmail.com
	
	# configure gnome desktop settings (gsettings list-recursively)
	gsettings set org.gnome.desktop.interface gtk-theme 'Matcha-dark-sea'
	gsettings set org.gnome.shell.extensions.user-theme name 'Matcha-dark-sea'
	gsettings set org.gnome.desktop.interface icon-theme 'Papirus-Adapta-Nokto-Maia'
	gsettings set org.gnome.desktop.wm.preferences button-layout 'close,minimize,maximize:appmenu'
	gsettings set org.gnome.shell.overrides dynamic-workspaces true
	gsettings set org.gnome.mutter dynamic-workspaces true
	gsettings set org.gnome.shell.overrides workspaces-only-on-primary false
	gsettings set org.gnome.mutter workspaces-only-on-primary false
	if [ ! -d ~/.local/share/backgrounds ]; then  
        	mkdir -p ~/.local/share/backgrounds
        fi
	cp ~/Pictures/Wallpaper/0021.jpg ~/.local/share/backgrounds/.
	gsettings set org.gnome.desktop.background picture-uri 'file:///home/jdoss/.local/share/backgrounds/0021.jpg'
	gsettings set org.gnome.desktop.screensaver picture-uri 'file:///home/jdoss/.local/share/backgrounds/0021.jpg'
	gsettings set org.gnome.desktop.background picture-options 'zoom'
	gsettings set org.gnome.desktop.screensaver picture-options 'zoom'
	gsettings set org.gnome.shell.extensions.openweather city '39.365992,-76.9688737>Sykesville, Carroll County, Maryland, United States >-1'
	
	# dash-to-dock config
	gsettings set org.gnome.shell.extensions.dash-to-dock extend-height true
	gsettings set org.gnome.shell.extensions.dash-to-dock custom-theme-shrink true
	# set favorite apps for dash-to-dock (desktop configurations in /usr/share/applications)
	gsettings set org-gnome.shell favorite.apps "['chromium.desktop', 'org.gnome.Terminal.desktop', 'org.gnome.Nautilus.desktop', 'libreoffice-writer.desktop', 'libreoffice-calc.desktop', 'gimp.desktop', 'mpv.desktop', 'org.gnome.gedit.desktop']"
	
	# enable gnome greeter
	sudo systemctl enable gdm.service
	sleep $SLEEPINTERVAL
}
#
#
function installXFCE() {
	local XFCE="xfce4 xfce4-goodies galculator deluge pavucontrol xfburn libburn libisofs libisoburn xarchiver arc-gtk-theme arc-icon-theme gtk-engine-murrine adapta-gtk-theme polkit-gnome gnome-disk-utility gufw gnome-packagekit catfish"
	
	if [ $PROCESSORTYPE == "x86" ]; then
		XCFE="$XFCE $X86APPS"
	else
		XFCE="$XFCE $ARMAPPS"
	fi
	
	yay -Sy --needed $XFCE
	
	# enable slick greeter
	installSlickGreeter
	sleep $SLEEPINTERVAL
}
#
#
function installKDE() {
	local KDE="plasma breeze-icons kwrite qbittorrent pavucontrol-qt print-manager sweeper dolphin kdenlive k3b ark konsole gwenview okular kcalc packagekit-qt5 gufw deluge timeshift sddm sddm-kcm kde-applications"
	
	if [ $PROCESSORTYPE == "x86" ]; then
		KDE="$KDE $X86APPS"
	else
		KDE="$KDE $ARMAPPS"
	fi
	
	yay -Sy --needed $KDE

	# enable kde greeter
	sudo systemctl enable sddm.service
	sleep $SLEEPINTERVAL
}
#
#
function installMate() {
	local MATE="mate mate-extra mate-utils mate-applet-dock adapta-gtk-theme arc-gtk-theme arc-icon-theme gtk-engine-murrine deluge gnome-disk-utility gufw mate-polkit gnome-packagekit mate-media mate-tweak network-manager-applet mate-power-manager system-config-printer mate-screensaver mate-screensaver-hacks mate-applet-dock mate-applet-streamer engrampa kvantum-qt5 mate-calc mate-utils materia-gtk-theme pluma"

	if [ $PROCESSORTYPE == "x86" ]; then
		MATE="$MATE $X86APPS"
	else
		MATE="$MATE $ARMAPPS"
	fi
	
	yay -Sy --needed $MATE
	
	# enable slick greeter
	installSlickGreeter
	sleep $SLEEPINTERVAL
}
#
#
function installLXQT() {
	local LXQT="lxqt openbox obconf-qt pcmanfm-qt lxqt-sudo breeze-icons qterminal kwrite networkmanager-qt qbittorrent pavucontrol-qt kdenlive k3b xarchiver galculator polkit-qt5 packagekit-qt5 xscreensaver"
	
	if [ $PROCESSORTYPE == "x86" ]; then
		LXQT="$LXQT $X86APPS"
	else
		LXQT="$LXQT $ARMAPPS"
	fi
	
	yay -Sy --needed $LXQT
	
	# enable lightdm greeter
	installLightDMGTKGreeter
	sleep $SLEEPINTERVAL
}
#
#
function installBudgie() {
	local BUDGIE="budgie-desktop gnome-control-center nautilus plata-theme vlc audacious audacity rhythmbox rhythmbox-plugin-alternative-toolbar celluloid clementine gnome-terminal gnome-calculator gnome-podcasts handbrake handbrake-cli avidemux-cli avidemux-qt p7zip gnome-todo gnome-notes gnome-photos deluge gufw gnome-disk-utility gufw polkit-gnome gnome-packagekit evince viewnior"
	
	if [ $PROCESSORTYPE == "x86" ]; then
		BUDGIE="$BUDGIE $X86APPS"
	else
		BUDGIE="$BUDGIE $ARMAPPS"
	fi
	
	yay -S --needed $BUDGIE
	# enable slick greeter
	installSlickGreeter
	sleep $SLEEPINTERVAL
}
#
#
function installi3wm() {
	local I3WM="hunspell-en_US alacritty i3-gaps i3lock-color i3status i3blocks dmenu terminator firefox chromium picom polybar nitrogen ttf-font-awesome dconf qutebrowser vim vifm flameshot trizen pyradio-git htop alacritty youtube-viewer pcmanfm lxappearance mpv vlc deadbeef jq materia-gtk-theme mint-backgrounds-tricia nerd-fonts-droid-sans-mono nerd-fonts-ubuntu-mono papirus-icon-theme network-manager-applet trayer volumeicon polkit-gnome htop lightdm-gtk-greeter-settings luit wireless_tools flex rofi librewolf-bin gnome-calculator mousepad vscodium-bin remmina scribus avidemux-qt avidemux-cli handbrake handbrake-cli foliate gnome-todo liferea"

	if [ $PROCESSORTYPE == "x86" ]; then
		I3WM="$I3WM $X86APPS"
	else
		I3WM="$I3WM $ARMAPPS"
	fi

	yay -Sy --needed $I3WM
 
 	# clone i3 configuration
	git clone https://github.com/jdoss2020/dotfiles.git ~/Downloads/i3_config
	
	# configure i3
	mv -i ~/Downloads/i3_config/.config/* ~/.config/.
	#set executable permissions
	find ~/.config -name "*.sh" -exec chmod +x {} \; 
	find ~/.config -name "*.py" -exec chmod +x {} \;
	chmod +x ~/.config/scripts/*

	# enable lightdm-gtk-greeter
	installLightDMGTKGreeter
	sleep $SLEEPINTERVAL
}
#
#
function configurePianobar() {
	# fix sound on pianobar
	sudo sh -c 'echo "default_driver=pulse" > /etc/libao.conf'
	if [[ ! -d ~/.config/pianobar ]]; then
		mkdir ~/.config/pianobar
	fi
	touch ~/.config/pianobar/config
	echo -en "audio_quality = high\nautostart_station = $PIANOBARSTART\npassword = $PIANOBARPWD\nuser = $PIANOBARUSER\n" > ~/.config/pianobar/config
}
#
#
function installWallpapers() {
	git clone https://gitlab.com/dwt1/wallpapers.git ~/Pictures/Wallpaper
	sleep $SLEEPINTERVAL
}
#
#
function installVMWare() {
	yay -Sy --needed vmware-workstation fuse2 gtkmm linux-lts-headers ncurses5-compat-libs libcanberra pcsclite open-vm-tools xf86-video-vmware

	# enable and start vmware services
	systemctl enable vmtoolsd.service vmware-vmblock-fuse.service vmware-networks.service vmware-usbarbitrator.service vmware-hostd.service
	systemctl start vmtoolsd.service vmware-vmblock-fuse.service vmware-networks.service vmware-usbarbitrator.service vmware-hostd.service

	# load vmware modules into the kernel
	sudo modprobe -a vmw_vmci vmmon
	sleep $SLEEPINTERVAL
}
#
#
function installVirtualBox() {
	local CHOICE USERID

	yay -Sy --needed virtualbox virtualbox-host-modules-arch virtualbox-guest-iso virtualbox-ext-oracle

	# load virtual box driver into the kernel
	sudo modprobe vboxdrv

	read -p "Add user to the virtualbox user's group? (Y or N)" CHOICE

	case $CHOICE in
		y|Y) 	read -p "Enter desired user id or Q to quit" USERID
			if [ $USERID == "q" ] || [ $USERID == "Q" ]; then
				break
			else
				sudo usermod -aG vboxuser $USERID
			fi			
			;;
		*) break ;;
	esac

	sleep $SLEEPINTERVAL
}
#
#
function installKVM() {
	local CHOICE
	
	yay -Sy --needed virt-manager virt-viewer dnsmasq vde2 bridge-utils openbsd-netcat libguestfs ebtables iptables dnsmasq dmidecode	

	# start kvm/qemu
	sudo systemctl enable libvirtd.service
	sudo systemctl start libvirtd.service

	# add user to libvert group
	sudo newgrp libvirt
	sudo usermod -aG libvert $(whoami)

	# list libvert networks
	sudo virsh net-list --all

	# build the libvert network if needed
	read -p "Build the default libvert network? (Y or N)" CHOICE
	if [ $CHOICE == 'y' ] || [ $CHOICE == 'Y' ]; then
		sudo virsh net-define --file /etc/libvirt/qemu/networks/default.xml
		sudo virsh net-autostart --network default
	fi

	sleep $SLEEPINTERVAL
}
#
#
function installCron() {
	yay -Sy --needed cronie
	sudo systemctl enable cronie.service
	sleep $SLEEPINTERVAL
}
#
#
function configureRepositories() {
    if [ $PROCESSORTYPE == "arm" ]; then
		echo "Reflector not available for arm processors at this time"
	else
		yay -Sy --needed reflector

		# pick fastest and most recently update repositories for home country
		sudo reflector -c "${HOMECOUNTRY}" -a 15 --sort rate --save /etc/pacman.d/mirrorlist
		sudo pacman -Syyy

		# show the results of reflector
		cat /etc/pacman.d/mirrorlist
	fi
	sleep $SLEEPINTERVAL
}
#
#
function createUserDirs() {
	yay -Sy --needed xdg-user-dirs 
	xdg-user-dirs-update
	sleep $SLEEPINTERVAL
}
#
#
function installNTP() {
	echo "Start Network Time Protocol Configuration"
	sudo systemctl enable systemd-timesyncd.service
	sudo systemctl start systemd-timesyncd.service
	sleep $SLEEPINTERVAL
}
#
#
function installTVHeadend() {
	yay -Sy --needed tvheadend xmltv ufw kodi-addon-pvr-hts kodi libiconv

	sudo systemctl enable tvheadend.service
	sudo systemctl start tvheadend.service

	# open ports on firewall
	sudo ufw enable
	sudo ufw default deny incoming
	sudo ufw default allow outgoing
	sudo ufw allow proto tcp from 192.168.1.0/24 to any port 9981
	sudo ufw allow proto tcp from 192.168.1.0/24 to any port 9982
	sudo ufw status numbered

	sudo systemctl enable ufw.service

	sleep $SLEEPINTERVAL
}
#
#
function activateFirewall() {
	yay -Sy --needed gufw ufw

	sudo ufw enable
	sudo ufw default deny incoming
	sudo ufw default allow outgoing

	sudo systemctl enable ufw.service
	sudo systemctl start ufw.service
	sleep $SLEEPINTERVAL
}
function activateNetworkManager() {
	sudo systemctl disable dhcpcd.service
	sudo systemctl enable NetworkManager.service
	sleep $SLEEPINTERVAL
}
#
#
function installLatex() {
	yay -Sy --needed texmaker texstudio texlive-bibtexextra texlive-bin texlive-core texlive-fontsextra texlive-formatsextra texlive-games texlive-humanities texlive-langchinese texlive-langcyrillic texlive-langextra texlive-langgreek texlive-langjapanese texlive-langkorean texlive-latexextra texlive-music texlive-pictures texlive-pstricks texlive-publishers texlive-science tex-gyre-fonts libreoffice-extension-writer2latex evince

	sleep $SLEEPINTERVAL
}
#
#
installVirtualMachines() {
	if [ $PROCESSORTYPE == "x86" ]; then
		local CHOICE
		while true; do
			clear
			echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
			echo " Desktop/Work Manager Selections "
			echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
			echo " 1. VMWare"
			echo " 2. VirtualBox"
			echo " 3. KVM"
			echo " 4. Return"
			read -p "Enter choice [1 - 4] " CHOICE

			case $CHOICE in
				1) installVMWare ;;
				2) installVirtualBox ;;
				3) installKVM ;;
				4) break ;;
				*) echo -e "${RED}Error...${CHOICE} is an invalid selection. ${RESET}" && sleep 2
			esac
		done

	else
		echo "Virtual Machines not supported on $PROCESSORTYPE processors."
		sleep 5
	fi
}
#
#
function installDesktops() {
	local CHOICE
	while true; do
		clear
		echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
		echo -e " ${TEST}Desktop/Work Manager Selections ${RESET} "
		echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
		echo -e " ${TEST1}1. Cinnamon"
		echo " 2. Gnome"
		echo " 3. KDE"
		echo " 4. XFCE"
		echo " 5. Mate"
		echo " 6. LXQT"
		echo " 7. Budgie"
		echo " 8. i3wm"
		echo -e " 9. Return ${RESET}"
		read -p "Enter choice [1 - 9] " CHOICE

		case $CHOICE in
			1) installCinnamon ;;
			2) installGnome ;;
			3) installKDE ;;
			4) installXFCE ;;
			5) installMate ;;
			6) installLXQT ;;
			7) installBudgie ;;
			8) installi3wm ;;
			9) break ;;
			*) echo -e "${RED}Error...${CHOICE} is an invalid selection. ${RESET}" && sleep 2
		esac
	done
}
#
#
function show_menus() {
	clear
	echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
	echo -e "                           ${TEST}Installation Selections ${RESET} "
	echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
	echo -e " ${TEST1} 1. AUR Package Manager (required)		11. Install Wallpapers"
	echo "  2. Optimize Package Repositories		12. Desktop or Window Manager"
	echo "  3. Xorg					13. Virtual Machines"
	echo "  4. System Utilities				14. Cron"
	echo "  5. Networking					15. Create User Directories"
	echo "  6. Multimedia					16. Network Time Protocol"
	echo "  7. Fonts & Themes				17. Over the Air TV"
	echo "  8. Office Tools				18. Activate Firewall"
	echo "  9. Printing					19. Latex"
	echo " 10. SSH					20. Activate Network Manager"
	echo " "
	echo -e " 21. Exit ${RESET}"
}
#
#
read_options() {
	local CHOICE
	read -p "Enter choice [ 1 - 21] " CHOICE
	case $CHOICE in
		1) installAURPackageManager ;;
		2) configureRepositories ;;
		3) installXorg ;;
		4) installSystemUtilities ;;
		5) installNetworking ;;
		6) installMultimedia ;;
		7) installFontsAndThemes ;;
		8) installOfficeTools ;;
		9) installPrinting ;;
		10) installSSH ;;
		11) installWallpapers ;;
		12) installDesktops ;;
		13) installVirtualMachines ;;
		14) installCron ;;
		15) createUserDirs ;;
		16) installNTP ;;
		17) installTVHeadend ;;
		18) activateFirewall ;;
		19) installLatex ;;
		20) activateNetworkManager ;;
		21) exit 0;;
		*) echo -e "${RED}Error...${choice} is an invalid selection. ${RESET}" && sleep 2
	esac

}

# ------------------------------------
# Trap CTRL+C, CTRL+Z and quit signals
# ------------------------------------
trap '' SIGINT SIGQUIT SIGTSTP
# ---- 
#
# Main Logic
#-----------

handleErrors
determineUserAndHardwareInfo

# execution loop
while true
do
	show_menus
	read_options
done
