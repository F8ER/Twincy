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

declare -r _Lib_base=1;
declare -r _Base_sourceFilepath="$( readlink -e -- "${BASH_SOURCE[0]:-$0}" 2> '/dev/null'; )";
declare -r _Base_sourceDirpath="$( dirname -- "$_Base_sourceFilepath" 2> '/dev/null'; )";

[[ ! -f "$_Base_sourceFilepath" || ! -d "$_Base_sourceDirpath" ]] && exit 199;

#############
# Variables #
#############

Base_ProhibitedPaths=(
	'/'
);

for prohibitedPath in '/'*;
do
	Base_ProhibitedPaths+=( "$prohibitedPath" );
done

# Base_PreserveTempFiles=0;

############################################################
# Methods                                                  #
############################################################

# File system

# Description: File system element existence
# 
# Options:
#	-t (argument) - Element type to process (a|0 - any (default), f|1 - file, d|2 - directory)
#	-v (multi-flag) - Verbose
#	 * - Paths of elements
#
# Returns:
#	  0 ~ All declared elements exist
#	  1 ~ An empty file path declared
#	  2 ~ At least one of the elements doesn't exist
#	200 ~ Invalid options
#
Base_FsExists()
{
	###########
	# Options #
	###########

	declare args;

	if ! Options args \
		'@0/[0-2adf]/' \
		'?-t;-v' \
		"$@";
	then
		Misc_PrintF -v 1 -t 'f' -nf $'[Base_FsExists] Invalid options (code %s, index %s ~ \'%s\'): \'%s\'' -- \
			"$_Options_ResultCode" \
			"$_Options_FailIndex" \
			"$_Options_ErrorMessage" \
			"$( Misc_ArrayJoin -- "$@" )";

		return 200;
	fi

	declare checkType="${args[0]}";
	declare verbose="${args[1]}";
	declare paths=( "${args[@]:2}" );

	case "$checkType" in
		''|'a') declare checkType=0;;
		'f') declare checkType=1;;
		'd') declare checkType=2;;
	esac

	########
	# Main #
	########

	declare pathIndex;
	declare path;

	# Loop through each path
	for (( pathIndex = 0; pathIndex < ${#paths[@]}; pathIndex++ ));
	do
		declare path="${paths[$pathIndex]}";

		if [ "$path" = '' ];
		then
			if [ "$verbose" != 0 ];
			then
				Misc_PrintF -v 3 -t 'w' -nf $'Empty path declared to check if exists at %s argument' -- "$pathIndex";
			fi

			return 1;
		fi

		# Remove all leading characters '/' (i.e. (/Path/To/ or /Path/To/// etc.) ~> /Path/To)
		while [ "${path: -1}" = '/' ];
		do
			declare path="${path%\/*}";
		done

		# If such file or directory exists
		if [ -d "$path" ];
		then
			declare elementType=2;
		elif [ -f "$path" ];
		then
			declare elementType=1;
		else
			declare elementType=0;
		fi

		# If doesn't exist or type mismatches with the requested one
		if [ "$elementType" = 0 ] || ( [ "$checkType" != 0 ] && [ "$checkType" != "$elementType" ] );
		then
			if [ "$verbose" != 0 ];
			then
				Misc_PrintF -v 3 -t 'w' \
					-nf $'No such %s%s: \'%s\'' -- \
					"$(
						case "$checkType" in
							2) printf 'directory';;
							1) printf 'file';;
							0) printf 'file and directory';;
						esac
					)" \
					"$(
						[ "$elementType" = 1 ] && printf ' (such file exists)';
						[ "$elementType" = 2 ] && printf ' (such directory exists)';
					)" \
					"$path";
			fi

			return 2;
		fi

		# If exists

		if [ "$verbose" != 0 ];
		then
			Misc_PrintF -v 4 -t 's' \
				-nf $'%s: \'%s\'' -- \
				"$( 
					[ "$elementType" = 1 ] && printf 'File';
					[ "$elementType" = 2 ] && printf 'Directory';
					printf ' exists';
					[ "$checkType" = 0 ] && printf ' (regardlessly)'; 
				)" \
				"$path";
		fi
	done

	return 0;
}

