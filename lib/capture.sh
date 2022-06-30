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

declare -r _Lib_capture=1;
declare -r _Capture_sourceFilepath="$( readlink -e -- "${BASH_SOURCE[0]:-$0}" 2> '/dev/null'; )";
declare -r _Capture_sourceDirpath="$( dirname -- "$_Capture_sourceFilepath" 2> '/dev/null'; )";

[[ ! -f "$_Capture_sourceFilepath" || ! -d "$_Capture_sourceDirpath" ]] && exit 199;

# File names

declare -r Capture_captureFilenamePrefix='capture';

# Directory names

declare -r Capture_capturesDirname='captures';

# Directory paths

declare -r Capture_capturesDirpath="${Environment_SessionDirpath}/${Capture_capturesDirname}";

############################################################
# Functions                                                #
############################################################

Capture_previewAPDetails()
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

############################################################
# Methods                                                  #
############################################################

Capture_Filter()
{
	###########
	# Options #
	###########

	declare args;

	if ! Options args \
		'@1/^(?:[0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}$/' \
		'?!-c;?!-b;?!-o;-f;-v' \
		"$@";
	then
		Misc_PrintF -v 1 -t 'f' -nf $'[Capture_Filter] Invalid options (code %s, index %s ~ \'%s\'): \'%s\'' -- \
			"$_Options_ResultCode" \
			"$_Options_FailIndex" \
			"$_Options_ErrorMessage" \
			"$( Misc_ArrayJoin -- "$@" )";

		exit 200;
	fi

	declare captureFilepath="${args[0]}";
	declare apBssid="${args[1]}";
	declare outputVariableReferenceName="${args[2]}";
	declare overwrite="${args[3]}";
	declare verbose="${args[4]}";

	if [ "$outputVariableReferenceName" != '' ]
	then
		if [ "$outputVariableReferenceName" = 'Capture_Filter_outputVariableReference' ];
		then
			Misc_PrintF -v 1 -t 'f' -nf $'[Capture_Filter] Output variable reference interference: \'%s\'' -- "$( Misc_ArrayJoin -- "$@" )";

			return 100;
		fi

		declare -n Capture_Filter_outputVariableReference="$outputVariableReferenceName";
		Capture_Filter_outputVariableReference='';
	fi

	########
	# Main #
	########

	[[ "$verbose" != 0 ]] && Misc_PrintF -v 4 -t 'i' -nf $'Filtering capture file: \'%s\'' -- "$captureFilepath";

	# If no such capture file exists
	if ! Base_FsExists -t 1 "$captureFilepath";
	then
		[[ "$verbose" != 0 ]] && Misc_PrintF -v 2 -t 'e' -n -- 'Could not filter capture file (no such exists)';

		return 2;
	fi

	# Todo: Check if actually filetered (e.g. via tshark)
	if [[ "$( basename -- "$captureFilepath" 2> '/dev/null'; )" =~ \-filtered\.cap$ ]];
	then
		[[ "$verbose" != 0 ]] && Misc_PrintF -v 4 -t 'i' -n -- $'Capture file is already filtered';
		Capture_Filter_outputVariableReference="$captureFilepath";

		return 0;
	fi

	# Add "-filtered" to the result file
	declare captureFilteredFilepath="${captureFilepath%\.*}-filtered.${captureFilepath##*\.}";

	# If such capture file exists
	if Base_FsExists -t f "$captureFilteredFilepath";
	then
		if [[ "$overwrite" == 0 ]];
		then
			[[ "$verbose" != 0 ]] && Misc_PrintF -v 4 -t 'i' -n -- $'Capture file already has filtered version';
			Capture_Filter_outputVariableReference="$captureFilteredFilepath";

			return 0;
		fi

		if ! Base_FsDelete -t f -- "$captureFilteredFilepath";
		then
			[[ "$verbose" != 0 ]] && Misc_PrintF -v 2 -t 'e' -n -- $'Failed to remove already filtered capture';

			return 1;
		fi

		[[ "$verbose" != 0 ]] && Misc_PrintF -v 4 -t 'i' -n -- $'Removed already filtered version';
	fi

	# Generate a name and regenerate if already exists in termorary and persistent destinations

	declare captureFilteredFilepathTemp='';
	declare captureId='';

	while
		[ "$captureFilteredFilepathTemp" = '' ] || 
		Base_FsExists -- "$captureFilteredFilepathTemp" ||
		Base_FsExists -- "${Capture_capturesDirpath}/$( basename -- "$captureFilteredFilepathTemp" 2> '/dev/null'; )"
	do
		declare captureId="$(Misc_RandomString 8)";
		declare captureFilteredFilepathTemp="${Environment_TempDirpath}/$( basename -- "$captureFilepath" '.cap' 2> '/dev/null'; )-${captureId}-filtered.cap";
	done

	# Filter the capture file, sort unique APs, and save the result to a new file
	# (note: tshark may return 2 exit code if the capture was cut in the middle (e.g. already filtered))
	# New file in "temp" is required in case it's no accessible by the alternative user

	declare Capture_Filter_captureFilter='';
	declare filterBssid='!(wlan.ta == 00:00:00:00:00:00) && !(wlan.ta == ff:ff:ff:ff:ff:ff)'; # wlan.bssid != ...

	if [ "$apBssid" != '' ];
	then
		declare filterBssid="wlan.ta == ${apBssid}";
	fi

	# tshatk -r... -Y "$filter" (one-pass)...; tshark -r... -R2 "$filter" (two-pass)...
	Environment_ProcessStart -o Capture_Filter_captureFilter -- \
		"sudo -u '${Environment_UserNonRoot}' \
			tshark -r '${captureFilepath}' \
				-Y '${filterBssid} && \
				( \
					wlan.fc.type_subtype == 0x08 ||
					wlan.fc.type_subtype == 0x00 || wlan.fc.type_subtype == 0x01 ||
					wlan.fc.type_subtype == 0x02 || wlan.fc.type_subtype == 0x03 ||
					wlan.fc.type_subtype == 0x04 || wlan.fc.type_subtype == 0x05 ||
					wlan.fc.type_subtype == 0x0B ||
					eapol ||
					((wlan.fc.type_subtype == 0x20 || wlan.fc.type_subtype == 0x28) && wlan.seq <= 2)
				)' \
				-F pcap -w '${captureFilteredFilepathTemp}'";

	# Check if filter succeeded and the new file exists

	if [[ ! "$Capture_Filter_captureFilter" =~ ^[02]$ ]] || ! Base_FsExists -t 1 "$captureFilteredFilepathTemp";
	then
		[[ "$verbose" != 0 ]] && Misc_PrintF -v 2 -t 'e' -nmf $'Failed to filter capture file (%s): \'%s\'' -- \
			"$( [[ ! "$Capture_Filter_captureFilter" =~ ^[02]$ ]] && printf 'code %s' "$Capture_Filter_captureFilter" || printf 'no such file' )" "$captureFilepath";

		return 4
	fi

	# Move the filtered post-fixed capture file from "temp" to the initial directory

	if ! Base_FsMove -ft 1 -- "$captureFilteredFilepathTemp" "$captureFilteredFilepath";
	then
		[[ "$verbose" != 0 ]] && Misc_PrintF -v 2 -t 'e' -nmf $'Failed to filter capture file (failed to move file): \'%s\' -> \'%s\'' -- \
			"$captureFilteredFilepathTemp" \
			"$captureFilteredFilepath";

		return 6;
	fi

	# declare captureFilteredFilepathTemp="${Capture_capturesDirpath}/$( basename -- "$captureFilteredFilepathTemp" 2> '/dev/null'; )";
	Capture_Filter_outputVariableReference="$captureFilteredFilepath";

	[[ "$verbose" != 0 ]] && Misc_PrintF -v 5 -t 'd' -nmf $'Filtered (EAPOL) capture file (%s): \'%s\' -> \'%s\'' -- \
		"$( [ "$apBssid" != '' ] && printf '%s' "$apBssid" || printf 'general' )" \
		"$captureFilepath" \
		"$captureFilteredFilepath";

	return 0;
}

