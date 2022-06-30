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

declare -r _Lib_environment=1;
declare -r _Environment_sourceFilepath="$( readlink -e -- "${BASH_SOURCE[0]:-$0}" 2> '/dev/null'; )";
declare -r _Environment_sourceDirpath="$( dirname -- "$_Environment_sourceFilepath" 2> '/dev/null'; )";

[[ ! -f "$_Environment_sourceFilepath" || ! -d "$_Environment_sourceDirpath" ]] && exit 199;

#---
# File system
#---

declare -r Environment_sessionDirPrefix='session';

# File names

declare -r Environment_pidsBoundFilename='pids_bound';

# Directory names

declare -r Environment_resourcesDirname='resources';
declare -r Environment_resourcesWebDirname='web';
declare -r Environment_librariesDirname='lib';
declare -r Environment_workspaceDirname="workspace";
declare -r Environment_librariesVendorDirname='vendor';
declare -r Environment_sessionsDirname="sessions";
declare -r Environment_soundsDirname='sounds';
declare -r Environment_logsDirname="logs";
declare -r Environment_configsDirname='configs';
declare -r Environment_tempDirname="temp";
declare -r Environment_webDirname='web';
declare -r Environment_webDesignsDirname='designs';
declare -r Environment_webRootDirname='public';

# Directory paths

declare -r Environment_currentDirpath="$_Main_sourceDirpath";
declare -r Environment_resourcesDirpath="${Environment_currentDirpath}/${Environment_resourcesDirname}";
declare -r Environment_librariesDirpath="${Environment_currentDirpath}/${Environment_librariesDirname}";
declare -r Environment_workspaceDirpath="${Environment_currentDirpath}/${Environment_workspaceDirname}";
declare -r Environment_librariesVendorDirpath="${Environment_librariesDirpath}/${Environment_librariesVendorDirname}";
declare -r Environment_sessionsDirpath="${Environment_workspaceDirpath}/${Environment_sessionsDirname}";

# Session

declare Environment_sessionId='';
declare Environment_sessionDirpath='';

# Regenerate session path if such exists
while [[ -d "$Environment_sessionDirpath" || "$Environment_sessionDirpath" == '' ]];
do
	Environment_sessionId="$( Misc_RandomString -l 8; )";
	Environment_sessionDirpath="${Environment_sessionsDirpath}/${Environment_sessionDirPrefix}-${Environment_sessionId}";
done

declare -r Environment_SessionId="$Environment_sessionId";
declare -r Environment_SessionDirpath="$Environment_sessionDirpath";
unset Environment_sessionId;
unset Environment_sessionDirpath;
declare -r Environment_resourcesWebDirpath="${Environment_resourcesDirpath}/${Environment_resourcesWebDirname}";
declare -r Environment_SoundsDirpath="${Environment_resourcesDirname}/${Environment_soundsDirname}";
declare -r Environment_LogsDirpath="${Environment_SessionDirpath}/${Environment_logsDirname}";
declare -r Environment_ConfigsDirpath="${Environment_SessionDirpath}/${Environment_configsDirname}";
declare -r Environment_WebDirpath="${Environment_SessionDirpath}/${Environment_webDirname}";

declare -r Environment_resourcesWebDesignsDirpath="${Environment_resourcesWebDirpath}/${Environment_webDesignsDirname}";
declare -r Environment_WebRootDirpath="${Environment_WebDirpath}/${Environment_webRootDirname}";

# File paths

declare -r Environment_pidsBoundFilepath="${Environment_SessionDirpath}/${Environment_pidsBoundFilename}";

# Other

declare -r Environment_trappedSignals=(0 1 2 3 4 5 15);

declare -r Environment_softwareDependencies=(
	'perl'
	'awk'
	'sed'
	'xdotool'
	'macchanger'
	'python'
	'aircrack-ng'
	'airmon-ng'
	'airodump-ng'
	'mdk4'
	'php-cgi'
	'dhcpd'
	'hostapd'
	'play'
);

declare -r Environment_OutputStreamStdIn=="/dev/stdin";
declare -r Environment_OutputStreamStdOut="/dev/stdout";
declare -r Environment_OutputStreamStdErr="/dev/stderr";
declare -r Environment_OutputStreamNull="/dev/null";

declare -r Environment_OutputStreams=(
	"$Environment_OutputStreamStdIn"
	"$Environment_OutputStreamStdOut"
	"$Environment_OutputStreamStdErr"
	"$Environment_OutputStreamNull"
);

# Defaults

declare -r Environment_ProcessIDTerminate_SignalDefault=15; # SIGTERM
declare -r Environment_ProcessIDTerminate_TimeoutDefault=0;
declare -r Environment_TempDirpathDefault="${Environment_SessionDirpath}/${Environment_tempDirname}";

############
# Variales #
############

# Alternatives

Environment_TempDirpath="$Environment_TempDirpathDefault";
Environment_UserNonRoot='';
Environment_WebDesign='';

# Other

Environment_clearCode='';
Environment_exitCode='';
Environment_ClearSession=0;
Environment_ResetInterfacesOnExit=1;

# Window

# Timeout to try to access a window of PID
Environment_WindowTimeoutDefault=4;

Environment_HorizontalSectorCountDefault=1;
Environment_VerticalSectorCountDefault=1;
Environment_HorizontalSectorDefault=0;
Environment_VerticalSectorDefault=0;
Environment_HorizontalGapDefault=20;
Environment_VerticalGapDefault=20;
Environment_HorizontalSectorGapDefault=10;
Environment_VerticalSectorGapDefault=10;

 # Window decorations (KDE Plasma, Theme: Breeze Dark) (e.g. window title bar ~ 20px; border ~ 4px)
Environment_OffsetTopDefault=20;
Environment_OffsetRightDefault=4;
Environment_OffsetBottomDefault=4;
Environment_OffsetLeftDefault=4;

############################################################
# Functions                                                #
############################################################

Environment_ScreenDimensions()
{
	if [[ "$1" != '' ]];
	then
		if [[ ! "$1" =~ ^(0|[1-9][0-9]*)$ ]];
		then
			return 1;
		fi

		screenIndex="$1";
		shift;
	else
		screenIndex="$Misc_ScreenDimensions_ScreenIndexDefault";
	fi

	xdpyinfo | grep -A 3 "screen #${screenIndex}" | grep 'dimensions' | tr -s ' ' | cut -d ' ' -f 3 | sed 's/x/ /';
}

Environment_PidExecName()
{
	if [[ ! "$1" =~ ^(0|[1-9][0-9]*)$ ]];
	then
		return 1;
	fi

	declare result="$( cat "/proc/${1}/status" 2>> "$_Main_Dump" | grep 'Name:' | perl -pe 's/^Name:\s+//'; )";

	if [[ "$result" == '' ]];
	then
		return 1;
	fi

	printf '%s' "$result";

	return 0;
}

############################################################
# Methods                                                  #
############################################################