# Description: Directory create
# 
# Options:
#	-p (flag) - Auto-create parent directories
#	-e (flag) - Ignore if exists
#	-v (multi-flag) - Verbose
#	 * - Paths of directories
#
# Returns:
#	  0 ~ Created all directories without issues
#	  1 ~ An empty file path declared
#	  2 ~ Such directory exists (ignore disabled)
#	  3 ~ Such file exists
#	  4 ~ Failed to create a directory
#	200 ~ Invalid options
#
Base_FsDirectoryCreate()
{
	###########
	# Options #
	###########

	declare args;

	if ! Options args \
		'@0/[0-1]/' \
		'@1/[0-1]/' \
		'-p;-e;-v' \
		"$@";
	then
		Misc_PrintF -v 1 -t 'f' -nf $'[Base_FsDirectoryCreate] Invalid options (code %s, index %s ~ \'%s\'): \'%s\'' -- \
			"$_Options_ResultCode" \
			"$_Options_FailIndex" \
			"$_Options_ErrorMessage" \
			"$( Misc_ArrayJoin -- "$@" )";

		return 200;
	fi

	declare createParents="${args[0]}";
	declare checkExistence="${args[1]}";
	declare verbose="${args[2]}";
	declare directoryPaths=( "${args[@]:3}" );

	########
	# Main #
	########

	declare directoryPathIndex;
	declare directoryPath;

	for (( directoryPathIndex = 0; directoryPathIndex < ${#directoryPaths[@]}; directoryPathIndex++ ));
	do
		declare directoryPath="${directoryPaths[$directoryPathIndex]}";

		if [ "$directoryPath" = '' ];
		then
			if [ "$verbose" != 0 ];
			then
				Misc_PrintF -v 3 -t 'w' -nf $'Empty path declared to create directory at %s argument' -- "$directoryPathIndex";
			fi

			return 1;
		fi

		# Remove all leading characters '/' (i.e. (/Path/To/ or /Path/To/// etc.) ~> /Path/To)
		while [ "${directoryPath: -1}" = '/' ];
		do
			declare directoryPath="${directoryPath%\/*}";
		done

		# If such directory or file exists
		if Base_FsExists -t 2 -- "$directoryPath";
		then
			declare directoryType=2;
		elif Base_FsExists -t 1 -- "$directoryPath";
		then
			declare directoryType=1;
		else
			declare directoryType=0;
		fi

		# If such file or directory already exists
		if [ "$directoryType" != 0 ];
		then
			if [ "$verbose" != 0 ];
			then
				# i.e. [ - ] Couldn't create the directory (such file exists; parented): "/some/path"
				Misc_PrintF -v 3 -t 'w' \
					-nf $'Couldn\'t create directory (such%s exists%s): \'%s\'' -- \
					"$(
						[ "$directoryType" = 1 ] && printf ' file';
						[ "$directoryType" = 2 ] && printf ' directory';
					)" \
					"$( [ "$createParents" = 1 ] && printf '; parented' )" \
					"$directoryPath";
			fi

			if [ "$checkExistence" = 0 ];
			then
				return 0;
			fi
			
			[ "$directoryType" = 2 ] && return 2 || return 3;
		fi

		# Try to create the directory

		if [ "$createParents" != 0 ];
		then
			mkdir -p "$directoryPath" &>> "$_Main_Dump";
			returnCodeTemp=$?;
		else
			mkdir "$directoryPath" &>> "$_Main_Dump";
			returnCodeTemp=$?;
		fi

		# If such directory or file exists
		if Base_FsExists -t 2 -- "$directoryPath";
		then
			declare directoryProcessedType=2;
		elif Base_FsExists -t 1 -- "$directoryPath";
		then
			declare directoryProcessedType=1;
		else
			declare directoryProcessedType=0;
		fi

		# If failed or directory doesn't exist (after the creation try)
		if [ "$returnCodeTemp" != 0 ] || [ "$directoryProcessedType" != 2 ];
		then
			if [ "$verbose" != 0 ];
			then
				# i.e. [ - ] Failed to create the directory (code 1; parented): "/some/path"
				Misc_PrintF -v 2 -t 'e' \
					-nf $'Failed to create directory (code %s%s): \'%s\'' -- \
					"$returnCodeTemp" \
					"$( [ "$createParents" = 1 ] && printf '; parented' )" \
					"$directoryPath";
			fi

			return 4;
		fi

		if [ "$verbose" != 0 ];
		then
			# i.e. [ + ] Created the directory (parented): "/some/path"
			Misc_PrintF -v 4 -t 's' \
				-nf $'Created directory%s: \'%s\'' -- \
				"$( [ "$createParents" = 1 ] && printf ' (parented)' )" \
				"$directoryPath";
		fi
	done

	return 0;
}

# Description: Directory internal's count
# 
# Options:
#	-t (argument) - Element type to process (0 - any (default), 1 - file, 2 - directory)
#	-d (argument) - Maximum depth
#	-o (argument) - Output variable reference
#	-v (multi-flag) - Verbose
#	 * - Paths of directories
#
# Returns:
#	  0 ~ Counted without any issues and found at least one element
#	  1 ~ Counted without any issues and found no elements of requested type
#	  2 ~ An empty file path declared
#	  3 ~ No such directory
#	  4 ~ No such directory (such file exists)
#	  5 ~ Failed to count a directory
#	100 ~ Output variable reference interference
#	200 ~ Invalid options
#
# Outputs:
#	1. Prints: Total element count
#	2. Output reference variable:
#		1.1. An array of element count of each directory, respectively
#
Base_FsDirectoryContains()
{
	declare args;

	if ! Options args \
		'@0/[0-2adf]/' \
		'?-t;?-d;?-o;-v' \
		"$@";
	then
		Misc_PrintF -v 1 -t 'f' -nf $'[Base_FsDirectoryContains] Invalid options (code %s, index %s ~ \'%s\'): \'%s\'' -- \
			"$_Options_ResultCode" \
			"$_Options_FailIndex" \
			"$_Options_ErrorMessage" \
			"$( Misc_ArrayJoin -- "$@" )";

		return 200;
	fi

	declare elementType="${args[0]}";
	declare maxdepth="${args[1]}";
	declare outputVariableReferenceName="${args[2]}";
	declare verbose="${args[3]}";
	declare directoryPaths=( "${args[@]:4}" );

	if [ "$outputVariableReferenceName" != '' ];
	then
		# If the output reference matches the important variables.
		# Both the reference and temp must mismatch or else the first would cause a reference loop and the second (temp) would return an empty result
		if 
			[ "$outputVariableReferenceName" = 'Base_FsDirectoryContains_outputVariableReference' ] || 
			[ "$outputVariableReferenceName" = 'Base_FsDirectoryContains_outputVariableReferenceTemp' ];
		then
			Misc_PrintF -v 1 -t 'f' -nf $'[Base_FsDirectoryContains] Output variable reference interference: \'%s\'' -- \
				"$( Misc_ArrayJoin -- "$@" )";

			return 100;
		fi

		# Set the reference variable to the element count
		declare -n Base_FsDirectoryContains_outputVariableReference="$outputVariableReferenceName";
		Base_FsDirectoryContains_outputVariableReference=();
	fi

	case "$elementType" in
		''|'a') declare elementType=0;;
		'f') declare elementType=1;;
		'd') declare elementType=2;;
	esac

	########
	# Main #
	########

	declare directoryPathIndex;
	declare directoryPath;
	unset Base_FsDirectoryContains_outputVariableReferenceTemp;
	declare Base_FsDirectoryContains_outputVariableReferenceTemp=();
	declare elementCountTotal=0;

	# Loop through each directory path
	for (( directoryPathIndex = 0; directoryPathIndex < ${#directoryPaths[@]}; directoryPathIndex++ ));
	do
		declare directoryPath="${directoryPaths[$directoryPathIndex]}";

		if [ "$directoryPath" = '' ];
		then
			Misc_PrintF -v 1 -t 'f' -nf $'Empty directory path declared to count its %s at %s argument' -- \
				"$(
					case "$elementType"
					in
						2) printf 'directory(s)';;
						1) printf 'file(s)';;
						0) printf 'element(s)';;
					esac
				)" \
				"$filePathIndex";

			return 2;
		fi

		# Remove all leading characters '/', if exists except one  (i.e. (/Path/To/ or /Path/To// etc.) ~> /Path/To/)

		if [ "${directoryPath: -1}" = '/' ];
		then
			# While /Path/To/ or /Path/To// etc.
			while [ "${directoryPath: -1}" = '/' ];
			do
				declare directoryPath="${directoryPath%\/*}";
			done
			
			directoryPath="${directoryPath}/"; # i.e. /Path/To ~> /Path/To/
		fi

		# If such directory or file exists
		if Base_FsExists -t 2 -- "$directoryPath";
		then
			declare directoryType=2;
		elif Base_FsExists -t 1 -- "$directoryPath";
		then
			declare directoryType=1;
		else
			declare directoryType=0;
		fi

		# If such directory doesn't exist or such file exists
		if [ "$directoryType" != 2 ];
		then
			if [ "$verbose" != 0 ];
			then
				Misc_PrintF -v 2 -t 'e' \
					-nf $'Couldn\'t count %s of directory (no such directory%s): \'%s\'' -- \
					"$( 
						case "$elementType"
						in
							2) printf 'directory(s)';;
							1) printf 'file(s)';;
							0) printf 'element(s)';;
						esac
					)" \
					"$( [ "$directoryType" = 1 ] && printf '; such file exists' )" \
					"$directoryPath";
			fi

			[ "$directoryType" = 0 ] && return 3 || return 4;
		fi

		# Try to count

		declare returnCodeTemp=0;

		# Temporary element count variable to preserve the exit code of `find` program below (perhaps, that requires a different approach)
		declare elementCountChars="";

		# Each element type (any, files, directories) (count by output character count)
		case "$elementType"
		in
			2) # Directories
				# No 'declare', or else we would have no returned 'exit code' from 'find' program
				elementCountChars="$( 
					{
						find "$directoryPath" \
							$( [[ "$maxdepth" != '' ]] && printf -- " -maxdepth ${maxdepth} " ) \
							! -path "$directoryPath" -type d -printf 1;
					} 2>> "$_Main_Dump";
				)";

				declare returnCodeTemp=$?;
			;;
			1) # Files
				elementCountChars="$(
					{
						find "$directoryPath" \
							$( [[ "$maxdepth" != '' ]] && printf -- " -maxdepth ${maxdepth} " ) \
							-type f -printf 1; 
					} 2>> "$_Main_Dump";
				)";

				declare returnCodeTemp=$?;
			;;
			0) # Any
				elementCountChars="$(
					{
						find "$directoryPath" \
							$( [[ "$maxdepth" != '' ]] && printf -- " -maxdepth ${maxdepth} " ) \
							! -path "$directoryPath" -printf 1;
					} 2>> "$_Main_Dump";
				)";

				declare returnCodeTemp=$?;
			;;
		esac

		# If failed to search the directory
		if [[ "$returnCodeTemp" != 0 ]];
		then
			if [ "$verbose" != 0 ];
			then
				Misc_PrintF -v 2 -t 'e' \
					-nf $'Failed to count %s of directory (code %s): \'%s\'' -- \
					"$( 
						case "$elementType" 
						in
							2) printf 'directory(s)';;
							1) printf 'file(s)';;
							0) printf 'element(s)';;
						esac
					)" \
					"$returnCodeTemp" \
					"$directoryPath";
			fi

			return 5;
		fi

		# Get the element count (the quanity of '1' characters from the string) and add it to the result and counter
		declare elementCount="$( printf '%s' "$elementCountChars" | wc -c )";
		Base_FsDirectoryContains_outputVariableReferenceTemp+=( "$elementCount" );
		declare elementCountTotal="$(( elementCountTotal + elementCount ))";

		# If match found
		if [ "$elementCount" != 0 ];
		then
			if [ "$verbose" != 0 ];
			then
				Misc_PrintF -v 4 -t 's' \
					-nf $'Found %s %s in directory (depth: %s): \'%s\'' -- \
					"$elementCount" \
					"$( 
						case "$elementType"
						in
							2) printf 'directory(s)';;
							1) printf 'file(s)';;
							0) printf 'element(s)';;
						esac
					)" \
					"$maxdepth" \
					"$directoryPath";
			fi

			continue;
		fi

		if [ "$verbose" != 0 ];
		then
			Misc_PrintF -v 4 -t 'i' \
				-nf $'Directory has no %s (empty): \'%s\'' -- \
				"$( 
					case "$elementType"
					in
						2) printf 'directories';;
						1) printf 'files';;
						0) printf 'elements';;
					esac
				)" \
				"$directoryPath";
		fi
	done

	# If requested to set to a referenced variable
	if [ "$outputVariableReferenceName" != '' ];
	then
		# Set the reference variable to the element count
		Base_FsDirectoryContains_outputVariableReference=( "${Base_FsDirectoryContains_outputVariableReferenceTemp[@]}" );
	fi

	# If found no elements of requested type
	if [ "$elementCountTotal" = 0 ];
	then
		printf '0';

		return 1;
	fi

	printf '%s' "$elementCountTotal";

	return 0;
}

