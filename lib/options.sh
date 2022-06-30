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

# TODO:
# Add default values for options (e.g. similar way as option verifications ~ '@0/regex/' - #0/default/) which are set if no option provided.
# In case Option #1 is enabled, the reference "declaration" array should help indicating whether default value is set or not

############################################################
# Initials                                                 #
############################################################

#############
# Constants #
#############

declare -r _Lib_options=1;
declare -r _Options_sourceFilepath="$( readlink -e -- "${BASH_SOURCE[0]:-$0}" 2> '/dev/null'; )";
declare -r _Options_sourceDirpath="$( dirname -- "$_Options_sourceFilepath" 2> '/dev/null'; )";

[[ ! -f "$_Options_sourceFilepath" || ! -d "$_Options_sourceDirpath" ]] && exit 199;

declare -r Options_errorMessages=(
	$'Pattern duplicate' #1
	$'Encountered value prefixed with \'-\' character' #2
	$'Encountered empty argument' #3
	$'Not supported option' #4
	$'Encountered pattern not prefixed with \'-\'' #5
	$'Empty pattern' #6
	$'Encountered value for flag' #7
	$'Argument not provided' #8
	$'Encountered value prefixed with \'-\' character after \'=\' character' #9
	$'Too many switches' #10
	$'Encountered option combined with its possible value' #11
	$'Encountered empty value for flag after \'=\' character' #12
	$'Encountered \'--\' pattern' #13
	$'Too few function arguments' #14
	$'Required option not provided' #15
	$'Invalid expression declaration' # 16
	$'Expression duplicate' # 17
	$'Expression overflow' # 18
	$'Option verification failed' #19
	$'Empty pattern variant' #20
	$'Encountered \'-\' option' #21
	$'Output variable reference interference' #22
)

# Options_switchDescriptions=(
# 	$'Return an array (referece + \'Declared\') of presence of declared options (i.e. (0 0 1 1 0) for pattern string like \'?-a;?-b;?-c;-d;-e\' and options \'-c "" -d\')' #1
# 	$'Accept option-like arguments which start with the \'-\' character (i.e. \'-x arg -non-option\')' #2
# 	$'Accept argument-like options which don\'t start with the \'-\' character (i.e. \'x arg\')' #3
# 	$'Prohibit combined short options with a joined argument after the \'=\' character \'(i.e. \'-x=yz\' ~= \'-x yz\')' #4
# 	$'Prohibit combined short options with a joined argument \'(i.e. \'-fxy\' ~= \'-f -x y\' or \'-xyz\' ~= \'-x yz\' where \'-f\' is a flag)' #5
# 	$'Prohibit combined short options (i.e. \'-oxy\' ~= \'-x -y -z\')' #6
# 	$'Prohibit empty arguments (i.e. \'-x \"\"\')' #7
# 	$'Prohibit empty arguments with declared failed expression' #8
# 	$'Prohibit the prefix \'-\' in arguments \'(i.e. \'-x -y\')' #9
# 	$'Prohibit the prefix \'-\' in arguments after \'=\' character \'(i.e. \'-x=-y\')' #10
# 	$'Prohibit supplemental expressions' #11
# 	$'Skip to the next option after the first argument occurrence \'(i.e. \'-x foo -x bar --foo bar\' ~= \'-x foo --foo bar\')' #12
# 	$'Skip to the next option after the first flag occurrence \'(i.e. \'-xyx\' ~= \'-x -y\')' #13
# 	$'Disable the prefix \'-\' for splitted short options (i.e. \'-xyz\' ~= \'x y z\')' #14
# )

# Enabled switch character(after "!" char)
declare -r Options_switchEnabledChar=1;

# Default value for not declared flag
declare -r Options_flagValueDefault=0;

# Default value for not declared option value
declare -r Options_argumentValueDefault='';

# Custom first char before each option as first option after split(when multiple split from options is allowed)
declare -r Options_optionShortCombinedPrefix="-";

#############
# Variables #
#############

# Default switch values
declare Options_switches=(
	0 0 0 0 0
	0 0 0 0 0
	0 0 0 0
)

# The index of the last failed option value verification
_Options_FailIndex=-1;

# The result code
_Options_ResultCode=-1;

# Error message of the last parse
_Options_ErrorMessage='';

Options_expressions=();
Options_expressionDefault='';

############################################################
# Functions                                                #
############################################################

