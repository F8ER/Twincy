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

declare -r _Lib_misc=1;
declare -r _Misc_sourceFilepath="$( readlink -e -- "${BASH_SOURCE[0]:-$0}" 2> '/dev/null'; )";
declare -r _Misc_sourceDirpath="$( dirname -- "$_Misc_sourceFilepath" 2> '/dev/null'; )";

[[ ! -f "$_Misc_sourceFilepath" || ! -d "$_Misc_sourceDirpath" ]] && exit 199;

# Colors and themes

declare -r clBlack='\033[0;30m';
declare -r clRed='\033[0;31m';
declare -r clGreen='\033[0;32m';
declare -r clOrange='\033[0;33m';
declare -r clBlue='\033[0;34m';
declare -r clPurple='\033[0;35m';
declare -r clCyan='\033[0;36m';
declare -r clLightGray='\033[0;37m'; # "\033[38;2;99;99;99m";
declare -r clGray='\033[1;30m';
declare -r clLightRed='\033[1;31m';
declare -r clLightGreen='\033[1;32m';
declare -r clYellow='\033[1;33m';
declare -r clLightBlue='\033[1;34m';
declare -r clLightPurple='\033[1;35m';
declare -r clLightCyan='\033[1;36m';
declare -r clWhite='\033[1;37m';
declare -r clDefault='\033[0m';

declare -rA Misc_colorsTheme_default=(
	['clDefault']="$clDefault"
	['clWhite']='#ffffff'
	['clBlack']='#000000'
	['clRed']='#F12E2E'
	['clGreen']='#00ff00'
	['clBlue']='#6648EC'
	['clBlue2']='#11afec'
	['clYellow']='#F0D54F' # '#ffff00'
	['clGray']='#777777'
	['clLightGray']='#888888'
	['clLightRed']='#ec5555'
	['clLightGreen']='#4de37d'
	['clLightBlue']='#98c1d9'
	['clLightBlue2']='#59acc6'
	['clLightPink']='#e54cbd'
	['clLightCyan']='#11ecec'
	['clLightOrange']='#F09A4F'
	['clDarkGray']='#555555'
	['clDarkCyan']='#64a495'
	['clLogo']='#31454c' # '#495356' # '#4f5456' # '#A9E4E4'
);

declare -rA Misc_colorsTheme_white=(
	['clDefault']="$clDefault"
	['clWhite']='#000000'
	['clBlack']='#ffffff'
	['clRed']='#BB1D1D'
	['clGreen']='#1F8C62'
	['clBlue']='#435AAC'
	['clBlue2']='#6177C4'
	['clYellow']='#D5AA36' # '#BF9930' # '#B3AE25'
	['clGray']='#696969'
	['clLightGray']='#aaaaaa'
	['clLightRed']='#ec5555'
	['clLightGreen']='#449A79'
	['clLightBlue']='#5695BB'
	['clLightBlue2']='#5F989A'
	['clLightPink']='#e54cbd'
	['clLightCyan']='#48B4BA'
	['clLightOrange']='#ae7e32' # '#C28D38'
	['clDarkGray']='#BBBBBB'
	['clDarkCyan']='#348C89'
	['clLogo']='#e5ecee' # '#d6dfe2' # '#d3dcdf' # '#c3d2d7' # 93ADBF
);

# Theme

declare -A Misc_ColorsTheme;

# If such color doesn't exist
if declare -p "Misc_colorsTheme_${_Main_ColorTheme}" &> '/dev/null';
then
	declare -n Misc_colorsTheme="Misc_colorsTheme_${_Main_ColorTheme}";
else
	declare -n Misc_colorsTheme="Misc_colorsTheme_default";
fi

for colorName in "${!Misc_colorsTheme[@]}";
do
	Misc_ColorsTheme["$colorName"]="${Misc_colorsTheme[$colorName]}";
done

# Defaults

declare -r Misc_PrintF_OutputStreamsDefault=(
	'/dev/stdin'
	'/dev/stdout'
	'/dev/stderr'
)

declare -r Misc_PrintF_SubshellLevelMaxDefault=1;
declare -r Misc_RandomString_LengthDefault=8;
declare -r Misc_RandomString_CharacterSetDefault='A-Za-z0-9';
declare -r Misc_NotificationSound_VolumeDefault=1;
declare -r Misc_ScreenDimensions_ScreenIndexDefault=0;

#############
# Variables #
#############

# 5 ~ debug, 4 ~ success, 3 ~ warning, 2 - error, 1 - fatal, 0 ~ silent
Misc_VerbosityLevel=4;
Misc_VerbosityTimestamp=1;
Misc_SoundVerbosityLevel=4;
Misc_OutputStreamStdDefault=1;
Misc_OutputStreamErrDefault=2;
Misc_TimeStoreTimes=();

############################################################
# Functions (public)                                       #
############################################################

Misc_ColorThemePrint()
{
	Misc_PrintF -nf $' Theme: \'%s\' (%s)' -- "$_Main_ColorTheme" "$( declare -p Misc_colorsTheme; )";
	Main_Logo;
	Misc_PrintF -np ,1 -mf '{{@clDarkGray}}%s' -- "$( Misc_PrintF -r 80 -- '-'; )";

	for colorName in "${!Misc_ColorsTheme[@]}";
	do
		Misc_PrintF -nmf "%20s: {{@${colorName}}}Colorized message example - %s" -- "'${colorName}'" "$( Misc_RandomString -l 20; )";
	done

	Misc_PrintF -np ,1 -mf '{{@clDarkGray}}%s' -- "$( Misc_PrintF -r 80 -- '-'; )";
}

Misc_EscapeFilename()
{
	printf '%s' "$@" | perl -pe 's/[:;,\?\[\]\/\\=<>''"&\$#*()|~`!{}%+_]//g; s/[\n\r\t\s-]+/-/g;';
}

Misc_IsArrayAssoc()
{
	if [[ "$( declare -p "$1" 2>> "$_Main_Dump" )" == 'declare -A'* ]];
	then
		return 0;
	fi

	return 1;
}