# Description: File write
# 
# Options:
#	-f (argument, important) - File path to write
#	-F (argument) - Write format
#	-n (multi-flag) - New line counter
#	-e (flag) - Check file existence
#	-a (flag) - Append to a file
#	-v (multi-flag) - Verbose
#	 * - Data to write
#
# Returns:
#	  0 ~ Moved, copied or renamed all elements without issues
#	  1 ~ An empty file path declared
#	  2 ~ No such directory
#	  3 ~ Such directory exists
#	  4 ~ Such file exists (overwrite disabled)
#	  5 ~ No such file (append enabled)
#	  6 ~ Failed to write to a file
#	200 ~ Invalid options
#
Base_FsWrite()
{

	###########
	# Options #
	###########

	declare args;

	if ! Options args \
		'@3/[0-1]/' \
		'@4/[0-1]/' \
		'?!-f;?-F;-n;-e;-a;-v' \
		"$@";
	then
		Misc_PrintF -v 1 -t 'f' -nf $'[Base_FsWrite] Invalid options (code %s, index %s ~ \'%s\'): \'%s\'' -- \
			"$_Options_ResultCode" \
			"$_Options_FailIndex" \
			"$_Options_ErrorMessage" \
			"$( Misc_ArrayJoin -- "$@" )";

		return 200;
	fi

	declare filePath="${args[0]}";
	declare format="${args[1]}";
	declare newLine="${args[2]}";
	declare checkExistence="${args[3]}";
	declare append="${args[4]}";
	declare verbose="${args[5]}";
	declare data=( "${args[@]:6}" );

	########
	# Main #
	########

	if [ "$filePath" = '' ];
	then
		Misc_PrintF -v 1 -t 'f' -nf $'Empty file path declared to write/%s' -- "$( [[ "$append" == 0 ]] && printf 'overwrite' || printf 'append' )" \

		return 1;
	fi

	# Remove all leading characters '/' (i.e. (/Path/To/ or /Path/To/// etc.) ~> /Path/To)
	while [ "${filePath: -1}" = '/' ];
	do
		declare filePath="${filePath%\/*}";
	done

	# Element's name and directory path
	declare fileName="${filePath##*\/}"; # i.e. /Path/From/SourceElement ~> SourceElement
	declare fileDirectoryPath="${filePath%\/*}"; # i.e. /Path/From/SourceElement ~ /Path/From
	[ "${#fileDirectoryPath}" = "${#filePath}" ]; # I.e. The full path is just filename
	declare fileDirectoryIsDefined="$(( ! ! $? ))";

	# If such destination directory or file exists
	if Base_FsExists -t 2 -- "$fileDirectoryPath";
	then
		declare fileDirectoryType=2;
	elif Base_FsExists -t 1 -- "$fileDirectoryPath";
	then
		declare fileDirectoryType=1;
	else
		declare fileDirectoryType=0;
	fi

	# If such file or directory exists
	if Base_FsExists -t 2 -- "$filePath";
	then
		declare fileType=2;
	elif Base_FsExists -t 1 -- "$filePath";
	then
		declare fileType=1;
	else
		declare fileType=0;
	fi

	# If a directory is defined and it doesn't exist
	if [ "$fileDirectoryIsDefined" = 1 ] && [ "$fileDirectoryType" != 2 ];
	then
		[[ "$verbose" != 0 ]] && Misc_PrintF -v 2 -t 'e' -nf $'Couldn\'t write/%s file (no such destination directory): \'%s\'' -- \
			"$( [[ "$append" == 0 ]] && printf 'overwrite' || printf 'append to' )" "$filePath";

		return 2;
	fi

	# If such directory exists
	if [ "$fileType" = 2 ];
	then
		[[ "$verbose" != 0 ]] && Misc_PrintF -v 2 -t 'e' -nf $'Couldn\'t write/%s file (such directory exists): \'%s\'' -- \
			"$( [[ "$append" == 0 ]] && printf 'overwrite' || printf 'append to' )" \
			"$filePath";

		return 3;
	fi

	# If check existence
	if [ "$checkExistence" = 1 ];
	then
		# If such file exists and do not append
		if [ "$fileType" = 1 ] && [ "$append" = 0 ];
		then
			[[ "$verbose" != 0 ]] && Misc_PrintF -v 2 -t 'e' -nf $'Couldn\'t write file (such file exists): \'%s\'' -- "$filePath";

			return 4;
		fi

		# If such file doesn't exist and append
		if [ "$fileType" = 0 ] && [ "$append" = 1 ];
		then
			[[ "$verbose" != 0 ]] && Misc_PrintF -v 2 -t 'e' -nf $'Couldn\'t append to file (no such file): \'%s\'' -- "$filePath";

			return 5;
		fi
	fi

	# If no format specified
	if [[ "$format" == '' ]];
	then
		declare format='%s';
	fi

	declare newLineIndex;
	
	# If a new line(s) was requested
	for (( newLineIndex = 0; newLineIndex < "$newLine"; newLineIndex++ ));
	do
		format+='\n';
	done

	# Try to write

	# If append is requested
	if [[ "$append" != 0 ]];
	then
		printf "$format" "${data[@]}" 2>> "$_Main_Dump" >> "$filePath";
		returnCode=$?;
	else
		printf "$format" "${data[@]}" 2>> "$_Main_Dump" > "$filePath";
		returnCode=$?;
	fi

	Base_FsExists -t 1 -- "$filePath"
	declare fileTypeNew="$?";

	# If failed to write or no such file exists
	if [[ "$returnCode" != 0 || "$fileTypeNew" != 0 ]];
	then
		[[ "$verbose" != 0 ]] && Misc_PrintF -v 2 -t 'e' -nf $'Failed to write/%s file (code %s%s): \'%s\'' -- \
			"$( [[ "$append" == 0 ]] && printf 'overwrite' || printf 'append to' )" \
			"$returnCode" \
			"$( [ "$fileTypeNew" != 1 ] && printf '; no such file'; )" \
			"$filePath";

		return 6;
	fi

	# If wrote to the file successfully

	[[ "$verbose" != 0 ]] && Misc_PrintF -v 4 -t 's' -nf $'%s file (%s data elements): \'%s\'' -- \
		"$(
			if [[ "$fileType" == 0 ]];
			then
				printf 'Wrote to new';
			elif [[ "$append" == 0 ]];
			then
				printf 'Overwrote';
			else
				printf 'Wrote to'
			fi
		)" \
		"${#data[@]}" "$filePath";

	return 0;
}

