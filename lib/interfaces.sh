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

declare -r _Lib_interfaces=1;
declare -r _Interfaces_sourceFilepath="$( readlink -e -- "${BASH_SOURCE[0]:-$0}" 2> '/dev/null'; )";
declare -r _Interfaces_sourceDirpath="$( dirname -- "$_Interfaces_sourceFilepath" 2> '/dev/null'; )";

[[ ! -f "$_Interfaces_sourceFilepath" || ! -d "$_Interfaces_sourceDirpath" ]] && exit 199;

#############
# Variables #
#############

Interface_DeviceMain='';
Interface_DeviceSecondary='';

############################################################
# Methods                                                  #
############################################################

Interface_Exists()
{
	declare args;

	if ! Options args \
		'@0/^[0-1]$/' \
		'@1/^[0-1]$/' \
		'-i;-v' \
		"$@";
	then
		Misc_PrintF -v 1 -t 'f' -nf $'[Interface_Exists] Invalid options (code %s, index %s ~ \'%s\'): \'%s\'' -- \
			"$_Options_ResultCode" \
			"$_Options_FailIndex" \
			"$_Options_ErrorMessage" \
			"$( Misc_ArrayJoin -- "$@" )";

		exit 200;
	fi

	declare ignoreFail="${args[0]}";
	declare verbose="${args[1]}";
	declare interfaces=( "${args[@]:2}" );

	if [ "${#interfaces[@]}" = 0 ];
	then
		Misc_PrintF -v 1 -t 'f' -n $'No interface declared to verify';

		return 100;
	fi

	########
	# Main #
	########

	declare returnCode=0;
	declare interfaceIndex;

	for (( interfaceIndex = 0; interfaceIndex < ${#interfaces[@]}; interfaceIndex++ ));
	do
		declare interface="${interfaces[$interfaceIndex]}";

		if ! airmon-ng | grep -E "$interface\s+" &>> "$_Main_Dump";
		then
			if [ "$verbose" != 0 ];
			then
				Misc_PrintF -v 2 -t 'e' -nmf $'No such 802.11 interface: "{{@clRed}}%s{{@clDefault}}"' -- \
					"$interface";
			fi

			if [ "$ignoreFail" = 0 ];
			then
				return 1;
			fi

			(( returnCode < 1 )) && declare returnCode=1;

			continue;
		fi

		if [ "$verbose" != 0 ];
		then
			Misc_PrintF -v 4 -t 's' -nmf $'Found 802.11 interface: "{{@clLightGreen}}%s{{@clDefault}}"' -- \
				"$interface";
		fi		
	done

	return "$returnCode";
}

Interface_ConflictsTerminate()
{
	declare args;

	if ! Options args \
		'@0/^[0-1]$/' \
		'@1/^[0-1]$/' \
		'-i;-v' \
		"$@";
	then
		Misc_PrintF -v 1 -t 'f' -nf $'[Interface_ConflictsTerminate] Invalid options (code %s, index %s ~ \'%s\'): \'%s\'' -- \
			"$_Options_ResultCode" \
			"$_Options_FailIndex" \
			"$_Options_ErrorMessage" \
			"$( Misc_ArrayJoin -- "$@" )";

		exit 200;
	fi

	declare ignoreFail="${args[0]}";
	declare verbose="${args[1]}";
	declare interfaces=( "${args[@]:2}" );

	if [ "${#interfaces[@]}" = 0 ];
	then
		Misc_PrintF -v 1 -t 'f' -n $'No interface declared to verify';

		return 100;
	fi

	########
	# Main #
	########

	declare returnCode=0;
	declare interfaceIndex;

	for (( interfaceIndex = 0; interfaceIndex < ${#interfaces[@]}; interfaceIndex++ ));
	do
		declare interface="${interfaces[$interfaceIndex]}";

		if ! Interface_Exists -- "$interface";
		then
			if [ "$verbose" != 0 ];
			then
				Misc_PrintF -v 2 -t 'e' -nmf $'No such 802.11 interface to terminate conflicts: "{{@clRed}}%s{{@clDefault}}"' -- \
					"$interface";
			fi

			if [ "$ignoreFail" = 0 ];
			then
				return 3;
			fi

			(( returnCode < 3 )) && declare returnCode=3;

			continue;
		fi

		declare interfaceConflicts;

		if ! Environment_ProcessStart -o Interface_ConflictsTerminate_interfaceConflicts -- "airmon-ng check '${interface}'";
		then
			if [ "$verbose" != 0 ];
			then
				Misc_PrintF -v 2 -t 'e' -nmf $'Failed to search for conflicts for 802.11 interface: "{{@clRed}}%s{{@clDefault}}"' -- \
					"$interface";
			fi

			if [ "$ignoreFail" = 0 ];
			then
				return 2;
			fi

			(( returnCode < 2 )) && declare returnCode=2;

			continue;
		fi

		declare interfaceConflictPids=(
			$( printf '%s' "$Interface_ConflictsTerminate_interfaceConflictsOut" | sed -n -e '/PID Name/,$p' | tail -n +2 | awk '{print $1}'; )
		);

		declare interfaceConflictNames=( 
			$( printf '%s' "$Interface_ConflictsTerminate_interfaceConflictsOut" | sed -n -e '/PID Name/,$p' | tail -n +2 | awk '{print $2}'; )
		);

		declare interfaceConflictIndex;

		for (( interfaceConflictIndex = 0; interfaceConflictIndex < ${#interfaceConflictPids[@]}; interfaceConflictIndex++ ));
		do
			declare interfaceConflictPid="${interfaceConflictPids[$interfaceConflictIndex]}";
			declare interfaceConflictName="${interfaceConflictNames[$interfaceConflictIndex]}";

			if ! Environment_ProcessIDTerminate -t 1 -- "${interfaceConflictPid[@]}";
			then
				if [ "$verbose" != 0 ];
				then
					Misc_PrintF -v 2 -t 'e' -nmf $'Failed to terminate \'%s\' (%s, %s/%s) conflict for 802.11 interface: "{{@clRed}}%s{{@clDefault}}"' -- \
						"$interfaceConflictName" "$interfaceConflictPid" "$(( interfaceConflictIndex + 1 ))" "${#interfaceConflictPids[@]}" "$interface";
				fi

				if [ "$ignoreFail" = 0 ];
				then
					return 1;
				fi

				(( returnCode < 1 )) && declare returnCode=1;

				continue;
			fi

			if [ "$verbose" != 0 ];
			then
				Misc_PrintF -v 5 -t 'd' -nmf $'Terminated \'%s\' (%s, %s/%s) conflict for 802.11 interface: "{{@clBlue2}}%s{{@clDefault}}"' -- \
					"$interfaceConflictName" "$interfaceConflictPid" "$(( interfaceConflictIndex + 1 ))" "${#interfaceConflictPids[@]}" "$interface";
			fi
		done

		if ! airmon-ng check kill &>> "$_Main_Dump";
		then
			Misc_PrintF -v 2 -t 'e' -nmf $'Failed to terminate conflict processes using \'airmon-ng\'. Ignored.';
		fi

		if [ "$verbose" != 0 ];
		then
			Misc_PrintF -v 4 -t 's' -nmf $'Terminated %s conflicts for 802.11 interface: "{{@clBlue2}}%s{{@clDefault}}"' -- \
				"${#interfaceConflictPids[@]}" "$interface";
		fi
	done

	return "$returnCode";
}

Interface_IsModeMonitor()
{
	###########
	# Options #
	###########

	declare args;

	if ! Options args \
		'@0/^[0-1]$/' \
		'@1/^[0-1]$/' \
		'-i;-v' \
		"$@";
	then
		Misc_PrintF -v 1 -t 'f' -nf $'[Interface_IsModeMonitor] Invalid options (code %s, index %s ~ \'%s\'): \'%s\'' -- \
			"$_Options_ResultCode" \
			"$_Options_FailIndex" \
			"$_Options_ErrorMessage" \
			"$( Misc_ArrayJoin -- "$@" )";

		exit 200;
	fi

	declare ignoreFail="${args[0]}";
	declare verbose="${args[1]}";
	declare interfaces=( "${args[@]:2}" );

	if [ "${#interfaces[@]}" = 0 ];
	then
		Misc_PrintF -v 1 -t 'f' -n $'No interface declared to check its \'monitor\' status';

		return 100;
	fi

	########
	# Main #
	########

	declare returnCode=0;
	declare interfaceIndex;

	for (( interfaceIndex = 0; interfaceIndex < ${#interfaces[@]}; interfaceIndex++ ));
	do
		declare interface="${interfaces[$interfaceIndex]}";

		if ! iwconfig 2>&1 | grep "$interface" | grep 'Monitor' &>> "$_Main_Dump";
		then
			if [ "$verbose" != 0 ];
			then
				Misc_PrintF -v 2 -t 'e' -nmf $'802.11 interface is {{@clRed}}not{{@clDefault}} in \'monitor\' mode: "{{@clRed}}%s{{@clDefault}}"' -- \
					"$interface";
			fi

			if [ "$ignoreFail" = 0 ];
			then
				return 1;
			fi

			(( returnCode < 1 )) && declare returnCode=1;

			continue;
		fi

		if [ "$verbose" != 0 ];
		then
			Misc_PrintF -v 4 -t 's' -nmf $'802.11 interface is in \'monitor\' mode: "{{@clLightGreen}}%s{{@clDefault}}"' -- \
				"$interface";
		fi		
	done

	return "$returnCode";
}

Interface_FromDevice()
{
	###########
	# Options #
	###########

	declare args;

	if ! Options args \
		'?!-d;?-o;-v' \
		"$@";
	then
		Misc_PrintF -v 1 -t 'f' -nf $'[Interface_FromDevice] Invalid options (code %s, index %s ~ \'%s\'): \'%s\'' -- \
			"$_Options_ResultCode" \
			"$_Options_FailIndex" \
			"$_Options_ErrorMessage" \
			"$( Misc_ArrayJoin -- "$@" )";

		exit 200;
	fi

	declare __device="${args[0]}";
	declare __outputVariableReferenceName="${args[1]}";
	declare __verbose="${args[2]}";

	if [[ "$__outputVariableReferenceName" != '' ]];
	then
		if [ "$__outputVariableReferenceName" = 'Interface_FromDevice_outputVariableReference' ];
		then
			Misc_PrintF -v 1 -t 'f' -nf $'[Interface_FromDevice] Output variable reference interference: \'%s\'' -- \
				"$( Misc_ArrayJoin -- "$@" )";

			return 100;
		fi

		declare -n  Interface_FromDevice_outputVariableReference="${__outputVariableReferenceName}";
		Interface_FromDevice_outputVariableReference='';
	fi

	########
	# Main #
	########

	if [[ "$__device" == '' ]];
	then
		[[ "$__verbose" != 0 ]] && Misc_PrintF -v 2 -t 'e' -nmf $'No such 802.11 device: \'%s\'' -- "$__device";

		return 1;
	fi

	declare devicePath="/sys/class/ieee80211/${__device}/device/net";
	declare interface='';

	# If there is such directory and there is a single device directory in it
	if Base_FsExists -t 2 -- "$devicePath" && [[ "$( Base_FsDirectoryContains -d 1 -t 2 -- "$devicePath" )" == 1 ]];
	then
		declare interface="$( basename -- "${devicePath}/"* 2> '/dev/null'; )";
	fi

	if [[ "$interface" == '' ]];
	then
		[[ "$__verbose" != 0 ]] && Misc_PrintF -v 2 -t 'e' -nmf $'No such 802.11 device or inappropriate interface: \'%s\'' -- "$__device";

		return 1;
	fi

	if [[ "$__outputVariableReferenceName" != '' ]];
	then
		Interface_FromDevice_outputVariableReference="$interface";

		return 0;
	fi

	printf '%s' "$interface";
}

Interface_ModeSet()
{
	###########
	# Options #
	###########

	declare args;

	if ! Options args \
		'@0/^[0-1]$/' \
		'@2/^[0-1]$/' \
		'@3/^[0-2]$/' \
		'?!-m;?-o;-i;-v' \
		"$@";
	then
		Misc_PrintF -v 1 -t 'f' -nf $'[Interface_ModeSet] Invalid options (code %s, index %s ~ \'%s\'): \'%s\'' -- \
			"$_Options_ResultCode" \
			"$_Options_FailIndex" \
			"$_Options_ErrorMessage" \
			"$( Misc_ArrayJoin -- "$@" )";

		exit 200;
	fi

	declare modeType="${args[0]}";
	declare outputVariableReferenceName="${args[1]}";
	declare ignoreFail="${args[2]}";
	declare verbose="${args[3]}";
	declare devices=( "${args[@]:4}" );

	if [[ "$outputVariableReferenceName" != '' ]];
	then
		if [[ "$outputVariableReferenceName" == 'Interface_ModeSet_outputVariableReference' ]];
		then
			Misc_PrintF -v 1 -t 'f' -nf $'[Interface_ModeSet] Output variable reference interference: \'%s\'' -- \
				"$( Misc_ArrayJoin -- "$@" )";

			return 100;
		fi

		declare -n  Interface_ModeSet_outputVariableReference="${outputVariableReferenceName}";
		Interface_ModeSet_outputVariableReference=();
	fi

	if [[ "${#devices[@]}" == 0 ]];
	then
		Misc_PrintF -v 1 -t 'f' -n $'No device declared to set its mode';

		return 100;
	fi

	########
	# Main #
	########

	declare returnCode=0;
	declare deviceIndex;
	declare deviceProcessed=();

	for (( deviceIndex = 0; deviceIndex < ${#devices[@]}; deviceIndex++ ));
	do
		declare device="${devices[$deviceIndex]}";
		declare Interface_ModeSet_interface;

		if ! Interface_FromDevice -o Interface_ModeSet_interface -d "$device";
		then
			[[ "$verbose" != 0 ]] && Misc_PrintF -v 3 -t 'w' -nmf $'Failed to obtain 802.11 device interface: \'%s\'' -- "$device";

			deviceProcessed[$deviceIndex]='';

			return 2;
		fi

		declare interface="$Interface_ModeSet_interface";
		declare interfaceProcessed='';

		case "$modeType" in
			1) # Monitor
				if Interface_IsModeMonitor -- "$interface";
				then
					[[ "$verbose" != 0 ]] && Misc_PrintF -v 3 -t 'w' -nmf $'802.11 interface (\'%s\') is already in \'monitor\' mode: \'%s\'' -- \
						"$device" "$interface";

					deviceProcessed[$deviceIndex]="$interface";

					continue;
				fi

				if ! Interface_ConflictsTerminate $( (( verbose > 1 )) && printf -- ' -v ' ) -- "$interface";
				then
					[[ "$verbose" != 0 ]] && Misc_PrintF -v 3 -t 'w' \
						-nmf $'Failed to terminate all conflicts to properly set interface (\'%s\') to \'monitor\' mode: \'%s\'' -- "$device" "$interface";

					if [ "$ignoreFail" = 0 ];
					then
						return 2;
					fi

					deviceProcessed[$deviceIndex]="$interface";

					continue;
				fi

				[[ "$verbose" != 0 ]] && Misc_PrintF -v 4 -t 'i' -nmf $'Setting interface (\'%s\') to \'monitor\' mode: \'%s\'...' -- \
					"$device" "$interface";

				declare Interface_ModeSet_interface;

				if ! airmon-ng start "$interface" &>> "$_Main_Dump" || ! Interface_FromDevice -o Interface_ModeSet_interface -d "$device";
				then
					[[ "$verbose" != 0 ]] && Misc_PrintF -v 2 -t 'e' -nmf $'Failed to properly set interface (\'%s\') to \'monitor\' mode: \'%s\'' -- \
						"$device" "$interface";

					deviceProcessed[$deviceIndex]='';

					return 1;
				fi

				declare interfaceProcessed="$Interface_ModeSet_interface";

				if ! Interface_IsModeMonitor -- "$interfaceProcessed";
				then
					[[ "$verbose" != 0 ]] && Misc_PrintF -v 2 -t 'e' \
						-nmf $'Failed to properly set interface (\'%s\') to \'monitor\' mode. Still not \'monitor\': \'%s\'' -- \
						"$device" "$interfaceProcessed";

					deviceProcessed[$deviceIndex]='';

					return 1;
				fi

				[[ "$verbose" != 0 ]] && Misc_PrintF -v 4 -t 's' -nmf $'Set interface (\'%s\') to \'monitor\' mode: \'%s\'%s' -- \
					"$device" "$interface" "$( [ "$interface" != "$interfaceProcessed" ] && printf -- $' -> \'%s\'' "$interfaceProcessed" )";
			;;
			0) # Promiscuous
				if ! Interface_IsModeMonitor -- "$interface";
				then
					[[ "$verbose" != 0 ]] && Misc_PrintF -v 3 -t 'w' -nmf $'802.11 interface (\'%s\') is already in "promiscuous" mode: \'%s\'' -- \
						"$device" "$interface";

					deviceProcessed[$deviceIndex]="$interface";

					continue;
				fi

				if ! Interface_ConflictsTerminate -- "$interface";
				then
					[[ "$verbose" != 0 ]] && Misc_PrintF -v 3 -t 'w' \
						-nmf $'Failed to terminate all conflicts to properly set interface (\'%s\') to "promiscuous" mode: \'%s\'' -- "$device" "$interface";

					if [ "$ignoreFail" = 0 ];
					then
						return 2;
					fi

					deviceProcessed[$deviceIndex]="$interface";

					continue;
				fi

				[[ "$verbose" != 0 ]] && Misc_PrintF -v 4 -t 'i' -nmf $'Setting interface (\'%s\') to "promiscuous" mode: \'%s\'...' -- \
					"$device" "$interface";

				declare Interface_ModeSet_interface;

				if ! airmon-ng stop "$interface" &>> "$_Main_Dump" || ! Interface_FromDevice -o Interface_ModeSet_interface -d "$device";
				then
					[[ "$verbose" != 0 ]] && Misc_PrintF -v 2 -t 'e' -nmf $'Failed to to properly set interface (\'%s\') to "promiscuous" mode: \'%s\'' -- \
						"$device" "$interface";

					deviceProcessed[$deviceIndex]='';

					return 1;
				fi

				declare interfaceProcessed="$Interface_ModeSet_interface";

				if Interface_IsModeMonitor -- "$interfaceProcessed";
				then
					[[ "$verbose" != 0 ]] && Misc_PrintF -v 2 -t 'e' \
						-nmf $'Failed to to properly set interface (\'%s\') to "promiscuous" mode. Still \'monitor\': \'%s\'' -- "$device" "$interfaceProcessed";

					deviceProcessed[$deviceIndex]='';

					return 1;
				fi

				[[ "$verbose" != 0 ]] && Misc_PrintF -v 4 -t 's' -nmf $'Set 802.11 interface \'%s\' to "promiscuous" mode: \'%s\'%s' -- \
					"$device" "$interface" "$( [ "$interface" != "$interfaceProcessed" ] && printf -- $' -> \'%s\'' "$interfaceProcessed" )";
			;;
		esac

		deviceProcessed[$deviceIndex]="$interfaceProcessed";
	done

	# If requested to set to a referenced variable
	if [ "$outputVariableReferenceName" != '' ];
	then
		Interface_ModeSet_outputVariableReference=( "${deviceProcessed[@]}" );
	fi

	return "$returnCode";
}

# List 802.11 interfaces
Interface_List()
{
	declare devicePath;
	declare deviceList=();

	for devicePath in '/sys/class/ieee80211/'*;
	do
		declare device="$( basename -- "$devicePath" 2> '/dev/null'; )";
		declare Interface_List_interface;
		deviceList+=("$device");

		if ! Interface_FromDevice -o Interface_List_interface -d "$device";
		then
			deviceList+=('' '');

			continue;
		fi

		declare interface="$Interface_List_interface";
		declare deviceState="$( Interface_IsModeMonitor -- "$interface" && printf 'monitor'; )"; # $(( ! $? ))
		deviceList+=("$interface" "$deviceState");
	done

	Misc_TablePrint -c 3 -- 'Device' 'Interface' 'State' "${deviceList[@]}";
}

Interface_State()
{
	###########
	# Options #
	###########

	declare args;

	if ! Options args \
		'?!-d;-D;-v' \
		"$@";
	then
		Misc_PrintF -v 1 -t 'f' -nf $'[Interface_State] Invalid options (code %s, index %s ~ \'%s\'): \'%s\'' -- \
			"$_Options_ResultCode" \
			"$_Options_FailIndex" \
			"$_Options_ErrorMessage" \
			"$( Misc_ArrayJoin -- "$@" )";

		exit 200;
	fi

	declare device="${args[0]}";
	declare disable="${args[1]}";
	declare verbose="${args[2]}";

	########
	# Main #
	########

	declare Interface_State_interface;

	if ! Interface_FromDevice -o Interface_State_interface -d "$device";
	then
		[[ "$verbose" != 0 ]] && Misc_PrintF -v 2 -t 'e' -nmf $'Could not process interface status. Failed to query interface of device: \'%s\'' -- "$device";

		return 1;
	fi

	declare interface="$Interface_State_interface";
	declare command='up';

	if [[ "$disable" != 0 ]];
	then
		declare command='down';
	fi

	# Try to turn up
	if ! ifconfig "$interface" "$command" &>> "$_Main_Dump";
	then
		[[ "$verbose" != 0 ]] && Misc_PrintF -v 2 -t 'e' -nmf $'Failed to turn %s interface: \'%s\'' -- "$command" "$interface";

		return 1;
	fi

	[[ "$verbose" != 0 ]] && Misc_PrintF -v 4 -t 's' -nmf $'Successfully turned %s interface: \'%s\'' -- "$command" "$interface";

	sleep 2;
}

# Change the MAC of interface
Interface_DeviceMac()
{
	###########
	# Options #
	###########

	declare args;

	if ! Options args \
		'@1/^([0-9A-F]{2}:){5}[0-9A-F]{2}$/' \
		'?!-d;?-m;-r;-c;-v' \
		"$@";
	then
		Misc_PrintF -v 1 -t 'f' -nf $'[Interface_DeviceMac] Invalid options (code %s, index %s ~ \'%s\'): \'%s\'' -- \
			"$_Options_ResultCode" \
			"$_Options_FailIndex" \
			"$_Options_ErrorMessage" \
			"$( Misc_ArrayJoin -- "$@" )";

		exit 200;
	fi

	declare device="${args[0]}";
	declare macNew="${args[1]}";
	declare macReset="${args[2]}";
	declare macChanged="${args[3]}";
	declare verbose="${args[4]}";

	########
	# Main #
	########

	declare Interface_DeviceMac_interface;

	if ! Interface_ModeSet -im 0 -- "$device" || ! Interface_FromDevice -o Interface_DeviceMac_interface -d "$device";
	then
		[[ "$verbose" != 0 ]] && Misc_PrintF -v 2 -t 'e' -nmf $'Couldn not change MAC of interface (%s). Failed to prepare device: \'%s\'' -- \
			"$( [[ "$macReset" != 0 ]] && printf 'reset' || printf 'to %s' "$macNew"; )" "$device";

		return 1;
	fi

	declare interface="$Interface_DeviceMac_interface";

	if [[ "$interface" == '' ]];
	then
		[[ "$verbose" != 0 ]] && Misc_PrintF -v 2 -t 'e' -nmf $'Couldn not change MAC of interface. Failed to retrieve interface of device: \'%s\'' -- "$device";

		return 1;
	fi

	# If reset the MAC
	if [[ "$macReset" != 0 ]];
	then
		# Get the current MAC
		declare macBeforeReset="$( Interface_DeviceMac -d "$device" )";

		if [[ ! "$macBeforeReset" =~ ^([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}$ ]];
		then
			[[ "$verbose" != 0 ]] && Misc_PrintF -v 2 -t 'e' -nmf $'Failed to retrieve old MAC of interface \'%s\' before reset: \'%s\'' -- "$interface" "$macBeforeReset";

			return 1;
		fi

		if ! Interface_State -d "$device" -D;
		then
			[[ "$verbose" != 0 ]] && Misc_PrintF -v 2 -t 'e' -nmf $'Failed to turn down interface \'%s\' before reset' -- "$interface";

			return 1;
		fi

		# Try to reset the MAC

		declare macchangerStdOut;
		macchangerStdOut="$( macchanger -p "$interface" 2>> "$_Main_Dump" )";
		declare macchangerReturnCode=$?;

		if [[ "$macchangerReturnCode" != 0 ]] && ( ! printf '%s' "$macchangerStdOut" | grep -q -- $'It\'s the same MAC' || [[ "$macChanged" != 0 ]] );
		then
			[[ "$verbose" != 0 ]] && Misc_PrintF -v 2 -t 'e' -nmf $'Failed to reset MAC of interface (code %s): \'%s\'' -- "$macchangerReturnCode" "$interface";

			return 2;
		fi

		sleep 2;

		if ! Interface_State -d "$device";
		then
			[[ "$verbose" != 0 ]] && Misc_PrintF -v 2 -t 'e' -nmf $'Failed to turn up interface \'%s\' after reset' -- "$interface";

			return 1;
		fi

		# Get the current MAC
		declare macAfterReset="$( Interface_DeviceMac -d "$device" )";

		if [[ ! "$macAfterReset" =~ ^([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}$ ]];
		then
			[[ "$verbose" != 0 ]] && Misc_PrintF -v 2 -t 'e' -nmf $'Failed to retrieve new MAC of interface \'%s\' after reset' -- "$interface";

			return 3;
		fi

		if [ "$verbose" != 0 ];
		then
			# If the new MAC matches with the old
			if [[ "$macBeforeReset" == "$macAfterReset" ]];
			then
				Misc_PrintF -v 3 -t 'w' -nmf $'MAC reset of interface \'%s\' resulted in same value: \'%s\'' -- "$interface" "$macAfterReset";
			else
				Misc_PrintF -v 4 -t 's' -nmf $'Successfully reset MAC of interface \'%s\': \'%s\' -> \'%s\'' -- "$interface" "$macBeforeReset" "$macAfterReset";
			fi
		fi
		
		return 0;
	elif [[ "$macNew" != '' ]]; # If change the MAC
	then
		declare macNew="$( Misc_ToLowUpString "$macNew" )";
		declare macOld="$( Interface_DeviceMac -d "$device" )";

		if [[ ! "$macOld" =~ ^([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}$ ]];
		then
			[[ "$verbose" != 0 ]] && Misc_PrintF -v 2 -t 'e' -nmf $'Failed to retrieve old MAC of interface \'%s\' before change: \'%s\'' -- "$interface" "$macOld";

			return 4;
		fi

		# If the MAC is the same
		if [ "$macOld" = "$macNew" ];
		then
			[[ "$verbose" != 0 ]] && Misc_PrintF -v 3 -t 'w' -nmf $'MAC of interface \'%s\' is already set to: \'%s\'' -- "$interface" "$macOld";

			return 0;
		fi

		if ! Interface_State -d "$device" -D;
		then
			[[ "$verbose" != 0 ]] && Misc_PrintF -v 2 -t 'e' -nmf $'Failed to turn down interface \'%s\' before change' -- "$interface";

			return 1;
		fi

		# Try to change the MAC

		declare macchangerStdOut;
		macchangerStdOut="$( macchanger -m "$macNew" "$interface" 2>> "$_Main_Dump" )";
		declare macchangerReturnCode=$?;

		# if ! macchanger -m "$macNew" "$interface" &>> "$_Main_Dump";
		if [[ "$macchangerReturnCode" != 0 ]] && ( ! printf '%s' "$macchangerStdOut" | grep -q -- $'It\'s the same MAC' || [[ "$macChanged" != 0 ]] );
		then
			[[ "$verbose" != 0 ]] && Misc_PrintF -v 2 -t 'e' -nmf $'Failed to set MAC of interface \'%s\' (code %s): \'%s\'' -- \
				"$interface" "$macchangerReturnCode" "$macNew";

			return 2;
		fi

		sleep 2;

		if ! Interface_State -d "$device";
		then
			[[ "$verbose" != 0 ]] && Misc_PrintF -v 2 -t 'e' -nmf $'Failed to turn up interface \'%s\' after change' -- "$interface";

			return 1;
		fi

		# Get the current MAC
		declare macModified="$( Interface_DeviceMac -d "$device" )";

		# If the MAC matches with the requested
		if [ "$macModified" = "$macNew" ];
		then
			[[ "$verbose" != 0 ]] && Misc_PrintF -v 4 -t 's' -nmf $'Successfully changed MAC of interface \'%s\': \'%s\' -> \'%s\'' -- \
				"$interface" \
				"$macOld" \
				"$macModified";

			return 0;
		fi

		[[ "$verbose" != 0 ]] && Misc_PrintF -v 2 -t 'e' -nmf $'Failed to set MAC of interface (%s). Mismacthes: \'%s\' with requested - \'%s\'' -- \
			"$interface" \
			"$macModified" \
			"$macNew";

		return 1;
	else # If print the current MAC
		declare macFound="$( ip -o link 2>> "$_Main_Dump" | grep "$interface" | awk '{ print $(NF-2); };' 2>> "$_Main_Dump" )";

		if [[ ! "$macFound" =~ ^([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}$ ]];
		then
			[[ "$verbose" != 0 ]] && Misc_PrintF -v 2 -t 'e' -nmf $'Failed to retrieve MAC of interface \'%s\': \'%s\'' -- "$interface" "$macFound";

			return 1;
		fi

		printf '%s' "$macFound";

		return 0;
	fi

	return 1;
}