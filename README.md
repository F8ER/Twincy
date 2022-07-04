# Disclaimer

This project is for educational purposes only. The authors do not endorse or promote any illegal activities.

# General

`./twincy -h`:
```




                ▄▄▄█████▓ █     █░ ██▓ ███▄    █  ▄████▄▓██   ██▓
                ▓  ██▒ ▓▒▓█░ █ ░█░▓██▒ ██ ▀█   █ ▒██▀ ▀█ ▒██  ██▒
                ▒ ▓██░ ▒░▒█░ █ ░█ ▒██▒▓██  ▀█ ██▒▒▓█    ▄ ▒██ ██░
                ░ ▓██▓ ░ ░█░ █ ░█ ░██░▓██▒  ▐▌██▒▒▓▓▄ ▄██▒░ ▐██▓░
                  ▒██▒ ░ ░░██▒██▓ ░██░▒██░   ▓██░▒ ▓███▀ ░░ ██▒▓░
                  ▒ ░░   ░ ▓░▒ ▒  ░▓  ░ ▒░   ▒ ▒ ░ ░▒ ▒  ░ ██▒▒▒ 
                    ░      ▒ ░ ░   ▒ ░░ ░░   ░ ▒░  ░  ▒  ▓██ ░▒░ 
                  ░        ░   ░   ▒ ░   ░   ░ ░ ░       ▒ ▒ ░░  
                             ░     ░           ░ ░ ░     ░ ░     
                                                 ░       ░ ░     


  Title: Twincy
  Version: v0.9 (2022)
  Description: Automated WPA/WPA2 twin attack
  Author: Faither

 --------------------------------------------------------------------------------

  Properties:
    -D - Main 802.11 device name (e.g. phy0)
    -d - Secondary 802.11 device name (e.g. phy1)
    -u - Non-root user
    -b - Target BSSID (e.g. 00:11:22:33:44:55)
    -s - Target SSID (characters [,'\] are currently unsupported)
    -c - Target channel
    -H - Handshake filepath
    -w - Web design name
    -T - Temporary data dirpath
    -L - Dump output log filepath
    -v - Verbosity [0-5]

  Flags:
    -i - Ignore existing handshakes
    -S - Clear session on exit
    -l - List found 802.11 devices and exit
    -h - Print help and exit {--help}

 --------------------------------------------------------------------------------

  Mandatory options for general usage: Ddu
  Temporary data is inside session by default
```

## Preview

[![Watch the video](https://user-images.githubusercontent.com/25136754/177021469-5f2b774a-e647-4e16-8633-43757d39297b.png)](https://mega.nz/file/tdsC0SrT#Qa3irO0VjBRGiP_6WcXd6r6wnfVRjOwh4aotd_Pk_mE) 

## Install

Dependencies: `aircrack-ng`, `mdk4`, `xdotool`, `tshark`, `php-cgi`, `lighttpd`, `isc-dhcp-server`, `hostapd`, `wpasupplicant`.

```bash
# sudo apt-get update && sudo apt-get install -y aircrack-ng mdk4;
sudo apt-get update && sudo apt-get install -y \
	build-essential autoconf automake libtool pkg-config libnl-3-dev libnl-genl-3-dev libssl-dev \
	ethtool shtool rfkill zlib1g-dev libpcap-dev libsqlite3-dev libpcre3-dev libhwloc-dev \
	libcmocka-dev hostapd wpasupplicant tcpdump screen iw usbutils;
mkdir './dependencies' && pushd './dependencies';

# Aircrack-ng
git clone 'https://github.com/aircrack-ng/aircrack-ng.git' &&
	pushd './aircrack-ng' &&
	'./autogen.sh' && './configure' && make && make install &&
	popd &&
	stat './aircrack-ng/aircrack-ng' './aircrack-ng/airodump-ng' './aircrack-ng/scripts/airmon-ng';

# MDK4
git clone 'https://github.com/aircrack-ng/mdk4.git' &&
	pushd './mdk4' &&
	make && make install &&
	popd &&
	stat './mdk4/src/mdk4';

popd;
# rm -rf './dependencies';
sudo apt-get install -y xdotool tshark php-cgi lighttpd isc-dhcp-server wpasupplicant;
```

## Sounds

```
ap-lost ~ twirl-470
ap_found ~ ill-make-it-possible-notification
handshake_found ~ message-ringtone-magic
ap-details_found ~ that-was-quick-606
psk_correct ~ ringtone-you-would-be-glad-to-know
psk_incorrect ~ confident-543
```

Source of the sound files: https://notificationsounds.com

# Related

https://github.com/vk496/linset  
https://github.com/aircrack-ng/aircrack-ng