# Description: File read
# 
# Options:
#	-o (argument) - Output variable reference
#	-v (multi-flag) - Verbose
#	 * - Files to read
#
# Returns:
#	  0 ~ Read all files without any issues
#	  1 ~ No file path declared to read
#	  2 ~ An empty file path declared to read
#	  3 ~ No such file
#	  4 ~ Such directory exists
#	  5 ~ Failed to read a file
#	100 ~ Output variable reference interference
#	200 ~ Invalid options
#
# Outputs:
#	1. Prints: A join string of all files content
#	2. Output reference variable:
#		1.1. An array of content of each file, respectively
#
Base_FsRead()
{
	declare args;

	if ! Options args \
		'?-o;-v' \
		"$@";
	then
		Misc_PrintF -v 1 -t 'f' -nf $'[Base_FsRead] Invalid options (code %s, index %s ~ \'%s\'): \'%s\'' -- \
			"$_Options_ResultCode" \
			"$_Options_FailIndex" \
			"$_Options_ErrorMessage" \
			"$( Misc_ArrayJoin -- "$@" )";

		return 200;
	fi

	declare outputVariableReferenceName="${args[0]}";
	declare verbose="${args[1]}";
	declare filePaths=( "${args[@]:2}" );

	if [ "$outputVariableReferenceName" != '' ];
	then
		if 
			[ "$outputVariableReferenceName" = 'Base_FsRead_outputVariableReference' ] ||
			[ "$outputVariableReferenceName" = 'Base_FsRead_outputVariableReferenceTemp' ];
		then
			if [ "$verbose" != 0 ];
			then
				Misc_PrintF -v 1 -t 'f' -nf $'[Base_FsRead] Output variable reference interference: \'%s\'' -- \
					"$( Misc_ArrayJoin -- "$@" )";
			fi

			return 100;
		fi

		declare -n Base_FsRead_outputVariableReference="$outputVariableReferenceName";
		Base_FsRead_outputVariableReference='';
	fi

	if [ ${#filePaths[@]} = 0 ];
	then
		if [ "$verbose" != 0 ];
		then
			Misc_PrintF -v 1 -t 'f' -n -- $'No file path declared to read';
		fi

		return 1;
	fi

	# Clear the variable's value
	unset Base_FsRead_outputVariableReferenceTemp;
	declare Base_FsRead_outputVariableReferenceTemp='';

	for (( filePathIndex = 0; filePathIndex < ${#filePaths[@]}; filePathIndex++ ));
	do
		declare filePath="${filePaths[$filePathIndex]}";

		if [ "$filePath" = '' ];
		then
			if [ "$verbose" != 0 ];
			then
				Misc_PrintF -v 1 -t 'f' -nf $'Empty file path declared to read at %s argument' -- "$filePathIndex";
			fi

			return 2;
		fi

		# Remove all leading characters '/' (i.e. (/Path/To/ or /Path/To/// etc.) ~> /Path/To)
		while [ "${filePath: -1}" = '/' ];
		do
			declare filePath="${filePath%\/*}";
		done

		# If such file or directory exists
		if Base_FsExists -t 2 -- "$filePath";
		then
			declare fileType=2;
		elif Base_FsExists -t 1 -- "$filePath";
		then
			declare fileType=1;
		else
			declare fileType=0;
		fi

		# If no such file or such directory exists
		if [ "$fileType" != 1 ];
		then
			if [ "$verbose" != 0 ];
			then
				Misc_PrintF -v 2 -t 'e' \
					-nf $'Couldn\'t read file (no such file%s): \'%s\'' -- \
					"$( if [ "$fileType" = 2 ]; then printf '%s' '; such directory exists'; fi )" \
					"$filePath";
			fi

			[ "$fileType" = 0 ] && return 3 || return 4;
		fi

		# Try to read the file into the temporary variable
		# Added and then removed character '.' at the end preserves leading whitespaces which Bash would truncate

		Base_FsRead_outputVariableReferenceTemp+="$( cat "$filePath" 2>> "$_Main_Dump"; printf '.' )";
		declare returnCodeTemp=$?;
		Base_FsRead_outputVariableReferenceTemp="${Base_FsRead_outputVariableReferenceTemp%\.}";

		# If couldn't read the file
		if [ "$returnCodeTemp" != 0 ];
		then
			if [ "$verbose" != 0 ];
			then
				Misc_PrintF -v 2 -t 'e' -d 2 -nf $'Failed to read file (code %s): \'%s\'' -- "$returnCodeTemp" "$filePath";
			fi

			return 5;
		fi

		if [ "$verbose" != 0 ];
		then
			Misc_PrintF -v 5 -t 'd' -d 2 -nf $'Read file (%s bytes): \'%s\'' -- \
				"${#Base_FsRead_outputVariableReferenceTemp}" \
				"$filePath";
		fi
	done

	# Tried to read all the files

	# If requested to store file contents into a variable
	if [ "$outputVariableReferenceName" != '' ];
	then
		Base_FsRead_outputVariableReference="$Base_FsRead_outputVariableReferenceTemp";
		
		return 0;
	fi

	# Output to '/etc/stdout';
	printf '%s' "$Base_FsRead_outputVariableReferenceTemp";

	return 0;
}

# Description: File system element move, copy and rename
#
# Current issues:
#	1. ".", ".." and move elements into directory which is included into the elements (d4 -> d4/d4 or ./d4 -> ./d4/d4)
#
# Options:
#	-t (argument) - Element type to process (0 - any (default), 1 - file, 2 - directory)
#	-f (multi-flag) - Force remove destination if exists. If two flags, then also remove non-empty directories.
#	-c (flag) - Make a copy
#	-v (multi-flag) - Verbose
#	 * - Element paths to process: source [source...] destination
#
# Returns:
#	  0 ~ Moved, copied or renamed without issues
#	  1 ~ Less than two paths declared
#	  2 ~ An empty destination path declared
#	  3 ~ An empty source path declared
#	  4 ~ Same destination and source
#	  5 ~ No such source
#	  6 ~ Such destination exists (ignore disabled)
#	  7 ~ Failed to remove the destination (ignore enabled)
#	  8 ~ Failed to move, copy or rename
#	102 ~ An empty source path declared
#	200 ~ Invalid options
#
Base_FsMove()
{
	###########
	# Options #
	###########

	declare args;

	if ! Options args \
		'@0/[0-2adf]/' \
		'@1/[0-2]/' \
		'@2/[0-1]/' \
		'?-t;-f;-c;-v' \
		"$@";
	then
		Misc_PrintF -v 1 -t 'f' -nf $'[Base_FsMove] Invalid options (code %s, index %s ~ \'%s\'): \'%s\'' -- \
			"$_Options_ResultCode" \
			"$_Options_FailIndex" \
			"$_Options_ErrorMessage" \
			"$( Misc_ArrayJoin -- "$@" )";

		return 200;
	fi

	declare elementType="${args[0]}";
	declare ignoreDestination="${args[1]}";
	declare actionCopy="${args[2]}";
	declare verbose="${args[3]}";
	declare paths=( "${args[@]:4}" );

	case "$elementType" in
		''|'a') declare elementType=0;;
		'f') declare elementType=1;;
		'd') declare elementType=2;;
	esac

	if (( ${#args[@]} < 2 ));
	then
		if [ "$verbose" != 0 ];
		then
			Misc_PrintF -v 1 -t 'f' -nf $'Less than 2 paths declared to move, rename or copy: \'%s\'' -- \
				"$_Options_ResultCode" \
				"$_Options_FailIndex" \
				"$( Misc_ArrayJoin -- "$@" )";
		fi

		return 1;
	fi

	declare destinationMainPath="${paths[-1]}"; # Get the last element from the paths array - destination

	# If the destination path is empty
	if [ "$destinationMainPath" = '' ];
	then
		if [ "$verbose" != 0 ];
		then
			Misc_PrintF -v 1 -t 'f' -n -- $'Empty destination path declared to move, rename or copy';
		fi

		return 2;
	fi

	unset paths[-1]; # Remove the destination from the paths array

	# Remove all leading characters '/', if exists except one  (i.e. (/Path/To/ or /Path/To// etc.) ~> /Path/To/)

	if [ "${destinationMainPath: -1}" = '/' ];
	then
		# While /Path/To/ or /Path/To// etc.
		while [ "${destinationMainPath: -1}" = '/' ];
		do
			declare destinationMainPath="${destinationMainPath%\/*}";
		done
		
		destinationMainPath="${destinationMainPath}/"; # i.e. /Path/To ~> /Path/To/
	fi

	########
	# Main #
	########

	declare sourcePathIndex;

	# Loop through each source path
	for (( sourcePathIndex = 0; sourcePathIndex < "${#paths[@]}"; sourcePathIndex++ ));
	do
		declare sourcePath="${paths[$sourcePathIndex]}";

		# If the source path is empty
		if [ "$sourcePath" = '' ];
		then
			if [ "$verbose" != 0 ];
			then
				Misc_PrintF -v 1 -t 'f' -nf $'Empty source path declared to move, rename or copy at %s argument' -- \
					"$sourcePathIndex";
			fi

			return 3;
		fi

		# Remove leading characters '/' from the source and destination

		# While /Path/From/ or /Path/From// etc.
		while [ "${sourcePath: -1}" = '/' ];
		do
			declare sourcePath="${sourcePath%\/*}"; # i.e. /Path/From/ ~> /Path/From
		done

		declare destinationPath="$destinationMainPath";

		# Element's name and directory path
		declare sourceName="${sourcePath##*\/}"; # i.e. /Path/From/SourceElement ~> SourceElement
		declare sourceDirectoryPath="${sourcePath%\/*}"; # i.e. /Path/From/SourceElement ~ /Path/From
		declare destinationDirectoryPath="${destinationPath%\/*}"; # i.e. /Path/To/ ~>. /Path/To or /Path/To ~>. /Path

		# [ "${#sourceDirectoryPath}" = "${#sourcePath}" ]; # I.e. The full source path is just filename
		# declare sourceDirectoryIsDefined="$(( ! ! $? ))";

		if [ "${sourceDirectoryPath}" = "${sourcePath}" ];
		then
			sourceDirectoryPath='.';
		fi

		# [ "${#destinationDirectoryPath}" = "${#destinationPath}" ]; # I.e. The full destination path is just filename
		# declare destinationDirectoryIsDefined="$(( ! ! $? ))";

		if [ "${destinationDirectoryPath}" = "${destinationPath}" ];
		then
			destinationDirectoryPath='.';
		fi

		# If the destination is a directory and its path ends with the character '/'
		if [ "${destinationPath: -1}" = '/' ]; # [ "$destinationType" = 2 ] &&
		then
			declare destinationPath="${destinationDirectoryPath}/$sourceName"; # i.e. /Path/To/ ~> (/Path/To/Dir or /Path/To/File)
		fi

		# If the source and destination are equal
		if [ "$sourcePath" = "$destinationPath" ];
		then
			if [ "$verbose" != 0 ];
			then
				Misc_PrintF -v 2 -t 'e' -nf $'Same destination and source to move, copy or rename at %s argument: \'%s\'' -- \
					"$sourcePathIndex" \
					"$sourcePath";
			fi

			return 4;
		fi

		# Get the source's file system type
		if Base_FsExists -t 2 -- "$sourcePath";
		then
			declare sourceType=2;
		elif Base_FsExists -t 1 -- "$sourcePath";
		then
			declare sourceType=1;
		else
			declare sourceType=0;
		fi

		# Get the destination's file system type
		if Base_FsExists -t 2 -- "$destinationPath";
		then
			declare destinationType=2;
		elif Base_FsExists -t 1 -- "$destinationPath";
		then
			declare destinationType=1;
		else
			declare destinationType=0;
		fi

		# If a copy operation is requested
		if [[ "$actionCopy" == 1 ]];
		then
			declare operationType=1; # Copy
		elif
			[ "${sourceDirectoryPath}" != "${destinationDirectoryPath}" ] && # I.e. Dir1 != Dir2
			[ "${sourceDirectoryPath}" != "${destinationPath}" ] # i.e. Dir1 != Dir2/Dir1
		then
			declare operationType=2; # Move
		else
			declare operationType=0; # Rename
		fi

		# exit 1;

		####################
		# Check the source #
		####################

		# If there's no such source file and directory or the source type mismatch with the requested one ("elementType")
		if [ "$sourceType" = 0 ] || ( [ "$elementType" != 0 ] && [ "$elementType" != "$sourceType" ] );
		then
			if [ "$verbose" != 0 ];
			then
				Misc_PrintF -v 2 -t 'e' -nf "Couldn't %s %s (no such source exists%s): \"%s\"" -- \
					"$( 
						case "$operationType" in
							2) printf 'move';;
							1) printf 'copy';;
							0) printf 'rename';;
						esac
					)" \
					"$(
						case "$elementType" in
							2) printf 'directory';;
							1) printf 'file';;
							0) printf 'file and directory';;
						esac
					)" \
					"$(
						[ "$sourceType" = 1 ] && printf '; such file exists';
						[ "$sourceType" = 2 ] && printf '; such directory exists';
					)" \
					"$sourcePath";
			fi

			return 5;
		fi

		#########################
		# Check the destination #
		#########################

		# If destination existence is not ignored and such element already exists
		if [ "$ignoreDestination" = 0 ] && [ "$destinationType" != 0 ] # If such already exists
		then
			if [ "$verbose" != 0 ];
			then
				Misc_PrintF -v 2 -t 'e' -nf $'Couldn\'t %s %s (%ssuch destination %s exists): \'%s\'' -- \
					"$( 
						case "$operationType" in
							2) printf 'move';;
							1) printf 'copy';;
							0) printf 'rename';;
						esac
					)" \
					"$(
						case "$sourceType" in
							2) printf 'directory';;
							1) printf 'file';;
						esac
					)" \
					"$( [ "$elementType" = 0 ] && printf 'regardlessly; ' )" \
					"$(
						[ "$destinationType" = 1 ] && printf 'file';
						[ "$destinationType" = 2 ] && printf 'directory';
					)" \
					"$destinationPath";
			fi

			return 6;
		fi

		declare destinationWasDeleted=0;

		# If such element already exists
		if [ "$destinationType" != 0 ];
		then
			# If ignore directory internals
			if [ "$ignoreDestination" = 2 ];
			then
				Base_FsDelete -f -- "$destinationPath";
				declare deleteResult=$?;
			else
				Base_FsDelete -- "$destinationPath";
				declare deleteResult=$?;
			fi

			# If couldn't delete the element
			if [ "$deleteResult" != 0 ];
			then
				if [ "$verbose" != 0 ];
				then
					Misc_PrintF -v 2 -t 'e' -nf $'Couldn\'t %s %s (%sfailed to remove destination%s%s): \'%s\' -> \'%s\'' -- \
						"$( 
							case "$operationType" in
								2) printf 'move';;
								1) printf 'copy';;
								0) printf 'rename';;
							esac
						)" \
						"$(
							case "$sourceType" in
								2) printf 'directory';;
								1) printf 'file';;
							esac
						)" \
						"$( [ "$elementType" = 0 ] && printf 'regardlessly; ' )" \
						"$(
							case "$destinationType" in
								2) printf 'directory';;
								1) printf 'file';;
							esac
						)" \
						"$( [ "$deleteResult" = 2 ] && printf '; not empty or accessible' || printf '; code %s' "$deleteResult" )" \
						"$sourcePath" \
						"$destinationPath";
				fi

				return 7;
			fi

			declare destinationWasDeleted=1;
		fi

		###########
		# Proceed #
		###########

		case "$operationType" in
			2|0) # Move or rename
				mv "$sourcePath" "$destinationPath" &>> "$_Main_Dump";
				declare returnCodeTemp=$?;
			;;
			1) # Copy
				cp -r "$sourcePath" "$destinationPath" &>> "$_Main_Dump";
				declare returnCodeTemp=$?;
			;;
		esac

		##########
		# Verify #
		##########

		if Base_FsExists -t 2 -- "$sourcePath";
		then
			declare sourceProcessedType=2;
		elif Base_FsExists -t 1 -- "$sourcePath";
		then
			declare sourceProcessedType=1;
		else
			declare sourceProcessedType=0;
		fi

		if Base_FsExists -t 2 -- "$destinationPath";
		then
			declare destinationProcessedType=2;
		elif Base_FsExists -t 1 -- "$destinationPath";
		then
			declare destinationProcessedType=1;
		else
			declare destinationProcessedType=0;
		fi

		# If failed to move or file or directory doesn't exist (respectively to "elementType")
		if 
			[ "$returnCodeTemp" != 0 ] || \
			(
				(
					# If "move" or "rename" operation and the source exists or destination doesn't exist
					[ "$operationType" != 1 ] && ( [ "$sourceProcessedType" != 0 ] || [ "$destinationProcessedType" = 0 ] )
				) ||
				(
					# If "copy" opertaion and the source or destination doesn't exist
					[ "$operationType" = 1 ] && ( [ "$sourceProcessedType" = 0 ] || [ "$destinationProcessedType" = 0 ] )
				)
			);
		then
			if [ "$verbose" != 0 ];
			then
				Misc_PrintF -v 2 -t 'e' -nf $'Failed to %s %s (%scode %s): \'%s\' -> \'%s\'' -- \
					"$( 
						case "$operationType" in
							2) printf 'move';;
							1) printf 'copy';;
							0) printf 'rename';;
						esac
					)" \
					"$(
						case "$sourceType" in
							2) printf 'directory';;
							1) printf 'file';;
						esac
					)" \
					"$( [ "$elementType" = 0 ] && printf 'regardlessly; ' )" \
					"$returnCodeTemp" \
					"$sourcePath" \
					"$destinationPath";
			fi

			return 8;
		fi

		# Moved

		if [ "$verbose" != 0 ];
		then
			Misc_PrintF -v 4 -t 's' -nf $'%s %s: \'%s\' -> \'%s\'' -- \
				"$( 
					case "$operationType" in
						2) printf 'Moved';;
						1) printf 'Copied';;
						0) printf 'Renamed';;
					esac
				)" \
				"$(
					[ "$sourceType" = 1 ] && printf 'file';
					[ "$sourceType" = 2 ] && printf 'directory';
					( [ "$elementType" = 0 ] || [ "$destinationWasDeleted" = 1 ] ) && printf ' (';
					[ "$elementType" = 0 ] && printf 'regardlessly';
					( [ "$elementType" = 0 ] && [ "$destinationWasDeleted" = 1 ] ) && printf '; ';
					[ "$destinationWasDeleted" = 1 ] && printf 'deleted destination%s' "$( [ "$ignoreDestination" = 2 ] && printf ' (ignored non-empty)' )";
					( [ "$elementType" = 0 ] || [ "$destinationWasDeleted" = 1 ] ) && printf ')';
				)" \
				"$sourcePath" \
				"$destinationPath";
		fi
	done

	return 0;
}