Environment_prepareResourcesWeb()
{
	declare resourceWebDesignDirpath='';

	if [[ "$Environment_WebDesign" != '' ]];
	then
		declare resourceWebDesignDirpath="${Environment_resourcesWebDesignsDirpath}/${Environment_WebDesign}";
	else
		declare webDesignDirpaths=();
		declare dirpath;

		while read dirpath;
		do
			webDesignDirpaths+=( "$dirpath" );
		done \
		< <(
			find "${Environment_resourcesWebDesignsDirpath}/" -mindepth 1 -maxdepth 1 -type d ! -name '-*' -print;
		);

		if [[ ${#webDesignDirpaths[@]} == 0 ]];
		then
			Misc_PrintF -v 4 -t 'i' -n -- 'Found 0 web designs';

			return 3;
		fi

		if [[ ${#webDesignDirpaths[@]} == 1 ]];
		then
			Misc_PrintF -v 4 -t 'i' -nmf $'Found {{@clLightCyan}}1{{@clDefault}} web design';
			declare resourceWebDesignDirpath="${webDesignDirpaths[0]}";
		else
			Misc_PrintF -v 4 -t 'i' -nmf $'Found {{@clLightCyan}}%s{{@clDefault}} web designs:' -- "${#webDesignDirpaths[@]}";
			Environment_WindowArrange --bm 'main_twincy_terminal' -- $( Environment_WindowSector -H 6 -V 6 -h 1-4 -v 1-4 -t 0 -r 0 -b 0 -l 0 );
			Misc_PrintF -n;
			declare webDesignDirpathCountLength="${#webDesignDirpaths[@]}";
			declare webDesignDirpathCountLength="${#webDesignDirpathCountLength}";
			declare webDesignDirpathIndex;

			for (( webDesignDirpathIndex = 0; webDesignDirpathIndex < ${#webDesignDirpaths[@]}; webDesignDirpathIndex++ ));
			do
				declare webDesignDirpathTemp="${webDesignDirpaths[$webDesignDirpathIndex]}";

				Misc_PrintF -nmf "    [ %${webDesignDirpathCountLength}s ] {{@clGray}}(%s){{@clDefault}} '{{@clWhite}}%s{{@clDefault}}'" -- \
					"$(( webDesignDirpathIndex + 1 ))" "$( date '+%F %T' -d "@$( stat -c '%Y' "$webDesignDirpathTemp"; )"; )" \
					"$( basename -- "$webDesignDirpathTemp" 2> '/dev/null'; )";
			done

			Misc_PrintF -n;
			unset webDesignDirpathIndex;
			declare Environment_Prepare_webDesignDirpathIndex;

			while [[ "${Environment_Prepare_webDesignDirpathIndex+s}" == '' ]];
			do
				# If cancelled
				if ! Misc_Prompt -o Environment_Prepare_webDesignDirpathIndex -p '^(0|[1-9][0-9]*)$' -e "[1-${#webDesignDirpaths[@]}]";
				then
					return 2;
				fi

				if (( Environment_Prepare_webDesignDirpathIndex <= 0 || Environment_Prepare_webDesignDirpathIndex > ${#webDesignDirpaths[@]} ));
				then
					Misc_PrintF -t 'e' -nf 'Index out of range (1-%s)' -- "${#webDesignDirpaths[@]}";
					unset Environment_Prepare_webDesignDirpathIndex;
					declare Environment_Prepare_webDesignDirpathIndex;
				fi
			done

			declare resourceWebDesignDirpath="${webDesignDirpaths[$(( Environment_Prepare_webDesignDirpathIndex - 1 ))]}";
		fi

		Environment_WebDesign=${resourceWebDesignDirpath##*\/};
	fi

	Misc_PrintF -v 4 -t 'n' -nmf $'Preparing web server data (%s)' -- "$Environment_WebDesign";

	if ! Base_FsExists -t d -- "$resourceWebDesignDirpath";
	then
		Misc_PrintF -v 2 -t 'e' -nmf $'No such web resource found: \'%s\'' -- "$resourceWebDesignDirpath";

		return 3;
	fi

	if Base_FsExists -t d -- "$Environment_WebDirpath";
	then
		declare resourcePaths=();
		declare path;

		while read path;
		do
			resourcePaths+=( "$path" );
		done \
		< <(
			find "${Environment_WebDirpath}/" -mindepth 1 -maxdepth 1 ! -name '.' ! -name '..' -print;
		);

		if ! Base_FsDelete -d 0-0 -f -- "${resourcePaths[@]}";
		then
			Misc_PrintF -v 2 -t 'e' -nmf $'Failed to clear web directory: \'%s\'' -- "$Environment_WebDirpath";

			return 1;
		fi
	else
		Base_FsDirectoryCreate -p -- "$Environment_WebDirpath";
	fi

	# Copy "web" resources

	if
		! Base_FsMove -c \
			"${resourceWebDesignDirpath}/"* "${Environment_resourcesWebDirpath}/input.php" "${Environment_WebDirpath}/" ||
		! Base_FsMove -c \
			"${Environment_resourcesWebDirpath}/script.js" "${Environment_WebRootDirpath}/";
	then
		Misc_PrintF -v 2 -t 'e' -nmf $'Failed to copy initial web resources: \'%s\'' -- "${Environment_resourcesWebDirpath}";

		return 3;
	fi
}

#
# Window
#

# Return window's arrange parameters based on "screen sector"
Environment_WindowSector()
{
	###########
	# Options #
	###########

	declare args;

	if ! Options args \
		'@0/^(?:0|[1-9][0-9]*)?$/' \
		'@1/^(?:0|[1-9][0-9]*)?$/' \
		'@2/^(?:0|[1-9][0-9]*)?$/' \
		'@3/^(?:0|[1-9][0-9]*)?$/' \
		'@4/^(?:0|[1-9][0-9]*)?$/' \
		'@5/^(?:0|[1-9][0-9]*)?$/' \
		'@6/^(?:0|[1-9][0-9]*)(?:\-(?:0|[1-9][0-9]*))?$/' \
		'@7/^(?:0|[1-9][0-9]*)(?:\-(?:0|[1-9][0-9]*))?$/' \
		'@8/^(?:0|[1-9][0-9]*)?$/' \
		'@9/^(?:0|[1-9][0-9]*)?$/' \
		'@10/^(?:0|[1-9][0-9]*)?$/' \
		'@11/^(?:0|[1-9][0-9]*)?$/' \
		'?--hsg;?--vsg;?--hg;?--vg;?-H;?-V;?-h;?-v;?-t;?-r;?-b;?-l;-s;-p' \
		"$@";
	then
		Misc_PrintF -v 1 -t 'f' -nf $'[Environment_WindowSector] Invalid options (code %s, index %s ~ \'%s\'): \'%s\'' -- \
			"$_Options_ResultCode" \
			"$_Options_FailIndex" \
			"$_Options_ErrorMessage" \
			"$( Misc_ArrayJoin -- "$@" )";

		exit 200;
	fi

	declare hsg="${args[0]}"; # horizontalSectorGap
	declare vsg="${args[1]}"; # verticalSectorGap
	declare hg="${args[2]}"; # horizontalGap
	declare vg="${args[3]}"; # verticalGap
	declare hsc="${args[4]}"; # horizontalSectorCount
	declare vsc="${args[5]}"; # verticalSectorCount
	declare hs="${args[6]}"; # horizontalSector(s)
	declare vs="${args[7]}"; # verticalSector(s)
	declare ot="${args[8]}"; # offsetTop
	declare or="${args[9]}"; # offsetRight
	declare ob="${args[10]}"; # offsetBottom
	declare ol="${args[11]}"; # offsetLeft
	declare returnSize="${args[12]}";
	declare returnPosition="${args[13]}";
	
	[ "$hsc" = '' ] && declare hsc="$Environment_HorizontalSectorCountDefault";
	[ "$vsc" = '' ] && declare vsc="$Environment_VerticalSectorCountDefault";
	[ "$hs" = '' ] && declare hs="$Environment_HorizontalSectorDefault";
	[ "$vs" = '' ] && declare vs="$Environment_VerticalSectorDefault";
	[ "$hg" = '' ] && declare hg="$Environment_HorizontalGapDefault";
	[ "$vg" = '' ] && declare vg="$Environment_VerticalGapDefault";
	[ "$hsg" = '' ] && declare hsg="$Environment_HorizontalSectorGapDefault";
	[ "$vsg" = '' ] && declare vsg="$Environment_VerticalSectorGapDefault";
	[ "$ot" = '' ] && declare ot="$Environment_OffsetTopDefault";
	[ "$or" = '' ] && declare or="$Environment_OffsetRightDefault";
	[ "$ob" = '' ] && declare ob="$Environment_OffsetBottomDefault";
	[ "$ol" = '' ] && declare ol="$Environment_OffsetLeftDefault";

	########
	# Main #
	########

	declare hss=1;
	declare vss=1;

	# If the sector includes multiple sectors (e.g. 1-3 - sectors from 1 to 3)
	if [[ "$hs" =~ [0-9][1-9]*\-[0-9][1-9]* ]];
	then
		declare hss="$(( ${hs#*\-} - ${hs%\-*} ))";
		declare hss="$(( ${hss#-} + 1 ))"; # Absolute + 1
		declare hs="${hs%\-*}";
	fi

	if [[ "$vs" =~ [0-9][1-9]*\-[0-9][1-9]* ]];
	then
		declare vss="$(( ${vs#*\-} - ${vs%\-*} ))";
		declare vss="$(( ${vss#-} + 1 ))";
		declare vs="${vs%\-*}";
	fi

	declare screenDimensions=( $( Environment_ScreenDimensions ) );
	declare sectorW="$(( ( screenDimensions[0] - hg * 2 - hsg * ( hsc - 1 ) ) / hsc - ( ol + or ) ))";
	declare sectorH="$(( ( screenDimensions[1] - vg * 2 - vsg * ( vsc - 1 ) ) / vsc - ( ot + ob ) ))";
	declare sectorX="$(( hg + ( sectorW + hsg + ( ol + or ) ) * hs ))";
	declare sectorY="$(( vg + ( sectorH + vsg + ( ot + ob ) ) * vs ))";
	declare windowW="$(( sectorW * hss + hsg * (hss - 1) ))";
	declare windowH="$(( sectorH * vss + vsg * (vss - 1) ))";
	declare windowX="$sectorX";
	declare windowY="$sectorY";

	if [ "$returnSize" != 0 ];
	then
		printf '%s %s' "$windowW" "$windowH";
	elif [ "$returnPosition" != 0 ];
	then
		printf '%s %s' "$windowX" "$windowY";
	else
		printf '%s %s %s %s' "$windowW" "$windowH" "$windowX" "$windowY";
	fi

	return 0;
}

# Return name of window by window ID
Environment_WindowNameByID()
{
	###########
	# Options #
	###########

	declare args;

	if ! Options args \
		'@0/^(?:0|[1-9][0-9]+)$/' \
		'?!-w;?-o;-v' \
		"$@";
	then
		Misc_PrintF -v 1 -t 'f' -nf $'[Environment_WindowNameByID] Invalid options (code %s, index %s ~ \'%s\'): \'%s\'' -- \
			"$_Options_ResultCode" \
			"$_Options_FailIndex" \
			"$_Options_ErrorMessage" \
			"$( Misc_ArrayJoin -- "$@" )";

		exit 200;
	fi

	declare __windowId=="${args[0]}";
	declare __outputVariableReferenceName="${args[1]}";
	declare __verbose="${args[2]}";

	if [ "$__outputVariableReferenceName" != '' ];
	then
		if [ "$__outputVariableReferenceName" = 'Environment_WindowNameByID_outputVariableReference' ];
		then
			Misc_PrintF -v 1 -t 'f' -nf $'[Environment_WindowNameByID] Output variable reference interference: \'%s\'' -- "$( Misc_ArrayJoin -- "$@" )";

			return 100;
		fi

		declare -n Environment_WindowNameByID_outputVariableReference="$__outputVariableReferenceName";
		Environment_WindowNameByID_outputVariableReference='';
	fi

	if [[ "$__windowId" == '' ]];
	then
		[[ "$__verbose" != 0 ]] && Misc_PrintF -v 2 -t 'e' -n $'Could not find name of window (no ID)';

		return 2;
	fi

	########
	# Main #
	########

	declare windowName="$( xdotool getwindowname "$__windowId" 2> '/dev/null'; )";
	declare returnCodeTemp=$?;

	# if [[ "$windowName" == '' ]];
	if [[ "$returnCodeTemp" != 0 ]]
	then
		[[ "$__verbose" != 0 ]] && Misc_PrintF -v 2 -t 'e' -n $'Failed to find name of window \'%s\' (code %s)' -- "$__windowId" "$returnCodeTemp";

		return 2;
	fi

	[[ "$__verbose" != 0 ]] && Misc_PrintF -v 5 -t 'd' -nf $'Found name of window \'%s\': \'%s\'' -- "$__windowId" "$windowName";

	# If requested to store the result in a reference variable
	if [[ "$__outputVariableReferenceName" != '' ]];
	then
		Environment_WindowNameByID_outputVariableReference="$windowName";

		return 0;
	fi

	printf '%s' "$windowName";

	return 0;
}


# Return PID's window ID
Environment_WindowFindByPid()
{
	###########
	# Options #
	###########

	declare args;

	if ! Options args \
		'?-n;?-o;-v' \
		"$@";
	then
		Misc_PrintF -v 1 -t 'f' -nf $'[Environment_WindowFindByPid] Invalid options (code %s, index %s ~ \'%s\'): \'%s\'' -- \
			"$_Options_ResultCode" \
			"$_Options_FailIndex" \
			"$_Options_ErrorMessage" \
			"$( Misc_ArrayJoin -- "$@" )";

		exit 200;
	fi

	declare __windowNameRegex="${args[0]}";
	declare __outputVariableReferenceName="${args[1]}";
	declare __verbose="${args[2]}";
	declare __processIds=( "${args[@]:3}" );

	if [ "$__outputVariableReferenceName" != '' ];
	then
		if [ "$__outputVariableReferenceName" = 'Environment_WindowFindByPid_outputVariableReference' ];
		then
			Misc_PrintF -v 1 -t 'f' -nf $'[Environment_WindowFindByPid] Output variable reference interference: \'%s\'' -- \
				"$( Misc_ArrayJoin -- "$@" )";

			return 100;
		fi

		declare -n Environment_WindowFindByPid_outputVariableReference="$__outputVariableReferenceName";
		Environment_WindowFindByPid_outputVariableReference=();
	fi

	if (( "${#__processIds[@]}" == 0 ));
	then
		[[ "$__verbose" != 0 ]] && Misc_PrintF -v 2 -t 'e' -n $'Could not find any window of PID (no PID)';

		return 2;
	fi

	########
	# Main #
	########

	declare processAllWindowIds=();
	declare processWindowIds=();
	declare processIdIndex;

	# Loop through each PID
	for (( processIdIndex = 0; processIdIndex < ${#__processIds[@]}; processIdIndex++ ));
	do
		declare processId="${__processIds[$processIdIndex]}";

		if [[ ! "$processId" =~ ^[0-9]+$ ]];
		then
			[[ "$__verbose" != 0 ]] && Misc_PrintF -v 2 -t 'e' -nf $'Invalid PID: %s' -- "$processId";

			continue;
		fi

		readarray -t processWindowIds < <( xdotool search --pid "$processId" 2>> "$_Main_Dump" );
		declare processWindowIdsIndex;

		for (( processWindowIdsIndex = 0; processWindowIdsIndex < ${#processWindowIds[@]}; processWindowIdsIndex++ ));
		do
			declare processWindowId="${processWindowIds[processWindowIdsIndex]}"

			if [[ ! "$processWindowId" =~ ^[0-9]+$ ]];
			then
				[[ "$__verbose" != 0 ]] && Misc_PrintF -v 2 -t 'e' -nf $'Invalid window ID: \'%s\'' -- "$processWindowId";

				continue;
			fi

			if [[ "$__windowNameRegex" != '' ]];
			then
				if
					! Environment_WindowNameByID -o Environment_WindowFindByPid_windowName -w "$processWindowId" ||
			 		! Misc_Regex -p "$__windowNameRegex" -- "$descriptors";
			 	then
			 		[[ "$__verbose" != 0 ]] && Misc_PrintF -v 5 -t 'd' -nf $'Window \'%s\' name mismatch: ! \'%s\' =~ \'%s\'' -- \
			 			"$processWindowId" "$Environment_WindowFindByPid_windowName" "$__windowNameRegex";

			 		continue;
			 	fi

			 	[[ "$__verbose" != 0 ]] && Misc_PrintF -v 5 -t 'd' -nf $'Window \'%s\' name match: \'%s\' =~ \'%s\'' -- \
			 		"$processWindowId" "$Environment_WindowFindByPid_windowName" "$__windowNameRegex";
			fi

			processAllWindowIds+=( "$processWindowId" );
		done

		# processAllWindowIds+=( "${processWindowIds[@]}" );

		[[ "$__verbose" != 0 ]] && Misc_PrintF -v 5 -t 'd' -nf $'Found %s window%s of PID %s (\'%s\')%s' -- \
			"${#processWindowIds[@]}" "$( (( ${#processWindowIds[@]} > 1 )) && printf 's'; )" "$processId" "$( Environment_PidExecName "$processId" )" \
			"$( [ ${#processWindowIds[@]} != 0 ] && printf ': ' && Misc_ArrayJoin -- "${processWindowIds[@]}" )";
	done

	# If did not find any window ID
	if [[ ${#processAllWindowIds[@]} == 0 ]];
	then
		[[ "$__verbose" != 0 ]] && Misc_PrintF -v 3 -t 'w' -nf $'Did not find any window of PID%s' -- \
			"$(
				if (( "${#__processIds[@]}" > 1 ));
				then
					printf 's: ';
					Misc_ArrayJoin -- "${__processIds[@]}";
				else
					printf ' %s' "${__processIds[0]}";
				fi
			)";
	
		return 1;
	fi

	# Found window(s)

	# If requested to store the result in a reference variable
	if [[ "$__outputVariableReferenceName" != '' ]];
	then
		Environment_WindowFindByPid_outputVariableReference=( "${processAllWindowIds[@]}" );
	fi

	[[ "$__verbose" != 0 ]] && Misc_PrintF -v 5 -t 'd' -nf $'Found %s window%s total of PID%s: %s' -- \
		"${#processAllWindowIds[@]}" "$( (( ${#processAllWindowIds[@]} > 1 )) && printf 's'; )" \
		"$( (( ${#__processIds[@]} > 1 )) && printf 's (%s)' "$( Misc_ArrayJoin -- "${__processIds[@]}" )" || printf ' %s' "${__processIds[0]}"; )" \
		"$( Misc_ArrayJoin -- "${processAllWindowIds[@]}" )";

	return 0;
}

# Return first found window IDs in PID's hierarchy
Environment_WindowFindFirstParentByPid()
{
	###########
	# Options #
	###########

	declare args;

	if ! Options args \
		'@1/^[0-9]+$/' \
		'?!-p;?-n;?-d;?-w;?-o;-v' \
		"$@";
	then
		Misc_PrintF -v 1 -t 'f' -nf $'[Environment_WindowFindFirstParentByPid] Invalid options (code %s, index %s ~ \'%s\'): \'%s\'' -- \
			"$_Options_ResultCode" \
			"$_Options_FailIndex" \
			"$_Options_ErrorMessage" \
			"$( Misc_ArrayJoin -- "$@" )";

		exit 200;
	fi

	declare __processId="${args[0]}";
	declare __processName="${args[1]}";
	declare __windowSearchDepthMax="${args[2]}";
	declare __windowNameRegex="${args[3]}";
	declare __outputVariableReferenceName="${args[4]}";
	declare __verbose="${args[5]}";

	if [[ "$__windowSearchDepthMax" == '' ]];
	then
		__windowSearchDepthMax=10;
	fi

	if [ "$__outputVariableReferenceName" != '' ];
	then
		if
			[ "$__outputVariableReferenceName" = 'Environment_WindowFindFirstParentByPid_outputVariableReference' ] ||
			[ "$__outputVariableReferenceName" = 'Environment_WindowFindFirstParentByPid_outputVariableReferencePid' ];
		then
			Misc_PrintF -v 1 -t 'f' -nf $'[Environment_WindowFindFirstParentByPid] Output variable reference interference: \'%s\'' -- "$( Misc_ArrayJoin -- "$@" )";

			return 100;
		fi

		declare -n Environment_WindowFindFirstParentByPid_outputVariableReference="$__outputVariableReferenceName";
		declare -n Environment_WindowFindFirstParentByPid_outputVariableReferencePid="${__outputVariableReferenceName}Pid";
		Environment_WindowFindFirstParentByPid_outputVariableReference='';
		Environment_WindowFindFirstParentByPid_outputVariableReferencePid=();
	fi

	########
	# Main #
	########

	declare Environment_WindowFindFirstParentByPid_processWindowId;
	declare Environment_WindowFindFirstParentByPid_processLoopPid="$__processId";
	declare processName='';
	declare windowSearchDepth=0;

	# While didn't find any windows for the PID, get upper in the PID hierarchy until certain depth reached
	for (( windowSearchDepth = 0; windowSearchDepth <= "$__windowSearchDepthMax"; windowSearchDepth++ ));
	do
		declare processName="$( Environment_PidExecName "$Environment_WindowFindFirstParentByPid_processLoopPid" )";

		if [[ "$__processName" == '' || "$__processName" == "$processName" ]];
		then
			# If found first window
			if
				Environment_WindowFindByPid -o Environment_WindowFindFirstParentByPid_processWindowIds -n "$__windowNameRegex" -- \
					"$Environment_WindowFindFirstParentByPid_processLoopPid";
			then
				break;
			fi
		elif [[ "$__processName" != '' ]];
		then
			[[ "$__verbose" != 0 ]] && Misc_PrintF -v 5 -t 'd' -nf $'Skipped window search for PID %s (process name mismatch: \'%s\' != \'%s\') (depth %s/%s).' -- \
				"$Environment_WindowFindFirstParentByPid_processLoopPid" "$__processName" "$processName" "$windowSearchDepth" "$__windowSearchDepthMax";
		fi

		# Did not find first window

		[[ "$__verbose" != 0 ]] && Misc_PrintF -v 5 -t 'd' -nf $'Did not find window (%s) of PID %s (\'%s\') (depth %s/%s).' -- \
			"$( [[ "$__windowNameRegex" != '' ]] && printf $'\'%s\'' "$__windowNameRegex" || printf 'any' )" \
			"$Environment_WindowFindFirstParentByPid_processLoopPid" "$processName" "$windowSearchDepth" "$__windowSearchDepthMax";

		if (( windowSearchDepth + 1 > __windowSearchDepthMax ));
		then
			break;
		fi

		[[ "$__verbose" != 0 ]] && Misc_PrintF -v 5 -t 'd' -nf $'Trying parent PID';

		# Try to get the PID's parent PID (AKA PPID)
		if ! Environment_PidFindParent -o Environment_WindowFindFirstParentByPid_processLoopPid -p "$Environment_WindowFindFirstParentByPid_processLoopPid";
		then
			[[ "$__verbose" != 0 ]] && Misc_PrintF -v 5 -t 'd' -nf 'Reached the end of PID %s hierarchy (depth %s/%s) or failed to obtain PPID' -- \
				"$Environment_WindowFindFirstParentByPid_processLoopPid" "$windowSearchDepth" "$__windowSearchDepthMax";

			break;
		fi

		[[ "$__verbose" != 0 ]] && Misc_PrintF -v 5 -t 'd' -nf $'Found parent PID (depth %s/%s): %s' -- \
			"$windowSearchDepth" "$__windowSearchDepthMax" "$Environment_WindowFindFirstParentByPid_processLoopPid";

		# declare windowSearchDepth="$((windowSearchDepth + 1))";
	done

	declare processWindowIds=( "${Environment_WindowFindFirstParentByPid_processWindowIds[@]}" );
	declare processLoopPid="$Environment_WindowFindFirstParentByPid_processLoopPid";

	[[ "$__verbose" != 0 ]] && Misc_PrintF -v 5 -t 'd' -nf $'Found %s first window%s (%s) in PID %s (\'%s\') hierarchy (max depth %s)%s' -- \
		"${#processWindowIds[@]}" "$( (( ${#processWindowIds[@]} > 1 )) && printf 's'; )" \
		"$( [[ "$__windowNameRegex" != '' ]] && printf $'\'%s\'' "$__windowNameRegex" || printf 'any' )" \
		"$__processId" "$processName" "$__windowSearchDepthMax" \
		"$( [[ ${#processWindowIds[@]} != 0 ]] && printf ' -> PID %s' "$processLoopPid" )";

	# If did not find any window in the PID hierarchy
	if [[ ${#processWindowIds[@]} == 0 ]];
	then
		return 1;
	fi

	# If requested to store the result in a reference variable
	if [[ "$__outputVariableReferenceName" != '' ]];
	then
		Environment_WindowFindFirstParentByPid_outputVariableReferencePid="$processLoopPid"; # PID with a window(s)
		Environment_WindowFindFirstParentByPid_outputVariableReference=( "${processWindowIds[@]}" ); # Window IDs of the PID
	fi

	return 0;
}

# Arrange window (Bind, WID, or PID) via command and arguments
Environment_WindowArrange()
{
	###########
	# Options #
	###########

	declare args;

	if ! Options args \
		'@0/^(?:0|[1-9][0-9]+)$/' \
		'@2/^(?:0|[1-9][0-9]+)$/' \
		'@3/^(?:0|[1-9][0-9]+)$/' \
		'@4/^-?[0-9]+\s+-?[0-9]+$/' \
		'@5/^-?[0-9]+\s+-?[0-9]+$/' \
		'@6/^(?:0|[1-9][0-9]+)$/' \
		'@8/^(?:0|[1-9][0-9]+)$/' \
		'?--bi;?--bm;?-w;?-P;?-p;?-s;?-d;?-n;?-t;-r;-S;-h;-v' \
		"$@";
	then
		Misc_PrintF -v 1 -t 'f' -nf $'[Environment_WindowArrange] Invalid options (code %s, index %s ~ \'%s\'): \'%s\'' -- \
			"$_Options_ResultCode" \
			"$_Options_FailIndex" \
			"$_Options_ErrorMessage" \
			"$( Misc_ArrayJoin -- "$@" )";

		exit 200;
	fi

	declare __processBindId="${args[0]}";
	declare __processBindMeta="${args[1]}";
	declare __windowId="${args[2]}";
	declare __processId="${args[3]}";
	declare __windowPosition="${args[4]}";
	declare __windowSize="${args[5]}";
	declare __windowSearchDepthMax="${args[6]}";
	declare __windowNameRegex="${args[7]}";
	declare __timeWaitForWindow="${args[8]}";
	declare __relative="${args[9]}";
	declare __windowShow="${args[10]}";
	declare __windowHide="${args[11]}";
	declare __verbose="${args[12]}";
	declare __parameters=( "${args[@]:13}" );

	if [[ "$__windowId" == '' && "$__processId" == '' && __processBindId == '' && __processBindMeta == '' ]];
	then
		[[ "$__verbose" != 0 ]] && Misc_PrintF -v 2 -t 'e' -nf $'Could not arrange window (no ID)';

		return 2;
	elif [[ "$__windowId" != '' && "$__processId" != '' ]];
	then
		[[ "$__verbose" != 0 ]] && Misc_PrintF -v 2 -t 'e' -nf $'Could not arrange window (too many IDs)';

		return 2;
	fi

	if [[ "$__windowShow" != 0 && "$__windowHide" != 0 ]];
	then
		[[ "$__verbose" != 0 ]] && Misc_PrintF -v 2 -t 'e' -nf $'Could not arrange window (hide/show conflict)';

		return 2;
	fi

	if [[ "${#__parameters[@]}" != 0 && ! "${__parameters[*]}" =~ ^[0-9]+\ +[0-9]+\ +[0-9]+\ +[0-9]+$ ]]; # WHLT
	then
		[[ "$__verbose" != 0 ]] && Misc_PrintF -v 2 -t 'e' -nf $'Could not arrange window (invalid parameters)';

		return 2;
	fi

	if [[ "$__windowSearchDepthMax" == '' ]];
	then
		__windowSearchDepthMax=10;
	fi

	########
	# Main #
	########

	# Define parameters if declared

	if [[ "${#__parameters[@]}" != 0 ]];
	then
		__windowSize=( "${__parameters[@]:0:2}" );
		__windowPosition=( "${__parameters[@]:2:2}" );
	else
		__windowSize=( "${__windowSize[@]}" );
		__windowPosition=( "${__windowPosition[@]}" );
	fi

	# Define window ID(s)

	declare windowIds=();

	if [[ "$__windowId" != '' ]];
	then
		declare windowIds=( $__windowId );
	else
		# Find window ID(s)

		declare processIds=( $__processId );

		if [[ "$__processBindId" != '' || "$__processBindMeta" != '' ]];
		then
			# Find process(es) by child ID/meta

			# Environment_ProcessBindRefresh;
			declare Environment_WindowArrange_processChildsFound;

			if ! Environment_ProcessBindSearch -o Environment_WindowArrange_processChildsFound --bi "$__processBindId" --bm "$__processBindMeta";
			then
				[[ "$__verbose" != 0 ]] && Misc_PrintF -v 2 -t 'e' -nf $'Could not arrange window (did not find child process of ID=\'%s\', Meta=\'%s\')' -- \
						"$__processBindId" "$__processBindMeta";

				return 3;
			fi

			declare processIds+=( "${Environment_WindowArrange_processChildsFound[@]}" );
		fi

		# Find window(s) of process(es)

		declare processIdIndex;

		for (( processIdIndex = 0; processIdIndex < ${#processIds[@]}; processIdIndex++ ));
		do
			declare processId="${processIds[$processIdIndex]}";
			declare Environment_WindowArrange_processWindowIds;

			# Try to find window IDs related to the process ID
			if
				! Environment_WindowFindFirstParentByPid -o Environment_WindowArrange_processWindowIds \
					-p "$processId" -d "$__windowSearchDepthMax" -w "$__windowNameRegex";
			then
				[[ "$__verbose" != 0 ]] && Misc_PrintF -v 2 -t 'e' -nf $'Could not arrange window of PID %s (did not find window ID)' -- \
						"$processId";

				return 3;
			fi

			declare windowIds+=( "${Environment_WindowArrange_processWindowIds[@]}" );
		done
	fi

	# Arrange window(s)

	declare alterCount=0;
	declare windowIdIndex;

	# Loop through each window ID
	for (( windowIdIndex = 0; windowIdIndex < ${#windowIds[@]}; windowIdIndex++ ));
	do
		declare windowId="${windowIds[$windowIdIndex]}";

		# Resize

		if [[ "${#__windowSize[@]}" != 0 ]];
		then
			# If failed to resize
			if
				xdotool windowsize --sync $( [[ "$__relative" != 0 ]] && printf ' --relative ' ) -- \
					"$windowId" "${__windowSize[@]}" # 2>> "$_Main_Dump";
			then
				[[ "$__verbose" != 0 ]] && Misc_PrintF -v 5 -t 'd' -nf $'Resized window %s -> %s (%s/%s, %s)' -- \
					"$windowId" "${__windowSize[0]}x${__windowSize[1]}" "$windowIdIndex" "${#windowIds[@]}" "$alterCount";
			else
				[[ "$__verbose" != 0 ]] && Misc_PrintF -v 2 -t 'e' -nf $'Failed to resize window %s (%s/%s, %s)' -- \
					"$windowId" "$windowIdIndex" "${#windowIds[@]}" "$alterCount";

				break;
			fi
		fi

		# Move

		if [[ "${#__windowPosition[@]}" != 0 ]];
		then
			# If failed to move
			if xdotool windowmove --sync -- "$windowId" "${__windowPosition[@]}"# 2>> "$_Main_Dump";
			then
				[[ "$__verbose" != 0 ]] && Misc_PrintF -v 5 -t 'd' -nf $'Moved window %s -> %s (%s/%s, %s)' -- \
					"$windowId" "${__windowPosition[0]}, ${__windowPosition[1]}" "$windowIdIndex" "${#windowIds[@]}" "$alterCount";
			else
				[[ "$__verbose" != 0 ]] && Misc_PrintF -v 2 -t 'e' -nf $'Failed to move window %s (%s/%s, %s)' -- \
					"$windowId" "$windowIdIndex" "${#windowIds[@]}" "$alterCount";

				break;
			fi
		fi

		# Show/Hide

		if [[ "$__windowShow" != 0 || "$__windowHide" != 0 ]];
		then
			if
				xdotool "$( [[ "$__windowShow" != 0 ]] && printf ' windowactivate ' || printf ' windowminimize ' )" \
					--sync -- "$windowId" 2>> "$_Main_Dump";
			then
				[[ "$__verbose" != 0 ]] && Misc_PrintF -v 5 -t 'd' -nf $'%s window %s (%s/%s, %s)' -- \
					"$( [[ "$__windowShow" != 0 ]] && printf 'Showed' || printf 'Hid' )" \
					"$windowId" "$windowIdIndex" "${#windowIds[@]}" "$alterCount";
			else
				[[ "$__verbose" != 0 ]] && Misc_PrintF -v 2 -t 'e' -nf $'Failed to %s window %s (%s/%s, %s)' -- \
					"$( [[ "$__windowShow" != 0 ]] && printf 'show' || printf 'hide' )" \
					"$windowId" "$windowIdIndex" "${#windowIds[@]}" "$alterCount";

				break;
			fi
		fi

		# Arranged window successfully

		declare alterCount="$(( alterCount + 1 ))";

		[[ "$__verbose" != 0 ]] && Misc_PrintF -v 5 -t 'd' -nf $'Arranged window %s successfully (%s/%s, %s)' -- \
			"$windowId" "$windowIdIndex" "${#windowIds[@]}" "$alterCount";
	done

	# If total window count and successful window arrangement count mismatch
	if [ "$alterCount" != ${#windowIds[@]} ];
	then
		[[ "$__verbose" != 0 ]] && Misc_PrintF -v 2 -t 'e' -nf $'Failed to arrange %s/%s window%s' -- \
			"$(( ${#windowIds[@]} - alterCount ))" "${#windowIds[@]}" "$( (( ${#windowIds[@]} - alterCount > 1 )) && printf 's'; )";

		return 1;
	fi

	# Successfully arranged all windows

	[[ "$__verbose" != 0 ]] && Misc_PrintF -v 5 -t 'd' -nf $'Successfully arranged %s window%s' -- \
		"${#windowIds[@]}" "$( (( ${#windowIds[@]} > 1 )) && printf 's'; )";

	return 0;
}

###########
# Process #
###########

Environment_ProcessIDExists()
{
	###########
	# Options #
	###########

	declare args;

	if ! Options args \
		'@0/^[0-1]$/' \
		'-v' \
		"$@";
	then
		Misc_PrintF -v 1 -t 'f' -nf $'[Environment_ProcessIDExists] Invalid options (code %s, index %s ~ \'%s\'): \'%s\'' -- \
			"$_Options_ResultCode" \
			"$_Options_FailIndex" \
			"$_Options_ErrorMessage" \
			"$( Misc_ArrayJoin -- "$@" )";

		exit 200;
	fi

	declare verbose="${args[0]}";
	declare pids=( "${args[@]:1}" );

	########
	# Main #
	########

	declare pidIndex;

	for (( pidIndex = 0; pidIndex < ${#pids[@]}; pidIndex++ ));
	do
		declare pid="${pids[$pidIndex]}";

		# If empty PID value
		if [[ "$pid" == '' ]];
		then
			[[ "$verbose" != 0 ]] && Misc_PrintF -v 2 -t 'e' -n -- $'No PID specified to check if exists';

			return 2;
		fi

		# Check if PID exists
		# if ! ps -p "$pid" &>> "$_Main_Dump";
		if ! ps -p "$pid" &>> "$Environment_OutputStreamNull";
		then
			[[ "$verbose" != 0 ]] && Misc_PrintF -v 3 -t 'w' -nf $'No such PID: \'%s\'' "$pid";

			return 1;
		fi
	done

	return 0;
}

Environment_PidFindParent()
{
	###########
	# Options #
	###########

	declare args;

	if ! Options args \
		'@0/^[0-9]+$/' \
		'?!-p;?-o;-v' \
		"$@";
	then
		Misc_PrintF -v 1 -t 'f' -nf $'[Environment_PidFindParent] Invalid options (code %s, index %s ~ \'%s\'): \'%s\'' -- \
			"$_Options_ResultCode" \
			"$_Options_FailIndex" \
			"$_Options_ErrorMessage" \
			"$( Misc_ArrayJoin -- "$@" )";

		exit 200;
	fi

	declare processId="${args[0]}";
	declare outputVariableReferenceName="${args[1]}";
	declare verbose="${args[2]}";

	if [ "$outputVariableReferenceName" != '' ];
	then
		if [ "$outputVariableReferenceName" = 'Environment_PidFindParent_outputVariableReference' ];
		then
			Misc_PrintF -v 1 -t 'f' -nf $'[Environment_PidFindParent] Output variable reference interference: \'%s\'' -- \
				"$( Misc_ArrayJoin -- "$@" )";

			return 100;
		fi

		declare -n Environment_PidFindParent_outputVariableReference="$outputVariableReferenceName";
		Environment_PidFindParent_outputVariableReference='';
	fi

	########
	# Main #
	########

	if [ "$processId" = '' ];
	then
		if [ "$verbose" != 0 ];
		then
			Misc_PrintF -v 2 -t 'e' -nf $'Could not find parent of PID (no initial PID)';
		fi

		return 1;
	fi

	declare parentPid="$( grep '^PPid:' "/proc/${processId}/status" 2>> "$_Main_Dump" | grep --color=never -o '[0-9]*$' )";
	declare returnCodeTemp="$?";

	if [[ "$returnCodeTemp" != 0 || ! "$parentPid" =~ ^[0-9]+$ ]];
	then
		if [ "$verbose" != 0 ];
		then
			Misc_PrintF -v 2 -t 'e' -nf $'Did not find proper parent PID of PID %s' -- "$processId";
		fi

		return 1;
	fi

	# If requested to store the result in a reference variable
	if [ "$outputVariableReferenceName" != '' ];
	then
		Environment_PidFindParent_outputVariableReference="$parentPid";
	fi

	if [ "$verbose" != 0 ];
	then
		Misc_PrintF -v 5 -t 'd' -nf $'Found the parent PID of %s PID: %s' -- "$processId" "$parentPid";
	fi

	return 0;
}

Environment_ProcessIDChildSearch()
{
	###########
	# Options #
	###########

	declare args;

	if ! Options args \
		'@0/^[0-9]+$/' \
		'?-p;?-n;?-o;-v' \
		"$@";
	then
		Misc_PrintF -v 1 -t 'f' -nf $'[Environment_ProcessIDChildSearch] Invalid options (code %s, index %s ~ \'%s\'): \'%s\'' -- \
			"$_Options_ResultCode" \
			"$_Options_FailIndex" \
			"$_Options_ErrorMessage" \
			"$( Misc_ArrayJoin -- "$@" )";

		exit 200;
	fi

	declare __processId="${args[0]}";
	declare __processName="${args[1]}";
	declare __outputVariableReferenceName="${args[2]}";
	declare __verbose="${args[3]}";

	if [ "$__outputVariableReferenceName" != '' ];
	then
		if [ "$__outputVariableReferenceName" = 'Environment_ProcessIDChildSearch_outputVariableReference' ];
		then
			Misc_PrintF -v 1 -t 'f' -nf $'[Environment_ProcessIDChildSearch] Output variable reference interference: \'%s\'' -- \
				"$( Misc_ArrayJoin -- "$@" )";

			return 100;
		fi

		declare -n Environment_ProcessIDChildSearch_outputVariableReference="$__outputVariableReferenceName"; # exit status code(s)
		Environment_ProcessIDChildSearch_outputVariableReference=();
	fi

	########
	# Main #
	########

	# Get child processes of PID
	declare processChildPids=( $( pgrep -P "$__processId" 2> '/dev/null' ) );

	if [[ ${#processChildPids[@]} == 0 ]];
	then
		[[ "$__verbose" != 0 ]] && Misc_PrintF -v 5 -t 'd' -nf $'No child process found of PID %s' -- "$__processId";

		return 1;
	fi

	# Get child processes of PID except zombies in format "Status Pid" (pstree -Tp -- "$__processId")
	declare processChildPids="$( ps -o 's=,pid=' $( pgrep -P "$__processId" ) 2> '/dev/null' | perl -ne 'print if s/^[^ZT]\s+//'; )"; # | sort

	# Check whether the response is valid
	if 
		[[ "$processChildPids" == '' ]] ||
		! Misc_Regex -p '^[0-9]+(?:\s+[0-9]+)*$' -c "$( printf '%s\n' "$processChildPids" | wc -l )" -- "$processChildPids"; # PID[ PID]...
	then
		[[ "$__verbose" != 0 ]] && Misc_PrintF -v 2 -t 'e' -nf $'Invalid child process data found of PID %s: \'%s\'' -- "$__processId" -- "$processChildPids";

		return 1;
	fi

	declare processChildPids;
	readarray -t processChildPids <<< "$processChildPids";

	if [[ ${#processChildPids[@]} == 0 ]];
	then
		[[ "$__verbose" != 0 ]] && Misc_PrintF -v 2 -t 'e' -nf $'Could not obtain child process of PID %s (unexpected result)' -- "$__processId";

		return 2;
	fi

	# Verify results

	# If do not filter by process name
	if [[ "$__processName" == '' ]];
	then
		declare processChildPidIndex;

		for (( processChildPidIndex = 0; processChildPidIndex < ${#processChildPids[@]}; processChildPidIndex++ ));
		do
			declare processChildPid="${processChildPids[$processChildPidIndex]}";
			[[ "$__verbose" != 0 ]] && Misc_PrintF -v 5 -f '   [%3s] %s (%s)\n' -- "$((processChildPidIndex + 1))" "$processChildPid" \
			"$( Environment_PidExecName "$processChildPid" )";
		done
	else
		[[ "$__verbose" != 0 ]] && Misc_PrintF -v 5 -t 'd' -nnf $'Filtering by process name \'%s\'' -- "$__processName";
		declare processChildPidsFiltered=();
		declare processChildPidIndex;

		for (( processChildPidIndex = 0; processChildPidIndex < ${#processChildPids[@]}; processChildPidIndex++ ));
		do
			declare processChildPid="${processChildPids[$processChildPidIndex]}";
			declare processName="$( Environment_PidExecName "$processChildPid"; )";

			if [[ "$processName" != "$__processName" ]];
			then
				[[ "$__verbose" != 0 ]] && Misc_PrintF -v 5 -nf $'   [%3s] [-] %s (%s) (Mismatch)' -- "$((processChildPidIndex + 1))" "$processChildPid" "$processName";

				continue;
			fi

			processChildPidsFiltered+=( "$processChildPid" );
			[[ "$__verbose" != 0 ]] && Misc_PrintF -v 5 -nf '   [%3s] [+] %s (%s)' -- "$((processChildPidIndex + 1))" "$processChildPid" "$processName";
		done

		[[ "$__verbose" != 0 ]] && Misc_PrintF -v 5 -t 'd' -p 1 -nf $'Filter match count %s of %s total' -- "${#processChildPidsFiltered}" "${#processChildPids[@]}";
		processChildPids=( "${processChildPidsFiltered[@]}" );
	fi

	if [ ${#processChildPids[@]} = 0 ];
	then
		[[ "$__verbose" != 0 ]] && Misc_PrintF -v 3 -t 'w' -nf $'Did not find child processes of PID %s%s' -- \
			"$__processId" "$( [[ "$__processName" == '' ]] && printf ' (filtered)' )";

		return 1;
	fi

	# Found child processes. Return.

	if [[ "$__outputVariableReferenceName" = '' ]];
	then
		printf '%s\n' "${processChildPids[@]}";
	else
		Environment_ProcessIDChildSearch_outputVariableReference=( "${processChildPids[@]}" );
	fi

	[[ "$__verbose" != 0 ]] && Misc_PrintF -v 5 -t 'd' -nf $'Found %s child process(es) of PID %s%s: %s' -- \
		"${#processChildPids[@]}" "$__processId" "$( [[ "$__processName" != '' ]] && printf $' (filtered \'%s\')' "$__processName" )" \
		"$( Misc_ArrayJoin -- "${processChildPids[@]}" )";

	return 0;
}

Environment_ProcessIDTerminate()
{
	###########
	# Options #
	###########

	declare args;

	if ! Options args \
		'@0/^(?:[0-9]|[1-2][0-9]|3[0-1])$/' \
		'@1/^(0|[1-9][0-9]*)$/' \
		'@2/^[0-1]$/' \
		'@3/^[0-1]$/' \
		'@4/^[0-1]$/' \
		'?-s;?-t;-e;-i;-v' \
		"$@";
	then
		Misc_PrintF -v 1 -t 'f' -nf $'[Environment_ProcessIDTerminate] Invalid options (code %s, index %s ~ \'%s\'): \'%s\'' -- \
			"$_Options_ResultCode" \
			"$_Options_FailIndex" \
			"$_Options_ErrorMessage" \
			"$( Misc_ArrayJoin -- "$@" )";

		exit 200;
	fi

	declare signal="${args[0]}";
	declare timeout="${args[1]}";
	declare checkExists="${args[2]}";
	declare continueOnFail="${args[3]}";
	declare verbose="${args[4]}";
	declare pids=( "${args[@]:5}" );

	if [ "$signal" = '' ];
	then
		declare signal="$Environment_ProcessIDTerminate_SignalDefault";
	fi

	if [ "$timeout" = '' ];
	then
		declare timeout="$Environment_ProcessIDTerminate_TimeoutDefault";
	fi

	########
	# Main #
	########

	# The result value
	declare returnCode=0;
	declare pidIndex;

	for (( pidIndex = 0; pidIndex < ${#pids[@]}; pidIndex++ ));
	do
		declare pid="${pids[$pidIndex]}";

		if [ "$pid" = '' ];
		then
			if [ "$verbose" != 0 ];
			then
				Misc_PrintF -v 2 -t 'e' -nf $'No PID declared to terminate at %s argument' -- "$pidIndex";
			fi

			if [ "$continueOnFail" = 0 ];
			then
				return 3;
			fi

			(( returnCode < 3 )) && declare returnCode=3;

			continue;
		fi

		if [ "$checkExists" = 1 ] && ! Environment_ProcessIDExists -- "$pid";
		then
			if [ "$verbose" != 0 ];
			then
				Misc_PrintF -v 3 -t 'w' -nf $'No such process with the PID: \'%s\'' -- "$pid";
			fi

			if [ "$continueOnFail" = 0 ];
			then
				return 2;
			fi

			(( returnCode < 2 )) && declare returnCode=2;

			continue;
		fi

		kill "-${signal}" "$pid" &>> "$_Main_Dump";
		declare returnCodeTemp=$?;

		if [[ "$timeout" != 0 ]];
		then
			sleep "$timeout";
		fi
		
		if Environment_ProcessIDExists -- "$pid";
		then
			[[ "$verbose" != 0 ]] && Misc_PrintF -v 2 -t 'e' -nf $'Process with PID=\'%s\' has not been terminated (code %s)' -- "$pid" "$returnCodeTemp";
			
			if [ "$continueOnFail" = 0 ];
			then
				return 1;
			fi

			(( returnCode < 1 )) && declare returnCode=1;

			continue;
		fi

		[[ "$verbose" != 0 ]] && Misc_PrintF -v 4 -t 's' -nf $'Successfully terminated the process with the PID: \'%s\'' -- "$pid";
	done

	return "$returnCode";
}

# Process bind

Environment_processBindAdd()
{
	###########
	# Options #
	###########

	declare args;

	if ! Options args \
		'?!--bi;?!--bm;?-t;-v' \
		"$@";
	then
		Misc_PrintF -v 1 -t 'f' -nf $'[Environment_processBindAdd] Invalid options (code %s, index %s ~ \'%s\'): \'%s\'' -- \
			"$_Options_ResultCode" \
			"$_Options_FailIndex" \
			"$_Options_ErrorMessage" \
			"$( Misc_ArrayJoin -- "$@" )";

		return 200;
	fi

	declare __processBindId="${args[0]}";
	declare __processBindMeta="${args[1]}";
	declare __processBindTime="${args[2]}";
	declare __verbose="${args[3]}";

	if [ "$__processBindTime" = '' ];
	then
		declare __processBindTime="$( Misc_DateTime )";
	fi

	########
	# Main #
	########

	Base_FsWrite -anf "$Environment_pidsBoundFilepath" -- "${__processBindId}:${__processBindTime}:${__processBindMeta}"
	declare returnCodeTemp=$?;

	if [[ "$returnCodeTemp" != 0 ]];
	then
		[[ "$__verbose" != 0 ]] && Misc_PrintF -v 2 -t 'e' -nmf $'Failed to store PID %s (code %s) with meta: \'%s\'' -- \
			"$__processBindId" "$returnCodeTemp" "$__processBindMeta";

		return 1;
	fi

	[[ "$__verbose" != 0 ]] && Misc_PrintF -v 4 -t 's' -nmf $'Stored PID %s successfully with meta: \'%s\'' -- "$__processBindId" "$__processBindMeta";

	return 0;
}

Environment_ProcessBindRefresh()
{
	# Remove empty lines, if exists
	Base_FsRegexFile -p '^\s+$' -RRRr '' -- "$Environment_pidsBoundFilepath";
	Base_FsRead -o processChildsRaw -- "$Environment_pidsBoundFilepath";

	if [[ $? != 0 || "$processChildsRaw" == '' ]];
	then
		return 0;
	fi

	readarray -t processChilds < <(printf '%s' "$processChildsRaw");

	if [[ "${#processChilds[@]}" == 0 ]];
	then
		return 0;
	fi

	declare processChildNotFoundCount=0;
	declare processChildIndex;

	for (( processChildIndex = 0; processChildIndex < ${#processChilds[@]}; processChildIndex++ ));
	do
		declare processChildRaw="${processChilds[$processChildIndex]}"; # {PID}:{time}:{meta}
		declare processChildId="${processChildRaw%%\:*}"; # {PID}:{time}:{meta} ~> # {PID}

		# If no such PID exists (i.e. not running, stopped, terminated etc.)
		if ! Environment_ProcessIDExists -- "$processChildId";
		then
			processChildNotFoundCount=$(( processChildNotFoundCount + 1 ));
			Base_FsRegexFile -p "^${processChildId}:.*" -RRRr '' -- "$Environment_pidsBoundFilepath";
		fi
	done

	if [[ "$processChildNotFoundCount" != 0 ]];
	then
		return 1;
	fi

	return 0;
}

# Search through the pids file and return code or arrays with found PIDs and metas
# (beware, returns unique PIDs between PID search and Meta search)
Environment_ProcessBindSearch()
{
	###########
	# Options #
	###########

	declare args;

	if ! Options args \
		'@0/^(0|[1-9][0-9]*)$/' \
		'@3/^[0-1]$/' \
		'?--bi;?--bm;?-o;-P;-v' \
		"$@";
	then
		Misc_PrintF -v 1 -t 'f' -nf $'[Environment_ProcessBindSearch] Invalid options (code %s, index %s ~ \'%s\'): \'%s\'' -- \
			"$_Options_ResultCode" \
			"$_Options_FailIndex" \
			"$_Options_ErrorMessage" \
			"$( Misc_ArrayJoin -- "$@" )";

		return 200;
	fi

	declare __procesBindId="${args[0]}";
	declare __processBindMeta="${args[1]}";
	declare __outputVariableReferenceName="${args[2]}";
	declare __doNotRefreshChildPidsInfo="${args[3]}"
	declare __verbose="${args[4]}";

	if [[ "$__outputVariableReferenceName" != '' ]];
	then
		if 
			[ "$__outputVariableReferenceName" = 'Environment_ProcessBindSearch_outputVariableReference' ] ||
			[ "$__outputVariableReferenceName" = 'Environment_ProcessBindSearch_outputVariableReferenceTimes' ] ||
			[ "$__outputVariableReferenceName" = 'Environment_ProcessBindSearch_outputVariableReferenceMetas' ];
		then
			Misc_PrintF -v 1 -t 'f' -nf $'[Environment_ProcessBindSearch] Output variable reference interference: \'%s\'' -- \
				"$( Misc_ArrayJoin -- "$@" )";

			return 100;
		fi

		# Set the reference variable to the element count
		declare -n Environment_ProcessBindSearch_outputVariableReference="$__outputVariableReferenceName";
		declare -n Environment_ProcessBindSearch_outputVariableReferenceTimes="${__outputVariableReferenceName}Times";
		declare -n Environment_ProcessBindSearch_outputVariableReferenceMetas="${__outputVariableReferenceName}Metas";
		Environment_ProcessBindSearch_outputVariableReference=();
		Environment_ProcessBindSearch_outputVariableReferenceTimes=();
		Environment_ProcessBindSearch_outputVariableReferenceMetas=();
	fi

	if [[ "$__procesBindId" == '' && "$__processBindMeta" == '' ]];
	then
		[[ "$__verbose" != 0 ]] && Misc_PrintF -v 2 -t 'e' -n $'No PID and meta declared to search in bound PIDs file';

		return 2;
	fi

	########
	# Main #
	########

	# If requested to update the current child PID status
	if [[ "$__doNotRefreshChildPidsInfo" == 0 ]];
	then
		Environment_ProcessBindRefresh;
	fi

	# If no pids file exists
	if ! Base_FsExists -t 1 -- "${Environment_pidsBoundFilepath}";
	then
		[[ "$__verbose" != 0 ]] && Misc_PrintF -v 3 -t 'w' -nf $'No bound PIDs file exists to check for %s' -- \
			"$(
				[ "$__procesBindId" != '' ] && printf $'PID \'%s\'' "$__procesBindId";
				[ "$__procesBindId" != '' ] && [ "$__processBindMeta" != '' ] && printf ' and ';
				[ "$__processBindMeta" != '' ] && printf $'meta \'%s\'' "$__processBindMeta";
			)";

		return 2;
	fi

	declare processChildMatches=();

	# If PID is declared
	if [[ "$__procesBindId" != '' ]];
	then
		declare processChildIdMatches=();

		# Get all PID matches
		Base_FsRegexFile -p "^${__procesBindId}\:.*" -o processChildIdMatches -- "$Environment_pidsBoundFilepath";

		processChildMatches+=( "${processChildIdMatches[@]}" );
	fi

	# If process meta is declared
	if [[ "$__processBindMeta" != '' ]];
	then
		declare processChildMetaMatches=();

		# Get all process meta matches
		Base_FsRegexFile -p "^[0-9]+\:[0-9]+.[0-9]+\:.*${__processBindMeta}.*" -o processChildMetaMatches -- "$Environment_pidsBoundFilepath";

		processChildMatches+=( "${processChildMetaMatches[@]}" );
	fi

	# If no match found
	if [ "${#processChildMatches[@]}" = 0 ];
	then
		[[ "$__verbose" != 0 ]] && Misc_PrintF -v 3 -t 'w' -nf $'No child process found with %s' -- \
			"$(
				[ "$__procesBindId" != '' ] && printf $'PID \'%s\'' "$__procesBindId";
				[ "$__procesBindId" != '' ] && [ "$__processBindMeta" != '' ] && printf ' and ';
				[ "$__processBindMeta" != '' ] && printf $'meta \'%s\'' "$__processBindMeta";
			)";

		return 1;
	fi

	# If requested to set to a referenced variable
	if [ "$__outputVariableReferenceName" != '' ];
	then
		declare processChildMatchIndex;

		for (( processChildMatchIndex = 0; processChildMatchIndex < ${#processChildMatches[@]}; processChildMatchIndex++ ));
		do
			declare processChildRaw="${processChildMatches[$processChildMatchIndex]}"; # {PID}:{time}:{meta}

			declare processChildMatchPid="${processChildRaw%%\:*}"; # {PID}:{time}:{meta} ~> # {PID}

			declare processChildMatchPart="${processChildRaw#*\:}"; # {PID}:{time}:{meta} ~> # {time}:{meta}
			declare processChildMatchTime="${processChildMatchPart%%\:*}"; # {time}:{meta} ~> # {time}

			declare processChildMatchMeta="${processChildMatchPart##*\:}"; # {time}:{meta} ~> # {meta}

			# declare alreadyExist=0;
			# declare processChildMatchPidAdded;

			# # Loop through each added PID (i.e. same PID and meta matched)
			# for processChildMatchPidAdded in "${Environment_ProcessPidsFileSearch_outputVariableReference[@]}";
			# do
			# 	if [ "$processChildMatchPid" = "$processChildMatchPidAdded" ];
			# 	then
			# 		alreadyExist=1;

			# 		continue;
			# 	fi
			# done

			# # If such PID already exists in the referenced variable
			# if [ "$alreadyExist" = 1 ];
			# then
			# 	continue;
			# fi

			Environment_ProcessBindSearch_outputVariableReference+=( "$processChildMatchPid" );
			Environment_ProcessBindSearch_outputVariableReferenceTimes+=( "$processChildMatchTime" );
			Environment_ProcessBindSearch_outputVariableReferenceMetas+=( "$processChildMatchMeta" );
		done
	fi

	[[ "$__verbose" != 0 ]] && Misc_PrintF -v 4 -t 's' -nf $'Found %s child process matches with %s' -- \
		"${#processChildMatches[@]}" \
		"$(
			[ "$__procesBindId" != '' ] && printf $'PID \'%s\'' "$__procesBindId";
			[ "$__procesBindId" != '' ] && [ "$__processBindMeta" != '' ] && printf ' and ';
			[ "$__processBindMeta" != '' ] && printf $'meta \'%s\'' "$__processBindMeta";
		)";

	return 0;
}

Environment_ProcessBindTerminate()
{
	###########
	# Options #
	###########

	declare args;

	if ! Options args \
		'@0/^(0|[1-9][0-9]*)$/' \
		'@3/^[0-1]$/' \
		'?--bi;?--bm;-e;-i;-v' \
		"$@";
	then
		Misc_PrintF -v 1 -t 'f' -nf $'[Environment_ProcessBindTerminate] Invalid options (code %s, index %s ~ \'%s\'): \'%s\'' -- \
			"$_Options_ResultCode" \
			"$_Options_FailIndex" \
			"$_Options_ErrorMessage" \
			"$( Misc_ArrayJoin -- "$@" )";

		return 200;
	fi

	declare __processBindId="${args[0]}";
	declare __processBindMeta="${args[1]}";
	declare __checkExists="${args[2]}";
	declare __continueOnFail="${args[3]}";
	declare __verbose="${args[4]}";

	########
	# Main #
	########

	Environment_ProcessBindRefresh;
	declare processChildsFound;

	if ! Environment_ProcessBindSearch -o processChildsFound --bi "$__processBindId" --bm "$__processBindMeta";
	then
		declare processQueryData=();
		[[ "$__processBindId" != '' ]] && processQueryData+=( "$( printf $'PID \'%s\'' "$__processBindId"; )" );
		[[ "$__processBindMeta" != '' ]] && processQueryData+=( "$( printf $'Meta \'%s\'' "$__processBindMeta"; )" );
		[[ "$__verbose" != 0 ]] && Misc_PrintF -v 3 -t 'w' -nf $'No such child process: %s' -- "$( Misc_ArrayJoin '' '' ' + ' "${processQueryData[@]}" )";

		if [ "$__checkExists" != 0 ];
		then
			return 1;
		fi

		return 0;
	fi

	declare returnCode=0;
	declare processChildIndex;
	
	for (( processChildIndex = 0; processChildIndex < "${#processChildsFound[@]}"; processChildIndex++ ));
	do
		declare processChildFoundPid="${processChildsFound[$processChildIndex]}";

		if ! Environment_ProcessIDTerminate -- "$processChildFoundPid";
		then
			[[ "$__verbose" != 0 ]] && Misc_PrintF -v 2 -t 'e' -nf $'Failed to terminate child PID %s [ %s ]' -- \
				"$processChildFoundPid" \
				"$(
					[ "$__processBindId" != '' ] && printf $'PID \'%s\'' "$__processBindId";
					[ "$__processBindId" != '' ] && [ "$__processBindMeta" != '' ] && printf ' and ';
					[ "$__processBindMeta" != '' ] && printf $'meta \'%s\'' "$__processBindMeta";
				)";

			if [ "$__continueOnFail" = 0 ];
			then
				return 2;
			fi

			(( returnCode < 2 )) && declare returnCode=2;

			continue;
		fi

		[[ "$__verbose" != 0 ]] && Misc_PrintF -v 4 -t 's' -nf $'Successfully terminated child PID %s [ %s ]' -- \
			"$processChildFoundPid" \
			"$(
				[ "$__processBindId" != '' ] && printf $'PID \'%s\'' "$__processBindId";
				[ "$__processBindId" != '' ] && [ "$__processBindMeta" != '' ] && printf ' and ';
				[ "$__processBindMeta" != '' ] && printf $'meta \'%s\'' "$__processBindMeta";
			)";
	done

	Environment_ProcessBindRefresh;

	return "$returnCode";
}

Environment_ProcessStart()
{
	###########
	# Options #
	###########

	declare args;

	if ! Options args \
		'?--so;?--se;?--bm;?-x;?-X;?-d;?-f;?-o;-v' \
		"$@";
	then
		Misc_PrintF -v 1 -t 'f' -nf $'[Environment_ProcessStart] Invalid options (code %s, index %s ~ \'%s\'): \'%s\'' -- \
			"$_Options_ResultCode" \
			"$_Options_FailIndex" \
			"$_Options_ErrorMessage" \
			"$( Misc_ArrayJoin -- "$@" )";

		return 200;
	fi

	declare __outputStreamOut="${args[0]}";
	declare __outputStreamErr="${args[1]}";
	declare __processBindMeta="${args[2]}";
	declare __windowParametersString="${args[3]}";
	declare __windowProcessName="${args[4]}";
	declare __windowSearchDepthMax="${args[5]}";
	declare __scriptFile="${args[6]}";
	declare __outputVariableReferenceName="${args[7]}";
	declare __verbose="${args[8]}";
	declare __scriptData=( "${args[@]:9}" );

	if [ "$__outputVariableReferenceName" != '' ];
	then
		if [ "$__outputVariableReferenceName" = 'Environment_ProcessStart_outputVariableReference' ];
		then
			Misc_PrintF -v 1 -t 'f' -nf $'[Environment_ProcessStart] Output variable reference interference: \'%s\'' -- \
				"$( Misc_ArrayJoin -- "$@" )";

			return 100;
		fi

		declare -n Environment_ProcessStart_outputVariableReference="$__outputVariableReferenceName"; # exit status code(s)
		Environment_ProcessStart_outputVariableReference='';
	fi

	if [[ "$__windowSearchDepthMax" == '' ]];
	then
		__windowSearchDepthMax=10;
	fi

	########
	# Main #
	########

	if [[ ${#__scriptData[@]} == 0 ]];
	then
		[[ "$__verbose" != 0 ]] && Misc_PrintF -v 1 -t 'f' -n $'No script declared to start process';

		return 100;
	fi

	if [[ "$__outputStreamOut" == '' ]];
	then
		__outputStreamOut="$Environment_OutputStreamStdOut";
	fi

	if [[ "$__outputStreamErr" == '' ]];
	then
		__outputStreamErr="$Environment_OutputStreamStdErr";
	fi

	# Just for log/output
	declare commandPreviewStringLengthMax=1000;

	# if (( __verbose > 1 ));
	# then
	# 	commandPreviewStringLengthMax=10000;
	# fi

	if
		! cat <<< $'\n--------------------\n'"Script/command preview: $( Misc_ArrayJoin -- "${__scriptData[@]}"; )" \
			>> "$_Main_Dump" 2> '/dev/null';
	then
		[[ "$__verbose" != 0 ]] && Misc_PrintF -v 3 -t 'w' -nf $'Failed to write script/command preview to \'%s\'' -- "$_Main_Dump";
	fi

	########
	# Main #
	########

	# If no meta declared (foreground process), no window parameters were requested, and requested to set to a referenced variable
	if [[ "$__processBindMeta" == '' && "$__windowParametersString" == '' && "$__outputVariableReferenceName" != '' ]];
	then
		if [[ "$__outputVariableReferenceName" != '' ]];
		then
			if
				[[
					"$__outputVariableReferenceName" = 'Environment_ProcessStart_outputVariableReferenceOut' ||
					"$__outputVariableReferenceName" = 'Environment_ProcessStart_outputVariableReferenceErr'
				]]
			then
				Misc_PrintF -v 1 -t 'f' -nf $'[Environment_ProcessStart] Output variable reference interference: \'%s\'' -- "$( Misc_ArrayJoin -- "$@" )";

				return 100;
			fi

			declare -n Environment_ProcessStart_outputVariableReferenceOut="${__outputVariableReferenceName}Out"; # stdout
			declare -n Environment_ProcessStart_outputVariableReferenceErr="${__outputVariableReferenceName}Err"; # stderr
			Environment_ProcessStart_outputVariableReferenceOut='';
			Environment_ProcessStart_outputVariableReferenceErr='';
		fi

		# If script file(s) declared
		if [[ "$__scriptFile" == 1 ]];
		then
			declare scriptDataIndex;

			# Each script file
			for (( scriptDataIndex = 0; scriptDataIndex < ${#__scriptData[@]}; scriptDataIndex++ ));
			do
				declare scriptDataFilepath="${__scriptData[scriptDataIndex]}";

				[[ "$__verbose" != 0 ]] && Misc_PrintF -v 5 -t 'd' -nmf $'Executing script%s: "{{@clLightCyan}}%s%s{{@clDefault}}"' -- \
					"$( [ "${#__scriptData[@]}" != 1 ] && printf ' (%s of %s)' "$((scriptDataIndex + 1))" "${#__scriptData[@]}" )" "$scriptDataFilepath";

				declare stdoutTemp;
				declare stderrTemp;

				{
					IFS=$'\n' read -rd '' stdoutTemp;
					IFS=$'\n' read -rd '' stderrTemp;

					Environment_ProcessStart_outputVariableReferenceOut+="$(
						[[ "${#Environment_ProcessStart_outputVariableReferenceOut}" != 0 ]] && printf '\n';
					)${stdoutTemp}";

					Environment_ProcessStart_outputVariableReferenceErr+="$(
						[[ "${#Environment_ProcessStart_outputVariableReferenceErr}" != 0 ]] && printf '\n';
					)${stderrTemp}";

					(
						declare returnCodeTemp;
						IFS=$'\n' read -rd '' returnCodeTemp;

						return "$returnCodeTemp";
					);
				} < <(
					(
						printf '\0%s\0%d\0' "$(
							(
								(
									(
										{
											bash -- "${scriptDataFilepath} & wait";
											printf '%s\n' "$?" 1>&3-;
										} | tr -d '\0' 1>&4-;
									) 4>&2- 2>&1- | tr -d '\0' 1>&4-;
								) 3>&1- | exit "$( cat )";
							) 4>&1-;
						)" "$?" 1>&2;
					) 2>&1;
				);

				declare returnCodeTemp="$?";

				Environment_ProcessStart_outputVariableReference="${Environment_ProcessStart_outputVariableReference}$(
					[ "${#Environment_ProcessStart_outputVariableReference}" != 0 ] && printf ' ';
				)${returnCodeTemp}";

				[[ "$__verbose" != 0 ]] && Misc_PrintF -v 5 -t 'd' -nf $'Script execution ended%s: code %s; stdout length: %s; stderr length: %s' \
					"$( [ "${#__scriptData[@]}" != 1 ] && printf ' (file; %s of %s)' "$((scriptDataIndex + 1))" "${#__scriptData[@]}" )" \
					"$returnCodeTemp" \
					"${#stdoutTemp}" \
					"${#stderrTemp}";
			done
		else
			declare scriptDataIndex;

			# Each script string
			for (( scriptDataIndex = 0; scriptDataIndex < ${#__scriptData[@]}; scriptDataIndex++ ));
			do
				declare scriptDataCode="${__scriptData[scriptDataIndex]}";

				[[ "$__verbose" != 0 ]] && Misc_PrintF -v 5 -t 'd' -nmf $'Executing code%s: "{{@clLightCyan}}%s%s{{@clDefault}}"' -- \
					"$( [ "${#__scriptData[@]}" != 1 ] && printf ' (raw; %s of %s)' "$((scriptDataIndex + 1))" "${#__scriptData[@]}" )" \
					"${scriptDataCode:0:$commandPreviewStringLengthMax}" "$( (( "${#scriptDataCode}" > commandPreviewStringLengthMax )) && printf '...' )";

				declare stdoutTemp;
				declare stderrTemp;

				{
					IFS=$'\n' read -rd '' stdoutTemp;
					IFS=$'\n' read -rd '' stderrTemp;

					Environment_ProcessStart_outputVariableReferenceOut+="$(
						[[ "${#Environment_ProcessStart_outputVariableReferenceOut}" != 0 ]] && printf '\n';
					)${stdoutTemp}";

					Environment_ProcessStart_outputVariableReferenceErr+="$(
						[[ "${#Environment_ProcessStart_outputVariableReferenceErr}" != 0 ]] && printf '\n';
					)${stderrTemp}";

					(
						declare returnCodeTemp;
						IFS=$'\n' read -rd '' returnCodeTemp;

						return "$returnCodeTemp";
					);
				} < <(
					(
						printf '\0%s\0%d\0' "$(
							(
								(
									(
										{
											bash -c "${scriptDataCode} & wait";
											printf '%s\n' "$?" 1>&3-;
										} | tr -d '\0' 1>&4-;
									) 4>&2- 2>&1- | tr -d '\0' 1>&4-;
								) 3>&1- | exit "$( cat )";
							) 4>&1-;
						)" "$?" 1>&2;
					) 2>&1;
				);

				declare returnCodeTemp="$?";

				Environment_ProcessStart_outputVariableReference="${Environment_ProcessStart_outputVariableReference}$(
					[ "${#Environment_ProcessStart_outputVariableReference}" != 0 ] && printf ' ';
				)${returnCodeTemp}";

				[[ "$__verbose" != 0 ]] && Misc_PrintF -v 5 -t 'd' -nf $'Code execution ended%s: code %s; stdout length: %s; stderr length: %s.' \
					"$( [ "${#__scriptData[@]}" != 1 ] && printf ' (raw; %s of %s)' "$((scriptDataIndex + 1))" "${#__scriptData[@]}" )" \
					"$returnCodeTemp" \
					"${#stdoutTemp}" \
					"${#stderrTemp}";
			done
			# fi
		fi

		# Log results

		if
			! cat <<< "Script/command process exit status(es): ${Environment_ProcessStart_outputVariableReference}"$'\n---------- stdout:' \
				>> "$_Main_Dump" 2> '/dev/null';
		then
			[[ "$__verbose" != 0 ]] && Misc_PrintF -v 3 -t 'w' -nf $'Failed to write script/command process exit status(es) to \'%s\'' -- \
				"$_Main_Dump";
		fi

		if ! cat <<< "$Environment_ProcessStart_outputVariableReferenceOut"$'\n---------- stderr(s):' >> "$_Main_Dump" 2> '/dev/null';
		then
			[[ "$__verbose" != 0 ]] && Misc_PrintF -v 3 -t 'w' -nf $'Failed to write script/command process \'stdout\' to \'%s\'' -- "$_Main_Dump";
		fi

		if ! cat <<< "$Environment_ProcessStart_outputVariableReferenceErr"$'\n--------------------' >> "$_Main_Dump" 2> '/dev/null';
		then
			[[ "$__verbose" != 0 ]] && Misc_PrintF -v 3 -t 'w' -nf $'Failed to write script/command process \'stderr\' to \'%s\'' -- "$_Main_Dump";
		fi

		# Return

		# If a single script file or script code declared
		if [[ ${#__scriptData[@]} == 1 ]];
		then
			return "$Environment_ProcessStart_outputVariableReference";
		fi

		# If any exit status code is not 0
		if [[ "$Environment_ProcessStart_outputVariableReference" =~ [^0\s] ]];
		then
			return 1;
		fi

		return 0;
	fi

	# A child process meta and/or window parameters and/or no output reference variable declared

	# If process meta is declared
	if [[ "$__processBindMeta" != '' ]];
	then
		Environment_ProcessBindRefresh;
		declare Environment_ProcessStart_processChilds;

		# If such meta already exists in the pids file
		if Environment_ProcessBindSearch -o Environment_ProcessStart_processChilds --bm "$__processBindMeta";
		then
			[[ "$__verbose" != 0 ]] && Misc_PrintF -v 2 -t 'e' \
				-nf $'Could not start bound process. Found %s active bound process%s with matching meta(s) (\'%s\'). PIDs: \'%s\'' -- \
				"${#Environment_ProcessStart_processChilds[@]}" "$( (( ${#Environment_ProcessStart_processChilds[@]} > 1 )) && printf 'es'; )" \
				"$__processBindMeta" "$( Misc_ArrayJoin -- "${Environment_ProcessStart_processChilds[@]}" )";

			return 1;
		fi
	elif [[ "$__windowParametersString" != '' ]]; # If requested to change window's parameters
	then
		# Enable the "job control"
		set -m;
	fi

	[[ "$__verbose" != 0 ]] && Misc_PrintF -v 5 -t 'd' -nmf $'Starting {{@clYellow}}bound{{@clDefault}} process: "{{@clLightCyan}}%s{{@clDefault}}"' -- \
		"$(
			declare scriptDataCommand="${__scriptData[*]}";
			printf '%s' "${scriptDataCommand:0:$commandPreviewStringLengthMax}";
			(( ${#scriptDataCommand} > "$commandPreviewStringLengthMax" )) && printf '...';
		)";

	# Execute

	# "${scriptData[@]}" > "$outputStreamOut" 2> "$outputStreamErr" & # Doesn't support pipelines in case required in the command
	# "wait" is to eliminate possible Bash optimization that may cause the executed command appear as the parent process instead of Bash itself (exec)
	bash -c "${__scriptData[*]} & wait" > "$__outputStreamOut" 2> "$__outputStreamErr" &
	declare shellProcessId=$!;

	[[ "$__verbose" != 0 ]] && Misc_PrintF -v 5 -t 'd' -nnf $'Started with PID %s (%s)\n\n%s' -- \
		"$shellProcessId" "$( Environment_PidExecName "$shellProcessId" )" "$( pstree -Tp -- "$PPID"; )";

	# Find all child PIDs

	declare Environment_ProcessStart_processChildIds;

	if ! Environment_ProcessIDChildSearch -o Environment_ProcessStart_processChildIds -p "$shellProcessId" -n "$__windowProcessName";
	then
		[[ "$__verbose" != 0 ]] && Misc_PrintF -v 3 -t 'w' -nmf $'Did not find any child process of new PID %s' -- "$shellProcessId";

		return 1;
	fi

	declare childPids=( "${Environment_ProcessStart_processChildIds[@]}" );

	[[ "$__verbose" != 0 ]] && Misc_PrintF -v 5 -t 'd' -nmf $'Found %s child process%s of new PID %s: %s' -- \
		"${#childPids[@]}" "$( (( ${#childPids[@]} > 1 )) && printf 'es'; )" "$shellProcessId" "$( Misc_ArrayJoin -- "${childPids[@]}" )";

	# If requested to arrange a window
	if [[ "$__windowParametersString" != '' ]];
	then
		[[ "$__verbose" != 0 ]] && Misc_PrintF -v 5 -t 'd' -nmf $'Arranging window(s) of bound process%s (%s): %s' -- \
			"$( (( ${#childPids[@]} > 1 )) && printf 'es'; )" "($( Misc_ArrayJoin -- "${childPids[@]}" ))" "$__windowParametersString";

		# Environment_WindowFindFirstParentByPid -o Environment_Prepare_mainTerminal -p "$$"; # $PPID
		declare childPidIndex;

		for (( childPidIndex = 0; childPidIndex < ${#childPids[@]}; childPidIndex++ ));
		do
			declare childPid="${childPids[childPidIndex]}";
			[[ "$__verbose" != 0 ]] && Misc_PrintF -v 5 -t 'd' -nmf $'Arranging window of PID %s (%s/%s)' -- "$childPid" "$(( childPidIndex + 1 ))" "${#childPids[@]}";
			Environment_WindowArrange -P "$childPid" -d "$__windowSearchDepthMax" -- $__windowParametersString;
		done
	fi

	# If no process meta is declared - foreground
	if [[ "$__processBindMeta" == '' ]];
	then
		declare childPid="${childPids[-1]}";
		[[ "$__verbose" != 0 ]] && Misc_PrintF -v 5 -t 'd' -nmf $'Returning to foreground of one of the first bound processes: %s' -- "$childPid";
		fg &>> "$_Main_Dump";

		# Disable "job control"
		set +m;

		declare returnCodeTemp=$?;
		[[ "$__verbose" != 0 ]] && Misc_PrintF -v 5 -t 'd' -nf $'Bound foreground process ended with code \'%s\'' "$returnCodeTemp";

		# while Environment_ProcessIDExists -- "$processChildId";
		# do
		# 	sleep 0.5;
		# done

		# Log results

		if ! cat <<< $'\n'"Unbound process exit status(es): ${returnCodeTemp}" >> "$_Main_Dump" 2> '/dev/null';
		then
			[[ "$__verbose" != 0 ]] && Misc_PrintF -v 3 -t 'w' -nf $'Failed to write unbound process exit status(es) to \'%s\'' \
				"$_Main_Dump";
		fi

		return $returnCodeTemp;
	fi

	# If requested to set to a referenced variable (to the background PID)
	if [[ "$__outputVariableReferenceName" != '' ]];
	then
		Environment_ProcessStart_outputVariableReference=( "${childPids[@]}" );
	fi

	# Log results

	if
		! cat <<< $'\n'"Bound PIDs: $( Misc_ArrayJoin -- "${Environment_ProcessStart_outputVariableReference[@]}" )" \
			>> "$_Main_Dump" 2> '/dev/null';
	then
		[[ "$__verbose" != 0 ]] && Misc_PrintF -v 3 -t 'w' -nf $'Failed to write bound PIDs to \'%s\'' \
			"$_Main_Dump";
	fi

	# Return

	# Store process meta in PIDs file

	declare childPidIndex;

	for (( childPidIndex = 0; childPidIndex < ${#childPids[@]}; childPidIndex++ ));
	do
		declare childPid="${childPids[childPidIndex]}";
		declare processChildMetaId="$( Misc_RandomString -l 8 )";

		# Try to add the process to the pids file
		if ! Environment_processBindAdd --bi "$childPid" --bm "bind_${__processBindMeta}_${processChildMetaId}";
		then
			return 2;
		fi
	done

	return 0;
}

#
# Terminal
#

Environment_TerminalStart()
{
	###########
	# Options #
	###########

	declare args;

	if ! Options args \
		'@4/^[0-9]+$/' \
		'@5/^(?:[0-9A-Fa-f]{6})?(?:,)?(?:[0-9A-Fa-f]{6})?$/' \
		'?--bm;?-t;?-o;?-x;?-s;?-c;?-f;-h;-T;-v' \
		"$@";
	then
		Misc_PrintF -v 1 -t 'f' -nf $'[Environment_TerminalStart] Invalid options (code %s, index %s ~ \'%s\'): \'%s\'' -- \
			"$_Options_ResultCode" \
			"$_Options_FailIndex" \
			"$_Options_ErrorMessage" \
			"$( Misc_ArrayJoin -- "$@" )";

		return 200;
	fi

	declare __processBindMeta="${args[0]}";
	declare __terminalTitle="${args[1]}";
	declare __outputVariableReferenceName="${args[2]}";
	declare __windowParameters="${args[3]}";
	declare __terminalFontSize="${args[4]}";
	declare __terminalColors="${args[5]}";
	declare __terminalFont="${args[6]}";
	declare __terminalHold="${args[7]}";
	declare __addTimeToTitle="${args[8]}";
	declare __verbose="${args[9]}";
	declare __command=( "${args[@]:10}" );

	if [[ "$__outputVariableReferenceName" != '' ]];
	then
		if 
			[ "$__outputVariableReferenceName" = 'Environment_TerminalStart_outputVariableReference' ] ||
			[ "$__outputVariableReferenceName" = 'Environment_TerminalStart_outputVariableReferenceOut' ] ||
			[ "$__outputVariableReferenceName" = 'Environment_TerminalStart_outputVariableReferenceErr' ]
		then
			Misc_PrintF -v 1 -t 'f' -nf $'[Environment_TerminalStart] Output variable reference interference: \'%s\'' -- \
				"$( Misc_ArrayJoin -- "$@" )";

			return 100;
		fi

		declare -n Environment_TerminalStart_outputVariableReference="${__outputVariableReferenceName}";
		declare -n Environment_TerminalStart_outputVariableReferenceOut="${__outputVariableReferenceName}Out";
		declare -n Environment_TerminalStart_outputVariableReferenceErr="${__outputVariableReferenceName}Err";
		Environment_TerminalStart_outputVariableReference='';
		Environment_TerminalStart_outputVariableReferenceOut='';
		Environment_TerminalStart_outputVariableReferenceErr='';
	fi

	if [[ "$__command" == '' ]];
	then
		[[ "$__verbose" != 0 ]] && Misc_PrintF -v 1 -t 'f' -n $'No command declared to start terminal';

		return 100;
	fi

	if [[ "$__terminalFontSize" == '' ]];
	then
		__terminalFontSize=8;
	fi

	if [[ "$__terminalFont" == '' ]];
	then
		__terminalFont='Terminus';
	fi
	
	########
	# Main #
	########

	declare terminalBackColor="${Misc_ColorsTheme['clBlack']:-000000}";
	declare terminalFontColor="${Misc_ColorsTheme['clWhite']:-ffffff}";

	if [[ "$__terminalColors" != '' ]];
	then
		if [[ "$__terminalColors" =~ ^[0-9A-Fa-f]{6},[0-9A-Fa-f]{6}$ ]]; # If "font,back" - font and back colors
		then
			terminalFontColor="${__terminalColors%,*}";
			terminalBackColor="${__terminalColors#*,}";
		elif [[ "$__terminalColors" =~ ^[0-9A-Fa-f]{6},$ ]]; # If "font," - only font
		then
			terminalFontColor="${__terminalColors%,*}";
		elif [[ "$__terminalColors" =~ ^,[0-9A-Fa-f]{6}$ ]]; # If ",back" - only back
		then
			terminalBackColor="${__terminalColors#*,}";
		elif [[ "$__terminalColors" =~ ^[0-9A-Fa-f]{6}$ ]]; # If just a color - only font
		then
			terminalFontColor="${__terminalColors%,*}";
			# terminalBackColor="$terminalFontColor";
		fi
	fi

	declare terminalBackColor="${terminalBackColor//\#}";
	declare terminalFontColor="${terminalFontColor//\#}";

	########
	# Main #
	########

	# Just for log/output
	declare commandStringPreview="${__command[*]}";
	declare commandPreviewStringLengthMax=1000;

	[[ "$__verbose" != 0 ]] && Misc_PrintF -v 5 -t 'd' -nmf $'Starting {{@clGreen}}%sbound{{@clDefault}} terminal: "{{@clLightCyan}}%s%s{{@clDefault}}"' -- \
		"$( [[ "$__processBindMeta" == '' ]] && printf 'un' )" "${commandStringPreview:0:$commandPreviewStringLengthMax}" \
		"$( (( "${#commandStringPreview}" > $commandPreviewStringLengthMax )) && printf '...' )";

	Environment_ProcessStart $( (( __verbose > 1 )) && printf ' -v ' ) \
		-o Environment_TerminalStart_commandResult --bm "$__processBindMeta" -x "$__windowParameters" -X 'xterm' -- \
		"xterm $( [[ "$__terminalHold" != 0 ]] && printf -- '-hold' ) \
			-fa '${__terminalFont}' -fs ${__terminalFontSize} -fg '#${terminalFontColor}' -bg '#${terminalBackColor}' \
			-title \"${__terminalTitle}$( [[ "$__addTimeToTitle" != 0 ]] && date '+ [%F_%T]' )\" \
			-e \"${__command[*]}\"";

	declare returnCodeTemp=$?;

	if [[ "$__processBindMeta" == '' ]];
	then
		[[ "$__verbose" != 0 ]] && Misc_PrintF -v 5 -t 'd' -nf $'Unbound terminal returned exit status %s' "$returnCodeTemp";
	fi

	# If requested to set referenced variable(s)
	if [[ "$__outputVariableReferenceName" != '' ]];
	then
		Environment_TerminalStart_outputVariableReference="$Environment_TerminalStart_commandResult";
		Environment_TerminalStart_outputVariableReferenceOut="$Environment_TerminalStart_commandResultOut";
		Environment_TerminalStart_outputVariableReferenceErr="$Environment_TerminalStart_commandResultErr";
	fi

	return "$returnCodeTemp";
}

Environment_DependencyVerify()
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
		Misc_PrintF -v 1 -t 'f' -nf $'[Environment_DependencyVerify] Invalid options (code %s, index %s ~ \'%s\'): \'%s\'' -- \
			"$_Options_ResultCode" "$_Options_FailIndex" "$_Options_ErrorMessage" "$( Misc_ArrayJoin -- "$@" )";

		exit 200;
	fi

	declare ignoreFail="${args[0]}";
	declare verbose="${args[1]}";
	declare dependencies=( "${args[@]:2}" );

	if [ "${#dependencies[@]}" = 0 ];
	then
		Misc_PrintF -v 1 -t 'f' -n $'No dependency declared to verify';

		return 100;
	fi

	########
	# Main #
	########

	declare returnCode=0;
	declare dependencyIndex;
	declare paddingNumber="${#dependencies}";
	declare paddingNumber="${#paddingNumber}";

	for (( dependencyIndex = 0; dependencyIndex < ${#dependencies[@]}; dependencyIndex++ ));
	do
		declare dependency="${dependencies[$dependencyIndex]}";

		if ! hash "$dependency" &>> "$_Main_Dump";
		then
			if [ "$verbose" != 0 ];
			then
				Misc_PrintF -v 2 -t 'e' -nmf $"[ %${paddingNumber}s/%s ] No such dependency: \"{{@clRed}}%s{{@clDefault}}\"" -- \
					"$(( $dependencyIndex + 1 ))" "${#dependencies[@]}" "$dependency";
			fi

			if [ "$ignoreFail" = 0 ];
			then
				return 1;
			fi

			(( returnCode < 1 )) && declare returnCode=1;

			continue;
		fi

		[[ "$verbose" != 0 ]] && Misc_PrintF -v 4 -t 's' -nmf $"[ %${paddingNumber}s/%s ] Found dependency: \"{{@clLightGreen}}%s{{@clDefault}}\"" -- \
			"$(( $dependencyIndex + 1 ))" "${#dependencies[@]}" "$dependency";
	done

	return "$returnCode";
}

# OS specific (this one is for KDE Neon 5.21.2, Linux x4 5.4.0-67-generic)
Environment_Prepare()
{
	###########
	# Options #
	###########

	declare args;

	if ! Options args \
		'?!-D;?!-d' \
		"$@";
	then
		Misc_PrintF -v 1 -t 'f' -nf $'[Environment_Prepare] Invalid options (code %s, index %s ~ \'%s\'): \'%s\'' -- \
			"$_Options_ResultCode" "$_Options_FailIndex" "$_Options_ErrorMessage" "$( Misc_ArrayJoin -- "$@" )";

		exit 200;
	fi

	declare __deviceMain="${args[0]}";
	declare __deviceSecondary="${args[1]}";

	########
	# Main #
	########

	# Trap/Map certain exit signals to a pre-exit function if required
	if [[ ${#Environment_trappedSignals[@]} != 0 ]];
	then
		trap 'Environment_Clear "$?";' "${Environment_trappedSignals[@]}";
	fi

	[[ "$verbose" != 0 ]] && Misc_PrintF -v 3 -t 'm' -nmf $'Preparing environment ({{@clYellow}}%s{{@clDefault}})' "$Environment_SessionId";
	[[ "$verbose" != 0 ]] && Misc_PrintF -v 4 -t 'i' -nmf $'Initializing workspace';

	#
	# Initial workspace
	#

	if ! Base_FsDelete -d 1-1 -f -- "${Environment_TempDirpath}/";
	then
		[[ "$verbose" != 0 ]] && Misc_PrintF -v 3 -t 'w' -nmf $'Failed to clear temp directory: \'%s\'' -- "$Environment_TempDirpath";
	fi

	# Create initial directories

	if ! Base_FsDirectoryCreate -p -- "$Environment_ConfigsDirpath" "$Environment_LogsDirpath" "$Environment_TempDirpath";
	then
		[[ "$verbose" != 0 ]] && Misc_PrintF -v 2 -t 'e' -nm -- $'Failed to form proper workspace';

		return 3;
	fi

	#
	# Main terminal window
	#

	# Add the main process's PID to the pids file
	Environment_processBindAdd --bi "$$" --bm 'main_twincy' -t "$( Misc_DateTime )";

	# Try to find the main terminal window in the process hierarchy (considering the terminal program name opaque)

	declare Environment_Prepare_mainTerminalWindow;

	# If found any parent process with a window
	if ! Environment_WindowFindFirstParentByPid -o Environment_Prepare_mainTerminalWindow -p "$$"; # $PPID
	then
		[[ "$verbose" != 0 ]] && Misc_PrintF -v 3 -t 'w' -nm $'Did not find main terminal window';

		return 1;
	fi

	[[ "$verbose" != 0 ]] && Misc_PrintF -v 5 -t 'd' -nmf $'Found main terminal window (PID %s): \'%s\'' -- \
		"$Environment_Prepare_mainTerminalWindowPid" "$Environment_Prepare_mainTerminalWindow";

	# Add the parent process which is *supposedly* a window terminal for future access (i.e. resize or move)
	if ! Environment_processBindAdd --bi "$Environment_Prepare_mainTerminalWindowPid" --bm "main_twincy_terminal";
	then
		[[ "$verbose" != 0 ]] && Misc_PrintF -v 5 -t 'w' -nmf $'Failed to bind main terminal window process: \'%s\'' -- "$Environment_Prepare_mainTerminalWindowPid";

		return 1;
	fi

	[[ "$verbose" != 0 ]] && Misc_PrintF -v 5 -t 'd' -nmf $'Bound main terminal window process: \'%s\'' -- "$Environment_Prepare_mainTerminalWindowPid";
	Environment_WindowArrange --bm 'main_twincy_terminal' -- $( Environment_WindowSector -H 6 -V 6 -h 1-4 -v 1-4 -t 0 -r 0 -b 0 -l 0 );

	#
	# Web resources and filesystem permissions
	#

	if ! Environment_prepareResourcesWeb;
	then
		return 3;
	fi

	# Todo: set temp to 751
	if ! Base_FsPerms -rm 755 -- "$Environment_SessionDirpath" || ! Base_FsPerms -rm 777 -- "$Environment_TempDirpath";
	then
		[[ "$verbose" != 0 ]] && Misc_PrintF -v 2 -t 'e' -nmf $'Failed to set permissions on workspace elements: \'%s\'' -- "$Environment_TempDirpath";

		return 3;
	fi

	#
	# Services and interfaces
	#

	if [[ "$__deviceMain" == '' || "$__deviceSecondary" == '' ]];
	then
		[[ "$verbose" != 0 ]] && Misc_PrintF -v 2 -t 'e' -nmf $'Two 802.11 interfaces are required';

		return 2;
	fi

	if [[ "$Environment_UserNonRoot" == '' ]];
	then
		[[ "$verbose" != 0 ]] && Misc_PrintF -v 2 -t 'e' -nmf $'No non-root user provided';

		return 2;
	fi

	[[ "$verbose" != 0 ]] && Misc_PrintF -v 4 -t 'n' -nm -- $'Stopping related services';

	service apparmor stop &>> "$_Main_Dump";
	service systemd-resolved stop &>> "$_Main_Dump";
	service network-manager stop &>> "$_Main_Dump";
	service networking stop  &>> "$_Main_Dump";
	service avahi-daemon stop &>> "$_Main_Dump";
	killall dhclient &>> "$_Main_Dump";

	[[ "$verbose" != 0 ]] && Misc_PrintF -v 4 -t 'n' -nmf $'Configuring 802.11 interfaces';

	if ! Interface_ModeSet -m 1 "$__deviceMain";
	then
		[[ "$verbose" != 0 ]] && Misc_PrintF -v 2 -t 'e' -nmf $'802.11 interface \'%s\' not ready' -- "$__deviceMain";
		printf '\n';
		Interface_List;

		return 2;
	fi

	if ! Interface_ModeSet -m 1 "$__deviceSecondary";
	then
		[[ "$verbose" != 0 ]] && Misc_PrintF -v 2 -t 'e' -nmf $'802.11 interface \'%s\' not ready' -- "$__deviceSecondary";
		printf '\n';
		Interface_List;

		return 2;
	fi

	Interface_DeviceMain="$__deviceMain";
	Interface_DeviceSecondary="$__deviceSecondary";

	# Misc_PrintF -v 4 -t 'i' -p 1 -nnf 'Verifying dependencies...';

	# if ! Environment_DependencyVerify -iv -- "${Environment_softwareDependencies[@]}";
	# then
	# 	return 5;
	# fi

	return 0;
}

Environment_EnvVarSet()
{
	IFS="$_Main_EnvVar_IFS";
}

# OS specific (this one is for KDE Neon 5.23.2, Linux 5.11.0-38-generic)
Environment_Clear()
{
	if [[ ! "$1" =~ [0-9]+ ]];
	then
		exit 200;
	fi

	if [[ "$Environment_exitCode" != '' ]];
	then
		printf 'Environment clearing already in progress (code %s)\n' "$Environment_exitCode";

		return "$Environment_exitCode";
	fi

	# if [[ "$IFS" == '' ]]; # In case of cancelled 'IFS= read...'
	# then
	# 	printf '\n';
	# fi

	Environment_EnvVarSet;
	Environment_exitCode="$1";

	if [[ "$Environment_clearCode" != '' ]];
	then
		Misc_PrintF -v 3 -t 'w' -nnf 'Encountered another termination with code %s (using initial instead: %s)' "$1" "$Environment_clearCode";

		exit "$Environment_clearCode";
	fi

	Misc_PrintF -f $'\n ';
	Misc_PrintF -r 80 -mf '{{@clDarkGray}}-';
	Misc_PrintF -v 4 -t 'm' -p 2 -nmf $'Stopping gracefully (code %s)' "$1";

	Misc_PrintF -v 4 -t 'i' -nmf $'Session: \'{{@clYellow}}%s{{@clDefault}}\' (%s)' -- "$Environment_SessionId" \
		"$( Misc_DateTimeDiff -s "$_Main_TimeStart"; )";

	Misc_PrintF -v 4 -t 'n' -nm -- $'Stopping bound processes';
	Environment_ProcessBindTerminate --bm 'bind_';

	# Todo - Because even -D option doesn't terminate them properly for some unknown reason...
	killall lighttpd &>> "$_Main_Dump";

	Misc_PrintF -v 1 -t 'n' -nm -- $'Stopping related services';
	service apparmor stop &>> "$_Main_Dump";
	service systemd-resolved stop &>> "$_Main_Dump";
	service network-manager stop &>> "$_Main_Dump";
	service networking stop  &>> "$_Main_Dump";
	service avahi-daemon stop &>> "$_Main_Dump";
	killall dhclient &>> "$_Main_Dump";

	# If reset monitor mode
	if [[ "$Environment_ResetInterfacesOnExit" == 1 ]];
	then
		Misc_PrintF -v 4 -t 'n' -nmf $'Resetting interfaces';

		if [[ "$Interface_DeviceMain" != '' ]];
		then
			Interface_ModeSet -im 0 -- "$Interface_DeviceMain";

			if ! Interface_DeviceMac -rd "$Interface_DeviceMain";
			then
				Misc_PrintF -v 2 -t 'e' -nmf $'Failed to reset main 802.11 \'%s\' device' -- "$Interface_DeviceMain";
			fi
		fi

		if [[ "$Interface_DeviceSecondary" != '' ]];
		then
			Interface_ModeSet -im 0 -- "$Interface_DeviceSecondary";

			if ! Interface_DeviceMac -rd "$Interface_DeviceSecondary";
			then
				Misc_PrintF -v 2 -t 'e' -nmf $'Failed to reset secondary 802.11 \'%s\' device' -- "$Interface_DeviceSecondary";
			fi
		fi
	fi

	Misc_PrintF -v 4 -t 'n' -nm -- $'Resetting network configuration';

	if ! Twin_network -r;
	then
		Misc_PrintF -v 2 -t 'e' -nmf 'Failed to reset network configuration';
	fi

	Misc_PrintF -v 4 -t 'n' -nm -- $'Starting related services';
	dhclient &>> "$_Main_Dump";
	service avahi-daemon restart &>> "$_Main_Dump";
	service networking restart &>> "$_Main_Dump";
	service network-manager restart &>> "$_Main_Dump";
	service systemd-resolved restart &>> "$_Main_Dump";
	service apparmor restart &>> "$_Main_Dump";

	printf '%s\n' \
		$'\n'"--------------------------------------------------------------------------------" \
		" Session end $( printf $'\'%s\' (%s)' "$Environment_SessionId" "$( date -u; )"; )" \
		"--------------------------------------------------------------------------------"$'\n' &>> "$_Main_Dump";

	# If requested to clear the session
	if
		(( Environment_ClearSession != 0 )) &&
		(
			Base_FsExists -t 2 -- "$Environment_SessionDirpath" ||
			Base_FsExists -t 2 -- "$Environment_TempDirpath" ||
			Base_FsExists -t 2 -- "$_Main_Dump"
		);
	then
		declare Environment_Clear_prompt;

		if Misc_Prompt -o Environment_Clear_prompt -p '^[YyNn]$' -e '[YyNn]' -T 10 -d 'y' -- 'Clear session?' && [[ "$Environment_Clear_prompt" =~ ^[Yy]$ ]];
		then
			Misc_PrintF -v 3 -t 'w' -nmf $'Clearing session';
			Base_FsDelete -t d -f -- "$Environment_SessionDirpath";

			if [[ "$Environment_TempDirpath" == "$Environment_TempDirpathDefault" ]];
			then
				Base_FsDelete -t f -f -- "$Environment_TempDirpathDefault";
			else
				Misc_PrintF -v 4 -t 'i' -nmf $'Skipped non-default temporary location';
			fi

			if [[ "$_Main_Dump" == "$_Main_DumpFilepathDefault" ]];
			then
				_Main_Dump='/dev/null';
				Base_FsDelete -t f -f -- "$_Main_DumpFilepathDefault";
			else
				Misc_PrintF -v 4 -t 'i' -nmf $'Skipped non-default dump location';
				# Base_FsWrite -f "$_Main_Dump";
			fi

			if Base_FsDelete -t d -- "$Environment_sessionsDirpath";
			then
				Base_FsDelete -t d -- "$Environment_workspaceDirpath";
			fi
		fi
	fi

	Base_FsDelete -f -- "$Environment_pidsBoundFilepath";
	Misc_PrintF -v 4 -t 's' -nnm -- $'Done';
	Environment_clearCode="$1";

	# Untrap signals if required
	if [[ ${#Environment_trappedSignals[@]} != 0 && "$( trap )" != '' ]];
	then
		trap - "${Environment_trappedSignals[@]}"; # trap | awk... | while read... # $( compgen -A signal )
	fi

	exit "$1";
}