Capture_Start()
{
	declare args;

	if ! Options args \
		'?!-d;?--bm;?-a;?-c;?-s;?-w;?-W;?-f;?-x;?-o;-C;-v' \
		"$@";
	then
		Misc_PrintF -v 1 -t 'f' -nf $'[Capture_Start] Invalid options (code %s, index %s ~ \'%s\'): \'%s\'' -- \
			"$_Options_ResultCode" \
			"$_Options_FailIndex" \
			"$_Options_ErrorMessage" \
			"$( Misc_ArrayJoin -- "$@" )";

		exit 200;
	fi

	declare device="${args[0]}";
	declare processBindMeta="${args[1]}";
	declare apBssid="${args[2]}";
	declare apChannel="${args[3]}";
	declare apSsid="${args[4]}";
	declare captureWaitTime="${args[5]}";
	declare captureWaitTimeout="${args[6]}";
	declare captureFilepathExplicit="${args[7]}";
	declare windowParameters="${args[8]}";
	declare outputVariableReferenceName="${args[9]}";
	declare highlightApActiveColor="${args[10]}";
	declare verbose="${args[11]}";

	if [ "$outputVariableReferenceName" != '' ];
	then
		if [ "$outputVariableReferenceName" = 'Capture_Start_outputVariableReference' ];
		then
			Misc_PrintF -v 1 -t 'f' -nf $'[Capture_Start] Output variable reference interference: \'%s\'' -- \
				"$( Misc_ArrayJoin -- "$@" )";

			return 100;
		fi

		# Set the reference variable to the element count
		declare -n Capture_Start_outputVariableReference="$outputVariableReferenceName";
		Capture_Start_outputVariableReference='';
	fi

	if [[ "$captureWaitTime" == '' ]];
	then
		captureWaitTime=-1; # Infinite
	fi

	if [[ "$captureWaitTimeout" = '' ]];
	then
		declare captureWaitTimeout=1;
	fi

	########
	# Main #
	########

	[[ "$verbose" != 0 ]] && Misc_PrintF -v 4 -t 'i' -nmf $'Starting AP capture %s' -- "$( Capture_previewAPDetails "$apBssid" "$apChannel" "$apSsid" )";

	if printf '%s' "$apSsid" | grep -q $',\|\'\|\\\\';
	then
		Misc_PrintF -v 2 -t 'e' -nf $'Characters [comma, \', \\\\] are currently unsupported in SSID for capture: \'%s\'' -- "$apSsid";

		return 1;
	fi

	# Create "captures" directory if doesn't exist

	if ! Base_FsDirectoryCreate -p -- "$Capture_capturesDirpath";
	then
		Misc_PrintF -v 2 -t 'e' -nnmf $'Could not form proper workspace file structure for capture: \'%s\'' -- \
			"$Environment_resourcesDirpath";

		return 3;
	fi

	# Interface

	declare Capture_Start_interface;

	if ! Interface_ModeSet -im 1 -- "$device" || ! Interface_FromDevice -o Capture_Start_interface -d "$device";
	then
		[[ "$verbose" != 0 ]] && Misc_PrintF -v 2 -t 'e' \
			-nmf $'Could not to start capture (failed to set/verify "monitor" mode of device "{{@clRed}}%s{{@clDefault}}")' -- "$device";

		return 1;
	fi

	declare interface="$Capture_Start_interface";

	# Start

	declare apBssidTruncated='all';
	declare apSsidTruncated='';

	# Truncate AP BSSID for a filename
	if [[ "$apBssid" != '' ]];
	then
		declare apBssidTruncated="$( Misc_EscapeFilename "$apBssid"; )";
	fi

	if [[ "$apSsid" != '' ]];
	then
		declare apSsidTruncated="$( Misc_EscapeFilename "$apSsid"; )";
	fi

	declare captureFilepath='';
	declare captureId='';

	if ! Base_FsExists -t d -- "$Handshake_HandshakesDirpath" && ! Base_FsDirectoryCreate -p -- "$Handshake_HandshakesDirpath";
	then
		[[ "$verbose" != 0 ]] && Misc_PrintF -v 2 -t 'e' -nf $'Failed to create directory for handshakes';

		return 2;
	fi

	# Generate a name and regenerate if already exists in termorary and persistent destinations
	while
		[[ "$captureFilepath" == '' ]] || 
		Base_FsExists -- "${captureFilepath}-01.cap" || Base_FsExists -- "${captureFilepath}-01.csv" ||
		Base_FsExists -- "${Handshake_HandshakesDirpath}/$( basename -- "${captureFilepath}-01.cap" 2> '/dev/null'; )" ||
		Base_FsExists -- "${Handshake_HandshakesDirpath}/$( basename -- "${captureFilepath}-01.csv" 2> '/dev/null'; )"
	do
		declare captureId="$(Misc_RandomString 8)";

		declare captureFilepath="${Capture_capturesDirpath}/${Capture_captureFilenamePrefix}_${apBssidTruncated}$(
			[ "$apSsidTruncated" != '' ] && printf '_%s' "$apSsidTruncated";
		)-${captureId}";
	done

	[[ "$verbose" != 0 ]] && Misc_PrintF -v 5 -t 'd' -nmf $'Capture (%s) filepath: \'%s\'' -- "$captureId" "$captureFilepath";

	# If declared a process meta, then terminate if such process already exists
	if [[ "$processBindMeta" != '' ]] && ! Environment_ProcessBindTerminate --bm "$processBindMeta";
	then
		[[ "$verbose" != 0 ]] && Misc_PrintF -v 2 -t 'e' \
			-nmf $'Failed to start AP capture %s (could not terminate bound process): "{{@clRed}}%s{{@clDefault}}"' -- \
			"$( Capture_previewAPDetails "$apBssid" "$apChannel" "$apSsid" )" "$processBindMeta";

		return 1;
	fi

	declare argsTemp=()

	if [[ "$apBssid" != '' ]];
	then
		declare argsTemp+=( '--bssid' "'$apBssid'" );
	fi

	if [[ "$apChannel" != '' ]];
	then
		declare argsTemp+=( '--channel' "$apChannel" );
	fi

	# Todo: Characters escape: ', \. E.g. "${apSsid//\'/\\\\\\\'}". # $( Misc_ArrayJoin "\\\$\\'" "\\'" ' ' "${argsTemp[@]}" ) \
	if [[ "$apSsid" != '' ]];
	then
		declare argsTemp+=( '--essid' "'$apSsid'" );
	fi

	# Start a capture process
	Environment_TerminalStart --bm "$processBindMeta" -x "$windowParameters" \
		-Tt "Capture '${captureId}' on '${interface}' $( printf $'[ B \'%s\', C \'%s\', S \'%s\' ]' "$apBssid" "$apChannel" "$apSsid" )" -- \
		"airodump-ng '${interface}' -t 'WPA1' -t 'WPA2' -w '${captureFilepath}' --write-interval 1 -a --wps --manufacturer --uptime \
			$( printf '%s ' "${argsTemp[@]}" ) \
			2>&1$(
				[[ "$highlightApActiveColor" != 0 ]] && printf '%s' " | grep --color=always -E '\s+([0-9A-F]{2}\:){5}[0-9A-F]{2}\s+\-[0-9]+\s+[0-9]+\s+([1-9]|[0-9]{2,}).*\$|'";
			)";

	declare returnCodeTemp=$?;

	if [[ "$returnCodeTemp" != 0 ]];
	then
		[[ "$verbose" != 0 ]] && Misc_PrintF -v 2 -t 'e' -nmf $'Failed to start capture \'%s\' process (code %s)' -- "$captureId" "$returnCodeTemp";

		return 1;
	fi

	declare captureFilepathBasename="$( basename -- "${captureFilepath}-01.cap" 2> '/dev/null'; )";

	# If it's a background process and requested to wait for the capture file
	if [[ "$processBindMeta" != '' && "$captureWaitTime" != 0 ]];
	then
		[[ "$verbose" != 0 ]] && Misc_PrintF -v 5 -t 'd' -nmf $'Waiting for capture CAP and CSV files (%s; each %ss): \'%s\'' -- \
			"$( [[ "$captureWaitTime" == -1 ]] && printf 'infinitely' || printf '%s' "${captureWaitTime}s" )" "$captureWaitTimeout" "${captureFilepathBasename::-4}.*";

		# Initial time amount to wait
		declare waitTimeStartSeconds=$( Misc_DateTime -t 3 );
		declare waitTimeSeconds="$(( waitTimeStartSeconds + captureWaitTime ))";

		# While the capture is active, capture files exist, and the wait did not time out
		while
			Environment_ProcessBindSearch --bm "$processBindMeta" && ! Base_FsExists -t 1 -- "${captureFilepath}-01.csv" "${captureFilepath}-01.cap" &&
			( [[ "$captureWaitTime" == -1 ]] || (( waitTimeSeconds > waitTimeStartSeconds )) );
		do
			declare waitTimeStartSeconds=$( Misc_DateTime -t 3 );

			[[ "$verbose" != 0 ]] && Misc_PrintF -v 5 -t 'd' -nmf $'Waiting %s more seconds for capture files (%ss, each %ss)' -- \
				"$(( waitTimeSeconds - waitTimeStartSeconds ))" "$( [[ "$captureWaitTime" == -1 ]] && printf 'infinitely' || printf '%s' "${captureWaitTime}" )" \
				"${captureWaitTimeout}";

			sleep "$captureWaitTimeout";
		done

		[[ "$verbose" != 0 ]] && Misc_PrintF -v 5 -t 'd' -nmf $'Stopped waiting for capture files';
	fi

	# Verify capture file existence

	declare capFileExists=0;
	declare csvFileExists=0;

	if Base_FsExists -t 1 -- "${captureFilepath}-01.cap";
	then
		declare capFileExists=1;
	fi

	if Base_FsExists -t 1 -- "${captureFilepath}-01.csv";
	then
		declare csvFileExists=1;
	fi

	# If no CAP or CSV file found
	if [[ "$capFileExists" != 1 || "$csvFileExists" != 1 ]];
	then
		[[ "$verbose" != 0 ]] && Misc_PrintF -v 2 -t 'e' -nmf $'Failed to find CAP and/or CSV capture file: %s' -- \ \
			"$(
				[[ "$capFileExists" != 1 ]] && printf "'%s'" "${captureFilepath}-01.cap";
				[[ "$capFileExists" != 1 ]] && [ "$csvFileExists" != 1 ] && printf ', ';
				[[ "$csvFileExists" != 1 ]] && printf "'%s'" "${captureFilepath}-01.csv";
			)";

		return 1;
	fi

	[[ "$verbose" != 0 ]] && Misc_PrintF -v 5 -t 'd' -nmf 'Found AP capture CAP and CSV files';

	# If requested to set to a referenced variable
	if [[ "$outputVariableReferenceName" != '' ]];
	then
		# Set the reference variable to the element count
		Capture_Start_outputVariableReference="${captureFilepath}-01";
	fi

	return 0;
}