# Description: File system element delete
# 
# Options:
#	-t (argument) - Element type to process (0 - any (default), 1 - file, 2 - directory)
#	-e (flag) - Check existence before deletion
#	-f (flag) - Ignore non-empty directories
#	-v (multi-flag) - Verbose
#	 * - Element paths to process
#
# Returns:
#	  0 ~ Deleted without issues
#	  1 ~ An empty path declared
#	  2 ~ No such exists (ignore disabled)
#	  3 ~ Couldn't delete a directory with elements inside (ignore disabled)
#	  4 ~ Failed to delete
#	101 ~ Prohibited path
#	200 ~ Invalid options
#
Base_FsDelete()
{
	###########
	# Options #
	###########

	declare args;

	if ! Options args \
		'@0/^[0-2adf]$/' \
		'@1/^(?:[0-9][1-9]*)?(?:\-)?(?:[0-9][1-9]*)?$/' \
		'@2/[01]/' \
		'@3/[01]/' \
		'?-t;?-d;-e;-f;-v' \
		"$@";
	then
		Misc_PrintF -v 1 -t 'f' -nf $'[Base_FsDelete] Invalid options (code %s, index %s ~ \'%s\'): \'%s\'' -- \
			"$_Options_ResultCode" \
			"$_Options_FailIndex" \
			"$_Options_ErrorMessage" \
			"$( Misc_ArrayJoin -- "$@" )";

		return 200;
	fi

	declare elementTypeToProcess="${args[0]}";
	declare depth="${args[1]}";
	declare checkExistence="${args[2]}";
	declare ignoreNonEmptyDirectories="${args[3]}";
	declare verbose="${args[4]}";
	declare paths=( "${args[@]:5}" );
	declare pathIndex;
	declare path;

	case "$elementTypeToProcess"
	in
		''|'a') declare elementTypeToProcess=0;;
		'f') declare elementTypeToProcess=1;;
		'd') declare elementTypeToProcess=2;;
	esac

	########
	# Main #
	########

	declare depthMin='';
	declare depthMax='';

	if [ "$depth" != '' ];
	then
		if [[ "$depth" =~ ^[0-9][1-9]*\-[0-9][1-9]*$ ]]; # If "min-max" - min and max
		then
			depthMin="${depth%\-*}";
			depthMax="${depth#*\-}";
		elif [[ "$depth" =~ ^[0-9][1-9]*\-$ ]]; # If "min-" - only min
		then
			depthMin="${depth%\-*}";
		elif [[ "$depth" =~ ^\-[0-9][1-9]*$ ]]; # If "-max" - only max
		then
			depthMax="${depth#*\-}";
		elif [[ "$depth" =~ ^[0-9][1-9]*$ ]]; # If just a number - min=max
		then
			depthMin="${depth%\-*}";
			depthMax="$depthMin";
		fi
	fi

	# Loop through each path
	for (( pathIndex = 0; pathIndex < ${#paths[@]}; pathIndex++ ));
	do
		declare path="${paths[$pathIndex]}";

		if [[ "$path" = '' ]];
		then
			[[ "$verbose" != 0 ]] && Misc_PrintF -v 2 -t 'e' -nf $'Empty path declared to %s at %s argument. Skipped.' -- \
				"$( [[ ( "$depthMin" == '' || "$depthMin" == 0 ) ]] && printf 'delete' || printf 'alter' )" "$pathIndex";

			continue;
		fi

		# If the path exists in prohibited list
		if Misc_ArraySearch - ! "$path" "${Base_ProhibitedPaths[@]}";
		then
			[[ "$verbose" != 0 ]] && Misc_PrintF -v 2 -t 'e' -nf $'Path is prohibited to %s: \'%s\'. Skipped.' -- \
				"$( [[ ( "$depthMin" == '' || "$depthMin" == 0 ) ]] && printf 'delete' || printf 'alter' )" "$path";

			continue;
		fi

		if Base_FsExists -t 1 -- "$path";
		then
			declare elementType=1;
		elif Base_FsExists -t 2 -- "$path";
		then
			declare elementType=2;
		else
			declare elementType=0;
		fi

		# If check existence and it already doesn't exist (file, directory or both, respectively to "elementTypeToProcess")
		if	
			( [ "$elementTypeToProcess" = 2 ] && [ "$elementType" != 2 ] ) || # If delete a directory and it doesn't exist
			( [ "$elementTypeToProcess" = 1 ] && [ "$elementType" != 1 ] ) || # If delete a file and it doesn't exist
			( [ "$elementTypeToProcess" = 0 ] && [ "$elementType" = 0 ] ); # If delete any type and it doesn't exist
		then
			[[ "$verbose" != 0 ]] && Misc_PrintF \
				-v "$( [ "$checkExistence" = 1 ] && printf '2' || printf '3' )" \
				-t "$( [ "$checkExistence" = 1 ] && printf 'e' || printf 'w' )" \
				-nf $'Could not %s %s (no such exists%s): \'%s\'' -- \
				"$( [[ ( "$depthMin" == '' || "$depthMin" == 0 ) ]] && printf 'delete' || printf 'alter' )" \
				"$(
					case "$elementTypeToProcess" in
						2) printf 'directory';;
						1) printf 'file';;
						0) printf 'file and directory';;
					esac
				)" \
				"$(
					[ "$elementType" = 1 ] && printf '; such file exists';
					[ "$elementType" = 2 ] && printf '; such directory exists';
				)" \
				"$path";

			[[ "$checkExistence" == 1 ]] && return 2 || continue;
		fi

		declare wasDirectoryWithElements=0;

		# If it's a directory and the directory has elements (not empty)
		if [[ "$elementType" = 2 ]] && Base_FsDirectoryContains -- "$path" &>> "$_Main_Dump";
		then
			# If do not ignore non-empty directories
			if [[ "$ignoreNonEmptyDirectories" == 0 ]];
			then
				[[ "$verbose" != 0 ]] && Misc_PrintF -v 3 -t 'w' \
					-nf $'Could not %s directory (not empty or accessible%s): \'%s\'' -- \
					"$( [[ ( "$depthMin" == '' || "$depthMin" == 0 ) ]] && printf 'delete' || printf 'alter' )" \
					"$( [ "$elementTypeToProcess" = 0 ] && printf '; regardlessly' )" \
					"$path";

				return 3;
			fi

			wasDirectoryWithElements=1;
		fi

		# Delete

		declare argsTemp=();

		[[ "$depthMin" != '' ]] && argsTemp+=( '-mindepth' "$depthMin" );
		[[ "$depthMax" != '' ]] && argsTemp+=( '-maxdepth' "$depthMax" );

		# rm -rf "$path" &>> "$_Main_Dump";
		printf 'Removing files (%s):\n' "$path" &>> "$_Main_Dump";
		find "$path" "${argsTemp[@]}" ! -name '.' ! -name '..' -print &>> "$_Main_Dump"; # Log files
		printf -- '-----\n' &>> "$_Main_Dump";
		find "$path" "${argsTemp[@]}" ! -name '.' ! -name '..' -exec rm -rf '{}' \; &>> "$_Main_Dump";
		declare returnCodeTemp=$?;

		if Base_FsExists -t 1 -- "$path";
		then
			declare elementProcessedType=1;
		elif Base_FsExists -t 2 -- "$path";
		then
			declare elementProcessedType=2;
		else
			declare elementProcessedType=0;
		fi

		# If failed or any still exists 
		if [[ "$returnCodeTemp" != 0 || ( "$depthMin" == '' || "$depthMin" == 0 ) && "$elementProcessedType" != 0 ]];
		then
			[[ "$verbose" != 0 ]] && Misc_PrintF -v 2 -t 'e' \
				-nf $'Failed to %s %s (expected %s; code %s): \'%s\'' -- \
				"$( [[ ( "$depthMin" == '' || "$depthMin" == 0 ) ]] && printf 'delete' || printf 'alter' )" \
				"$( [[ "$elementProcessedType" == 1 ]] && printf 'file' || printf 'directory' )" \
				"$(
					case "$elementTypeToProcess"
					in
						2) printf 'directory';;
						1) printf 'file';;
						0) printf 'file or directory';;
					esac
				)" \
				"$returnCodeTemp" \
				"$path";

			return 4;
		fi

		[[ "$verbose" != 0 ]] && Misc_PrintF -v 4 -t 's' -nf $'%s %s%s: \'%s\'' -- \
			"$( [[ ( "$depthMin" == '' || "$depthMin" == 0 ) ]] && printf 'Deleted' || printf 'Altered' )" \
			"$( [[ "$elementType" == 1 ]] && printf 'file' || printf 'directory' )" \
			"$( 
				[[ "$elementType" == 1 && "$wasDirectoryWithElements" == 1 || "$elementTypeToProcess" == 0 ]] && printf ' (';
				[[ "$elementType" == 1 && "$wasDirectoryWithElements" == 1 ]] && printf 'non-empty'
				[[ "$elementType" == 1 && "$wasDirectoryWithElements" == 1 && "$elementTypeToProcess" == 0 ]] && printf '; ';
				[[ "$elementTypeToProcess" == 0 ]] && printf 'regardlessly';
				[[ "$elementType" == 1 && "$wasDirectoryWithElements" == 1 || "$elementTypeToProcess" == 0 ]] && printf ')';
			)" \
			"$path";
	done

	return 0;
}