# Set the return code (exit code) and related global variables
Options_resultCodeSet()
{
	# If reset
	if [ "$1" = '-r' ];
	then
		_Options_ResultCode=-1;
		_Options_ErrorMessage='';

		# Reset the index of the last failed option value verification
		_Options_FailIndex=-1;

		return 0;
	fi

	_Options_ResultCode="$1";

	# If the return code (exit code) was declared and it's greater than 0
	if (( "$1" > 0 ));
	then
		_Options_ErrorMessage="${Options_errorMessages["$(( $1 - 1 ))"]}";

		# If the failed element index was declared
		if [ "$2" != '' ] && (( "$2" >= 0 ));
		then
			_Options_FailIndex="$2";
		fi
	fi

	return "$_Options_ResultCode";
}

# Check if the array contains any of the declared elements and return the first found position
Options_arrayFindElement()
{
	declare valuePositionPrint=1;

	# If requested to not print the value's position in the array
	if [ "$1" = '-' ];
	then
		declare valuePositionPrint=0;
		shift;
	fi

	# Delimiter of elements to find
	declare delimiter="";
	declare elementsToFind=( "$1" ); # Value or delimiter

	# If the delimiter is declared, meaning multiple values to find may be also declared
	if [ "${1:0:1}" = '!' ];
	then
		# Remove the first '!' from the delimiter
		declare delimiter="${1:1}";
		shift;

		# If the delimiter is empty
		if [ "$delimiter" = '' ];
		then
			return 2;
		fi

		# Fill the array with values separated by the delimiter
		IFS="$delimiter" read -ra elementsToFind <<< "$1";
	elif [ "${1:0:1}" = '%' ]; # If the char '!' may the be first character in the value
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
			if [ "$element" = "$elementToFind" ]; # If value is equal to array's element
			then
				if [ "$valuePositionPrint" = 1 ]; # If allowed, print value's position in array
				then
					if [ "$delimiter" != "" ]; # Echo value's position in values' array(if delimiter declared)
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

# Get or set switches
Options_switch()
{
	# If reset
	if [ "$1" = '-r' ];
	then
		for (( i = 0; i < "${#Options_switches[@]}"; i++ ));
		do
			Options_switches[$i]=0;
		done

		return 0;
	fi

	# If set the switches using a switch string (i.e. '0100101') (do we need a dec to bin conversion here just for comfy?)
	if [ "$1" = '-s' ];
	then
		shift;

		declare switchesString="$1";

		# If the length of switch string is longer than then the number of switches supported
		if (( ${#switchesString} > ${#Options_switches[@]} ));
		then
			return 2;
		fi

		declare i;

		# Set switches
		for (( i = 0; i < ${#Options_switches[@]}; i++ ));
		do
			if [ "${switchesString:$i:1}" = "$Options_switchEnabledChar" ];
			then
				Options_switches[$i]=1;

				continue;
			fi
			
			Options_switches[$i]=0;
		done

		return 0;
	fi

	if (( "$1" > 0 )) && (( "$1" <= "${#Options_switches[@]}" ));
	then
		declare i=$(( $1 - 1 ));

		if [ "$2" != 0 ] && [ "$2" != 1 ];
		then
			if [ "${Options_switches[$i]}" = 1 ];
			then
				return 0;
			fi

			return 1;
		else
			Options_switches[$i]="$2";
		fi
	fi
}

Options_isRegexValid()
{
	for value in "$@";
	do
		if ! IFS=' \t\n' printf '%s' "$value" | perl -ne 'eval { qr/$_/ }; die if $@;' &>> '/dev/null';
		then
			return 1;
		fi
	done

	return 0;
}

Options_regexTest()
{
	# # If variable for export is already set
	# if [ "${Options_regexTest_expressionExported+s}" != '' ];
	# then
	# 	return 2;
	# fi

	if (( "$#" < 2 ));
	then
		return 3;
	fi

	export Options_regexTest_expressionExported="$1";
	shift;

	for value in "$@";
	do
		if ! IFS=' \t\n' printf '%s' "$value" | perl -ne '/$ENV{Options_regexTest_expressionExported}/ && $MATCH++; END{exit 1 unless $MATCH > 0}' &>> '/dev/null';
		then
			unset Options_regexTest_expressionExported;

			return 1;
		fi
	done

	unset Options_regexTest_expressionExported;

	return 0;
}

# Verify option value using extended regular expressions (ERE)
Options_verify()
{
	# If reset
	if [ "$1" = '-r' ];
	then
		Options_expressions=();
		Options_expressionDefault='';
		_Options_FailIndex=-1;

		return 0;
	fi

	# If add an expression
	if [ "$1" = '-a' ];
	then
		shift;
		declare expression="$1";

		# If the last character in the expression declaration is not '/'
		if [ "${expression: -1}" != '/' ];
		then
			return 2;
		fi

		declare expressionIndex="${expression%%/*}"; # i.e. [empty] or 3
		declare expressionValue="${expression#*/}"; # i.e. [a-z]/
		declare expressionValue="${expressionValue%/*}"; # i.e. [a-z]

		# If invalid expression declaration (not in the format '/{exp}/' or 'N/{exp}/' where '{exp}' is not empty)
		if 
			( [ "$expressionIndex" != '' ] && [[ ! "$expressionIndex" =~ ^(0|[1-9][0-9]*)$ ]] ) || 
			[ "$expressionValue" = '' ] ||
			( ! Options_isRegexValid "$expressionValue" )
		then
			return 2;
		fi

		# [empty] index assumes the "default" expression
		# declare expressionIndex="$((expressionIndex - 1))";

		# If the expression already exists
		if 
			( [ "$expressionIndex" = '' ] && [ "$Options_expressionDefault" != '' ] ) ||
			( (( expressionIndex >= 0 )) && [ "${Options_expressions["$expressionIndex"]}" != '' ] )
		then
			return 3;
		fi

		# If it's the default expression
		if [ "$expressionIndex" = '' ];
		then
			Options_expressionDefault="$expressionValue";

			return 0;
		fi

		declare expressionCount="${#Options_expressions[@]}";
		declare i;

		# Change the expressions array size according to the maximum expression index declared
		for (( i = 0; i < "$(( expressionIndex - expressionCount + 1 ))"; i++ ));
		do
			Options_expressions+=( '' );
		done

		Options_expressions["$expressionIndex"]="$expressionValue";

		return 0;
	fi

	shift;
	declare valueIndex;
	declare values=( "$@" );
	_Options_FailIndex=-1;

	# If the default expression is declared
	if [ "$Options_expressionDefault" != '' ];
	then
		# Loop through all values and check both custom and default(if custom is absent) expressions
		for (( valueIndex = 0; valueIndex < "${#values[@]}"; valueIndex++ ));
		do
			declare value="${values[$valueIndex]}";

			# If the value is empty and that's allowed
			if [ "$value" = '' ] && ! Options_switch 8;
			then
				continue;
			fi

			declare customExpression="${Options_expressions[$valueIndex]}";

			# If the value doesn't doesn't coresspond to the expressions (the default expression is ignored if the custom is declared)
			if
				(
					[ "$customExpression" = '' ] && # No custom expression is declared
					[ "$Options_expressionDefault" != '' ] && # Default expression is declared
					! Options_regexTest "$Options_expressionDefault" "$value"
				) || (
					[ "$customExpression" != '' ] && # Custom expression is declared
					! Options_regexTest "$customExpression" "$value"
				);
			then
				# Set the index of the last failed option value verification
				_Options_FailIndex="$valueIndex";

				return 1;
			fi
		done

		return 0;
	fi

	# Loop only through custom expressions
	for (( valueIndex = 0; valueIndex < "${#Options_expressions[@]}"; valueIndex++ ));
	do
		declare value="${values[$valueIndex]}";

		# If the value is empty and that's allowed
		if [ "$value" = '' ] && ! Options_switch 8;
		then
			continue;
		fi

		declare customExpression="${Options_expressions[$valueIndex]}";

		# If the custom expression is empty
		if [ "$customExpression" = '' ]
		then
			continue;
		fi

		# If the value doesn't correspond to the custom expression
		if ! Options_regexTest "$customExpression" "$value";
		then
			# Set the index of the last failed option value verification
			_Options_FailIndex="$valueIndex";

			return 1;
		fi

		# unset customExpressionExported;
	done

	return 0;
}

############################################################
# Methods                                                  #
############################################################

# The main thingy
Options()
{
	# Reset the result of a parse
	Options_resultCodeSet -r;

	# If too few function arguments (no pattern and possible element) were declared
	if (( "$#" < 2 ));
	then
		Options_resultCodeSet 14;

		return "$_Options_ResultCode";
	fi

	# Set the result global variable reference
	declare outputVariableReferenceName="$1";
	shift;

	############
	# Switches #
	############

	# Reset switches
	Options_switch '-r';

	# If a switch(es) has been declared
	# Switch(es) must start with the '!' character, else ignored (i.e. '!0100101')
	if [ "${1:0:1}" = '!' ];
	then
		# Remove the '!' character at the start and try to set the switches
		if ! Options_switch -s "${1:1}";
		then
			Options_resultCodeSet 10;

			return "$_Options_ResultCode";
		fi

		shift; # Remove expression(s) or pattern(s) from declared function options
	fi

	# In case an output variable has the same name as the reference (may interfere)
	if 
		[ "$outputVariableReferenceName" = 'Options_OutputVariableReference' ] ||
		[ "$outputVariableReferenceName" = 'Options_OutputVariableReferenceTemp' ]
	then
		Options_resultCodeSet 22;

		return "$_Options_ResultCode";
	fi

	declare -n Options_OutputVariableReference="$outputVariableReferenceName";
	Options_OutputVariableReference=();

	###############
	# Expressions #
	###############

	# Reset expressions
	Options_verify -r;
	declare functionOptionIndex;

	functionOptionCount=$#;

	# Loop through each function option
	for (( functionOptionIndex = 1; functionOptionIndex < "$functionOptionCount"; functionOptionIndex++ ));
	do
		# Expression(s) must start with the '@' character, else ignored (i.e. '@3/[a-z]/')
		if [ "${1:0:1}" != '@' ];
		then
			break;
		fi

		# Remove the '@' character at the start and try to add the expression (i.e. '3/[a-z]/')
		Options_verify -a "${1:1}";
		declare expressionAddResult=$?;

		# If the expression is invalid
		if [ "$expressionAddResult" = 2 ];
		then
			Options_resultCodeSet 16 "$(( functionOptionIndex - 1 ))";

			return "$_Options_ResultCode";
		fi

		# If expression duplicate
		if [ "$expressionAddResult" = 3 ];
		then
			Options_resultCodeSet 17 "$(( functionOptionIndex - 1 ))";

			return "$_Options_ResultCode";
		fi

		# If expression exported 
		if [ "$expressionAddResult" = 4 ];
		then
			Options_resultCodeSet 17 "$(( functionOptionIndex - 1 ))";

			return "$_Options_ResultCode";
		fi

		shift; # Remove expression(s) from declared function options
	done

	############
	# Patterns #
	############

	declare patternsString="$1";
	shift;

	# A pattern may also start with the '!' char. For example, "Options '%!;-x' "$@" where "$@" includes '!' option-flag
	if [ "${patternsString:0:1}" = "%" ];
	then
		declare patternsString="${patternsString:1}";
	fi

	# If the pattern is empty
	if [ "$patternsString" = '' ];
	then
		# Set the result code to error and the index from the expressions loop which stopped at this option
		Options_resultCodeSet 6 "$(( functionOptionIndex - 1 ))";

		return "$_Options_ResultCode";
	fi

	declare doubleDashPosition="$(Options_arrayFindElement '--' "$@")"; # If "--" option exists return its position
	declare valuesAdditional=(); # Array with plain values which are after "--" option
	declare elements=( "$@" ); # Array with all options

	# If the option "--" exists then separate options and plain values(before and after "--" option)
	if [ "$doubleDashPosition" != "" ];
	then
		declare elements=( "${@:1:$doubleDashPosition}" ); # Options before "--" option
		declare valuesAdditional=( "${@:$(( doubleDashPosition + 2 ))}" ); # Options after "--" option
	fi

	declare patterns=""; # For array from all pattern(s)
	IFS=';' read -ra patterns <<< "$patternsString";

	# If too many expressions
	if (( ${#Options_expressions[@]} > ${#patterns[@]} )) && Options_switch 11;
	then
		Options_resultCodeSet 18;

		return "$_Options_ResultCode";
	fi

	declare flagPatterns=(); # For array of flags
	declare argumentOptionPatterns=(); # For array of option(s) which require(s) value
	declare pattern="";

	# Fill up separated arrays of argument option and flag patterns
	for pattern in "${patterns[@]}"; # To get all flags and options from all patterns
	do
		# If option(s) pattern expects value(after "=" char or next element) or not
		declare patternIsArgumentOption=0;

		# If "?" char is a first character in option(s) pattern then it expects value(after "=" char or next element)
		if [ "${pattern:0:1}" = "?" ]; then
			declare pattern="${pattern:1}";
			declare patternIsArgumentOption=1;
		fi

		# If the pattern is important
		if [ "${pattern:0:1}" = "!" ];
		then
			declare pattern="${pattern:1}";
		fi

		# If the pattern's first character should be "?" or "!"
		if [ "${pattern:0:1}" = "%" ];
		then
			declare pattern="${pattern:1}";
		fi

		declare patternVariants=''; # For array from loop
		IFS=':' read -ra patternVariants <<< "$pattern"; # Create an array with ":" delimiter

		# If pattern expects a value then add its element(s) to options' array else add its elemenet(s) to flags' array
		if [ "$patternIsArgumentOption" = 1 ];
		then
			argumentOptionPatterns+=("${patternVariants[@]}");
		else
			flagPatterns+=("${patternVariants[@]}");
		fi
	done

	# If found the option '--' in the pattern
	if Options_arrayFindElement '-' '--' "${flagPatterns[@]}" "${argumentOptionPatterns[@]}";
	then
		Options_resultCodeSet 13;

		return "$_Options_ResultCode";
	fi

	if 
		[ "$(printf '%s\n' "${argumentOptionPatterns[@]}" | LC_ALL=C sort | wc -l)" != "$(printf '%s\n' "${argumentOptionPatterns[@]}" | LC_ALL=C sort | uniq | wc -l)" ] || # If options' array doesn't have duplicates
		[ "$(printf '%s\n' "${flagPatterns[@]}" | LC_ALL=C sort | wc -l)" != "$(printf '%s\n' "${flagPatterns[@]}" | LC_ALL=C sort | uniq | wc -l)" ] || # If flags' array doesn't have duplicates
		[ "$(LC_ALL=C comm -1 -2  <(printf '%s\n' "${argumentOptionPatterns[@]}" | LC_ALL=C sort) <(printf '%s\n' "${flagPatterns[@]}" | LC_ALL=C sort))" != "" ]; # If both options' both flags' arrays don't have duplicates between themselves
	then
		Options_resultCodeSet 1; # Pattern duplicate

		return "$_Options_ResultCode";
	fi

	# If combined short options are allowed, then try to split them
	if ! Options_switch 6;
	then
		declare elementsTemp=(); # Temporary array of splitted multiple options from one and other options
		declare nextElementIsValue=''; # If skip option because it's a value for previous option
		declare element=''; # For split loop when splitting multiple options from one
		declare elementIndex;

		# Loop through all elements(before "--", if exists)
		for (( elementIndex = 0; elementIndex < "${#elements[@]}"; elementIndex++ ));
		do
			element="${elements[$elementIndex]}";
			declare optionName="${element%%=*}"; # Get the possible option's name

			# If it's the value for the previous option
			if [ "$nextElementIsValue" = 1 ];
			then
				elementsTemp+=("$element"); # Add an option because it's a  
				declare nextElementIsValue=0;

				continue;
			fi

			# If the option is an argument option
			if ! Options_arrayFindElement '-' "%${optionName}" "${argumentOptionPatterns[@]}";
			then
				# If the option doesn't start from the '-' character or starts with '--' characters or is not an option with the leading '=' character
				if 
					[ "${element:0:1}" != '-' ] || [ "${element:1:1}" = '-' ] ||
					[ "${element:1:1}" = '=' ] || [ "${element:2:1}" = '=' ];
				then
					elementsTemp+=( "$element" ); # Add a not combined option

					continue;
				fi

				# If encountered the option '-'
				if [ "$element" = '-' ];
				then
					Options_resultCodeSet 21 "$elementIndex";

					return "$_Options_ResultCode";
				fi
				
				# Get everything after '-' character from the element
				declare optionNameDirty="${element#-*}";

				# If the option name has only one character
				if [ "${#optionNameDirty}" = 1 ];
				then
					elementsTemp+=( "$element" ); # Add a not combined option

					continue;
				fi

				declare optionNameCharacterIndex;
				declare optionNameCharacter;
				declare optionsSplitted=(); # An array of splitted and other options

				# Loop through all characters in the option's name
				for (( optionNameCharacterIndex=0; optionNameCharacterIndex < "${#optionNameDirty}"; optionNameCharacterIndex++ ));
				do
					# Set current character
					declare optionNameCharacter="${optionNameDirty:optionNameCharacterIndex:1}";

					# If it's not the '-' character and the prefix '-' for splitted short options is enabled
					if [ "$optionNameCharacter" != '-' ] && ! Options_switch 14;
					then
						# Add the prefix to the option
						declare optionNameCharacter="${Options_optionShortCombinedPrefix}${optionNameCharacter}";
					fi

					# If the next character is '=' and combined short options with a leading "=" character and joined argument are allowed
					if [ "${optionNameDirty:$(( optionNameCharacterIndex + 1 )):1}" = "=" ] && ! Options_switch 4;
					then
						# Add the option with the leading '=' and its argument
						optionsSplitted+=("${optionNameCharacter}${optionNameDirty:$(( optionNameCharacterIndex + 1 ))}");

						break;
					fi

					# Add the short option
					optionsSplitted+=( "$optionNameCharacter" );

					# If there's such short argument option
					if Options_arrayFindElement '-' "%${optionNameCharacter}" "${argumentOptionPatterns[@]}";
					then
						# If this is the last character
						if [ "${optionNameDirty:$(( optionNameCharacterIndex + 1 ))}" = '' ];
						then
							# The next element is an argument
							declare nextElementIsValue=1;

							continue;
						fi

						# If options combined with values are allowed
						if ! Options_switch 5;
						then
							# Add the option with everything joined as its argument
							optionsSplitted+=("${optionNameDirty:$(( optionNameCharacterIndex + 1 ))}");

							break;
						fi

						# Encountered an option combined with its possible value
						Options_resultCodeSet 11 "$elementIndex";

						return "$_Options_ResultCode";
					fi
				done

				# Add splitted and other options
				elementsTemp+=("${optionsSplitted[@]}");

				continue;
			fi

			# Add a not combined option
			elementsTemp+=( "$element" );

			# If there's no leading "=" character
			if [ "${element:${#optionName}:1}" != "=" ];
			then
				# The next element is an argument
				declare nextElementIsValue=1;
			fi
		done

		# Add all splitted and other options to array of all options
		elements=( "${elementsTemp[@]}" );
	fi

	declare optionPlains=(); # An array for all plain values
	declare optionArguments=(); # An array for all option values
	unset Options_OutputVariableReferenceCountTemp;
	declare Options_OutputVariableReferenceCountTemp=(); # An array for all option presence counters
	unset Options_OutputVariableReferenceCountTotalTemp;
	declare Options_OutputVariableReferenceCountTotalTemp=0; # An array for all option presence counters
	declare checkedAllElements=''; # If already checked all elements in array(before "--", if exists)(for force next pattern(if there were plain values after last checked pattern and also all patterns were found))
	declare pattern=''; # For loop when looping through each pattern divided by ";" char
	declare patternIndex;

	# Loop through each pattern (Between ';')
	for (( patternIndex = 0; patternIndex < ${#patterns[@]}; patternIndex++ ));
	do
		# Set the option's presence counter to 0
		Options_OutputVariableReferenceCountTemp[$patternIndex]=0;
	done

	# Loop through each pattern (Between ';')
	for (( patternIndex = 0; patternIndex < ${#patterns[@]}; patternIndex++ ));
	do
		declare pattern="${patterns[$patternIndex]}";
		declare patternIsArgumentOption=0; # If option(s) pattern require(s) value
		declare patternIsImportant=0; # If option is important
		# if [ "${pattern:0:1}" = "?" ]; then pattern="${pattern:1}"; fi # If "?" char is a first character in option(s) pattern then it expects value(after "=" char or next element), so, remove it from pattern
		# declare patternIsImportant="0"; # If option is important

		if [ "${pattern:0:1}" = "?" ]; # If "?" char is a first character in option(s) pattern then it expects value(after "=" char or next element)
		then
			declare patternIsArgumentOption=1; # Option(s) pattern expects value
			declare pattern="${pattern:1}"; # Remove "?" char as first character from option(s) pattern
		fi

		if [ "${pattern:0:1}" = "!" ]; # If option is important
		then
			declare patternIsImportant=1;
			declare pattern="${pattern:1}";
		fi

		if [ "${pattern:0:1}" = "%" ]; # If pattern's first character should be "?" or "!"
		then
			declare pattern="${pattern:1}";
		fi

		declare patternVariants; # For array from loop
		IFS=':' read -ra patternVariants <<< "$pattern";
		declare optionPlainCount=0; # Current plain value's index
		declare nextElementIsValue=0; # If get value from next option inside loop
		declare skipToNextPattern=0; # If got value flag
		declare skipElement=0; # An element is a value is for previous option or not
		unset optionArgument; # Unset option's value
		declare element; # For loop
		declare elementIndex;

		# Loop through all elements(before "--", if exists)
		for (( elementIndex = 0; elementIndex < ${#elements[@]}; elementIndex++ ));
		do
			# If skip to the next option pattern and all elements were parsed
			if [ "$skipToNextPattern" = 1 ] && [ "$checkedAllElements" = 1 ];
			then
				break;
			fi

			declare element="${elements[$elementIndex]}";

			# If the previous element was an option which expects the current be a value for that option
			if [ "$nextElementIsValue" = 1 ];
			then
				# If the argument is prefixed with the '-' character and that's prohibited
				if [ "${element:0:1}" = '-' ] && Options_switch 9;
				then
					Options_resultCodeSet 2 "$elementIndex";

					return "$_Options_ResultCode";
				fi

				# If skip to the next option pattern (a value has already been set and checked)
				if [ "$skipToNextPattern" = "1" ];
				then
					break;
				fi

				declare optionArgument="$element"; # Set an actual value of the option
				declare nextElementIsValue=0; # Tell the loop that value for the option was gathered
				declare skipElement=0; # Tell the loop don't skip next option(happens when more than one option in pattern, any option in pattern had value and other option's in pattern told to skip next option because they searches in known option(s))

				# If skip to the next pattern after the first argument occurrence
				if Options_switch 12;
				then
					declare skipToNextPattern=1; # Skip to the next option pattern

					break;
				fi

				continue;
			fi

			if [ "$skipElement" = 1 ];
			then
				declare skipElement=0; # An element is a value for previous option(not current)(skip)

				continue;
			fi

			declare patternVariant=''; # For loop of options in pattern of patterns(between ":")
			unset optionPlain; # Temporary plain value

			# Loop through each pattern variant in the pattern (between ':')
			for (( patternVariantIndex = 0; patternVariantIndex < ${#patternVariants[@]}; patternVariantIndex++ ));
			do
				declare patternVariant="${patternVariants[patternVariantIndex]}";

				# If the pattern variant is empty
				if [ "$patternVariant" = "" ];
				then
					Options_resultCodeSet 20 "$patternVariantIndex";

					return "$_Options_ResultCode";
				fi

				# If the pattern variant doesn't assume a general option or an argument-like option (no '-' prefix)
				if [ "${patternVariant:0:1}" != "-" ] && ! Options_switch 3;
				then
					Options_resultCodeSet 5 "$patternVariantIndex";

					return "$_Options_ResultCode";
				fi

				case "$patternVariant" in
					"$element") # i.e. '-a'
						if [ "$patternIsArgumentOption" = "1" ]; # If pattern has "?" char at the start(which means that it requires next option be a value) then get value from next option else default value for flag
						then
							declare nextElementIsValue="1";
						else
							if [ "$skipToNextPattern" = "1" ]; # If skip to the next option pattern
							then
								break;
							fi

							# If it's the first flag occurrence
							if [ "$optionArgument" = "" ];
							then
								declare optionArgument="1"; # Set the flag's counter to 1
							else
								declare optionArgument="$(( optionArgument + 1 ))"; # Increase the flag's counter
							fi

							# If skip to next pattern after the first flag occurrence
							if Options_switch 13;
							then
								declare skipToNextPattern="1"; # Skip to the next option pattern

								break;
							fi
						fi
					;;
					"${element%%=?*}") # i.e. '-a=[value]'
						declare optionName="${element%%=*}";

						if ! Options_arrayFindElement '-' "%${optionName}" "${argumentOptionPatterns[@]}"; # If option expects value
						then
							Options_resultCodeSet 7 "$elementIndex"; # Encountered a value for a flag

							return "$_Options_ResultCode"; 
						fi

						declare optionValueTemp="${element#*=}"; # A value of option(after "=" char)

						# If the argument after the '=' character is prefixed with the '-' character and that's prohibited
						if [ "${optionValueTemp:0:1}" = "-" ] && Options_switch 10;
						then
							Options_resultCodeSet 9 "$elementIndex"; # Encountered a value prefixed with the '-' character after '=' character

							return "$_Options_ResultCode";
						fi

						if [ "$skipToNextPattern" = "1" ]; # If skip to the next option pattern
						then
							break;
						fi

						declare optionArgument="$optionValueTemp"; # Set an actual value of the option

						# If skip to next pattern after the first argument occurrence
						if Options_switch 12;
						then
							declare skipToNextPattern=1; # Skip to the next option pattern

							break;
						fi
					;;
					"${element%%=}") # i.e. '-a=[empty]'
						declare optionName="${element%%=}";

						# If such option exists in pattern(s) and expects a value
						if ! Options_arrayFindElement '-' "%${optionName}" "${argumentOptionPatterns[@]}";
						then
							Options_resultCodeSet 12 "$elementIndex"; # Encountered an empty value for a flag

							return "$_Options_ResultCode";
						fi

						# If empty arguments are prohibited
						# if Options_switch 7;
						# then
						# 	Options_resultCodeSet 3 "$elementIndex"; # Encountered an empty argument

						# 	return "$_Options_ResultCode";
						# fi

						declare optionArgument=''; # Set an actual value of the option
					;;
					*) # If it's plain value or it's not related to the currently processed pattern
						# Get the name of the option(before "=" char or whole)
						declare optionName="${element%%=*}";

						# If the element is a supported option
						if Options_arrayFindElement '-' "%${optionName}" "${argumentOptionPatterns[@]}";
						then
							# If the option assumes the next element to be its value
							if [ "${element:${#optionName}:1}" != '=' ];
							then
								# Skip the next iteration
								declare skipElement=1;
							fi
						elif ! Options_arrayFindElement '-' "%${optionName}" "${flagPatterns[@]}"; # If the element is not a supported flag
						then
							# If it's an unsupported option and option-like arguments are not allowed
							if [ "${element:0:1}" == '-' ] && ! Options_switch 2;
							then
								Options_resultCodeSet 4 "$elementIndex"; # Not supported option

								return "$_Options_ResultCode";
							fi
							
							# It is a plain value
							declare optionPlain="$element";
						fi
					;;
				esac
			done

			# If it was a plain value
			if [ "${optionPlain+s}" != '' ];
			then
				# Increase the current plain value index
				declare optionPlainCount="$(( optionPlainCount + 1 ))";

				# If the current plain value index is bigger than the plain value array length then add it to the plain value's array
				if (( optionPlainCount > ${#optionPlains[@]} ));
				then
					optionPlains+=( "$optionPlain" );
				fi
			fi
		done

		# If the argument was found (an argument or flag)
		if [ "${optionArgument+s}" != '' ];
		then
			# If the argument is not empty or it's a flag
			if [ "$optionArgument" != '' ];
			then
				# Add the value to the result array
				optionArguments+=( "$optionArgument" );
			else
				# If empty arguments are prohibited
				if Options_switch 7;
				then
					Options_resultCodeSet 3 "$patternIndex"; # Encountered an empty argument

					return "$_Options_ResultCode";
				fi

				# Add the default argument value to the result array
				optionArguments+=( "$Options_argumentValueDefault" );
			fi

			# Set/increase option presence counter (flag's value is its count in general)

			# If option counter already has value
			if [ "${Options_OutputVariableReferenceCountTemp[$patternIndex]}" != 0 ];
			then
				Options_OutputVariableReferenceCountTemp[$patternIndex]="$((Options_OutputVariableReferenceCountTemp[$patternIndex] + 1))";
			elif [ "$patternIsArgumentOption" = 1 ]; # If option is argument option type (not flag)
			then
				Options_OutputVariableReferenceCountTemp[$patternIndex]=1;
			else # If option is flag
				Options_OutputVariableReferenceCountTemp[$patternIndex]="$optionArgument";
			fi
		else
			# If the option is important
			if [ "$patternIsImportant" = 1 ];
			then
				Options_resultCodeSet 15 "$patternIndex"; # An important option was not declared

				return "$_Options_ResultCode";
			fi

			# If it's an argument option
			if [ "$patternIsArgumentOption" = 1 ];
			then
				# Add the default argument value to the result array
				optionArguments+=( "$Options_argumentValueDefault" );
			else
				# Add the default flag value to the result array
				optionArguments+=( "$Options_flagValueDefault" );
			fi
		fi

		# An argument was not declared
		if [ "$nextElementIsValue" = 1 ];
		then
			Options_resultCodeSet 8 "$patternIndex";

			return "$_Options_ResultCode";
		fi

		# Tell that the loop has already iterated through all elements (What is that ?)
		if [ "$checkedAllElements" != 1 ];
		then
			checkedAllElements=1;
		fi
	done

	# Successful parse; Save a result to a variable(firstly, option(s)' and flag(s)' values and, secondly, plain value(s)) and, finally, everything after "--" option
	unset Options_OutputVariableReferenceTemp;
	declare Options_OutputVariableReferenceTemp=( "${optionArguments[@]}" "${optionPlains[@]}" "${valuesAdditional[@]}" );

	# Verify values
	if ! Options_verify -v "${Options_OutputVariableReferenceTemp[@]}";
	then
		Options_resultCodeSet 19; # Option verification failed

		return "$_Options_ResultCode";
	fi

	# Set the result global variable
	Options_OutputVariableReference=( "${Options_OutputVariableReferenceTemp[@]}" );

	if Options_switch 1;
	then
		# In case an output variable has the same name as the reference (may interfere)
		if
			[ "$outputVariableReferenceName" = 'Options_OutputVariableReferenceCount' ] ||
			[ "$outputVariableReferenceName" = 'Options_OutputVariableReferenceCountTemp' ] ||
			[ "$outputVariableReferenceName" = 'Options_OutputVariableReferenceCountTotalTemp' ]
		then
			Options_resultCodeSet 22;

			return "$_Options_ResultCode";
		fi

		declare -n Options_OutputVariableReferenceCount="${outputVariableReferenceName}Count";
		declare -n Options_OutputVariableReferenceCountTotal="${outputVariableReferenceName}CountTotal";

		# Set the result global variable
		Options_OutputVariableReferenceCount=( "${Options_OutputVariableReferenceCountTemp[@]}" );
		unset Options_OutputVariableReferenceCountTotalTemp;
		declare Options_OutputVariableReferenceCountTotalTemp=0;
		declare optionValueCount;

		for optionValueCount in "${Options_OutputVariableReferenceCountTemp[@]}";
		do
			Options_OutputVariableReferenceCountTotalTemp="$((Options_OutputVariableReferenceCountTotalTemp + optionValueCount))";
		done

		Options_OutputVariableReferenceCountTotal="$Options_OutputVariableReferenceCountTotalTemp";
	fi

	Options_resultCodeSet 0; # Successfully parsed

	return "$_Options_ResultCode";
}