# Join an array of values to a string
Misc_ArrayJoin()
{
	if [ "$1" == '-e' ];
	then
		declare escape=1;
		shift;
	else
		declare escape=0;
	fi

	if [ "$1" == '--' ];
	then
		declare prefix="'";
		declare postfix="'";
		declare separator=", ";
		shift;
	else
		declare prefix="$1";
		declare postfix="$2";
		declare separator="$3";
		shift 3;
	fi

	if [ $# = 0 ];
	then
		return 1;
	fi

	declare index;

	# If escape chars
	if [ "$escape" = 1 ];
	then
		declare pattern='%s%q%s';
	else
		declare pattern='%s%s%s';
	fi

	for (( index = 1; index <= $#; index++ ));
	do
		IFS=' \t\n' printf "$pattern" "$prefix" "${!index}" "$postfix"

		if (( "$index" < $# ));
		then
			printf '%s' "$separator";
		fi
	done
}

# Check if the array contains any of the declared elements and return the first found position
Misc_ArraySearch()
{
	declare valuePositionPrint=1;

	# If requested to not print the value's position in the array
	if [[ "$1" == '-' ]];
	then
		declare valuePositionPrint=0;
		shift;
	fi

	# Delimiter of elements to find
	declare delimiter="";
	declare elementsToFind=( "$1" ); # Value or delimiter

	# If the delimiter is declared, meaning multiple values to find may be also declared
	if [[ "${1:0:1}" == '!' ]];
	then
		# Remove the first '!' from the delimiter
		declare delimiter="${1:1}";
		shift;

		# If the delimiter is empty
		if [ "$delimiter" = '' ];
		then
			delimiter=',';
		fi

		# Fill the array with values separated by the delimiter
		IFS="$delimiter" read -ra elementsToFind <<< "$1";
	elif [ "${1:0:1}" = '%' ]; # If the symbol '!' may the be first character in the value
	then
		elementsToFind=( "${1:1}" );
	fi

	shift;
	declare elementToFindPosition="0"; # Value's position in values' array(if delimiter declared)
	declare elementToFind;

	for elementToFind in "${elementsToFind[@]}"; # Loop each value(if delimiter declared) or only one value
	do
		declare elementPosition="0"; # Position of value in array
		declare element; # For array of elements of array

		for element in "$@";
		do
			if [[ "$element" == "$elementToFind" ]]; # If value is equal to array's element
			then
				if [[ "$valuePositionPrint" == 1 ]]; # If allowed, print value's position in array
				then
					if [[ "$delimiter" != '' ]]; # Echo value's position in values' array(if delimiter declared)
					then
						printf '%s' "$elementToFindPosition,";
					fi

					printf $'%s\n' "$elementPosition";
				fi

				return 0;
			fi

			declare elementPosition="$(( elementPosition + 1 ))"; # Increment checking value's position
		done

		declare elementToFindPosition="$(( elementToFindPosition + 1 ))"; # Increment value's position in values' array
	done

	return 1;
}

# Get or set the verbosity level
Misc_Verbosity()
{
	if [ "$1" = '-s' ];
	then
		declare setVerbosity=1;
		shift;
	else
		declare setVerbosity=0;
	fi

	# If the verbosity level declared is invalid
	if [ "$#" != 1 ] || [[ ! "$1" =~ ^[0-5]+$ ]];
	then
		return 1;
	fi

	# If requested to set the verbosity
	if [ "$setVerbosity" = 1 ];
	then
		Misc_VerbosityLevel="$1";

		return 0;
	fi

	return $(( $1 > Misc_VerbosityLevel ));
}

Misc_TrimString()
{
	IFS=' \t\n' printf '%s' "$@" | perl -pe 's/^\s+|\s+$//g';
}

Misc_ToLowUpString()
{
	if [ "$1" = '-u' ];
	then
		shift;
		IFS=' \t\n' printf '%s' "$@" | awk '{ print toupper($1) }';

		return;
	fi

	IFS=' \t\n' printf '%s' "$@" | awk '{ print tolower($1) }';
}

# Convert any descriptors string to a proper descriptors string
#
# Examples:
# 	o -> ion -> 013
# 	2 -> in2 -> 032
# 	n -> inn -> 033
# 	1n -> i1n -> 013
# 	ei -> iei -> 020
# 	e1 -> ie1 -> 021
# 	oo -> ioo -> 011
# 	ioe -> 012
# 	no3 -> 313
# 
Misc_Descriptors()
{
	if [ $# != 1 ];
	then
		printf '012';

		return 1;
	fi

	declare descriptors="$1";

	if ! Misc_Regex -p '^[0123ioen]{0,3}$' -- "$descriptors";
	then
		printf '012';

		return 2;
	fi

	if [ "${#descriptors}" = 0 ];
	then
		printf '012';

		return 0;
	elif [ "${#descriptors}" = 1 ];
	then
		case "$descriptors"
		in
			'0'|'n'|'i') declare descriptors='033';;
			'1'|'o') declare descriptors='013';;
			'2'|'e') declare descriptors='032';;
		esac
	elif [ "${#descriptors}" = 2 ];
	then
		declare descriptors="0${descriptors}";
	fi

	printf '%s' "$descriptors" | sed 's/i/0/g; s/o/1/g; s/e/2/g; s/n/3/g;';

	return 0;
}

# Description: The random string function
# 
# Options:
# 	-l (argument) - Length of string to generate
# 	-c (argument) - Set of characters
#
# Returns:
#	200 ~ Invalid options
#
# Outputs:
#	1. Prints: A generated random string
#
Misc_RandomString()
{
	declare args;

	if ! Options args \
		'@0/^(0|[1-9][0-9]*)$/' \
		'?-l;?-c' \
		"$@";
	then
		Misc_PrintF -v 1 -t 'f' -nf $'[Misc_RandomString] Invalid options (code %s, index %s ~ \'%s\'): \'%s\'' -- \
			"$_Options_ResultCode" \
			"$_Options_FailIndex" \
			"$_Options_ErrorMessage" \
			"$( Misc_ArrayJoin -- "$@" )";

		exit 200;
	fi

	declare length="${args[0]}";
	declare characterSet="${args[1]}";

	if [ "$length" = '' ];
	then
		declare length="$Misc_RandomString_LengthDefault";
	fi

	if [ "$characterSet" = '' ];
	then
		declare characterSet="$Misc_RandomString_CharacterSetDefault";
	fi

	head '/dev/urandom' | tr -dc "$characterSet" | head -c "$length";
}

# [~] Can be shorter, but just in case
Misc_RandomInteger()
{
	declare rangeLow=0;
	declare rangeHigh=100;

	if (( $# > 0 ));
	then
		if (( $# > 2 ));
		then
			return 5;
		fi

		if [[ "$1" != '' ]];
		then
			if [[ ! "$1" =~ ^(0|[1-9][0-9]*)$ ]];
			then
				return 1;
			fi

			declare rangeHigh="$1";
		fi

		if [[ "$2" != '' ]];
		then
			if [[ ! "$2" =~ ^(0|[1-9][0-9]*)$ ]];
			then
				return 2;
			fi

			declare rangeLow="$2";
		fi

		if (( rangeLow > rangeHigh ));
		then
			return 3;
		fi
	fi

	if ! shuf --random-source='/dev/urandom' -i "${rangeLow}-${rangeHigh}" -n 1 2>> "$_Main_Dump";
	then
		return 4;
	fi
}

Misc_DateTime()
{
	###########
	# Options #
	###########

	declare args;

	if ! Options args \
		'@0/^[0-6]$/' \
		'?-t;?-T;?-F;-l' \
		"$@"
	then
		Misc_PrintF -v 1 -t 'f' -nf $'[Misc_DateTime] Invalid options (code %s, index %s ~ \'%s\'): \'%s\'' -- \
			"$_Options_ResultCode" \
			"$_Options_FailIndex" \
			"$_Options_ErrorMessage" \
			"$( Misc_ArrayJoin -- "$@" )";

		return 200;
	fi

	declare __dateTimeType="${args[0]}";
	declare __dateTimeCustom="${args[1]}";
	declare __dateTimeFormat="${args[2]}";
	declare __dateTimeLocal="${args[3]}";

	########
	# Main #
	########

	declare dateArgs=( '-u' ); # UTC

	if [[ "$__dateTimeLocal" != 0 ]];
	then
		declare dateArgs=();
	fi

	if [[ "$__dateTimeCustom" != '' ]];
	then
		dateArgs+=( '-d' "@${__dateTimeCustom}" );
	fi

	if [[ "$__dateTimeFormat" != '' ]];
	then
		date "${dateArgs[@]}" "+${__dateTimeFormat}" 2>> "$_Main_Dump";

		return $?;
	fi

	case "$__dateTimeType" in
		1) 
			date "${dateArgs[@]}" -Ins 2>> "$_Main_Dump";

			return $?;
		;;
		2) 
			date "${dateArgs[@]}" -Iseconds 2>> "$_Main_Dump";
			
			return $?;
		;;
		3) 
			date "${dateArgs[@]}" '+%s' 2>> "$_Main_Dump";
			
			return $?;
		;;
		4)
			date "${dateArgs[@]}" '+%F %T' 2>> "$_Main_Dump";

			return $?;
		;;
		5)
			date "${dateArgs[@]}" '+%T' 2>> "$_Main_Dump";

			return $?;
		;;
		6)
			date "${dateArgs[@]}" '+%F_%T' 2>> "$_Main_Dump";

			return $?;
		;;
	esac

	date "${dateArgs[@]}" '+%s.%N' 2>> "$_Main_Dump";
}

Misc_DateTimeDiff()
{
	###########
	# Options #
	###########

	declare args;

	if ! Options args \
		'@0/^(?:0|[1-9][0-9]*)(?:.(?:[0-9]+))?$/' \
		'@1/^(?:0|[1-9][0-9]*)(?:.(?:[0-9]+))?$/' \
		'?-s;?-e' \
		"$@"
	then
		Misc_PrintF -v 1 -t 'f' -nf $'[Misc_DateTime] Invalid options (code %s, index %s ~ \'%s\'): \'%s\'' -- \
			"$_Options_ResultCode" \
			"$_Options_FailIndex" \
			"$_Options_ErrorMessage" \
			"$( Misc_ArrayJoin -- "$@" )";

		return 200;
	fi

	declare __dateTimeStart="${args[0]}";
	declare __dateTimeEnd="${args[1]}";

	if [[ "$__dateTimeEnd" == '' ]];
	then
		declare __dateTimeEnd="$( Misc_DateTime -t 3 )";
	fi

	########
	# Main #
	########

	declare timeDiffSeconds="$(( ${__dateTimeEnd%%\.*} - ${__dateTimeStart%%\.*} ))";

	# date -ud "0000-01-01 ${__dateTimeEnd} seconds - "${__dateTimeStart}" seconds" "${__dateTimeFormat[@]}";
	printf '%sd %s' "$(( timeDiffSeconds / 3600 / 24 ))" "$( date -ud "@${timeDiffSeconds}" '+%T' 2>> "$_Main_Dump"; )";
}

# i.e. #ff9 or ffff99 -> 255 255 153
Misc_HexToRgb()
{
	colorRgbHex="$1";

	if [ "${colorRgbHex:0:1}" = '#' ];
	then
		colorRgbHex="${colorRgbHex:1}";
	fi

	if [[ ! "${colorRgbHex}" =~ ^([0-9a-fA-F]{3}|[0-9a-fA-F]{6})$ ]];
	then
		return 1;
	elif [[ "${colorRgbHex}" =~ ^[0-9a-fA-F]{3}$ ]];
	then
		colorRgbHex="${colorRgbHex:0:1}${colorRgbHex:0:1}${colorRgbHex:1:1}${colorRgbHex:1:1}${colorRgbHex:2:1}${colorRgbHex:2:1}";
	fi

	printf "%d %d %d" "0x${colorRgbHex:0:2}" "0x${colorRgbHex:2:2}" "0x${colorRgbHex:4:2}";
}

Misc_JsonGet()
{
	if (( $# < 3 ));
	then
		return 1;
	fi

	declare -n result="$1";
	shift;
	declare jsonString="$1";
	shift;

	if [ $# = 0 ];
	then
		return 1;
	fi

	declare keys="'${@:1:1}'";

	if [[ ! "$keys" =~ ^\'[0-9a-zA-Z\_\$]+\'$ ]];
	then
		return 1;
	fi

	if (($# > 1));
	then
		declare keyIndex;

		for (( keyIndex = 2; keyIndex <= $#; keyIndex++ ))
		do
			declare key="${@:$keyIndex:1}";

			if [[ ! "$key" =~ [0-9a-zA-Z\_\$]+ ]];
			then
				return 1;
			fi

			declare keys="${keys}, '$key'";
		done
	fi

	result="$(
		printf '%s' "$jsonString" | python3 -c "
import sys, json;

data = json.load(sys.stdin);
keys = [${keys}];
valueTemp = data;

for key in keys:
	if key not in valueTemp:
		exit(1);

	valueTemp = valueTemp[key];

print(valueTemp);
";
	)";
}

# Test if a regex Perl Compatible Regular Expressions (PCRE) pattern is valid (<3 Perl)
Misc_RegexVerify()
{
	IFS=' \t\n' printf '%s' "$@" | perl -ne 'eval { qr/$_/ }; die if $@;' &>> '/dev/null';
}

# Escape characters
Misc_Escape()
{
	###########
	# Options #
	###########

	declare args;

	if ! Options args \
		'@0/^(0|[1-9][0-9]*)$/' \
		'?-d;?-c;?-o' \
		"$@"
	then
		Misc_PrintF -v 1 -t 'f' -nn -f $'[Misc_Escape] Invalid options (code %s, index %s ~ \'%s\'): \'%s\'' -- \
			"$_Options_ResultCode" "$_Options_FailIndex" "$_Options_ErrorMessage" "$( Misc_ArrayJoin -- "$@" )";

		return 200;
	fi

	declare depth="${args[0]}";
	declare characterSet="${args[1]}";
	declare __outputVariableReferenceName="${args[2]}";
	declare data=( "${args[@]:3}" );

	if [[ "$depth" == '' ]];
	then
		declare depth=1;
	fi

	if [[ "$characterSet" == '' ]];
	then
		declare characterSet=$'\\\'';
	fi

	if [[ "$__outputVariableReferenceName" != '' ]];
	then
		if [[ "$__outputVariableReferenceName" == 'Misc_Escape_outputVariableReference' ]];
		then
			Misc_PrintF -v 1 -t 'f' -nf $'[Misc_Escape] Output variable reference interference: \'%s\'' -- "$( Misc_ArrayJoin -- "$@" )";

			return 100;
		fi

		declare -n Misc_Escape_outputVariableReference="$__outputVariableReferenceName";
		Misc_Escape_outputVariableReference=();
	fi

	########
	# Main #
	########

	declare result=();
	declare dataIndex;

	for (( dataIndex = 0; dataIndex < ${#data[@]}; dataIndex++ ));
	do
		declare dataItem="${data[$dataIndex]}";
		declare level;

		for (( level = 0; level < $depth; level++ ));
		do
			declare characterIndex;

			for (( characterIndex = 0; characterIndex < ${#characterSet}; characterIndex++ ));
			do
				declare character="${characterSet[$characterIndex]}";
				declare dataItem="${dataItem//$character/\\$character}";
			done
		done

		result+=( "$dataItem" );
	done

	if [[ "$__outputVariableReferenceName" != '' ]];
	then
		Misc_Escape_outputVariableReference=( "${result[@]}" );

		return 0;
	fi

	printf '%s' "${result[*]}";

	return 0;
}

Misc_TablePrint()
{
	###########
	# Options #
	###########

	declare args;

	if ! Options args \
		'@0/^(0|[1-9][0-9]*)$/' \
		'@1/^(0|[1-9][0-9]*)$/' \
		'?!-c;?-n' \
		"$@"
	then
		Misc_PrintF -v 1 -t 'f' -nn -f $'[Misc_Escape] Invalid options (code %s, index %s ~ \'%s\'): \'%s\'' -- \
			"$_Options_ResultCode" "$_Options_FailIndex" "$_Options_ErrorMessage" "$( Misc_ArrayJoin -- "$@" )";

		return 200;
	fi

	declare columnCount="${args[0]}";
	declare columnNoName="${args[1]}";
	declare items=( "${args[@]:2}" );

	if [[ "$columnNoName" == '' ]];
	then
		declare columnNoName='No';
	fi

	########
	# Main #
	########

	gapLength=2; # Gaps between brackets. For example: [ value ] - 2 spaces.
	declare columns=( "${items[@]:0:$columnCount}" ); # Must not include column "No"
	declare values=( "${items[@]:$columnCount}" );

	# If too few items
	if (( ${#values[@]} % ${#columns[@]} > 0 ));
	then
		declare itemIndex;

		for (( itemIndex = 0; itemIndex < ${#values[@]} % ${#columns[@]}; itemIndex++ ));
		do
			values+=('');
		done
	fi

	# Maximum value lengths
	# Assuming Header length >= Gap
	# Header length: Value length + Gap >= Header length (since headers are static + pritnf format should adjust in case V+G is shorter)

	declare columnNoLengthMax="$(( ${#values[@]} / ${#columns[@]} ))";
	declare columnNoLengthMax="${#columnNoLengthMax}";
	declare columnsRowFormat="{{@clGray}}   %$((columnNoLengthMax + gapLength))s"; # Initial + column "No"
	declare valueLengthsMax=();
	declare columnIndex;

	# Each column
	for (( columnIndex = 0; columnIndex < ${#columns[@]}; columnIndex++ ));
	do
		declare valueIndexStart;
		valueLengthsMax[$columnIndex]=0;

		# Each value in the column
		for (( valueIndexStart = 0; valueIndexStart < ${#values[@]}; valueIndexStart += ${#columns[@]} ));
		do
			declare value="${values[$(( valueIndexStart + columnIndex ))]}";
			# declare value="${value//$'\n'}";
			(( valueLengthsMax[$columnIndex] < ${#value} )) && valueLengthsMax[$columnIndex]="${#value}";
		done

		columnsRowFormat+="     %-$((valueLengthsMax[$columnIndex] + gapLength))s";
	done

	Misc_PrintF -nmf "$columnsRowFormat" -- "$columnNoName" "${columns[@]}";

	# Column and value row lengths
	# Value length: Value length + Gap < Header length ? Header length : Value length + Gap
	# declare columnNoWidth="$( diff=$(( columnNoLengthMax - 5 )); printf '%s' "$(( 5 - ${diff/-*/0} ))"; )";

	declare columnNoWidth="$(( ${#columnNoName} - gapLength ))";
	(( columnNoLengthMax + gapLength > ${#columnNoName} )) && declare columnNoWidth="$columnNoLengthMax";
	declare rowIndex;

	# Each row
	for (( rowIndex = 0; rowIndex < $(( ${#values[@]} / ${#columns[@]} )); rowIndex++ ));
	do
		declare rowFormat="  ${clGray}[${clDefault} %${columnNoWidth}s ${clGray}]${clDefault}"; # Initial + column "No"
		declare columnIndex;

		# Each column
		for (( columnIndex = 0; columnIndex < ${#columns[@]}; columnIndex++ ));
		do
			declare value="${values[$(( rowIndex * ${#columns[@]} + columnIndex ))]}";
			# declare value="${value//$'\n'}";
			declare columnWidth="$(( ${#columns[columnIndex]} - gapLength ))";
			(( valueLengthsMax[$columnIndex] + gapLength > ${#columns[columnIndex]})) && declare columnWidth="${valueLengthsMax[$columnIndex]}";
			rowFormat+="${clGray} - [${clDefault} %-${columnWidth}s ${clGray}]${clDefault}";
		done

		Misc_PrintF -nmf "$rowFormat" -- "$(( rowIndex + 1 ))" "${values[@]:$((rowIndex * ${#columns[@]})):${#columns[@]}}";
	done
}

# Remove Control Sequence Introducer (CSI) ANSI escape codes
Misc_AnsiEscapeCodesRemove()
{
	# printf '%s' "$@" | sed -r 's/\x1B\[([0-9]{1,3}(;[0-9]{1,2})?)?[mGK]//g';
	# printf '%s' "$@" | sed 's/\x1B\[[0-9;]\{1,\}[A-Za-z]//g';
	# printf '%s' "$@" | sed 's/\x1b\[[0-9;]*m//g';
	# printf '%s' "$@" | sed 's/\x1b\[[0-9;]*[a-zA-Z]//g';
	# printf '%s' "$@" | perl -pe 's/\e\[[0-9;]*[a-zA-Z]//g';
	Misc_RegexReplace -gs '\e\[[0-9;]*[a-zA-Z]' -- "$@";
}

############################################################
# Methods (public)                                         #
############################################################

Misc_RegexTest()
{
	if (( "$#" < 2 ));
	then
		return 3;
	fi

	if ! Misc_RegexVerify "$1";
	then
		[[ "$verbose" != 0 ]] && Misc_PrintF -v 1 -t 'f' -nf $'Invalid search pattern was declared for regex search: \'%s\'' "$1";

		return 2;
	fi

	export patternSearchExported="$1";
	shift;
	declare noMatch=0;

	for value in "$@";
	do
		if ! IFS=' \t\n' printf '%s' "$value" | perl -ne '/$ENV{patternSearchExported}/ && $MATCH++; END{exit 1 unless $MATCH > 0}' &>> '/dev/null';
		then
			declare noMatch=1;

			break;
		fi
	done

	unset patternSearchExported;

	return "$noMatch";
}

Misc_RegexReplace()
{
	###########
	# Options #
	###########

	declare args;

	if ! Options args \
		'?!-s;?-r;-g' \
		"$@"
	then
		Misc_PrintF -v 1 -t 'f' -nn -f $'[Misc_Escape] Invalid options (code %s, index %s ~ \'%s\'): \'%s\'' -- \
			"$_Options_ResultCode" "$_Options_FailIndex" "$_Options_ErrorMessage" "$( Misc_ArrayJoin -- "$@" )";

		return 200;
	fi

	declare patternSearch="${args[0]}";
	declare patternReplace="${args[1]}";
	declare searchGlobal="${args[2]}";
	declare data=( "${args[@]:3}" );

	########
	# Main #
	########

	if ! Misc_RegexVerify "$patternSearch";
	then
		[[ "$verbose" != 0 ]] && Misc_PrintF -v 1 -t 'f' -nf $'Invalid search pattern was declared for regex replace: \'%s\'' "$1";

		return 2;
	fi

	if [[ "$patternReplace" != '' ]] && ! Misc_RegexVerify "$patternReplace";
	then
		[[ "$verbose" != 0 ]] && Misc_PrintF -v 1 -t 'f' -nf $'Invalid replace pattern was declared for regex replace: \'%s\'' "$1";

		return 2;
	fi

	export patternSearchExported="$patternSearch";
	export patternReplaceExported="$patternReplace";
	declare noMatch=0;
	# ${searchGlobal/[^0]/g}

	for value in "${data[@]}";
	do
		if
			! IFS=' \t\n' printf '%s' "$value" | perl -pe \
				's/$ENV{patternSearchExported}/$ENV{patternReplaceExported}/'"$( [[ "$searchGlobal" != 0 ]] && printf 'g'; )"' && $MATCH++; END{exit 1 unless $MATCH > 0}';
		then
			declare noMatch=1;
		fi
	done

	unset patternSearchExported;
	unset patternReplaceExported;

	return "$noMatch";
}

# Description: The [string] data regex
# 
# Options:
#	-p (parameter) - Search RegEx pattern
#	-o (parameter) - Output variable reference
#	-r (parameter) - Replace RegEx pattern (rewrite files)
#	-R (multi-flag) - Remove empty lines from the file: 1 flag = only if left by replacement; 2 flags = remove every empty lines; 3 - every empty line including spaces.
#	-v (flag) - Verbose
#	 * - Data
#
# Returns:
#	0 ~ Found any match or replaced any data
#	1 ~ No match found or no data replaced
#	2 ~ Invalid search RegEx pattern
#	3 ~ Invalid replace RegEx pattern
#	4 ~ Empty search RegEx pattern
#	100 ~ Output variable reference interference
#	101 ~ No data declared
#	200 ~ Invalid options
#
# Outputs:
#	1. Output variable reference
#		1.1. If only search for matches, then 5 arrays: {ref} (matches), {ref}Indexes, {ref}Lines, {ref}Positions, {ref}Offsets
#		1.2. If replace matches, then 8 arrays:
#			{ref} (processed),
#			{ref}Replaced, 
#			{ref}Indexes, {ref}Lines, {ref}Positions, {ref}Offsets, {ref}SourcePositions, {ref}SourceOffsets
#
Misc_Regex()
{
	declare args;
	declare argsCount;

	if ! Options args '!1' \
		'@3/^(?:[0-9]+)?(?:,)?(?:[0-9]+)?$/' \
		'@4/^[0-1]$/' \
		'@5/^[0-4]$/' \
		'@6/^[0-1]$/' \
		'?!-p;?-o;?-r;?-c;-s;-R;-v' \
		"$@";
	then
		Misc_PrintF -v 1 -t 'f' -nf $'[Misc_Regex] Invalid options (code %s, index %s ~ \'%s\'): \'%s\'' -- \
			"$_Options_ResultCode" \
			"$_Options_FailIndex" \
			"$_Options_ErrorMessage" \
			"$( Misc_ArrayJoin -- "$@" )";

		return 200;
	fi

	declare patternSearch="${args[0]}";
	declare outputVariableReferenceName="${args[1]}";
	unset patternReplace;
	[ "${argsCount[2]}" != 0 ] && declare patternReplace="${args[2]}";
	declare matchCountMinMax="${args[3]}";
	declare streamsOutput="${args[4]}";
	declare removeEmptyLines="${args[5]}";
	declare verbose="${args[6]}";
	declare data=( "${args[@]:7}" );

	if [ "$outputVariableReferenceName" != '' ];
	then
		# If the output reference matches the important variables.
		# Both the reference and temp must mismatch or else the first would cause a reference loop and the second (temp) would return an empty result
		if 
			[ "$outputVariableReferenceName" = 'Misc_Regex_outputVariableReference' ] ||
			[ "$outputVariableReferenceName" = 'Misc_Regex_outputVariableReferenceIndexes' ] ||
			[ "$outputVariableReferenceName" = 'Misc_Regex_outputVariableReferenceLines' ] ||
			[ "$outputVariableReferenceName" = 'Misc_Regex_outputVariableReferenceOffsets' ]
		then
			Misc_PrintF -v 1 -t 'f' -nf $'[Misc_Regex] Output variable reference interference: \'%s\'' -- \
				"$( Misc_ArrayJoin -- "$@" )";

			return 100;
		fi

		# Declare and set/clear referenced variables

		declare -n Misc_Regex_outputVariableReference="$outputVariableReferenceName";
		declare -n Misc_Regex_outputVariableReferenceIndexes="${outputVariableReferenceName}Indexes";
		declare -n Misc_Regex_outputVariableReferenceLines="${outputVariableReferenceName}Lines";
		declare -n Misc_Regex_outputVariableReferenceOffsets="${outputVariableReferenceName}Offsets";
		Misc_Regex_outputVariableReference=();
		Misc_Regex_outputVariableReferenceIndexes=();
		Misc_Regex_outputVariableReferenceLines=();
		Misc_Regex_outputVariableReferenceOffsets=();
	fi

	declare matchCountMin='';
	declare matchCountMax='';

	if [ "$matchCountMinMax" != '' ];
	then
		if [[ "$matchCountMinMax" =~ ^[0-9]+,[0-9]+$ ]]; # If "min,max" - min and max
		then
			matchCountMin="${matchCountMinMax%,*}";
			matchCountMax="${matchCountMinMax#*,}";
		elif [[ "$matchCountMinMax" =~ ^[0-9]+,$ ]]; # If "min," - only min
		then
			matchCountMin="${matchCountMinMax%,*}";
		elif [[ "$matchCountMinMax" =~ ^,[0-9]+$ ]]; # If ",max" - only max
		then
			matchCountMax="${matchCountMinMax#*,}";
		elif [[ "$matchCountMinMax" =~ ^[0-9]+$ ]]; # If just a number - min=max
		then
			matchCountMin="${matchCountMinMax%,*}";
			matchCountMax="$matchCountMin";
		fi
	fi

	########
	# Main #
	########

	# If no search regex pattern is provided
	if [ "${#patternSearch}" = 0 ];
	then
		if [ "$verbose" != 0 ];
		then
			Misc_PrintF -v 1 -t 'f' -nf $'Empty search pattern declared for regex %s\n\n' \
				"$( if [ "${patternReplace+s}" != '' ] && printf 'replace' || printf 'search' )";
		fi

		return 4;
	fi

	# If no data is declared
	if [ "${#data[@]}" = 0 ];
	then
		if [ "$verbose" != 0 ];
		then
			Misc_PrintF -v 1 -t 'f' -nf $'No data declared for regex %s\n' \
				"$(
					if [ "${patternReplace+s}" != '' ];
					then
						printf $'replace: \'%s\' -> \'%s\'' "$patternSearch" "$patternReplace";
					else
						printf $'search: \'%s\'' "$patternSearch";
					fi
				)";
		fi

		return 101;
	fi

	if ! Misc_RegexVerify "$patternSearch";
	then
		if [ "$verbose" != 0 ];
		then
			Misc_PrintF -v 1 -t 'f' -nf $'Invalid search pattern was declared for regex %s: \'%s\'\n\n' \
				"$( [ "${patternReplace+s}" != '' ] && printf 'replace' || printf 'search' )" \
				"$patternSearch";
		fi

		return 2;
	fi

	# If a replace pattern is declared (even empty)
	if [ "${patternReplace+s}" != '' ];
	then
		######################
		# Search and replace #
		######################

		# If output reference variable is declared (requested to store results in referenced variables)
		if [ "$outputVariableReferenceName" != '' ];
		then
			if
				[ "$outputVariableReferenceName" = 'Misc_Regex_outputVariableReferenceSkips' ] ||
				[ "$outputVariableReferenceName" = 'Misc_Regex_outputVariableReferenceSourceStarts' ] ||
				[ "$outputVariableReferenceName" = 'Misc_Regex_outputVariableReferenceSourceEnds' ] ||
				[ "$outputVariableReferenceName" = 'Misc_Regex_outputVariableReferenceStarts' ] ||
				[ "$outputVariableReferenceName" = 'Misc_Regex_outputVariableReferenceEnds' ] ||
				[ "$outputVariableReferenceName" = 'Misc_Regex_outputVariableReferenceDifferences' ] ||
				[ "$outputVariableReferenceName" = 'Misc_Regex_outputVariableReferenceMatches' ]
			then
				Misc_PrintF -v 1 -t 'f' -nf $'[Misc_Regex] Output variable reference interference: \'%s\'' -- \
					"$( Misc_ArrayJoin -- "$@" )";

				return 100;
			fi

			# Declare and set/clear referenced variables

			declare -n Misc_Regex_outputVariableReferenceSkips="${outputVariableReferenceName}Skips";
			declare -n Misc_Regex_outputVariableReferenceSourceStarts="${outputVariableReferenceName}SourceStarts";
			declare -n Misc_Regex_outputVariableReferenceSourceEnds="${outputVariableReferenceName}SourceEnds";
			declare -n Misc_Regex_outputVariableReferenceStarts="${outputVariableReferenceName}Starts";
			declare -n Misc_Regex_outputVariableReferenceEnds="${outputVariableReferenceName}Ends";
			declare -n Misc_Regex_outputVariableReferenceDifferences="${outputVariableReferenceName}Differences";
			declare -n Misc_Regex_outputVariableReferenceMatches="${outputVariableReferenceName}Matches";
			Misc_Regex_outputVariableReferenceSkips=();
			Misc_Regex_outputVariableReferenceSourceStarts=();
			Misc_Regex_outputVariableReferenceSourceEnds=();
			Misc_Regex_outputVariableReferenceStarts=();
			Misc_Regex_outputVariableReferenceEnds=();
			Misc_Regex_outputVariableReferenceDifferences=();
			Misc_Regex_outputVariableReferenceMatches=();
		fi

		export patternSearchExported="$patternSearch";
		export patternReplaceExported="$patternReplace";
		export removeEmptyLinesExported="$removeEmptyLines";
		declare replaceOffsets=();
		declare replaceSkips=();
		declare replaces=();
		declare replaceMetas=();
		declare dataIndex;

		for (( dataIndex = 0; dataIndex < ${#data[@]}; dataIndex++ ));
		do
			declare dataElement="${data[$dataIndex]}";

			if [ "$dataElement" = '' ];
			then
				if [ "$verbose" != 0 ];
				then
					Misc_PrintF -v 3 -t 'w' -nf $'Empty data declared for regex replace at %s argument' -- "$dataIndex";
				fi

				continue;
			fi

			declare replaceRaw;
			declare replaceIndex=0;

			# Process the regex operation and loop through every replace
			while IFS= read -r replaceRaw; # L:Ss:Se:Rs:Re:D:{match}
			do
				# If it's a line byte offset
				if [ "${replaceRaw:0:1}" = '#' ];
				then
					declare replaceOffsets+=( "${replaceRaw:1}" );

					continue;
				fi

				# If it's a line byte offset
				if [ "${replaceRaw:0:1}" = '!' ];
				then
					declare replaceSkips+=( "${replaceRaw:1}" );

					continue;
				fi

				# If it's a replaced element
				if [ "${replaceRaw:0:1}" = '@' ];
				then
					declare replaces+=( "${replaceRaw:1}" );

					continue;
				fi

				# Add the match to the array
				replaceMetas+=( "${dataIndex}:${replaceRaw}" );

				if (( verbose > 1 )) && Misc_Verbosity 5;
				then
					declare replaceMeta=""; # For: L:Ss:Se:Rs:Re:D:{match} ~> L:Ss:Se:Rs:Re:D
					declare replaceMatch="$replaceRaw"; # For: L:Ss:Se:Rs:Re:D:{match} ~> {match}

					for (( i = 0; i < 6; i++ ));
					do
						declare replaceMeta="${replaceMeta}${replaceMatch%%\:*},";
						declare replaceMatch="${replaceMatch#*\:}";
					done

					declare replaceLine="${replaceMeta%%\:*}"; # L:Ss:Se:Rs:Re:D ~> L
					declare replaceOffset=0;

					if [ "${replaceOffsets[$replaceLine]+s}" != '' ];
					then
						declare replaceOffset="${replaceOffsets[$replaceLine]+s}";
					fi

					Misc_PrintF -v 5 -t 'd' -f $'Replaced %s match at [%s;%s] in %s/%s element using regex \'%s\' -> \'%s\': \'%s\'%s\n' -- \
						"$(( replaceIndex + 1 ))" \
						"$replaceMeta" \
						"$replaceOffset" \
						"$(( dataIndex + 1 ))" \
						"${#data[@]}" \
						"$patternSearch" \
						"$patternReplace" \
						"${replaceMatch:0:20}" \
						"$( (( "${#replaceMatch}" > 20 )) && printf '...' )";
				fi

				declare replaceIndex=$(( replaceIndex + 1 ));
			done \
			< <(
				# i.e. L:Ss:Se:Rs:Re:D:{match}; #offset; !skipped; @processed; or:
				# 0:1:2:3:4:5:6 -
				#     0 - Line number
				#     1 - Source match start position (relative to processed)
				#     2 - Source match end position (relative to processed)
				#     3 - Replace start position (relative to processed)
				#     4 - Replace end position (relative to processed)
				#     5 - Replace length difference
				#     6 - Match
				# # - Line byte offeset
				# ! - Skipped line
				# @ - Processed line
				printf '%s' "$dataElement" | perl -ne $'
					sub submatches { # From package "Data::Munge" (v0.097; line 122)
						no strict \'refs\';
						map $$_, 1 .. $#+
					}

					sub replace { # From package "Data::Munge" (v0.097; line 96)
						my ($str, $re, $x, $g) = @_;
						my $f = ref $x ? $x : sub {
							my $r = $x;
							$r =~ s{\$([\$&`\'0-9]|\{([0-9]+)\})}{
								$+ eq \'$\' ? \'$\' :
								$+ eq \'&\' ? $_[0] :
								$+ eq \'`\' ? substr($_[-1], 0, $_[-2]) :
								$+ eq "\'" ? substr($_[-1], $_[-2] + length $_[0]) :
								$_[$+]
							}eg;
							$r
						};
						if ($g) {
							$str =~ s{$re}{ $f->(substr($str, $-[0], $+[0] - $-[0]), submatches(), $-[0], $str) }eg;
						} else {
							$str =~ s{$re}{ $f->(substr($str, $-[0], $+[0] - $-[0]), submatches(), $-[0], $str) }e;
						}
						$str
					}

					# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

					$processed = $_; # Get the source line
					$processed =~ s/\n+$//; # Remove last trailing new line characters # or is "perl -nle" better?
					$result = "";
					$matchEndPrevious = 0;
					$replacedDiffPrevious = 0;

					# While any match exists
					while ($processed =~ /$ENV{patternSearchExported}/ && length $processed)
					{
						$match = substr($processed, $-[0], $+[0] - $-[0]);
						$replaced = replace($processed, $ENV{patternSearchExported}, $ENV{patternReplaceExported}); # Replace the match
						$replacedDiff = ((length $replaced) - (length $processed)); # Get the length difference between the source and replaced
						$result = $result . substr($replaced, 0, $+[0] + $replacedDiff); # Append data from source start to replace end
						$processed = substr($processed, $+[0]); # Remove data from the start to the match end (so to not match the same in the loop)

						print (
							join (
								":",
								$., # Line number (0)
								($matchEndPrevious + $-[0]), # Source match start position (1) (relative to processed)
								($matchEndPrevious + $+[0]), # Source match end position (2) (relative to processed)
								($matchEndPrevious + $-[0] + $replacedDiffPrevious), # Replace start position (3) (relative to processed)
								($matchEndPrevious + $+[0] + $replacedDiffPrevious + $replacedDiff), # Replace end position (4) (relative to processed)
								$replacedDiff, # Replace length difference (5)
								$match # Match (6)
							) . "\n"
						);

						$matchEndPrevious += $+[0]; # Preserve the match end position
						$replacedDiffPrevious += $replacedDiff; # Preserve the replace difference
					}

					print "#" . tell . "\n"; # Print the line byte offset
					$result = $result . $processed; # Append the source leftover

					# If whitespace:
					#     "1" - If source is not empty but result;
					#     "2" - If source is not empty but result is empty or contains only space characters;
					#     "3" - If result is empty;
					#     "4" - If result is empty or contains only space characters.
					if (
						$ENV{removeEmptyLinesExported} == 1 && length $_ && $result =~ /^$/ ||
						$ENV{removeEmptyLinesExported} == 2 && length $_ && $result =~ /^\s*$/ ||
						$ENV{removeEmptyLinesExported} == 3 && $result =~ /^$/ ||
						$ENV{removeEmptyLinesExported} == 4 && $result =~ /^\s*$/
					)
					{
						print "\!" . $. . "\n"; # Print the skipped line number

						next; # Skip the line
					}

					print "\@" . $result . "\n"; # Print the processed line (either replaced or not)
					';
			);

			if [ "$verbose" != 0 ];
			then
				Misc_PrintF -v 4 -t 's' -f $'Replaced %s matches in total using regex pattern (\'%s\' -> \'%s\') in %s/%s element\n' -- \
					"${#replaceMetas[@]}" \
					"$patternSearch" \
					"$patternReplace" \
					"$(( dataIndex + 1 ))" \
					"${#data[@]}";
			fi
		done

		unset patternSearchExported;
		unset patternReplaceExported;
		unset removeEmptyLinesExported;

		# If no limit is declared and did not find any match
		if [ "$matchCountMin" = '' ] && [ "$matchCountMax" = '' ] && [ "${#replaceMetas[@]}" = 0 ];
		then
			return 1;
		fi

		# If too few replaces
		if [ "$matchCountMin" != '' ] && (( ${#replaceMetas[@]} < matchCountMin ));
		then
			if [ "$verbose" != 0 ];
			then
				Misc_PrintF -v 2 -t 'e' -f $'Too few (minimum %s) replaces: %s\n' -- \
					"$matchCountMin" \
					"${#replaceMetas[@]}";
			fi

			return 2;
		fi

		# If too many replaces
		if [ "$matchCountMax" != '' ] && (( ${#replaces[@]} > matchCountMax ));
		then
			if [ "$verbose" != 0 ];
			then
				Misc_PrintF -v 2 -t 'e' -f $'Too many (maximum %s) replaces: %s\n' -- \
					"$matchCountMax" \
					"${#replaceMetas[@]}";
			fi

			return 3;
		fi

		if [ "$streamsOutput" = 1 ];
		then
			# If a single replace (no new line)
			if [ "${#replaces[@]}" = 1 ];
			then
				printf '%s' "${replaces[0]}";

				return 0;
			fi

			# If more than one replace (each line)

			declare replace;

			for replace in "${replaces[@]}";
			do
				printf $'%s\n' "$replace";
			done

			return 0;
		fi

		# If no output reference variable is declared
		if [ "$outputVariableReferenceName" = '' ];
		then
			return 0;
		fi

		# Requested to store results in a referenced variable

		Misc_Regex_outputVariableReference=( "${replaces[@]}" );
		Misc_Regex_outputVariableReferenceOffsets=( "${replaceOffsets[@]}" );
		Misc_Regex_outputVariableReferenceSkips=( "${replaceSkips[@]}" );
		declare metaIndex;

		# Loop through every replace meta
		for (( metaIndex = 0; metaIndex < ${#replaceMetas[@]}; metaIndex++ ));
		do
			declare metaTemp="${replaceMetas[$metaIndex]}"; # I:L:Ss:Se:Rs:Re:D:{match}

			Misc_Regex_outputVariableReferenceIndexes+=( "${metaTemp%%\:*}" ); # I:L:Ss:Se:Rs:Re:D:{match} ~> I

			declare metaTemp="${metaTemp#*\:}"; # I:L:Ss:Se:Rs:Re:D:{match} ~> L:Ss:Se:Rs:Re:D:{match}
			Misc_Regex_outputVariableReferenceLines+=( "${metaTemp%%\:*}" ); # L:Ss:Se:Rs:Re:D:{match} ~> L

			declare metaTemp="${metaTemp#*\:}"; # L:Ss:Se:Rs:Re:D:{match} ~> Ss:Se:Rs:Re:D:{match}
			Misc_Regex_outputVariableReferenceSourceStarts+=( "${metaTemp%%\:*}" ); # Ss:Se:Rs:Re:D:{match} ~> Ss

			declare metaTemp="${metaTemp#*\:}"; # Ss:Se:Rs:Re:D:{match} ~> Se:Rs:Re:D:{match}
			Misc_Regex_outputVariableReferenceSourceEnds+=( "${metaTemp%%\:*}" ); # Se:Rs:Re:D:{match} ~> Se

			declare metaTemp="${metaTemp#*\:}"; # Se:Rs:Re:D:{match} ~> Rs:Re:D:{match}
			Misc_Regex_outputVariableReferenceStarts+=( "${metaTemp%%\:*}" ); # Rs:Re:D:{match} ~> Rs

			declare metaTemp="${metaTemp#*\:}"; # Rs:Re:D:{match} ~> Re:D:{match}
			Misc_Regex_outputVariableReferenceEnds+=( "${metaTemp%%\:*}" ); # Re:D:{match} ~> Re

			declare metaTemp="${metaTemp#*\:}"; # Re:D:{match} ~> D:{match}
			Misc_Regex_outputVariableReferenceDifferences+=( "${metaTemp%%\:*}" ); # D:{match} ~> D

			Misc_Regex_outputVariableReferenceMatches+=( "${metaTemp#*\:}" ); # D:{match} ~> {match}
		done

		return 0;
	fi

	##########
	# Search #
	##########

	# If output reference variable is declared (requested to store results in referenced variables)
	if [ "$outputVariableReferenceName" != '' ];
	then
		if
			[ "$outputVariableReferenceName" = 'Misc_Regex_outputVariableReferencePositions' ]
		then
			Misc_PrintF -v 1 -t 'f' -nf $'[Misc_Regex] Output variable reference interference: \'%s\'' -- \
				"$( Misc_ArrayJoin -- "$@" )";

			return 100;
		fi

		declare -n Misc_Regex_outputVariableReferencePositions="${outputVariableReferenceName}Positions";
		Misc_Regex_outputVariableReferencePositions=();
	fi

	export patternSearchExported="$patternSearch";
	declare matches=();
	declare dataIndex;

	for (( dataIndex = 0; dataIndex < ${#data[@]}; dataIndex++ ));
	do
		declare dataElement="${data[$dataIndex]}";

		if [ "$dataElement" = '' ];
		then
			if [ "$verbose" != 0 ];
			then
				Misc_PrintF -v 3 -t 'w' -nf $'Empty data declared for regex search at %s argument' -- "$dataIndex";
			fi

			continue;
		fi

		declare matchRaw;
		declare matchIndex=0;

		# Process the regex opertaion and loop through every found match
		while IFS= read -r matchRaw # i.e. L:P:O:{match}
		do
			# Add the match to the array
			matches+=( "${dataIndex}:${matchRaw}" );

			if [ "$verbose" != 0 ] && Misc_Verbosity 5;
			then
				declare matchLine="${matchRaw%%\:*}"; # L:P:O:{match} ~> L

				declare match="${matchRaw#*\:}"; # L:P:O:{match} ~> P:O:{match}
				declare matchPosition="${match%%\:*}"; # P:O:{match} ~> P

				declare match="${match#*\:}"; # P:O:{match} ~> O:{match}
				declare matchOffset="${match%%\:*}"; # O:{match} ~> O

				declare match="${match#*\:}"; # O:{match} ~> {match}

				Misc_PrintF -v 5 -t 'd' -f $'Found %s match at [%4s,%4s,%4s] in %s/%s element using regex pattern(\'%s\'): \'%s\'%s\n' -- \
					"$(( matchIndex + 1 ))" \
					"$matchLine" \
					"$matchPosition" \
					"$matchOffset" \
					"$(( dataIndex + 1 ))" \
					"${#data[@]}" \
					"$patternSearch" \
					"${match:0:20}" \
					"$( (( "${#match}" > 20 )) && printf '...' )";
			fi

			declare matchIndex=$(( matchIndex + 1 ));
		done \
		< <( # i.e. L:P:O:{match}
			# | perl -ne 'if (!/$ENV{patternSearchExported}/g) { exit 1; }; print $1; exit 0;
			printf '%s' "$dataElement" | perl -nle \
				$'
					$line=$_;
					$o;

					while (/$ENV{patternSearchExported}/g)
					{
						print join ":", $., $-[0], $o + $-[0], $&;
					}

					$o = tell;
				' \
				2> '/dev/null';
		);

		# declare matchLineCount="${#matches[@]}";

		if [ "$verbose" != 0 ];
		then
			Misc_PrintF -v 4 -t 's' -f $'Found %s match(es) in total using regex pattern (\'%s\') in %s/%s element\n' -- \
				"${#matches[@]}" \
				"$patternSearch" \
				"$(( dataIndex + 1 ))" \
				"${#data[@]}";
		fi
	done

	unset patternSearchExported;

	# If no limit is declared and did not find any match
	if [ "$matchCountMin" = '' ] && [ "$matchCountMax" = '' ] && [ "${#matches[@]}" = 0 ];
	then
		if [ "$verbose" != 0 ];
		then
			Misc_PrintF -v 2 -t 'e' -f $'No match found\n';
		fi

		return 1;
	fi

	# If too few matches
	if [ "$matchCountMin" != '' ] && (( ${#matches[@]} < matchCountMin ));
	then
		if [ "$verbose" != 0 ];
		then
			Misc_PrintF -v 2 -t 'e' -f $'Too few (minimum %s) matches found: %s\n' -- \
				"$matchCountMin" \
				"${#matches[@]}";
		fi

		return 2;
	fi

	# If too many matches
	if [ "$matchCountMax" != '' ] && (( ${#matches[@]} > matchCountMax ));
	then
		if [ "$verbose" != 0 ];
		then
			Misc_PrintF -v 2 -t 'e' -f $'Too many (maximum %s) matches found: %s\n' -- \
				"$matchCountMax" \
				"${#matches[@]}";
		fi

		return 3;
	fi

	# If requested to output to stdout
	if [ "$streamsOutput" = 1 ];
	then
		if [ ${#matches[@]} = 1 ];
		then
			declare match="${matches[0]}"; # I:L:P:O:{match}
			declare match="${match#*\:}"; # I:L:P:O:{match} ~> L:P:O:{match}
			declare match="${match#*\:}"; # L:P:O:{match} ~> P:O:{match}
			declare match="${match#*\:}"; # P:O:{match} ~> O:{match}
			declare match="${match#*\:}"; # O:{match} ~> {match}

			printf '%s' "$match";
		else
			declare match;

			for match in "${matches[@]}";
			do
				declare match="${match#*\:}"; # I:L:P:O:{match} ~> L:P:O:{match}
				declare match="${match#*\:}"; # L:P:O:{match} ~> P:O:{match}
				declare match="${match#*\:}"; # P:O:{match} ~> O:{match}
				declare match="${match#*\:}"; # O:{match} ~> {match}

				printf $'%s\n' "$match";
			done
		fi
	fi

	# If no output reference variable is declared
	if [ "$outputVariableReferenceName" = '' ];
	then
		return 0;
	fi

	# Requested to store results in a referenced variable

	declare matchIndex;

	# Loop through every match
	for (( matchIndex = 0; matchIndex < ${#matches[@]}; matchIndex++ ));
	do
		declare matchRaw="${matches[$matchIndex]}"; # I:L:P:O:{match}

		declare matchElementIndex="${matchRaw%%\:*}"; # I:L:P:O:{match} ~> I

		declare match="${matchRaw#*\:}"; # I:L:P:O:{match} ~> L:P:O:{match}
		declare matchLine="${match%%\:*}"; # L:P:O:{match} ~> L

		declare match="${match#*\:}"; # L:P:O:{match} ~> P:O:{match}
		declare matchPosition="${match%%\:*}"; # P:O:{match} ~> P

		declare match="${match#*\:}"; # P:O:{match} ~> O:{match}
		declare matchOffset="${match%%\:*}"; # O:{match} ~> O

		declare match="${match#*\:}"; # O:{match} ~> {match}

		# Add the match data to the result arrays
		Misc_Regex_outputVariableReference+=( "$match" );
		Misc_Regex_outputVariableReferenceIndexes+=( "$matchElementIndex" );
		Misc_Regex_outputVariableReferenceLines+=( "$matchLine" );
		Misc_Regex_outputVariableReferencePositions+=( "$matchPosition" );
		Misc_Regex_outputVariableReferenceOffsets+=( "$matchOffset" );
	done

	return 0;
}

# Description: The general output function
# 
# Options:
# 	-v (parameter) - Verbosity level (0-5)
# 	-t (parameter) - Text type (n, m, q, i, s, w, e, f, d)
# 	-f (parameter) - Text format
# 	-d (parameter) - Descriptor (0-2)
# 	-p (parameter) - Text padding (top[, left] or ,left)
# 	-r (parameter) - Repeat count
# 	-o (parameter) - Output variable reference
# 	-n (multi-flag) - New line
# 	-m (flag) - Enable text meta
# 	 * - Text
#
# Returns:
# 	0 ~ Successful output
# 	1 ~ Too low verbosity level
# 	100 ~ Output variable reference interference
#	200 ~ Invalid options
#
# Outputs:
#	1. Prints: A pre-formatted and colored text
#	2. Output reference variable: A pre-formatted and colored text
#
Misc_PrintF()
{
	###########
	# Options #
	###########

	declare args;

	# '@3/^(?:[0-9a-fA-F]{3}|[0-9a-fA-F]{6})$/' \

	if ! Options args \
		'@0/^[0-2]$/' \
		'@1/^-?[0-5]$/' \
		'@2/^[nmqiswefd]$/' \
		'@4/^[0-9]*\,?[0-9]+$/' \
		'@5/^-?[0-9]+$/' \
		'@9/^[0-1]$/' \
		'?-d;?-v;?-t;?-f;?-p;?-r;?-s;?-o;-n;-m;-M;-T;-c' \
		"$@"
	then
		printf $'[Misc_PrintF] Invalid options (code %s, index %s ~ \'%s\'): \'%s\'\n' \
			"$_Options_ResultCode" "$_Options_FailIndex" "$_Options_ErrorMessage" "$( Misc_ArrayJoin -- "$@" )";

		return 200;
	fi

	declare descriptor="${args[0]}";
	declare verbosityLevel="${args[1]}";
	declare textType="${args[2]}";
	declare textFormat="${args[3]}";
	declare textPadding="${args[4]}";
	declare repeatCount="${args[5]}";
	declare subshellLevelMax="${args[6]}";
	declare outputVariableReferenceName="${args[7]}";
	declare newLine="${args[8]}";
	declare textMeta="${args[9]}";
	declare textMetaEnd="${args[10]}";
	declare textTimestamp="${args[11]}";
	declare clearBefore="${args[12]}";
	declare text=( "${args[@]:13}" );

	if [[ "$outputVariableReferenceName" != '' ]];
	then
		if [[
			"$outputVariableReferenceName" == 'Misc_PrintF_outputVariableReference' ||
			"$outputVariableReferenceName" == 'Misc_PrintF_outputVariableReferenceFormatMetas'
		]];
		then
			Misc_PrintF -v 1 -t 'f' -nn -f $'[Misc_PrintF] Output variable reference interference: \'%s\'' -- \
				"$( Misc_ArrayJoin -- "$@" )";

			return 100;
		fi

		declare -n Misc_PrintF_outputVariableReference="$outputVariableReferenceName";
		declare -n Misc_PrintF_outputVariableReferenceFormatMetas="${outputVariableReferenceName}FormatMetas";
		Misc_PrintF_outputVariableReference='';
		Misc_PrintF_outputVariableReferenceFormatMetas=();
	fi

	if [[ "$verbosityLevel" == '' ]];
	then
		declare verbosityLevel="$Misc_VerbosityLevel";
	fi

	if [[ "$subshellLevelMax" == '' ]];
	then
		declare subshellLevelMax="$Misc_PrintF_SubshellLevelMaxDefault";
	fi

	########
	# Main #
	########

	# If the current subshell level is higher than permitted or the verbosity level of the text is greater than the configured one
	if (( subshellLevelMax >= 0 && "$BASH_SUBSHELL" > "$subshellLevelMax" || verbosityLevel >= 0 && verbosityLevel > Misc_VerbosityLevel ));
	then
		printf "<<<<< [%s/%s; %s/%s, %s%s] ${textFormat}"$'\n' "$BASH_SUBSHELL" "$subshellLevelMax" "$verbosityLevel" "$Misc_VerbosityLevel" "$textType" \
			"$( [[ "$textMeta" != 0 ]] && printf '; M'; (( repeatCount > 1 )) && printf '; R%s' "$repeatCount" )" "${text[@]}" &>> "$_Main_Dump";

		return 0;
	fi

	printf ">>>>> [%s/%s; %s/%s, %s%s] ${textFormat}"$'\n' "$BASH_SUBSHELL" "$subshellLevelMax" "$verbosityLevel" "$Misc_VerbosityLevel" "$textType" \
		"$( [[ "$textMeta" != 0 ]] && printf '; M'; (( repeatCount > 1 )) && printf '; R%s' "$repeatCount" )" "${text[@]}" &>> "$_Main_Dump";

	# The default text prefix
	declare textPrefix='';

	if [[ "$textType" != '' ]];
	then
		if [[ "$textTimestamp" != 0 || "$Misc_VerbosityTimestamp" != 0 ]];
		then
			declare textPrefix+=" ${clGray}[ $( Misc_DateTime -t 5; ) ]${clDefault} ";
		else
			declare textPrefix=' ';
		fi

		# Set the text prefix according the text type
		# declare textPrefix=" ${clGray}[${clDefault} ${textTypeColors["$textType"]}${textTypeSigns["$textType"]} ${clGray}]${clDefault} ";
		case "$textType" in
			'n') declare textPrefix+="${clGray}[${clDefault}   ${clGray}]${clDefault} ";; # [   ]
			'm') declare textPrefix+="${clGray}[${clDefault} ${clLightPurple}#${clDefault} ${clGray}]${clDefault} ";; # [ # ]
			'q') declare textPrefix+="${clGray}[${clDefault} ${clCyan}?${clDefault} ${clGray}]${clDefault} ";; # [ ? ]
			'i') declare textPrefix+="${clGray}[${clDefault} ${clGray}*${clDefault} ${clGray}]${clDefault} ";; # [ * ]
			's') declare textPrefix+="${clGray}[${clDefault} ${clLightGreen}+${clDefault} ${clGray}]${clDefault} ";; # [ + ]
			'w') declare textPrefix+="${clGray}[${clDefault} ${clYellow}!${clDefault} ${clGray}]${clDefault} ";; # [ ! ]
			'e') declare textPrefix+="${clGray}[${clDefault} ${clLightRed}-${clDefault} ${clGray}]${clDefault} ";; # [ - ]
			'f') declare textPrefix+="${clGray}[${clDefault} ${clRed}x${clDefault} ${clGray}]${clDefault} ";; # [ x ]
			'd') declare textPrefix+="${clGray}[${clDefault} ${clBlue}D${clDefault} ${clGray}]${clDefault} ";; # [ D ]
		esac

		if [[ "$subshellLevelMax" != "$Misc_PrintF_SubshellLevelMaxDefault" ]];
		then
			declare textPrefix+="${clGray}[${clDefault} $( printf '%s/%s' "$BASH_SUBSHELL" "$subshellLevelMax"; ) ${clGray}]${clDefault} ";
		fi
	fi

	# If a custom output stream was declared
	if [[ "$descriptor" != '' && "${Misc_PrintF_OutputStreamsDefault[$descriptor]}" != '' ]];
	then
		declare outputStream="${Misc_PrintF_OutputStreamsDefault[$descriptor]}";
	else
		# If the text type is related to an error or fatal
		if [[ "$textType" == 'e' || "$textType" == 'f' ]];
		then
			declare outputStream="${Misc_PrintF_OutputStreamsDefault[$Misc_OutputStreamErrDefault]}";
		else
			declare outputStream="${Misc_PrintF_OutputStreamsDefault[$Misc_OutputStreamStdDefault]}";
		fi
	fi

	declare metaType=0;
	declare textFormatMetas=();
	declare textFormatMetasPositions=();

	# If text format was declared
	if [[ "$textFormat" != '' ]];
	then
		# If metas are enabled
		if [[ "$textMeta" != 0 ]];
		then
			Misc_Regex -o Misc_PrintF_textFormatMetas -p '(?:\{\{@[0-9a-zA-Z]+\}\}|\{\{\#[0-9a-fA-F]{6}\}\}|\{\{\#[0-9a-fA-F]{3}\}\})' -- "$textFormat";
			declare textFormatMetas=( "${Misc_PrintF_textFormatMetas[@]}" );
			declare textFormatMetasPositions=( "${Misc_PrintF_textFormatMetasPositions[@]}" );

			# If a meta was found
			if [[ "${#textFormatMetas[@]}" != 0 ]];
			then
				# declare textFormatTemp='';
				# Get the first plain part before the first meta, if exists
				# echo "textFormatMetas=${textFormatMetas[@]}" &>> "$_Main_Dump";
				declare textFormatTemp="${textFormat:0:${textFormatMetasPositions[0]}}";
				declare textFormatPlainLength=0;
				declare textFormatMetaIndex;

				# Loop through each found meta
				for (( textFormatMetaIndex = 0; textFormatMetaIndex < ${#textFormatMetas[@]}; textFormatMetaIndex++ ));
				do
					# Parse the meta

					# Get raw meta data from the format string and trim it
					declare textFormatMetaRaw="${textFormatMetas[$textFormatMetaIndex]}"; # {{meta}}
					declare textFormatMeta="${textFormatMetaRaw%\}\}}" # {{meta}} ~> {{meta
					declare textFormatMeta="${textFormatMeta#\{\{}" # {{meta ~> meta
					# echo "[${textFormatMetaIndex}]textFormatMeta=${textFormatMeta}" &>> "$_Main_Dump";

					# We might need another way to find the meta's type (i.e. with a group search above, returning
					# groups' positions(which mean the types of meta) instead of only match or not), else
					# it runs multiple times per the same data (the textFormat and each meta)

					# Set the constant if exists (@constant)
					declare textFormatConstantName="${textFormatMeta#\@}"; # @constant ~> constant

					# If the constant with such array associative index exists
					if [[ "${Misc_ColorsTheme[$textFormatConstantName]+s}" != '' ]];
					then
						declare textFormatMeta="${Misc_ColorsTheme[$textFormatConstantName]}";
					fi

					# If a meta is a color (#RRGGBB or #RGB)
					if Misc_Regex -p '\#[0-9a-zA-Z]{6}|\#[0-9a-zA-Z]{3}' -- "$textFormatMeta";
					then
						declare metaType=1;

						# A meta is a color

						declare textFormatCHex=${textFormatMeta#\#}; # #RRGGBB ~> RRGGBB or #RGB ~> RGB

						# If the colors is in RGB format
						if [[ "${#textFormatCHex}" == 3 ]];
						then
							textFormatCHex="${textFormatCHex:0:1}${textFormatCHex:0:1}${textFormatCHex:1:1}${textFormatCHex:1:1}${textFormatCHex:2:1}${textFormatCHex:2:1}"
						fi

						# i.e. 33FF11 ~> 51;255;17
						declare textFormatMetaDec="$( printf "%d;%d;%d" "0x${textFormatCHex:0:2}" "0x${textFormatCHex:2:2}" "0x${textFormatCHex:4:2}" )";

						declare textFormatMeta="\033[38;2;${textFormatMetaDec}m";
					else # Meta is a constant
						declare metaType=2;
					fi

					# Get the current color start char position
					declare textFormatMetaStart="${textFormatMetasPositions[textFormatMetaIndex]}";

					# If the next color exists
					if (( "$textFormatMetaIndex" + 1 < ${#textFormatMetas[@]} ));
					then
						# Get the next color start char position
						declare textFormatMetaStartNext="${textFormatMetasPositions[textFormatMetaIndex + 1]}";
					else
						# Set the next color position to the end of the format string
						declare textFormatMetaStartNext="${#textFormat}";
					fi

					# Parse the text

					# The start position of the plain text part (meta start + meta length)
					declare textFormatStart=$(( textFormatMetaStart + ${#textFormatMetaRaw} ));

					# The plain text part (from whole format: from "text start" to ("next meta start or end of the format" - text start))
					declare textFormatPlain="${textFormat:$textFormatStart:$(( textFormatMetaStartNext - textFormatStart ))}";

					# Add the current part's length to the parsed plain text length
					textFormatPlainLength=$((textFormatPlainLength + ${#textFormatPlain}));

					# Append the current part with the color to the parsed plain text
					textFormatTemp+="${textFormatMeta}${textFormatPlain}";
				done

				# Set the text format
				declare textFormat="${textFormatTemp}";
			fi
		fi
	else
		declare textFormat='%s';
	fi

	# If color was found in textFormat and metaEnd is not set or no color was found and metEnd is set
	if [[ "$metaType" != 0 && "$textMetaEnd" == 0 || "$metaType" == 0 && "$textMetaEnd" != 0 ]];
	then
		# End colors
		textFormat+="\033[m";
	fi

	# Padding (top[,left] or ,left)

	declare textPaddingTop="${textPadding%%,*}";

	if [[ "$textPadding" =~ \, ]];
	then
		declare textPaddingLeft="${textPadding##*,}";
	fi

	if [[ "$textPaddingTop" == '' ]];
	then
		declare textPaddingTop=0;
	fi

	if [[ "$textPaddingLeft" == '' ]];
	then
		declare textPaddingLeft=0;
	fi

	if [[ "$repeatCount" == '' ]];
	then
		declare repeatCount=1;
	fi

	if [[ "$clearBefore" != 0 ]];
	then
		clear;
	fi

	# If requested to set the referenced variable
	if [[ "$outputVariableReferenceName" != '' ]];
	then
		Misc_PrintF_outputVariableReference='';
		declare whitespaceIndex;

		# Padding top loop
		for (( whitespaceIndex = 0; whitespaceIndex < "$textPaddingTop"; whitespaceIndex++ ));
		do
			Misc_PrintF_outputVariableReference="\n${Misc_PrintF_outputVariableReference}";
		done

		# Padding left loop
		for (( whitespaceIndex = 0; whitespaceIndex < "$textPaddingLeft"; whitespaceIndex++ ));
		do
			Misc_PrintF_outputVariableReference=" ${Misc_PrintF_outputVariableReference}";
		done

		declare repeatIndex;

		# As many times as declared
		for (( repeatIndex = 0; repeatIndex < "$repeatCount"; repeatIndex++ ));
		do
			# > Command substitutions strip all trailing newlines from the output of the command inside them.
			# So, we add 1 character at the very end after possible new lines and remove it later
			Misc_PrintF_outputVariableReference+="$( printf "${textPrefix}${textFormat}" "${text[@]}"; printf '.'; )";
			Misc_PrintF_outputVariableReference="${Misc_PrintF_outputVariableReference%\.}";
		done

		# New line loop (padding bottom)
		for (( whitespaceIndex = 0; whitespaceIndex < "$newLine"; whitespaceIndex++ ));
		do
			Misc_PrintF_outputVariableReference="${Misc_PrintF_outputVariableReference}\n";
		done

		Misc_PrintF_outputVariableReferenceFormatMetas=( "${textFormatMetas[@]}" );

		return 0;
	fi

	declare whitespaceIndex;

	# Padding top loop
	for (( whitespaceIndex = 0; whitespaceIndex < "$textPaddingTop"; whitespaceIndex++ ));
	do
		printf '\n';
	done

	# Padding left loop
	for (( whitespaceIndex = 0; whitespaceIndex < "$textPaddingLeft"; whitespaceIndex++ ));
	do
		printf ' ';
	done

	declare repeatIndex;

	# As many times as declared
	for (( repeatIndex = 0; repeatIndex < "$repeatCount"; repeatIndex++ ));
	do
		# Output a prepared text to the specified stream
		printf "${textPrefix}${textFormat}" "${text[@]}" > "$outputStream";
	done

	# New line loop (padding bottom)
	for (( whitespaceIndex = 0; whitespaceIndex < "$newLine"; whitespaceIndex++ ));
	do
		printf '\n';
	done

	return 0;
}

Misc_Prompt()
{
	###########
	# Options #
	###########

	declare args;
	declare argsCount;

	if ! Options args '!1' \
		'@5/^(0|[1-9][0-9]*)$/' \
		'@8/^(0|[1-9][0-9]*)$/' \
		'@9/^(0|[1-9][0-9]*)$/' \
		'?-v;?-t;?-f;?-p;?-P;?-c;?-e;?-d;?-E;?-T;?-o;-m;-D;-n;-N;-s' \
		"$@"
	then
		Misc_PrintF -v 1 -t 'f' -nn -f $'[Misc_Prompt] Invalid options (code %s, index %s ~ \'%s\'): \'%s\'' -- \
			"$_Options_ResultCode" "$_Options_FailIndex" "$_Options_ErrorMessage" "$( Misc_ArrayJoin -- "$@" )";

		return 200;
	fi

	declare textType;
	unset textType;
	declare textType;

	declare textVerbosity="${args[0]}";
	[ "${argsCount[1]}" != 0 ] && declare textType="${args[1]}";
	declare textFormat="${args[2]}";
	declare patternVerify="${args[3]}";
	declare textPadding="${args[4]}";
	declare charCount="${args[5]}";
	declare explanation="${args[6]}";
	declare defaultValue="${args[7]}";
	declare __emptyInputCountMax="${args[8]}";
	declare __timeout="${args[9]}";
	declare outputVariableReferenceName="${args[10]}";
	declare textMeta="${args[11]}"; # Process meta
	declare disableDefaultValuePreview="${args[12]}";
	declare disablePostfix="${args[13]}";
	declare disableMessage="${args[14]}";
	declare isSecret="${args[15]}";
	declare message=( "${args[@]:16}" );

	if [[ "$outputVariableReferenceName" != '' ]];
	then
		if [[ "$outputVariableReferenceName" == 'Misc_Prompt_outputVariableReference' ]];
		then
			Misc_PrintF -v 1 -t 'f' -nf $'[Misc_Prompt] Output variable reference interference: \'%s\'' -- "$( Misc_ArrayJoin -- "$@" )";

			return 100;
		fi

		declare -n Misc_Prompt_outputVariableReference="$outputVariableReferenceName";
		Misc_Prompt_outputVariableReference='';
	fi

	########
	# Main #
	########

	declare emptyInputCountMax=2;

	if [[ "$__emptyInputCountMax" != '' ]];
	then
		declare emptyInputCountMax="$__emptyInputCountMax";
	fi

	if [[ "$textVerbosity" == '' ]];
	then
		declare textVerbosity=-1;
	fi

	if [[ "${textType+s}" == '' ]];
	then
		declare textType='q';
	fi

	if [[ "$disableMessage" == 0 ]];
	then
		if [[ "$textFormat" == '' ]];
		then
			declare textFormat='%s';
		fi

		if [[ ( "$textType" == '' || ${#message[@]} != 0 && ${message[-1]} != ' ' ) && "${textFormat: -1}" != ' ' ]];
		then
			declare textFormat+=' ';
		fi

		if [[ "$__timeout" != '' ]];
		then
			declare textFormat+="$( Misc_PrintF -mf $'{{@clYellow}}{%ss}{{@clDefault}}' -- "$__timeout"; ) ";
		fi

		if [[ "$explanation" != '' ]];
		then
			declare textFormat+="$( Misc_PrintF -mf '{{@clLightBlue2}}%s{{@clDefault}}' -- "$explanation"; ) ";
		fi

		# If default is set and its preview is not disabled (presence in the prompt message)
		if [[ "$defaultValue" != '' && "$disableDefaultValuePreview" == 0 ]];
		then
			declare textFormat+="$( Misc_PrintF -mf $'{{@clLightGray}}(%s){{@clDefault}}' -- "$defaultValue"; ) ";
		fi

		if [[ "$disablePostfix" == 0 ]];
		then
			declare textFormat+='>  ';
		fi

		declare textFormat="${textFormat:0:$(( ${#textFormat} - 1 ))}"; # Remove the last space
	fi

	# Start the input procedure (as fast as the input doesn't correspond to the requirements)

	declare emptyInput=0;
	declare timedout=0;
	declare inputData;

	while [[ "${inputData+s}" == '' ]] && (( emptyInput < emptyInputCountMax ));
	do
		if [[ "$disableMessage" == 0 ]];
		then
			Misc_PrintF -v "$textVerbosity" -t "$textType" -f "$textFormat" \
				$( [[ "$textPadding" != '' ]] && printf ' -p %s ' "$textPadding" ) \
				$( [[ "$textMeta" != 0 ]] && Misc_PrintF -r "$textMeta" -- ' -m ' ) -- "${message[@]}";
		fi

		IFS= read -r \
			$( [[ "$isSecret" != 0 ]] && printf -- ' -s ' ) \
			$( [[ "$charCount" != '' ]] && printf -- ' -n %s ' "$charCount" ) \
			$( [[ "$__timeout" != '' ]] && printf -- ' -t %s ' "$__timeout" ) -- inputData; # &>> "$_Main_Dump";

		declare returnCodeTemp=$?;

		# If timed out (exit code 142)
		if [[ "$returnCodeTemp" == 142 ]];
		then
			declare timedout=1;
			declare inputData="$defaultValue";

			break;
		fi

		# If normal input
		if [[ "$returnCodeTemp" == 0 ]];
		then
			if [[ "${#inputData}" == 0 ]];
			then
				declare inputData="$defaultValue";

				# If the input is still empty (no default value was set)
				if [[ "${#inputData}" == 0 ]];
				then
					declare emptyInput="$(( emptyInput + 1 ))";

					if [[ "$emptyInput" == 1 ]];
					then
						Misc_PrintF -v "$textVerbosity" -t 'i' $( [[ "$isSecret" != 0 ]] && printf -- '-p 1' ) \
							-nf '%s consecutive empty inputs cancel input' -- "$emptyInputCountMax";

						unset inputData;
						declare inputData;

						continue;
					fi
				fi
			else
				declare emptyInput=0;
			fi
		else
			Misc_PrintF -nv "$textVerbosity";
			declare emptyInput="$emptyInputCountMax";
		fi

		if (( emptyInput < emptyInputCountMax )) && [[ "$patternVerify" != '' ]] && ! Misc_Regex -p "$patternVerify" -- "$inputData";
		then
			Misc_PrintF -v "$textVerbosity" -t 'e' $( [[ "$isSecret" != 0 ]] && printf '%s' '-p' '1' ) -nf "${clGray}%s" -- 'Invalid input';

			unset inputData;
			declare inputData;
		fi
	done

	if (( emptyInput >= emptyInputCountMax ));
	then
		Misc_PrintF -v "$textVerbosity" -t 'w' $( [[ "$isSecret" != 0 ]] && printf -- '-p 1' ) -n -- 'Input cancelled';

		return 1;
	fi

	if [[ "$timedout" != 0 ]];
	then
		Misc_PrintF -v "$textVerbosity" -t 'w' -p 1 -nf 'Input timed out%s' -- "$( [[ "$inputData" != '' ]] && printf $' (%s)' "$inputData" )";
	fi

	if [[ "$outputVariableReferenceName" != '' ]];
	then
		Misc_Prompt_outputVariableReference="$inputData";

		return 0;
	fi

	printf '%s' "$inputData";

	return 0;
}

Misc_TimeStore()
{
	declare args;

	if ! Options args \
		'@0/^(0|[1-9][0-9]*)$/' \
		'@2/^[0-2]$/' \
		'@3/^[0-2]$/' \
		'@4/^[0-1]$/' \
		'?-i;?-o;?-t;?-p;-v' \
		"$@"
	then
		Misc_PrintF -v 1 -t 'f' -nn -f $'[Misc_DateTimeStore] Invalid options (code %s, index %s ~ \'%s\'): \'%s\'' -- \
			"$_Options_ResultCode" \
			"$_Options_FailIndex" \
			"$_Options_ErrorMessage" \
			"$( Misc_ArrayJoin -- "$@" )";

		return 200;
	fi

	declare index="${args[0]}";
	declare outputVariableReferenceName="${args[1]}";
	declare operationType="${args[2]}";
	declare print="${args[3]}";
	declare verbose="${args[4]}";

	if [ "$outputVariableReferenceName" != '' ];
	then
		if [ "$outputVariableReferenceName" = 'Misc_TimeStore_outputVariableReference' ];
		then
			Misc_PrintF -v 1 -t 'f' -nn -f $'[Misc_TimeStore] Output variable reference interference' -- \
				"$( Misc_ArrayJoin -- "$@" )";

			return 100;
		fi

		declare -n Misc_TimeStore_outputVariableReference="$outputVariableReferenceName";
		Misc_TimeStore_outputVariableReference='';
	fi

	# If no index is declared
	if [ "$index" = '' ];
	then
		if [ "$outputVariableReferenceName" = '' ];
		then
			if [ "$verbose" != 0 ];
			then
				Misc_PrintF -v 1 -t 'f' -nn -f $'No output variable reference declared to store the time value index' -- \
					"${#Misc_TimeStoreTimes[@]}" \
					"$index";
			fi

			return 100;
		fi

		declare timeValue="$( Misc_DateTime )";
		declare timeIndex;

		# Loop through each element in the time store array in order to find a possible removed/empty space
		for (( timeIndex = 0; timeIndex < "${#Misc_TimeStoreTimes[@]}"; timeIndex++ ));
		do
			if [ "${Misc_TimeStoreTimes[$timeIndex]}" = '' ];
			then
				# Store the time in the previously cleared element
				Misc_TimeStoreTimes[$timeIndex]="$timeValue";

				# Output the time's index
				printf '%s' "$timeIndex";

				return 0;
			fi
		done

		# Add new element to the array
		Misc_TimeStoreTimes+=( "$timeValue" );
		Misc_TimeStore_outputVariableReference="$(( ${#Misc_TimeStoreTimes[@]} - 1 ))";

		return 0;
	fi

	# If no such time value index or it's empty
	if (( "$index" > "${#Misc_TimeStoreTimes[@]}" )) || [ "${Misc_TimeStoreTimes[$index]}" = '' ];
	then
		if [ "$verbose" != 0 ];
		then
			Misc_PrintF -v 2 -t 'e' -nf $'No such stored time value with index (%s total stored): \'%s\'' -- \
				"${#Misc_TimeStoreTimes[@]}" \
				"$index";
		fi

		return 1;
	fi

	case "$print" in
		2) # Output the time value difference between current and the stored one
			if [ "$outputVariableReferenceName" != '' ];
			then
				Misc_TimeStore_outputVariableReference="$( printf '%s\n' "$( Misc_DateTime ) - ${Misc_TimeStoreTimes[$index]}" | bc -l )";
			else
				printf '%s' "$( printf '%s\n' "$( Misc_DateTime ) - ${Misc_TimeStoreTimes[$index]}" | bc -l )";
			fi
		;;
		1) # Output the time value
			if [ "$outputVariableReferenceName" != '' ];
			then
				Misc_TimeStore_outputVariableReference="${Misc_TimeStoreTimes[$index]}";
			else
				printf '%s' "${Misc_TimeStoreTimes[$index]}";
			fi
		;;
	esac

	case "$operationType" in
		2) # Remove the time value
			Misc_TimeStoreTimes[$index]='';

			if [ "$verbose" != 0 ];
			then
				Misc_PrintF -v 2 -t 'e' -nf $'Removed the stored time value with index: \'%s\'' -- \
					"$index";
			fi
		;;
		1) # Update the time value
			Misc_TimeStoreTimes[$index]="$( Misc_DateTime )";

			if [ "$verbose" != 0 ];
			then
				Misc_PrintF -v 2 -t 'e' -nf $'Updated the stored time value with index: \'%s\'' -- \
					"$index";
			fi
		;;
	esac

	return 0;
}

Misc_SoundPlay()
{
	###########
	# Options #
	###########

	declare args;

	if ! Options args \
		'?-v;?-V;?-d' \
		"$@";
	then
		Misc_PrintF -v 1 -t 'f' -nn -f $'[Misc_NotificationSound] Invalid options (code %s, index %s ~ \'%s\'): \'%s\'' -- \
			"$_Options_ResultCode" \
			"$_Options_FailIndex" \
			"$_Options_ErrorMessage" \
			"$( Misc_ArrayJoin -- "$@" )";

		return 200;
	fi

	declare soundVerbosity="${args[0]}";
	declare volume="${args[1]}";
	declare soundsDirpath="${args[2]}";
	declare sounds=( "${args[@]:3}" );

	if [[ "$soundVerbosity" == '' ]];
	then
		declare soundVerbosity="$Misc_SoundVerbosityLevel";
	fi

	if [[ "$volume" == '' ]];
	then
		declare volume="$Misc_NotificationSound_VolumeDefault";
	fi

	if [ "$soundsDirpath" == '' ];
	then
		declare soundsDirpath="$Environment_SoundsDirpath";
	fi

	########
	# Main #
	########

	if (( soundVerbosity > Misc_SoundVerbosityLevel ));
	then
		return 0;
	fi

	declare soundIndex;

	for (( soundIndex = 0; soundIndex < ${#sounds[@]}; soundIndex++ ));
	do
		declare soundFilepath="${soundsDirpath}/${sounds[$soundIndex]}.ogg";

		if [[ ! -f "$soundFilepath" ]];
		then
			Misc_PrintF -v 1 -t 'f' -nf $'No such audio file: \'%s\'' -- "$soundFilepath";

			continue;
		fi

		play -qv "$volume" -- "$soundFilepath" &>> "$_Main_Dump" &
	done
	
	return 0;
}