# Description: File system element permission change
# 
# Options:
#	-t (argument) - Element type to modify (0 - any (default), 1 - file, 2 - directory)
#	-m (argument) - Mode
#	-o (argument) - Owner and/or group
#	-r (flag) - Recursive
#	-v (multi-flag) - Verbose
#	 * - Paths of elements
#
# Returns:
#	  0 ~ All declared elements modifed successfully
#	  1 ~ An empty path declared
#	  2 ~ No such element
#	  3 ~ Failed to modify the mode of an element
#	  4 ~ Failed to modify the owner and/or group of an element
#	200 ~ Invalid options
#
Base_FsPerms()
{
	###########
	# Options #
	###########

	declare args;

	if ! Options args \
		'@0/[0-2adf]/' \
		'@1/^(|[0-7]|[0-7][0-7]|[0-7][0-7][0-7]|[0-7][0-7][0-7][0-7])$/' \
		'@2/^(|[_a-z][_\-a-z0-9]*|[_a-z][_\-a-z0-9]*\:[_a-z][_\-a-z0-9]*|\:[_a-z][_\-a-z0-9]*)$/' \
		'@3/[0-1]/' \
		'?-t;?-m;?-o;-r;-v' \
		"$@";
	then
		Misc_PrintF -v 1 -t 'f' -nf $'[Base_FsPerms] Invalid options (code %s, index %s ~ \'%s\'): \'%s\'' -- \
			"$_Options_ResultCode" \
			"$_Options_FailIndex" \
			"$_Options_ErrorMessage" \
			"$( Misc_ArrayJoin -- "$@" )";

		return 200;
	fi

	declare elementTypeToProcess="${args[0]}";
	declare fsMode="${args[1]}";
	declare fsOwner="${args[2]}";
	declare recursive="${args[3]}";
	declare verbose="${args[4]}";
	declare paths=( "${args[@]:5}" );

	case "$elementTypeToProcess" in
		''|'a') declare elementTypeToProcess=0;;
		'f') declare elementTypeToProcess=1;;
		'd') declare elementTypeToProcess=2;;
	esac

	if [ "${#fsMode}" = 1 ];
	then
		declare fsMode="${fsMode}${fsMode}${fsMode}";
	fi

	########
	# Main #
	########

	if [ "$recursive" != 0 ];
	then
		declare recursiveOption='-R';
	else
		declare recursiveOption='';
	fi

	declare pathIndex;
	declare path;

	# Loop through each path
	for (( pathIndex = 0; pathIndex < ${#paths[@]}; pathIndex++ ));
	do
		declare path="${paths[$pathIndex]}";

		if [ "$path" = '' ];
		then
			if [ "$verbose" != 0 ];
			then
				Misc_PrintF -v 3 -t 'w' -nf $'Empty path declared to change permissions at %s argument' -- \
					"$pathIndex";
			fi

			return 1;
		fi

		# Remove all leading characters '/' (i.e. (/Path/To/ or /Path/To/// etc.) ~> /Path/To)
		while [ "${path: -1}" = '/' ];
		do
			declare path="${path%\/*}";
		done

		if Base_FsExists -t 1 -- "$path";
		then
			declare elementType=1;
		elif Base_FsExists -t 2 -- "$path";
		then
			declare elementType=2;
		else
			declare elementType=0;
		fi

		# If such file or directory exists
		if	
			( [ "$elementTypeToProcess" = 2 ] && [ "$elementType" != 2 ] ) || # If modify a directory and it doesn't exist
			( [ "$elementTypeToProcess" = 1 ] && [ "$elementType" != 1 ] ) || # If modify a file and it doesn't exist
			( [ "$elementTypeToProcess" = 0 ] && [ "$elementType" = 0 ] ); # If modify any type and it doesn't exist
		then
			if [ "$verbose" != 0 ];
			then
				Misc_PrintF -v 2 -t 'e' -nf $'Couldn\'t change permissions of %s (no such exists%s): \'%s\'' -- \
					"$(
						case "$elementTypeToProcess" in
							2) printf 'directory';;
							1) printf 'file';;
							0) printf 'file and directory';;
						esac
					)" \
					"$(
						[ "$elementType" = 1 ] && printf '; such file exists';
						[ "$elementType" = 2 ] && printf '; such directory exists';
					)" \
					"$path";
			fi

			return 2;
		fi

		# If a mode is declared
		if [ "$fsMode" != '' ];
		then
			if ! chmod "$fsMode" $recursiveOption -- "$path";
			then
				if [ "$verbose" != 0 ];
				then
					Misc_PrintF -v 2 -t 'e' -nf $'Failed to change %s mode (%s%s): \'%s\'' -- \
						"$(
							case "$elementType" in
								2) printf 'directory';;
								1) printf 'file';;
							esac
						)" \
						"$fsMode" \
						"$( [ "$elementTypeToProcess" = 0 ] && printf '; regardlessly' )" \
						"$path";
				fi

				return 3;
			fi

			if [ "$verbose" != 0 ];
			then
				Misc_PrintF -v 4 -t 's' -nf $'Changed %s mode (%s%s): \'%s\'' -- \
					"$(
						case "$elementType" in
							2) printf 'directory';;
							1) printf 'file';;
						esac
					)" \
					"$fsMode" \
					"$( [ "$elementTypeToProcess" = 0 ] && printf '; regardlessly' )" \
					"$path";
			fi
		fi

		# If an [owner][:group] is declared
		if [ "$fsOwner" != '' ];
		then
			if ! chown "$fsOwner" $recursiveOption -- "$path";
			then
				if [ "$verbose" != 0 ];
				then
					Misc_PrintF -v 2 -t 'e' -nf $'Failed to change %s owner and/or group (%s%s): \'%s\'' -- \
						"$(
							case "$elementType" in
								2) printf 'directory';;
								1) printf 'file';;
							esac
						)" \
						"$fsMode" \
						"$( [ "$elementTypeToProcess" = 0 ] && printf '; regardlessly' )" \
						"$path";
				fi

				return 4;
			fi

			if [ "$verbose" != 0 ];
			then
				Misc_PrintF -v 4 -t 's' -nf $'Changed %s owner and/or group (%s%s): \'%s\'' -- \
					"$(
						case "$elementType" in
							2) printf 'directory';;
							1) printf 'file';;
						esac
					)" \
					"$fsMode" \
					"$( [ "$elementTypeToProcess" = 0 ] && printf '; regardlessly' )" \
					"$path";
			fi
		fi
	done

	return 0;
}