# Todo: Add handshake return if available
Capture_ApDetails()
{
	###########
	# Options #
	###########

	declare args;

	if ! Options args \
		'?!-D;?!-d;?!-o;?-a;?-s;?-c;-v' \
		"$@";
	then
		Misc_PrintF -v 1 -t 'f' -nf $'[Capture_ApDetails] Invalid options (code %s, index %s ~ \'%s\'): \'%s\'' -- \
			"$_Options_ResultCode" "$_Options_FailIndex" "$_Options_ErrorMessage" "$( Misc_ArrayJoin -- "$@" )";

		exit 200;
	fi

	declare __deviceMain="${args[0]}";
	declare __deviceSecondary="${args[1]}";
	declare __outputVariableReferenceName="${args[2]}";
	declare __apTargetBssid="${args[3]}";
	declare __apTargetSsid="${args[4]}";
	declare __apTargetChannel="${args[5]}";
	declare __verbose="${args[6]}";

	if [[ "$__outputVariableReferenceName" != '' ]];
	then
		if [[
			"$__outputVariableReferenceName" == 'Capture_ApDetails_outputVariableReference' ||
			"$__outputVariableReferenceName" == 'Capture_ApDetails_outputVariableReferenceChannel' ||
			"$__outputVariableReferenceName" == 'Capture_ApDetails_outputVariableReferenceSsid' ||
			"$__outputVariableReferenceName" == 'Capture_ApDetails_outputVariableReferenceHandshake'
		]];
		then
			Misc_PrintF -v 1 -t 'f' -nf $'[Capture_ApDetails] Output variable reference interference: \'%s\'' -- "$( Misc_ArrayJoin -- "$@" )";

			return 100;
		fi

		declare -n Capture_ApDetails_outputVariableReference="$__outputVariableReferenceName";
		declare -n Capture_ApDetails_outputVariableReferenceChannel="${__outputVariableReferenceName}Channel";
		declare -n Capture_ApDetails_outputVariableReferenceSsid="${__outputVariableReferenceName}Ssid";
		declare -n Capture_ApDetails_outputVariableReferenceHandshake="${__outputVariableReferenceName}Handshake";
		Capture_ApDetails_outputVariableReference='';
		Capture_ApDetails_outputVariableReferenceChannel='';
		Capture_ApDetails_outputVariableReferenceSsid='';
		Capture_ApDetails_outputVariableReferenceHandshake='';
	else
		Misc_PrintF -v 1 -t 'f' -nf $'[Capture_ApDetails] No reference variable declared';

		return 1;
	fi

	########
	# Main #
	########

	if [[ "$__apTargetBssid" != '' && "$__apTargetSsid" != '' ]];
	then
		Misc_PrintF -v 2 -t 'e' -nf $'BSSID/SSID capture conflict (both BSSID and SSID provided to capture)';

		return 1;
	fi

	# Set the initial target AP data
	declare apBssid="$__apTargetBssid";
	declare apChannel="$__apTargetChannel";
	declare apSsid="$__apTargetSsid";

	[[ "$__verbose" != 0 ]] && Misc_PrintF -v 4 -t 'm' -nmTf $'Starting %sSSID capture %s' -- \
		"$( [[ "$apSsid" != '' ]] && printf 'B' )" "$( Capture_previewAPDetails "$apBssid" "$apChannel" "$apSsid" )";

	# Process metas

	declare processMetaPrefixSsid='ssid_1';
	declare processMetaGather_1="${processMetaPrefixSsid}_main_1";
	declare processMetaCompanion_1="${processMetaPrefixSsid}_companion_1";

	# Window parameters

	declare windowParametersSsidMain="$( Environment_WindowSector -H 2 -V 2 -h 0 -v 1 -t 0 -r 0 -b 0 -l 0 )";
	declare windowParametersSsidCapture="$( Environment_WindowSector -V 2 -v 0 )";
	declare windowParametersSsidCompanion="$( Environment_WindowSector -H 2 -V 2 -h 1 -v 1 )";
	Environment_WindowArrange --bm 'main_twincy_terminal' -- $windowParametersSsidMain;

	# Terminate related processes
	Environment_ProcessBindTerminate --bm "$processMetaPrefixSsid";

	# The target AP BSSID/SSID variable
	declare apTargetData='';

	# Timeouts (approximate)
	declare captureTimerTime=0;
	declare apDataVerifyRestartTimeout=5; # Check main data each N seconds
	declare companionFirstCheckTimeout=10; # The timeout before first companion data check after its (re)start
	declare companionRestartTimeout=30; # Restart companion each N seconds
	declare apTargetOnlineTimeout=30; # Target AP's maximum offline in N seconds

	# Times
	declare apTargetOnlineTime=-1;
	declare companionStartTime=0;
	declare apDataVerifyTime=0;

	# Counters
	declare apDataVerifyCount=0;
	declare mainCaptureStartCount=0;
	declare companionStartCount=0;
	declare mainCycleCount=0;

	# Target AP status
	declare apTargetIsActive=0;
	declare apTargetDataStatus=0; # (0 ~ Default, 1 ~ Reset target AP data to initial, 2 ~ Updated AP from companion, 3 ~ Not found or not enough target AP data)

	#
	# Start
	#

	# While not found a valid BSSID/SSID
	while [[ "$apTargetData" == '' ]];
	do
		declare currentTimeSeconds="$( Misc_DateTime -t 3 )";
		[[ "$__verbose" != 0 ]] && Misc_PrintF -v 5 -t 'd' -nTf $'Cycle #%s (%s)' -- "$mainCycleCount" "$apDataVerifyCount";
		declare mainCycleCount="$(( mainCycleCount + 1 ))";

		# If no actual target AP BSSID is availabled after cycle (e.g. a companion did not find)
		if [[ ! "$apBssid" =~ ^([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}$ ]] && [[ ! "$apSsid" =~ ^.{1,32}$ ]];
		then
			declare apBssid="$__apTargetBssid";
			declare apSsid="$__apTargetSsid";
			declare apChannel='';
			declare apTargetDataStatus=1; # Set the target AP's data status to "set to initial"

			[[ "$__verbose" != 0 ]] && Misc_PrintF -v 3 -t 'w' -nmTf $'Trying initial target AP details %s' -- \
				"$( Capture_previewAPDetails "$apBssid" "$apChannel" "$apSsid" )";
		fi

		####################
		# BSSID/SSID check #
		####################

		# If it's required to find SSID (based on BSSID) and the BSSID of the target AP is available,
		# or it's required to find BSSID (based on SSID) and the SSID of the target AP is available,
		# the AP data verification timed out, the main capture is active, and the capture file is available
		if
			[[
				"$__apTargetBssid" =~ ^([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}$ && "$apBssid" =~ ^([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}$ ||
				"$__apTargetSsid" =~ ^.{1,32}$ && "$apSsid" =~ ^.{1,32}$
			]] &&
			(( apDataVerifyTime + apDataVerifyRestartTimeout < currentTimeSeconds )) &&
			Environment_ProcessBindSearch --bm "$processMetaGather_1" && Base_FsExists -t 1 -- "${Capture_ApDetails_mainCaptureBaseFilepath}.csv"
		then
			# Read the capture file
			if Capture_CsvApRead -o Capture_ApDetails_apData -f "${Capture_ApDetails_mainCaptureBaseFilepath}.csv";
			then
				declare apDataIndex;

				# Loop through each AP from the capture file
				for (( apDataIndex = 0; apDataIndex < ${#Capture_ApDetails_apData[@]}; apDataIndex++ ));
				do
					declare apCsvBssid="${Capture_ApDetails_apData[$apDataIndex]}";
					# declare apCsvChannel="${Capture_ApDetails_apDataChannels[$apDataIndex]}";
					declare apCsvSsid="${Capture_ApDetails_apDataSsids[$apDataIndex]}";
					declare apCsvPrivacy="${Capture_ApDetails_apDataPrivacies[$apDataIndex]}";
					# declare apCsvStationCount="${Capture_ApDetails_apDataStationCounts[$apDataIndex]}";

					# If found a protected station (WPA (WPA1) or WPA2), same BSSID, and non-empty SSID
					if [[ "$apCsvPrivacy" == *"WPA"* ]];
					then
						if [[ "$__apTargetBssid" =~ ^([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}$ && "$apCsvBssid" == "$apBssid" && "$apCsvSsid" != '' ]];
						then
							declare apTargetData="$apCsvSsid";

							break;
						elif [[ "$__apTargetSsid" =~ ^.{1,32}$ && "$apCsvSsid" == "$apSsid" && "$apCsvBssid" != '' ]];
						then
							declare apTargetData="$apCsvBssid";

							break;
						fi
					fi
				done
			fi

			declare apDataVerifyCount="$(( apDataVerifyCount + 1 ))";
			declare apDataVerifyTime="$( Misc_DateTime -t 3 )";
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
			[[ "$__verbose" != 0 ]] && Misc_PrintF -v 4 -t 'n' -nTf $'%starting companion capture%s %s' -- \
				"$( (( companionStartCount > 0 )) && printf 'Res' || printf 'S' )" \
				"$( (( companionStartCount > 0 )) && printf ' (%s total)' "$companionStartCount" )" \
				"$( Capture_previewAPDetails "$apBssid" "$apChannel" "$apSsid" )";

			# If the companion capture filepath is declared
			if [[ "$Capture_ApDetails_companionCaptureBaseFilepath" != '' ]];
			then
				# Delete all files of the previous companion capture if exists
				Base_FsDelete -t 1 -- "$Capture_ApDetails_companionCaptureBaseFilepath"*;
			fi

			declare Capture_ApDetails_companionCaptureBaseFilepath;

			# Start a companion capture
			if
				! Capture_Start -o Capture_ApDetails_companionCaptureBaseFilepath --bm "$processMetaCompanion_1" -x "$windowParametersSsidCompanion" \
					-d "$__deviceSecondary" -a "$apBssid" -s "$apSsid" -c "$apChannel";
			then
				[[ "$__verbose" != 0 ]] && Misc_PrintF -v 2 -t 'e' -nTf $'Failed to %sstart companion capture %s' -- \
					"$( (( companionStartCount > 0 )) && printf 're' )" "$( Capture_previewAPDetails "$apBssid" "$apChannel" "$apSsid" )";

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
			# declare apCompanionPrivacy='';
			declare companionApFoundCount=0;
			declare apCompanionApProtectedFoundCount=0;
			declare Capture_ApDetails_apData;

			if Capture_CsvApRead -o Capture_ApDetails_apData -f "${Capture_ApDetails_companionCaptureBaseFilepath}.csv";
			then
				declare apDataIndex;

				# Loop through each AP from the capture file
				for (( apDataIndex = 0; apDataIndex < ${#Capture_ApDetails_apData[@]}; apDataIndex++ ));
				do
					declare apCsvBssid="${Capture_ApDetails_apData[$apDataIndex]}";
					declare apCsvChannel="${Capture_ApDetails_apDataChannels[$apDataIndex]}";
					declare apCsvSsid="${Capture_ApDetails_apDataSsids[$apDataIndex]}";
					declare apCsvPrivacy="${Capture_ApDetails_apDataPrivacies[$apDataIndex]}";
					declare apCsvStationCount="${Capture_ApDetails_apDataStationCounts[$apDataIndex]}";

					# If found a protected station (WPA (WPA1) or WPA2)
					if [[ "$apCsvPrivacy" == *"WPA"* ]];
					then
						# If a BSSID matches with the target and a SSID is not empty
						if [[ "$__apTargetBssid" =~ ^([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}$ && "$apCsvBssid" == "$apBssid" && "$apCsvSsid" != '' ]];
						then
							declare apTargetData="$apCsvSsid";

							# End the companion data read loop
							break;
						elif [[ "$__apTargetSsid" =~ ^.{1,32}$ && "$apCsvSsid" == "$apSsid" && "$apCsvBssid" != '' ]];
						then
							declare apTargetData="$apCsvBssid";

							break;
						fi

						# Update the target/relative AP's data
						declare apCompanionBssid="$apCsvBssid";
						declare apCompanionChannel="$apCsvChannel";
						declare apCompanionSsid="$apCsvSsid";
						# declare apCompanionPrivacy="$apCsvPrivacy";
						declare apCompanionApProtectedFoundCount=$(( apCompanionApProtectedFoundCount + 1 ));
					fi
				done

				# If obtained the SSID of the target AP
				if [[ "$apTargetData" != '' ]];
				then
					# End the main loop
					break;
				fi

				declare companionApFoundCount="${#Capture_ApDetails_apData[@]}";
			else
				# [[ "$__verbose" != 0 ]] && Misc_PrintF -v 3 -t 'w' -nmTf $'{{@clRed}}Companion did not find any target AP{{@clDefault}}';
				[[ "$__verbose" != 0 ]] && Misc_PrintF -v 3 -t 'w' -nmTf $'Could not read companion capture file';
			fi

			# If found any related protected AP
			if [[ "$apCompanionApProtectedFoundCount" != 0 ]];
			then
				# Refresh the target AP's presence time
				apTargetOnlineTime="$( Misc_DateTime -t 3 )";

				[[ "$__verbose" != 0 ]] && Misc_PrintF -v 5 -t 'd' -nmTf $'Updated target AP online time: %s (%s)' -- \
					"$apTargetOnlineTime" "$( date '+%F_%T' -d "@${apTargetOnlineTime}" )";
			elif [[ "$apTargetOnlineTime" == -1 ]]; # If it's the first companion capture check after a companion restart
			then
				declare apTargetOnlineTime=-2;
				[[ "$verbose" != 0 ]] && Misc_PrintF -v 4 -t 'w' -nmTf $'Companion: target AP {{@clRed}}not found{{@clDefault}} (%s total)' -- "$companionApFoundCount";
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
				"$apTargetOnlineTime" != -1 &&
				(
					"$apCompanionChannel" != "$apChannel" || "$apCompanionBssid" != "$apBssid" || ( "$apCompanionSsid" != '' && "$apCompanionSsid" != "$apSsid" )
				)
			]]
		then
			# If channel is available and initial and companion BSSIDs are available, or initial and companion SSIDs are available
			if [[
				"$apCompanionChannel" != '' &&
				(
					"$__apTargetBssid" =~ ^([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}$ && "$apCompanionBssid" != '' ||
					"$__apTargetSsid" =~ ^.{1,32}$ && "$apCompanionSsid" != ''
				)
			]];
			then
				declare apTargetDataStatus=2; # Set the target AP data status to "At least one target AP parameter has changed"

				if [[ "$__verbose" != 0 ]];
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
				[[ "$__apTargetBssid" =~ ^([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}$ && "$apCompanionBssid" == '' ]] && missingApData+=( 'BSSID' );
				[[ "$__apTargetSsid" =~ ^.{1,32}$ && "$apCompanionSsid" == '' ]] && missingApData+=( 'SSID' );

				[[ "$__verbose" != 0 ]] && Misc_PrintF -v 4 -t 'w' -nTf $'Companion: Incomplete target AP details. Missing: %s' -- \
					"$( Misc_ArrayJoin -- "${missingApData[@]}" )";
			fi

			# Terminate the current main capture and companion processes if exist so to restart them with new data
			Environment_ProcessBindTerminate --bm "$processMetaGather_1";
			Environment_ProcessBindTerminate --bm "$processMetaCompanion_1";

			# Update the target AP's details according to the companion

			declare apChannel="$apCompanionChannel";
			declare apBssid="$apCompanionBssid";

			if [[ "$apCompanionSsid" != '' ]];
			then
				declare apSsid="$apCompanionSsid";

				# If it's requested to find SSID
				if [[ "$__apTargetBssid" =~ ^([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}$ ]];
				then
					declare apTargetData="$apCompanionSsid";
				
					# Reset the main loop to check the SSID
					continue;
				fi
			fi

			# If it's requested to find BSSID
			if [[ "$apCompanionBssid" != '' && "$__apTargetSsid" =~ ^.{1,32}$ ]];
			then
				declare apTargetData="$apCompanionBssid";

				# Reset the main loop to check the BSSID
				continue;
			fi

			# Sleep each full cycle
			# sleep "$twinTimerTime";

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
			sleep "$captureTimerTime";

			continue;
		fi

		# If companion didn't find the target or not found/incomplete target AP data
		if [[ "$apTargetOnlineTime" == -2 || "$apTargetDataStatus" == 3 ]];
		then
			# If the target AP's off-line timeout reached and it is considered currently active
			if (( apTargetOnlineTime + apTargetOnlineTimeout < currentTimeSeconds )) && [[ "$apTargetIsActive" == 1 ]];
			then
				if [[ "$mainCaptureStartCount" != 0 ]];
				then
					[[ "$__verbose" != 0 ]] && Misc_PrintF -v 2 -t 'w' -nmTf $'Target AP is probably {{@clRed}}offline{{@clDefault}}';
					Misc_SoundPlay 'ap_lost';
				fi

				declare apTargetIsActive=0;
			fi

			# declare apTargetDataStatus=0;

			# Sleep each full cycle
			# sleep "$captureTimerTime";

			# continue;
		elif [[ "$apTargetIsActive" == 0 ]];
		then
			if [[ "$mainCaptureStartCount" != 0 ]];
			then
				[[ "$__verbose" != 0 ]] && Misc_PrintF -v 2 -t 's' -nmTf $'{{@clLightGreen}}Found{{@clDefault}} target AP';
				Misc_SoundPlay 'ap_found';
			fi

			declare apTargetIsActive=1;
		fi

		################
		# Main capture #
		################

		# If target BSSID or SSID is available
		if [[
			"$__apTargetBssid" =~ ^([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}$ && "$apBssid" =~ ^([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}$ ||
			"$__apTargetSsid" =~ ^.{1,32}$ && "$apSsid" =~ ^.{1,32}$
		]];
		then
			# If the main capture is not running
			if ! Environment_ProcessBindSearch --bm "$processMetaGather_1";
			then
				[[ "$__verbose" != 0 ]] && Misc_PrintF -v 4 -t 'n' -nTf $'%starting main capture%s %s' -- \
					"$( (( mainCaptureStartCount > 0 )) && printf 'Res' || printf 'S' )" \
					"$( (( mainCaptureStartCount > 0 )) && printf ' (%s total)' "$mainCaptureStartCount" )" \
					"$( Capture_previewAPDetails "$apBssid" "$apChannel" )";

				# If the main capture filepath is declared
				if [[ "$Capture_ApDetails_mainCaptureBaseFilepath" != '' ]];
				then
					# Delete all files of the previous main capture
					Base_FsDelete -t 1 -- "$Capture_ApDetails_mainCaptureBaseFilepath"*;
				fi

				# Start the main capture
				if
					! Capture_Start -o Capture_ApDetails_mainCaptureBaseFilepath --bm "$processMetaGather_1" -x "$windowParametersSsidCapture" \
						-d "$__deviceMain" -a "$apBssid" -s "$apSsid" -c "$apChannel";
				then
					[[ "$__verbose" != 0 ]] && Misc_PrintF -v 2 -t 'e' -nTf $'Failed to %sstart main capture' -- "$( (( mainCaptureStartCount > 0 )) && printf 're' )";

					return 1;
				fi

				declare mainCaptureStartCount="$(( mainCaptureStartCount + 1 ))";
			fi
		else
			[[ "$__verbose" != 0 ]] && Misc_PrintF -v 4 -t 'w' -nTf $'Could not start main capture of target AP (no target BSSID known)';
		fi

		# Set the target AP data status to "default"
		declare apTargetDataStatus=0;

		# Sleep each full cycle
		sleep "$captureTimerTime";
	done

	##########
	# Ending #
	##########

	# Terminate all related processes
	Environment_ProcessBindTerminate --bm "$processMetaPrefixSsid";

	if [[ "${apTargetData+s}" == '' ]];
	then
		[[ "$__verbose" != 0 ]] && Misc_PrintF -v 2 -t 'e' -nmTf $'{{@clRed}}Failed{{@clDefault}} to capture %sSSID of %s' -- \
			"$( [[ "$__apTargetSsid" =~ ^.{1,32}$ ]] && printf 'B'; )" \
			"$( [[ "$__apTargetSsid" =~ ^.{1,32}$ ]] && printf '%s' "$apBssid" || printf $'\'%s\'' "$apSsid"; )";

		return 1;
	fi

	[[ "$__verbose" != 0 ]] && Misc_PrintF -v 4 -t 's' -nmTf $'{{@clLightGreen}}Obtained %sSSID{{@clDefault}} of %sSSID %s: \'%s\'' -- \
		"$( [[ "$__apTargetSsid" =~ ^.{1,32}$ ]] && printf 'B'; )" "$( [[ ! "$__apTargetSsid" =~ ^.{1,32}$ ]] && printf 'B'; )" \
		"$( [[ "$__apTargetSsid" =~ ^.{1,32}$ ]] && printf $'\'%s\'' "$apSsid" || printf '%s' "$apBssid"; )" \
		"$apTargetData";
	
	Misc_SoundPlay 'ap-details_found';

	Capture_ApDetails_outputVariableReferenceChannel="$apChannel";

	# If it's requested to find SSID based on BSSID
	if [[ "$__apTargetBssid" =~ ^([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}$ ]];
	then
		Capture_ApDetails_outputVariableReferenceSsid="$apTargetData";
		Capture_ApDetails_outputVariableReference="$apBssid";
	else
		Capture_ApDetails_outputVariableReference="$apTargetData";
		Capture_ApDetails_outputVariableReferenceSsid="$apSsid";
	fi

	# If gathered handshake

	declare handshakeCaptureFilepath='';

	if
		Base_FsExists -t f -- "${Capture_ApDetails_mainCaptureBaseFilepath}.cap" && 
		Handshake_Verify -fc "${Capture_ApDetails_mainCaptureBaseFilepath}.cap" -b "$apBssid" -s "$apSsid";
	then
		declare handshakeCaptureFilepath="${Capture_ApDetails_mainCaptureBaseFilepath}.cap";
	elif
		Base_FsExists -t f -- "${Capture_ApDetails_companionCaptureBaseFilepath}.cap" && 
		Handshake_Verify -fc "${Capture_ApDetails_companionCaptureBaseFilepath}.cap" -b "$apBssid" -s "$apSsid";
	then
		declare handshakeCaptureFilepath="${Capture_ApDetails_companionCaptureBaseFilepath}.cap";
	fi

	# No handshake found
	if [[ "$handshakeCaptureFilepath" == '' ]];
	then
		sleep 1;
		
		return 0;
	fi

	# Store the handshake

	declare handshakeFilename="$( basename -- "$handshakeCaptureFilepath" 2> '/dev/null'; )"; # 'capture_MAC_SSID-RAND-01.cap'
	declare handshakeFilename="${Handshake_HandshakeFilenamePrefix}_${handshakeFilename#*_}"; # 'capture_MAC_SSID-RAND-01.cap' ~> 'handshake_MAC_SSID-RAND-01.cap'
	declare handshakeCaptureCopyFilepath="${Handshake_HandshakesDirpath}/${handshakeFilename}";

	if ! Base_FsMove -c "$handshakeCaptureFilepath" "$handshakeCaptureCopyFilepath";
	then
		[[ "$verbose" != 0 ]] && Misc_PrintF -v 2 -t 'e' -nmTf $'{{@clLightRed}}Failed to store{{@clDefault}} handshake: \'%s\'' -- "$handshakeCaptureFilepath";

		return 2;
	fi

	[[ "$verbose" != 0 ]] && Misc_PrintF -v 4 -t 's' -nmTf $'Stored handshake: \'%s\'' -- \
		"$( basename -- "$handshakeCaptureCopyFilepath" 2> '/dev/null'; )";

	Capture_ApDetails_outputVariableReferenceHandshake="$handshakeCaptureCopyFilepath";

	sleep 1;

	return 0;
}

Capture_SelectAp()
{
	###########
	# Options #
	###########

	declare args;

	if ! Options args \
		'@3/^[0-2]$/' \
		'?!-f;?!-o;-F;-v' \
		"$@";
	then
		Misc_PrintF -v 1 -t 'f' -nf $'[Capture_SelectAp] Invalid options (code %s, index %s ~ \'%s\'): \'%s\'' -- \
			"$_Options_ResultCode" \
			"$_Options_FailIndex" \
			"$_Options_ErrorMessage" \
			"$( Misc_ArrayJoin -- "$@" )";

		exit 200;
	fi

	declare captureFilepath="${args[0]}";
	declare outputVariableReferenceName="${args[1]}";
	declare filter="${args[2]}";
	declare verbose="${args[3]}";

	if [ "$outputVariableReferenceName" != '' ];
	then
		if
			[ "$outputVariableReferenceName" = 'Capture_SelectAp_outputVariableReference' ] ||
			[ "$outputVariableReferenceName" = 'Capture_SelectAp_outputVariableReferenceSsid' ] ||
			[ "$outputVariableReferenceName" = 'Capture_SelectAp_outputVariableReferenceFilepath' ] ||
			[ "$outputVariableReferenceName" = 'Capture_SelectAp_outputVariableReferenceCount' ]
		then
			Misc_PrintF -v 1 -t 'f' -nf $'[Capture_SelectAp] Output variable reference interference: \'%s\'' -- \
				"$( Misc_ArrayJoin -- "$@" )";

			return 100;
		fi

		declare -n Capture_SelectAp_outputVariableReference="$outputVariableReferenceName"; # Selected BSSID
		declare -n Capture_SelectAp_outputVariableReferenceSsid="${outputVariableReferenceName}Ssid";
		declare -n Capture_SelectAp_outputVariableReferenceFilepath="${outputVariableReferenceName}Filepath";
		declare -n Capture_SelectAp_outputVariableReferenceCount="${outputVariableReferenceName}Count";
		Capture_SelectAp_outputVariableReference='';
		Capture_SelectAp_outputVariableReferenceSsid='';
		Capture_SelectAp_outputVariableReferenceFilepath='';
		Capture_SelectAp_outputVariableReferenceCount=-1;
	fi

	########
	# Main #
	########

	# If no such capture file exists
	if ! Base_FsExists -t 1 "$captureFilepath";
	then
		[[ "$verbose" != 0 ]] && Misc_PrintF -v 2 -t 'e' -nmf $'Could not read capture file (no such exists): \'%s\'' -- "$captureFilepath";

		return 3;
	fi

	# Filter and sort unique APs of the capture file (note: tshark may return 2 exit code if the capture was "cut in the middle" (e.g. already filtered))

	declare captureDataSorted='';

	Environment_ProcessStart -o captureDataSorted -- \
		"sudo -u \"$Environment_UserNonRoot\" \
			tshark -r \"$captureFilepath\" \
				-2R 'wlan.bssid != 00:00:00:00:00:00 && wlan.bssid != ff:ff:ff:ff:ff:ff && wlan.ssid != \"\"' \
				-o $'gui.column.format:\"BSSID\",\"%Cus:wlan.bssid\",\"SSID\",\"%Cus:wlan.ssid\"' \
		| sort -u";

	# If failed to filter
	if [ "$captureDataSorted" != 0 ] || [ "${#captureDataSortedOut}" = 0 ];
	then
		[[ "$verbose" != 0 ]] && Misc_PrintF -v 2 -t 'e' -nmf $'Failed to list capture file (code %s): \'%s\'' -- "$captureDataSorted" "$captureFilepath";

		return 5;
	fi

	captureDataSortedOut="$( Misc_RegexReplace -s '\s' -r $'\n' -- "$captureDataSortedOut"; )";
	declare captureDataSortedArr;
	# IFS=$'\n' read -d '' -ra captureDataSortedArr <<< "$captureDataSortedOut";
	# mapfile -td $'\xa' captureDataSortedArr <<< "$captureDataSortedOut";
	# readarray -t captureDataSortedArr <<< "$captureDataSortedOut";
	readarray -td $'\xa' captureDataSortedArr <<< "$captureDataSortedOut";
	declare captureApCount="$(( ${#captureDataSortedArr[@]} / 2 ))"; # 2 lines (BSSID\nSSID)

	# If there's no proper array items
	if [[ "$captureApCount" == 0 ]];
	then
		return 1;
	fi

	# Select the single or request selection

	declare captureApIndex=0;

	# If there's more than 1 stations in the capture file
	if (( captureApCount > 1 ));
	then
		Misc_PrintF -n;
		Misc_TablePrint -c 2 -- 'BSSID' 'SSID' "${captureDataSortedArr[@]}";
		Misc_PrintF -n;

		# Select index
		declare Capture_SelectAp_captureApIndex;

		while [[ "${Capture_SelectAp_captureApIndex+s}" == '' ]];
		do
			# If cancelled
			if ! Misc_Prompt -o Capture_SelectAp_captureApIndex -p '^(0|[1-9][0-9]*)$' -e "[1-${captureApCount}]";
			then
				return 1;
			fi

			if (( Capture_SelectAp_captureApIndex <= 0 || Capture_SelectAp_captureApIndex > captureApCount ));
			then
				Misc_PrintF -t 'e' -nf 'Index out of range (1-%s)' -- "$captureApCount";
				unset Capture_SelectAp_captureApIndex;
				declare Capture_SelectAp_captureApIndex;
			fi
		done

		declare captureApIndex="$(( Capture_SelectAp_captureApIndex - 1 ))";
	fi

	# Set proper BSSID at index
	declare captureApBssid="$( Misc_Regex -sp '^((?:[0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2})' -c 1 -- "${captureDataSortedArr[$((captureApIndex * 2))]}" )";
	declare captureApSsid="${captureDataSortedArr[$((captureApIndex * 2 + 1))]}";

	# If no valid BSSID found
	if [[ "$captureApBssid" == '' ]];
	then
		Misc_PrintF -t 'e' -nf $'Invalid BSSID: \'%s\'' -- "$captureApBssid";

		return 2;
	fi

	# Filter if requested

	declare captureSelectedFilepath="$captureFilepath";

	# If requested to filter
	if [[ "$filter" != 0 ]];
	then
		declare Capture_captureFilteredFilepath;

		if ! Capture_Filter -fo Capture_captureFilteredFilepath -c "$captureSelectedFilepath" -b "$captureApBssid";
		then
			[[ "$verbose" != 0 ]] && Misc_PrintF -v 2 -t 'e' -nmf $'Failed to select AP from capture file (failed to filter): \'%s\'' -- "$captureSelectedFilepath";

			return 3;
		fi

		declare captureSelectedFilepath="$Capture_captureFilteredFilepath";
	fi

	# Final

	Capture_SelectAp_outputVariableReference="$captureApBssid";
	Capture_SelectAp_outputVariableReferenceSsid="$captureApSsid";
	Capture_SelectAp_outputVariableReferenceFilepath="$captureSelectedFilepath";
	Capture_SelectAp_outputVariableReferenceCount="$captureApCount";

	[[ "$verbose" != 0 ]] && Misc_PrintF -v 5 -t 'd' -nmf $'Selected AP (%s) from capture file (%s): \'%s\'' -- \
		"$captureApBssid" "$( [ "$filter" != 0 ] && printf 'filtered' )" "$captureSelectedFilepath";

	return 0;
}

# Print APs data from a CSV file
Capture_CsvApPrint()
{
	###########
	# Options #
	###########

	declare args;

	if ! Options args \
		'?!-f;?-t;?-o' \
		"$@";
	then
		Misc_PrintF -v 1 -t 'f' -nf $'[Capture_CsvApPrint] Invalid options (code %s, index %s ~ \'%s\'): \'%s\'' -- \
			"$_Options_ResultCode" \
			"$_Options_FailIndex" \
			"$_Options_ErrorMessage" \
			"$( Misc_ArrayJoin -- "$@" )";

		exit 200;
	fi

	declare captureFilepath="${args[0]}";
	declare printType="${args[1]}";
	declare outputVariableReferenceName="${args[2]}";

	if [[ "$outputVariableReferenceName" != '' ]];
	then
		if [[
			"$outputVariableReferenceName" == 'Capture_CsvApPrint_outputVariableReference' ||
			"$outputVariableReferenceName" == 'Capture_CsvApPrint_outputVariableReferenceSkippedPowerIndexes'
		]];
		then
			Misc_PrintF -v 1 -t 'f' -nf $'[Capture_CsvApPrint] Output variable reference interference: \'%s\'' -- \
				"$( Misc_ArrayJoin -- "$@" )";

			return 100;
		fi

		declare -n Capture_CsvApPrint_outputVariableReference="$outputVariableReferenceName";
		declare -n Capture_CsvApPrint_outputVariableReferenceSkippedPowerIndexes="${outputVariableReferenceName}SkippedPowerIndexes";
		Capture_CsvApPrint_outputVariableReference=();
		Capture_CsvApPrint_outputVariableReferenceSkippedPowerIndexes=();
	fi

	########
	# Main #
	########

	if ! Base_FsExists -t 1 -- "$captureFilepath";
	then
		if [ "$verbose" != 0 ];
		then
			Misc_PrintF -v 2 -t 'e' -nf $'Could not print data from capture CSV file (no such file): \'%s\'' -- \
				"$captureFilepath";
		fi
	fi

	declare apIndex=-1;
	declare apIndexes=(); # Passed APs
	declare apSkippedPower=(); # Skipped APs
	declare apDataTable=();
	declare csvApBssid;
	declare csvApPower;
	declare csvApChannel;
	declare cvsApSpeed;
	declare csvApBeaconCount;
	declare csvApDataCount;
	declare csvApSsid;
	declare csvVoid;

	while IFS=',' read \
		csvApBssid csvVoid csvVoid csvApChannel cvsApSpeed csvVoid csvVoid csvVoid csvApPower csvApBeaconCount csvApDataCount csvVoid csvVoid csvApSsid csvVoid;
	do
		# Trim values
		declare csvApBssid="$( Misc_TrimString "$csvApBssid" )";
		declare csvApPower="$( Misc_TrimString "$csvApPower" )";

		if [[ "$csvApBssid" == 'Station MAC' ]]; # If reached stations
		then
			break;
		elif [[ ! "$csvApBssid" =~ ^([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}$ || ! "$csvApPower" =~ ^-?(0|[1-9][0-9]*)$ ]];
		then
			continue;
		fi

		apIndex="$(( apIndex + 1 ))";

		if (( csvApPower >= -1 ));
		then
			apSkippedPower+=( "$apIndex" ); # Record the index of the skipped AP

			continue;
		fi

		declare csvApChannel="$( Misc_TrimString "$csvApChannel" )";
		declare cvsApSpeed="$( Misc_TrimString "$cvsApSpeed" )";
		declare csvApBeaconCount="$( Misc_TrimString "$csvApBeaconCount" )";
		declare csvApDataCount="$( Misc_TrimString "$csvApDataCount" )";
		declare csvApSsid="$( Misc_TrimString "$csvApSsid" )";
		declare apStationCount=$(cat "$captureFilepath" | grep "$csvApBssid" | wc -l)
		declare apStationCount="$(( apStationCount - 1 ))";
		apDataTable+=( "$csvApBssid" "$csvApPower" "$csvApChannel" "$cvsApSpeed" "$apStationCount" "$csvApDataCount" "$csvApBeaconCount" "'${csvApSsid}'" );
		apIndexes+=( "$apIndex" ); # Record the index of the AP
	done \
		< "$captureFilepath" 2>> "$_Main_Dump";

	if (( ${#apSkippedPower[@]} > 0 ));
	then
		Misc_PrintF -v 3 -t 'w' -nf 'Skipped %s too opaque AP%s (%s total)' -- \
			"${#apSkippedPower[@]}" "$( (( ${#apSkippedPower[@]} > 1 )) && printf 's' )" "${#apIndexes[@]}";
	fi

	Misc_PrintF -n;
	Misc_TablePrint -c 8 -- 'BSSID' 'PWR' 'CHA' 'SPD' 'STA' 'DATA' 'BEAC' 'SSID' "${apDataTable[@]}";
	Misc_PrintF -n;

	if [[ "$outputVariableReferenceName" != '' ]];
	then
		Capture_CsvApPrint_outputVariableReference=( "${apIndexes[@]}" );
		Capture_CsvApPrint_outputVariableReferenceSkippedPowerIndexes=( "${apSkippedPower[@]}" );
	fi

	return 0;
}

# Print APs from CSV file and prompt a user the AP's index
Capture_CsvApSelect()
{
	###########
	# Options #
	###########

	declare args;

	if ! Options args \
		'@1/[a-zA-Z][0-9a-zA-Z]*/' \
		'?!-f;?!-o' \
		"$@";
	then
		Misc_PrintF -v 1 -t 'f' -nf $'[Capture_CsvApSelect] Invalid options (code %s, index %s ~ \'%s\'): \'%s\'' -- \
			"$_Options_ResultCode" \
			"$_Options_FailIndex" \
			"$_Options_ErrorMessage" \
			"$( Misc_ArrayJoin -- "$@" )";

		exit 200;
	fi

	declare captureFilepath="${args[0]}";
	declare outputVariableReferenceName="${args[1]}";

	if [ "$outputVariableReferenceName" != '' ];
	then
		if [[ "$outputVariableReferenceName" == 'Capture_CsvApSelect_outputVariableReference' ]];
		then
			Misc_PrintF -v 1 -t 'f' -nf $'[Capture_CsvApSelect] Output variable reference interference: \'%s\'' -- \
				"$( Misc_ArrayJoin -- "$@" )";

			return 100;
		fi

		declare -n Capture_CsvApSelect_outputVariableReference="$outputVariableReferenceName";
		Capture_CsvApSelect_outputVariableReference=-1;
	fi

	########
	# Main #
	########

	if ! Base_FsExists -t 1 -- "$captureFilepath";
	then
		if [ "$verbose" != 0 ];
		then
			Misc_PrintF -v 2 -t 'e' -nf $'Could not select from capture CSV file (no such file): \'%s\'' -- \
				"$captureFilepath";
		fi
	fi

	declare Capture_CsvApSelect_apIndexes;
	Capture_CsvApPrint -o Capture_CsvApSelect_apIndexes -t 1 -f "$captureFilepath";
	declare apTableIndexes=( "${Capture_CsvApSelect_apIndexes[@]}" );
	declare apTableSkippedIndexes=( "${Capture_CsvApSelect_apTableSkippedPowerIndexes[@]}" );

	if [[ "${#apTableIndexes[@]}" == 0 ]];
	then
		if [ "$verbose" != 0 ];
		then
			Misc_PrintF -v 2 -t 'e' -nf $'Could not select from capture CSV file (no proper AP data found): \'%s\'' -- \
				"$captureFilepath";
		fi

		return 1;
	elif [[ "${#apTableIndexes[@]}" == 1 ]];
	then
		Capture_CsvApSelect_outputVariableReference=0;

		return 0;
	fi

	# Input data
	unset Capture_CsvApSelect_apSelectedIndex;
	declare Capture_CsvApSelect_apSelectedIndex;

	while [[ "${Capture_CsvApSelect_apSelectedIndex+s}" == '' ]];
	do
		# If cancelled
		if ! Misc_Prompt -o Capture_CsvApSelect_apSelectedIndex -p '^(r|0|[1-9][0-9]*)$' -e "[1-${#apTableIndexes[@]}][r]" -- 'Access point';
		then
			return 1;
		fi

		if [[ "$Capture_CsvApSelect_apSelectedIndex" == 'r' ]];
		then
			break;
		fi

		if (( Capture_CsvApSelect_apSelectedIndex <= 0 || Capture_CsvApSelect_apSelectedIndex > ${#apTableIndexes[@]} ));
		then
			Misc_PrintF -t 'e' -nf 'Index out of range (1-%s)' -- "${#apTableIndexes[@]}";
			unset Capture_CsvApSelect_apSelectedIndex;
			declare Capture_CsvApSelect_apSelectedIndex;
		fi
	done

	# If not a number

	if [[ ! "$Capture_CsvApSelect_apSelectedIndex" =~ ^(0|[1-9][0-9]*)$ ]];
	then
		Capture_CsvApSelect_outputVariableReference="$Capture_CsvApSelect_apSelectedIndex";

		return 0;
	fi

	# Assuming the array is arranged properly

	declare apSelectedIndex="${apTableIndexes[$((Capture_CsvApSelect_apSelectedIndex - 1))]}";

	if [[ ! "$apSelectedIndex" =~ ^(0|[1-9][0-9]*)$ ]];
	then
		Misc_PrintF -t 'e' -nf $'Invalid final AP index \'%s\' (%s total)' -- "$apSelectedIndex" "${#apTableIndexes[@]}";
	fi

	Capture_CsvApSelect_outputVariableReference="$apSelectedIndex";

	return 0;
}

# Gather AP data at specific index from CSV file (assumed SSIDs don't have trailing and leading whitespace characters)
Capture_CsvApRead()
{
	###########
	# Options #
	###########

	declare args;

	if ! Options args \
		'@1/[a-zA-Z][0-9a-zA-Z]*/' \
		'@2/^[0-2]$/' \
		'?!-f;?!-o;-v' \
		"$@";
	then
		Misc_PrintF -v 1 -t 'f' -nf $'[Capture_CsvApData] Invalid options (code %s, index %s ~ \'%s\'): \'%s\'' -- \
			"$_Options_ResultCode" \
			"$_Options_FailIndex" \
			"$_Options_ErrorMessage" \
			"$( Misc_ArrayJoin -- "$@" )";

		exit 200;
	fi

	declare captureFilepath="${args[0]}";
	declare outputVariableReferenceName="${args[1]}";
	declare verbose="${args[2]}";

	if [ "$outputVariableReferenceName" != '' ];
	then
		if
			[ "$outputVariableReferenceName" = 'Capture_CsvApRead_outputVariableReference' ] ||
			[ "$outputVariableReferenceName" = 'Capture_CsvApRead_outputVariableReferenceChannels' ] ||
			[ "$outputVariableReferenceName" = 'Capture_CsvApRead_outputVariableReferenceSsids' ] || 
			[ "$outputVariableReferenceName" = 'Capture_CsvApRead_outputVariableReferencePrivacies' ] || 
			[ "$outputVariableReferenceName" = 'Capture_CsvApRead_outputVariableReferenceStationCounts' ];
		then
			Misc_PrintF -v 1 -t 'f' -nf $'[Capture_CsvApData] Output variable reference interference: \'%s\'' -- \
				"$( Misc_ArrayJoin -- "$@" )";

			return 100;
		fi

		declare -n Capture_CsvApRead_outputVariableReference="$outputVariableReferenceName";
		declare -n Capture_CsvApRead_outputVariableReferenceChannels="${outputVariableReferenceName}Channels";
		declare -n Capture_CsvApRead_outputVariableReferenceSsids="${outputVariableReferenceName}Ssids";
		declare -n Capture_CsvApRead_outputVariableReferencePrivacies="${outputVariableReferenceName}Privacies";
		declare -n Capture_CsvApRead_outputVariableReferenceStationCounts="${outputVariableReferenceName}StationCounts";
		Capture_CsvApRead_outputVariableReference=();
		Capture_CsvApRead_outputVariableReferenceChannels=();
		Capture_CsvApRead_outputVariableReferenceSsids=();
		Capture_CsvApRead_outputVariableReferencePrivacies=();
		Capture_CsvApRead_outputVariableReferenceStationCounts=();
	fi

	########
	# Main #
	########

	if ! Base_FsExists -t 1 -- "$captureFilepath";
	then
		if [ "$verbose" != 0 ];
		then
			Misc_PrintF -v 2 -t 'e' -nf $'Could not get data from capture file (no such file): \'%s\'' -- \
				"$captureFilepath";
		fi
	fi

	# Find the stations section start line
	declare stationSectionStart="$( grep -on 'Station MAC' "$captureFilepath" )";
	declare stationSectionStart="${stationSectionStart%%\:*}";

	if [[ ! "$stationSectionStart" =~ ^(0|[1-9][0-9]*)$ ]];
	then
		[[ "$verbose" != 0 ]] && Misc_PrintF -v 5 -t 'd' -nf $'Invalid capture CSV file: \'%s\'' -- "$( basename -- "$captureFilepath" 2> '/dev/null'; )";

		return 1;
	fi

	declare stationSectionStart="$(( stationSectionStart - 1 ))";

	# Predefined local variables for the "while read" loop
	declare csvApBssid;
	declare csvApChannel;
	declare csvApSsid;
	declare csvApPrivacy;
	declare csvVoid;

	declare stationCountTotal=0;
	# declare stationCountTotalRelevant=0;

	declare csvApBssids=();
	declare csvApChannels=();
	declare csvApSsids=();
	declare csvApPrivacies=();
	declare csvApStationCounts=();
	declare apIndex=0;

	while IFS=',' read \
		csvApBssid csvVoid csvVoid csvApChannel csvVoid \
		csvApPrivacy csvVoid csvVoid csvVoid csvVoid \
		csvVoid csvVoid csvVoid csvApSsid csvVoid;
	do
		if [[ ! $csvApBssid =~ ^([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}$ ]]
		then
			continue;
		fi

		# Trim values
		declare csvApBssid="$( Misc_TrimString "$csvApBssid" )";
		declare csvApChannel="$( Misc_TrimString "$csvApChannel" )";
		declare csvApSsid="$( Misc_TrimString "$csvApSsid" )";
		declare csvApPrivacy="$( Misc_TrimString "$csvApPrivacy" )";

		# Add values to the arrays
		declare csvApBssids["$apIndex"]="$csvApBssid";
		declare csvApChannels["$apIndex"]="$csvApChannel";
		declare csvApSsids["$apIndex"]="$csvApSsid";
		declare csvApPrivacies["$apIndex"]="$csvApPrivacy";		
		declare csvApStationCounts["$apIndex"]="$( cat "$captureFilepath" | tail -n "+${stationSectionStart}" | grep "$csvApBssid" | wc -l )";
		declare stationCountTotal=$(( stationCountTotal + ${csvApStationCounts["$apIndex"]} ));
		declare apIndex=$(( apIndex + 1 ));
	done < <( cat "$captureFilepath" | head -n "$stationSectionStart" );

	[[ "$verbose" != 0 ]] && Misc_PrintF -v 5 -t 'd' -nf $'Found %s AP%s and %s associated station%s in capture CSV file: \'%s\'' -- \
		"${#csvApBssids[@]}" "$( (( ${#csvApBssids[@]} > 1 )) && printf 's'; )" "$stationCountTotal" "$( (( stationCountTotal > 1 )) && printf 's'; )" \
		"$( basename -- "$captureFilepath" 2> '/dev/null'; )";

	# If didn't find any AP
	# if [[ ${#csvApBssids[@]} == 0 ]];
	# then
	# 	return 1;
	# fi

	# Found AP

	Capture_CsvApRead_outputVariableReference=( "${csvApBssids[@]}" );
	Capture_CsvApRead_outputVariableReferenceChannels=( "${csvApChannels[@]}" );
	Capture_CsvApRead_outputVariableReferenceSsids=( "${csvApSsids[@]}" );
	Capture_CsvApRead_outputVariableReferencePrivacies=( "${csvApPrivacies[@]}" );
	Capture_CsvApRead_outputVariableReferenceStationCounts=( "${csvApStationCounts[@]}" );

	return 0;
}