# Description: Search for file contents
# 
# Options:
#	-p (argument) - Search RegEx pattern
#	-o (argument) - Output variable reference
#	-r (argument) - Replace RegEx pattern (rewrite)
#	-R (multi-flag) - Remove empty lines from the file:
#		1 flag - only if left by replacement; 2 flags - remove all empty lines; 3 - remove all empty lines even spaces characters
#	-v (multi-flag) - Verbose
#	 * - Paths of files
#
# Returns:
#	  0 ~ Found any match or replaced any data
#	  1 ~ Empty search pattern
#	  2 ~ No filepath declared
#	  3 ~ Invalid search RegEx pattern
#	  4 ~ Invalid replace RegEx pattern
#	  5 ~ An empty filepath declared for regex replace
#	  6 ~ No such file to regex replace
#	  7 ~ No such file to regex replace (such directory exists)
#	  8 ~ No match found and replaced
#	  9 ~ An empty filepath declared for regex search
#	 10 ~ No such file to regex search
#	 11 ~ No such file to regex search (such directory exists)
#	 12 ~ No match found
#	100 ~ Output variable reference interference
#	200 ~ Invalid options
#
# Outputs:
#	1. Output variable reference
#		1.1. If only search for matches, then 5 arrays: {ref} (matches), {ref}Indexes, {ref}Lines, {ref}Positions, {ref}Offsets
#		1.2. If replace matches, then 7 arrays: {ref} (replaced), {ref}Indexes, {ref}Lines, {ref}Positions, {ref}Offsets, {ref}SourcePositions, {ref}SourceOffsets
#
Base_FsRegexFile()
{
	declare args;
	declare argsCount;

	if ! Options args '!1' \
		'@3/[0-3]/' \
		'?!-p;?-o;?-r;-R;-v' \
		"$@";
	then
		Misc_PrintF -v 1 -t 'f' -nf $'[Base_FsRegexFile] Invalid options (code %s, index %s ~ \'%s\'): \'%s\'' -- \
			"$_Options_ResultCode" \
			"$_Options_FailIndex" \
			"$_Options_ErrorMessage" \
			"$( Misc_ArrayJoin -- "$@" )";

		return 200;
	fi

	unset patternReplace;

	declare patternSearch="${args[0]}";
	declare outputVariableReferenceName="${args[1]}";
	[ "${argsCount[2]}" != 0 ] && declare patternReplace="${args[2]}";
	declare removeEmptyLines="${args[3]}";
	declare verbose="${args[4]}";
	declare filePaths=( "${args[@]:5}" );

	if [ "$outputVariableReferenceName" != '' ];
	then
		# If the output reference matches the important variables.
		# Both the reference and temp must mismatch or else the first would cause a reference loop and the second (temp) would return an empty result
		if 
			[ "$outputVariableReferenceName" = 'Base_FsRegexFile_outputVariableReference' ] ||
			[ "$outputVariableReferenceName" = 'Base_FsRegexFile_outputVariableReferenceIndexes' ] ||
			[ "$outputVariableReferenceName" = 'Base_FsRegexFile_outputVariableReferenceLines' ] ||
			[ "$outputVariableReferenceName" = 'Base_FsRegexFile_outputVariableReferencePositions' ] ||
			[ "$outputVariableReferenceName" = 'Base_FsRegexFile_outputVariableReferenceOffsets' ]
		then
			Misc_PrintF -v 1 -t 'f' -nf $'[Base_FsRegexFile] Output variable reference interference: \'%s\'' -- \
				"$( Misc_ArrayJoin -- "$@" )";

			return 100;
		fi

		declare -n Base_FsRegexFile_outputVariableReference="$outputVariableReferenceName";
		declare -n Base_FsRegexFile_outputVariableReferenceIndexes="${outputVariableReferenceName}Indexes";
		declare -n Base_FsRegexFile_outputVariableReferenceLines="${outputVariableReferenceName}Lines";
		declare -n Base_FsRegexFile_outputVariableReferencePositions="${outputVariableReferenceName}Positions";
		declare -n Base_FsRegexFile_outputVariableReferenceOffsets="${outputVariableReferenceName}Offsets";
		Base_FsRegexFile_outputVariableReference=();
		Base_FsRegexFile_outputVariableReferenceIndexes=();
		Base_FsRegexFile_outputVariableReferenceLines=();
		Base_FsRegexFile_outputVariableReferencePositions=();
		Base_FsRegexFile_outputVariableReferenceOffsets=();
	fi

	########
	# Main #
	########

	# If no search regex pattern is provided
	if [ "${#patternSearch}" = 0 ];
	then
		if [ "$verbose" != 0 ];
		then
			Misc_PrintF -v 1 -t 'f' -nf $'Empty search pattern declared to regex %s' \
				"$( [ "${patternReplace+s}" != '' ] && printf 'replace' || printf 'search' )";
		fi

		return 1;
	fi

	# If no data is declared
	if [ "${#filePaths[@]}" = 0 ];
	then
		if [ "$verbose" != 0 ];
		then
			Misc_PrintF -v 1 -t 'f' -nf $'No file declared to regex %s' \
				"$(
					if [ "${patternReplace+s}" != '' ];
					then
						printf $'replace: \'%s\' -> \'%s\'' "$patternSearch" "$patternReplace";
					else
						printf $'search: \'%s\'' "$patternSearch";
					fi
				)";
		fi

		return 2;
	fi

	if ! Misc_RegexVerify "$patternSearch";
	then
		if [ "$verbose" != 0 ];
		then
			Misc_PrintF -v 1 -t 'f' -nf $'Invalid search regex pattern declared to %s: \'%s\'' \
				"$( [ "${patternReplace+s}" != '' ] && printf 'replace' || printf 'search' )" \
				"$patternSearch";
		fi

		return 3;
	fi

	# If a replace pattern is declared
	if [ "${patternReplace+s}" != '' ];
	then
		######################
		# Search and replace #
		######################

		if [ "$outputVariableReferenceName" != '' ];
		then
			# If the output reference matches the important variables.
			# Both the reference and temp must mismatch or else the first would cause a reference loop and the second (temp) would return an empty result
			if 
				[ "$outputVariableReferenceName" = 'Base_FsRegexFile_outputVariableReferenceSourcePositions' ] ||
				[ "$outputVariableReferenceName" = 'Base_FsRegexFile_outputVariableReferenceSourceOffsets' ]
			then
				Misc_PrintF -v 1 -t 'f' -nf $'[Base_FsRegexFile] Output variable reference interference: \'%s\'' -- \
					"$( Misc_ArrayJoin -- "$@" )";

				return 100;
			fi

			declare -n Base_FsRegexFile_outputVariableReferenceSourcePositions="${outputVariableReferenceName}SourcePositions";
			declare -n Base_FsRegexFile_outputVariableReferenceSourceOffsets="${outputVariableReferenceName}SourceOffsets";
			Base_FsRegexFile_outputVariableReferenceSourcePositions=();
			Base_FsRegexFile_outputVariableReferenceSourceOffsets=();
		fi

		export patternSearchExported="$patternSearch";
		export patternReplaceExported="$patternReplace";
		export removeEmptyLinesExported="$removeEmptyLines";

		if ! Misc_RegexVerify "$patternReplace";
		then
			if [ "$verbose" != 0 ];
			then
				Misc_PrintF -v 1 -t 'f' -nf $'Invalid replace regex pattern declared: \'%s\'' \
					"$patternReplace";
			fi

			return 4;
		fi

		# Patterns are valid

		# declare replaceCount=0;
		declare replaces=();
		declare filePathIndex;

		for (( filePathIndex = 0; filePathIndex < ${#filePaths[@]}; filePathIndex++ ));
		do
			declare filePath="${filePaths[$filePathIndex]}";

			if [ "$filePath" = '' ];
			then
				if [ "$verbose" != 0 ];
				then
					Misc_PrintF -v 3 -t 'w' -nf $'Empty filepath declared for regex replace at %s argument' -- "$filePathIndex";
				fi

				return 5;
			fi

			# Remove all leading characters '/' (i.e. (/Path/To/ or /Path/To/// etc.) ~> /Path/To)
			while [ "${filePath: -1}" = '/' ];
			do
				declare filePath="${filePath%\/*}";
			done

			# If such file or directory exists
			if Base_FsExists -t 2 -- "$filePath";
			then
				declare fileType=2;
			elif Base_FsExists -t 1 -- "$filePath";
			then
				declare fileType=1;
			else
				declare fileType=0;
			fi

			# If no such file or such directory exists
			if [ "$fileType" != 1 ];
			then
				if [ "$verbose" != 0 ];
				then
					Misc_PrintF -v 2 -t 'e' \
						-nf $'Couldn\'t regex replace file (no such exists%s): \'%s\'' -- \
						"$( [ "$fileType" = 2 ] && printf '; such directory exists' )" \
						"$filePath";
				fi

				[ "$fileType" = 0 ] && return 6 || return 7;
			fi

			declare replaceRaw;
			declare replaceIndex=0;

			# Process the regex operation and loop through every found match
			while IFS= read -r replaceRaw; # i.e. L:Ps:Os:Pr:Or:{match}
			do
				# Add the match to the array
				replaces+=( "${filePathIndex}:${replaceRaw}" );

				if [[ "$verbose" != 0 ]] && Misc_Verbosity 5;
				then
					declare replaceLine="${replaceRaw%%\:*}"; # L:Ps:Os:Pr:Or:{match} ~> L

					declare replace="${replaceRaw#*\:}"; # L:Ps:Os:Pr:Or:{match} ~> Ps:Os:Pr:Or:{match}
					declare replaceSourcePosition="${replace%%\:*}"; # Ps:Os:Pr:Or:{match} ~> Ps

					declare replace="${replace#*\:}"; # Ps:Os:Pr:Or:{match} ~> Os:Pr:Or:{match}
					declare replaceSourceOffset="${replace%%\:*}"; # Os:Pr:Or:{match} ~> Os

					declare replace="${replace#*\:}"; # Os:Pr:Or:{match} ~> Pr:Or:{match}
					declare replacePosition="${replace%%\:*}"; # Pr:Or:{match} ~> Pr

					declare replace="${replace#*\:}"; # Pr:Or:{match} ~> Or:{match}
					declare replaceOffset="${replace%%\:*}"; # Or:{match} ~> Or

					declare replace="${replace#*\:}"; # Or:{match} ~> {match}

					Misc_PrintF -v 5 -t 'd' -nf $'Replaced %s match at [%4s,%4s,%4s,%4s,%4s] in %s/%s file using regex patterns(\'%s\' -> \'%s\'): \'%s\'%s' -- \
						"$(( replaceIndex + 1 ))" \
						"$replaceLine" \
						"$replaceSourcePosition" \
						"$replaceSourceOffset" \
						"$replacePosition" \
						"$replaceOffset" \
						"$(( filePathIndex + 1 ))" \
						"${#filePaths[@]}" \
						"$patternSearch" \
						"$patternReplace" \
						"${replace:0:20}" \
						"$( (( "${#replace}" > 20 )) && printf '...' )";
				fi

				declare replaceIndex=$(( replaceIndex + 1 ));
			done \
			< <( # i.e. L:Ps:Os:Pr:Or:{match}
				perl -nli"$createBackup" -e \
					$'
						$line = $_;
						$offsetStart;

						$patternDiff=((length $ENV{patternSearchExported}) - (length $ENV{patternReplaceExported}));
						$count=0;

						while (s/$ENV{patternSearchExported}/$ENV{patternReplaceExported}/)
						{
							$positionSource=($-[0] + $count * $patternDiff);
							print STDOUT join ":", $., $positionSource, ($offsetStart + $positionSource), $-[0], ($offsetStart + $-[0]), $&;
							$count++;
						}

						if (
							$ENV{removeEmptyLinesExported} == 1 && length $line && /^$/ ||
							$ENV{removeEmptyLinesExported} == 2 && /^$/ ||
							$ENV{removeEmptyLinesExported} == 3 && /^\s*$/
						)
						{
							next; # Skip removed or initially empty line
						}

						print $_;

						$offsetStart = tell;
					' \
					"$filePath" 2>> "$_Main_Dump";
			);

			if [ "$verbose" != 0 ];
			then
				Misc_PrintF -v 4 -t 's' -nf $'Replaced %s matches in total using regex pattern (\'%s\' -> \'%s\') in file %s/%s: \'%s\'' -- \
					"${#replaces[@]}" \
					"$patternSearch" \
					"$patternReplace" \
					"$(( filePathIndex + 1 ))" \
					"${#filePaths[@]}" \
					"$filePath";
			fi

			# declare replaceCount="$(( replaceCount + ${#replaces[@]} ))";
		done

		unset patternSearchExported;
		unset patternReplaceExported;
		unset removeEmptyLinesExported;

		# If no output reference variable is declared
		if [ "$outputVariableReferenceName" = '' ];
		then
			# If did not replace any (no match)
			if [ "${#replaces[@]}" = 0 ];
			then
				return 8;
			fi

			return 0;
		fi

		# Requested to store the results in referenced variables

		declare replaceIndex;

		# Loop through every match
		for (( replaceIndex = 0; replaceIndex < "${#replaces[@]}"; replaceIndex++ ));
		do
			declare replaceRaw="${replaces[$replaceIndex]}"; # I:L:Ps:Os:Pr:Or:{match}

			declare replaceFileIndex="${replaceRaw%%\:*}"; # I:L:Ps:Os:Pr:Or:{match} ~> I

			declare replace="${replaceRaw#*\:}"; # I:L:Ps:Os:Pr:Or:{match} ~> L:Ps:Os:Pr:Or:{match}
			declare replaceLine="${replace%%\:*}"; # L:Ps:Os:Pr:Or:{match} ~> L

			declare replace="${replace#*\:}"; # L:Ps:Os:Pr:Or:{match} ~> Ps:Os:Pr:Or:{match}
			declare replaceSourcePosition="${replace%%\:*}"; # Ps:Os:Pr:Or:{match} ~> Ps

			declare replace="${replace#*\:}"; # Ps:Os:Pr:Or:{match} ~> Os:Pr:Or:{match}
			declare replaceSourceOffset="${replace%%\:*}"; # Os:Pr:Or:{match} ~> Os

			declare replace="${replace#*\:}"; # Os:Pr:Or:{match} ~> Pr:Or:{match}
			declare replacePosition="${replace%%\:*}"; # Pr:Or:{match} ~> Pr

			declare replace="${replace#*\:}"; # Pr:Or:{match} ~> Or:{match}
			declare replaceOffset="${replace%%\:*}"; # Or:{match} ~> Or

			declare replace="${replace#*\:}"; # Or:{match} ~> {match}

			# Add the match data to the result arrays
			Base_FsRegexFile_outputVariableReference+=( "$replace" );
			Base_FsRegexFile_outputVariableReferenceIndexes+=( "$replaceFileIndex" );
			Base_FsRegexFile_outputVariableReferenceLines+=( "$replaceLine" );
			Base_FsRegexFile_outputVariableReferenceSourcePositions+=( "$replaceSourcePosition" );
			Base_FsRegexFile_outputVariableReferenceSourceOffsets+=( "$replaceSourceOffset" );
			Base_FsRegexFile_outputVariableReferencePositions+=( "$replacePosition" );
			Base_FsRegexFile_outputVariableReferenceOffsets+=( "$replaceOffset" );
		done

		# If did not replace any (no match)
		if [ "${#replaces[@]}" = 0 ];
		then
			return 8;
		fi

		return 0;
	fi

	##########
	# Search #
	##########

	export patternSearchExported="$patternSearch";

	# Patterns are valid

	# declare matchCount=0;
	declare matches=();
	declare filePathIndex;

	for (( filePathIndex = 0; filePathIndex < ${#filePaths[@]}; filePathIndex++ ));
	do
		declare filePath="${filePaths[$filePathIndex]}";

		if [ "$filePath" = '' ];
		then
			if [ "$verbose" != 0 ];
			then
				Misc_PrintF -v 3 -t 'w' -nf $'Empty filepath declared for regex search at %s argument' -- "$filePathIndex";
			fi

			return 9;
		fi

		# Remove all leading characters '/' (i.e. (/Path/To/ or /Path/To/// etc.) ~> /Path/To)
		while [ "${filePath: -1}" = '/' ];
		do
			declare filePath="${filePath%\/*}";
		done

		# If such file or directory exists
		if Base_FsExists -t 2 -- "$filePath";
		then
			declare fileType=2;
		elif Base_FsExists -t 1 -- "$filePath";
		then
			declare fileType=1;
		else
			declare fileType=0;
		fi

		# If no such file or such directory exists
		if [ "$fileType" != 1 ];
		then
			if [ "$verbose" != 0 ];
			then
				Misc_PrintF -v 2 -t 'e' \
					-nf $'Couldn\'t regex search file (no such exists%s): \'%s\'' -- \
					"$( if [ "$fileType" = 2 ]; then printf '%s' '; such directory exists'; fi )" \
					"$filePath";
			fi

			[ "$fileType" = 0 ] && return 10 || return 11;
		fi

		# declare matches=();
		declare matchRaw;
		declare matchIndex=0;

		# Process the regex operation and loop through every found match
		while IFS= read -r matchRaw # i.e. L:P:O:{match}
		do
			# Add the match to the array
			matches+=( "${filePathIndex}:${matchRaw}" );

			if [[ "$verbose" != 0 ]] && Misc_Verbosity 5;
			then
				declare matchLine="${matchRaw%%\:*}"; # L:P:O:{match} ~> L

				declare match="${matchRaw#*\:}"; # L:P:O:{match} ~> P:O:{match}
				declare matchPosition="${match%%\:*}"; # P:O:{match} ~> P

				declare match="${match#*\:}"; # P:O:{match} ~> O:{match}
				declare matchOffset="${match%%\:*}"; # O:{match} ~> O

				declare match="${match#*\:}"; # O:{match} ~> {match}

				Misc_PrintF -v 5 -t 'd' -nf $'Found %s match at [%4s,%4s,%4s] in %s/%s file using a regex pattern(\'%s\'): \'%s\'%s' -- \
					"$(( matchIndex + 1 ))" \
					"$matchLine" \
					"$matchPosition" \
					"$matchOffset" \
					"$(( matchFileIndex + 1 ))" \
					"${#filePaths[@]}" \
					"$patternSearch" \
					"${match:0:20}" \
					"$( (( "${#match}" > 20 )) && printf '...' )";
			fi

			declare matchIndex=$(( matchIndex + 1 ));
		done \
		< <( # i.e. L:P:B:{match}
			perl -nle \
				$'
					$line=$_;
					$o;

					while (/$ENV{patternSearchExported}/g)
					{
						print join ":", $., $-[0], $o + $-[0], $&;
					}

					$o = tell;
				' \
				< "$filePath" 2>> "$_Main_Dump";
		);

		# declare matchLineCount="${#matches[@]}";

		if [ "$verbose" != 0 ];
		then
			Misc_PrintF -v 4 -t 's' -nf $'Found %s match(es) in total using a regex pattern (\'%s\') in the file %s/%s: \'%s\'' -- \
				"${#matches[@]}" \
				"$patternSearch" \
				"$(( filePathIndex + 1 ))" \
				"${#filePaths[@]}" \
				"$filePath";
		fi
	done

	# If no output reference variable is declared
	if [[ "$outputVariableReferenceName" == '' ]];
	then
		# If did not find any match
		if [ "${#matches[@]}" = 0 ];
		then
			return 12;
		fi

		return 0;
	fi

	# Requested to store the results in a referenced variable
	
	declare matchIndex;

	# Loop through every match
	for (( matchIndex = 0; matchIndex < ${#matches[@]}; matchIndex++ ));
	do
		declare matchRaw="${matches[$matchIndex]}"; # I:L:P:O:{match}

		declare matchFileIndex="${matchRaw%%\:*}"; # I:L:P:O:{match} ~> I

		declare match="${matchRaw#*\:}"; # I:L:P:O:{match} ~> L:P:O:{match}
		declare matchLine="${match%%\:*}"; # L:P:O:{match} ~> L

		declare match="${match#*\:}"; # L:P:O:{match} ~> P:O:{match}
		declare matchPosition="${match%%\:*}"; # P:O:{match} ~> P

		declare match="${match#*\:}"; # P:O:{match} ~> O:{match}
		declare matchOffset="${match%%\:*}"; # O:{match} ~> O

		declare match="${match#*\:}"; # O:{match} ~> {match}

		# Add the match data to the result arrays
		Base_FsRegexFile_outputVariableReference+=( "$match" );
		Base_FsRegexFile_outputVariableReferenceIndexes+=( "$matchFileIndex" );
		Base_FsRegexFile_outputVariableReferenceLines+=( "$matchLine" );
		Base_FsRegexFile_outputVariableReferencePositions+=( "$matchPosition" );
		Base_FsRegexFile_outputVariableReferenceOffsets+=( "$matchOffset" );

		# matchLength="${#match}";
	done

	# If did not find any match
	if [ "${#matches[@]}" = 0 ];
	then
		return 12;
	fi

	return 0;
}