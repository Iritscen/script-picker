#!/bin/bash

# ScriptPicker
# An interactive menu for quickly finding and setting up an invocation for one of the Unix scripts
# found in a specified directory. A table of available scripts and information about them is built
# from the specified read-me file in the same directory, and then the names of the scripts are
# checked against the file names in the read-me to ensure agreement. A menu is then offered for
# browsing the scripts by category. When a script is chosen, the invocation of said script is
# conveniently started for you on the command line.
#
# You pass the script one or more paths. Each path should point to a read-me inside a folder of
# scripts. The read-me is a Markdown-formatted file which contains metadata on the scripts beside
# it. Following is the format required for the file, modeled after the README.md that I use
# for my GitHub account's "Small scripts" repository (the surrounding box is a visual aid, not
# part of the file):
#
# /----------------------------------------------------------------------------------------------\
# |# My Script Listing										 |
# |Any text here will be ignored by SP. 							 |
# |												 |
# |## Contents - The first "##" section will be ignored by SP, but subsequent sections will be	 |
# |read in as categories of scripts.								 |
# |[Some Category of Scripts](#anchor_link_to_this_category)					 |
# |												 |
# |[Some Other Category](#anchor_link_to_it)							 |
# |												 |
# |## Some Category of Scripts - All "##" sections from here on will be read by SP.		 |
# |### [Some Script of Mine](link_to_file_in_repo.sh)						 |
# |<!--Explanation of first parameter that script takes.					 |
# |Explanation of second parameter. This text does not show in GitHub's Markdown implementation  |
# |and is only read by SP.-->									 |
# |Short description of the script, both for the read-me and for SP to display in the menu.	 |
# |												 |
# |### [Another Script](another_script.sh)							 |
# |<!--(none) - Type "(none)" to tell SP that there are no parameters taken by this script.-->   |
# |Description of this script.									 |
# |												 |
# |## Some Other Category									 |
# |[etc.]											 |
# \----------------------------------------------------------------------------------------------/
#
# Recommended width:
# |---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ----|

IFS="
"
shopt -s nocasematch

## VARIABLES ##
# Mode: 0 = normal operation, 1 = print script table parsed from read-me and then quit, 2 =
# perform reconciliation of script dir. to read-me and then quit
DEBUG_MODE=0

# Constants
ESCAPE_CHAR=$(printf "\x1b")
ENTER_CHAR=$(printf "\x0a")
PARAM_SPACE=" "
COLS=$(tput cols)

# Storage for categories of scripts and number of scripts by category
declare -a CAT_NAMES=()
NUM_CATS=0
declare -a NUM_SCRS=()

# Declare parallel arrays for holding a table of info about my scripts, read in from read-me. None
# of my scripts currently have more than 5 parameters, but if a script is encountered which does,
# this script will warn the user when it builds the table.
declare -a SCR_CATS=()
declare -a SCR_NAMES=()
declare -a SCR_FILES=()
declare -a SCR_PARAMS1=()
declare -a SCR_PARAMS2=()
declare -a SCR_PARAMS3=()
declare -a SCR_PARAMS4=()
declare -a SCR_PARAMS5=()
declare -a SCR_DESCS=()

# State variables
declare -a CUR_CHOICE=(0 -1)
LOW_SCR=0
HIGH_SCR=0
INPUT_FIRST_BYTE=""
INPUT_MORE_BYTES=""
MENU_DONE=0
QUIT_SCRIPT=0

## ARGUMENT PROCESSING ##
declare -a README_PATHS=()
while (( "$#" )); do
   if [ ! -d "$(dirname $1)" ]; then
      echo "Did not find a directory at '$(dirname $1)'. Is that really where your scripts are? Exiting."
      exit
   fi

   if [ ! -f "$1" ]; then
      echo "Did not find a file at path '$1'. Is that really where your script listing is? Exiting."
      exit
   fi

   README_PATHS+=("$1")
   shift
done

## FUNCTIONS ##
# Build script table by parsing read-me at the path that's passed in
function collectScripts()
{
   README_PATH="$1"
   PASSED_CONTENTS=0
   READING_IN=""

   for THE_LINE in `cat "$README_PATH"`; do
      # If this is a category line, read it in. Skip past the first "##" line, which is the table
      # of contents
      if [[ $THE_LINE =~ ^"## " ]]; then
         if [ $PASSED_CONTENTS -eq 0 ]; then
            PASSED_CONTENTS=1
            continue
         else
            let NUM_CATS+=1
            CAT_NAMES+=("${THE_LINE//## /}")
            NUM_SCRS[$((NUM_CATS - 1))]=0
         fi
      fi

      # If we found the start of a script listing, record what category it's under, then record
      # script name and file name
      if [[ $THE_LINE =~ ^"### " ]]; then
         SCR_CATS+=($((NUM_CATS - 1)))
         let NUM_SCRS[$((NUM_CATS - 1))]+=1
         SCR_NAME=$(echo "$THE_LINE" | sed 's/### \[//' | sed 's/\].*//')
         SCR_NAMES+=($SCR_NAME)
         SCR_FILE=$(echo "$THE_LINE" | sed 's/.*(//' | sed 's/)//')
         SCR_FILES+=($SCR_FILE)
         READING_IN="param1"
         continue
      fi

      # If the last thing we read in was the script name and file name, parameters should be next
      if [ "$READING_IN" == "param1" ]; then
         if [[ ! $THE_LINE =~ "<!--" ]]; then
            echo "Did not find start of parameter listing where it was expected! Line was '$THE_LINE'"
            exit
         fi
      
         SCR_PARAM=$(echo "$THE_LINE" | sed 's/<!--//' | sed 's/-->//')
         SCR_PARAMS1+=($SCR_PARAM)

         if [[ $THE_LINE =~ "-->" ]]; then
            READING_IN="desc"
            SCR_PARAMS2+=("")
            SCR_PARAMS3+=("")
            SCR_PARAMS4+=("")
            SCR_PARAMS5+=("")
         else
            READING_IN="param2"
         fi
         continue
      fi

      # Read in further params
      if [ "$READING_IN" == "param2" ]; then
         SCR_PARAM=$(echo "$THE_LINE" | sed 's/-->//')
         SCR_PARAMS2+=($SCR_PARAM)

         if [[ $THE_LINE =~ "-->" ]]; then
            READING_IN="desc"
            SCR_PARAMS3+=("")
            SCR_PARAMS4+=("")
            SCR_PARAMS5+=("")
         else
            READING_IN="param3"
         fi
         continue
      fi

      # Read in further params
      if [ "$READING_IN" == "param3" ]; then
         SCR_PARAM=$(echo "$THE_LINE" | sed 's/-->//')
         SCR_PARAMS3+=($SCR_PARAM)

         if [[ $THE_LINE =~ "-->" ]]; then
            READING_IN="desc"
            SCR_PARAMS4+=("")
            SCR_PARAMS5+=("")
         else
            READING_IN="param4"
         fi
         continue
      fi

      # Read in further params
      if [ "$READING_IN" == "param4" ]; then
         SCR_PARAM=$(echo "$THE_LINE" | sed 's/-->//')
         SCR_PARAMS4+=($SCR_PARAM)

         if [[ $THE_LINE =~ "-->" ]]; then
            READING_IN="desc"
            SCR_PARAMS5+=("")
         else
            READING_IN="param5"
         fi
         continue
      fi

      # Read in further params
      if [ "$READING_IN" == "param5" ]; then
         SCR_PARAM=$(echo "$THE_LINE" | sed 's/-->//')
         SCR_PARAMS5+=($SCR_PARAM)

         if [[ $THE_LINE =~ "-->" ]]; then
            READING_IN="desc"
         else
            echo "Too many parameters encountered for script $SCR_NAME!"
            exit
         fi
         continue
      fi

      # If we finished reading in the parameters, the description is next
      if [ "$READING_IN" == "desc" ]; then
         SCR_DESCS+=($THE_LINE)
         READING_IN=""
      fi
   done
}

# Checks file names collected from read-me against the actual scripts in the directory to make
# sure that there are no discrepancies
function compareTableToDir()
{
   README_WARN=0
   DIR_WARN=0

   # Check for scripts listed in read-me that don't exist
   a=0
   while [ "x${SCR_FILES[$a]}" != "x" ]; do # if this evaluates to "x", the array is done
      # Look in each script directory
      b=0
      FOUND=0
      while [ "x${README_PATHS[$b]}" != "x" ]; do
         SCRIPT_DIR="$(dirname ${README_PATHS[$b]})"
         #echo "Looking for read-me's $(basename $SCRIPT_DIR/${SCR_FILES[$a]}) on disk..."
         if [ -f "$SCRIPT_DIR/${SCR_FILES[$a]}" ]; then
            FOUND=1
            break
         fi
         let b+=1
      done
      if [ $FOUND -eq 0 ]; then
         if [ $README_WARN == 0 ]; then
            echo "Present in read-me but missing from script directory:"
            README_WARN=1
         fi
         echo ${SCR_FILES[$a]}
      fi
      let a+=1
   done

   # Check for scripts in script dir.s that aren't listed in read-me
   a=0
   while [ "x${README_PATHS[$a]}" != "x" ]; do
      SCRIPT_DIR="$(dirname ${README_PATHS[$a]})"
      for THE_SCRIPT in `find "$SCRIPT_DIR" -maxdepth 1 | grep .sh$`; do
         SCR_NAME=$(echo "$THE_SCRIPT" | sed 's/.*\///') # clip file name from whole path
         # Look in each read-me
         b=0
         FOUND=0
         while [ "x${README_PATHS[$b]}" != "x" ]; do
            #echo "Looking for $(basename $THE_SCRIPT) in read-me $README_PATH..."
            README_PATH="${README_PATHS[$b]}"
            RESULT=`cat "$README_PATH" | grep --max-count=1 "$SCR_NAME"`
            RESULT_CHARS=`echo -n "$RESULT" | wc -c`
            if [ "$RESULT_CHARS" -ge 2 ]; then
               FOUND=1
               break
            fi
            let b+=1
         done
         if [ $FOUND -eq 0 ]; then
            if [ $DIR_WARN -eq 0 ]; then
               echo "Present in script directory but missing from read-me:"
               DIR_WARN=1
            fi
            echo $SCR_NAME
         fi
      done
      let a+=1
   done

   if [ $README_WARN -eq 1 ] || [ $DIR_WARN -eq 1 ]; then
      QUIT_SCRIPT=1
   fi
}

# Print out parameters of the number of the script passed in, and clear $PARAM_SPACE if no
# parameters exist for the function
function printParams()
{
   # Set up one or two space characters depending on what was requested for alignment purposes
   PCS=" "
   if [ $2 -eq 1 ]; then
      PCS="  "
   fi

   if [ ${SCR_PARAMS1[$1]} == "(none)" ]; then
      echo "This script has no parameters."
      PARAM_SPACE=""
   else
      echo "Param 1:${PCS}${SCR_PARAMS1[$1]}" | fmt -w $COLS
      if [ ! -z ${SCR_PARAMS2[$1]} ]; then
         echo "Param 2:${PCS}${SCR_PARAMS2[$1]}" | fmt -w $COLS
      fi
      if [ ! -z ${SCR_PARAMS3[$1]} ]; then
         echo "Param 3:${PCS}${SCR_PARAMS3[$1]}" | fmt -w $COLS
      fi
      if [ ! -z ${SCR_PARAMS4[$1]} ]; then
         echo "Param 4:${PCS}${SCR_PARAMS4[$1]}" | fmt -w $COLS
      fi
      if [ ! -z ${SCR_PARAMS5[$1]} ]; then
         echo "Param 5:${PCS}${SCR_PARAMS5[$1]}" | fmt -w $COLS
      fi
   fi
}

# Print out full database of scripts that was loaded by collectScripts()
function printScripts()
{
   echo "Found these categories:"
   a=0
   while [ "x${CAT_NAMES[$a]}" != "x" ]; do
      echo "Category: ${CAT_NAMES[$a]}"
      echo "Count:    ${NUM_SCRS[$a]}"
      echo
      let a+=1
   done

   echo "Found these scripts:"
   a=0
   while [ "x${SCR_CATS[$a]}" != "x" ]; do
      echo "Category: ${CAT_NAMES[${SCR_CATS[$a]}]}"
      echo "Name:     ${SCR_NAMES[$a]}"
      echo "File:     ${SCR_FILES[$a]}"
      printParams $a 1
      echo "Descrip:  ${SCR_DESCS[$a]}" | fmt -w $COLS
      echo
      let a+=1
   done
}

# Draws title of script and user instructions
function drawMenuTitle()
{
   echo "--ScriptPicker--" | fmt -w $COLS -c # centered text
   echo "Select a $1 by using the arrow keys or A-Z and choose it with Enter, or press spacebar to quit:" | fmt -w $COLS
}

# Draws all script categories, all scripts under currently-selected category, and description of
# currently-selected script
function drawMenuBody()
{
   a=0
   while [ "x${CAT_NAMES[$a]}" != "x" ]; do
      if [ $a -eq ${CUR_CHOICE[0]} ]; then
         echo "$(tput rev)-${CAT_NAMES[$a]}-$(tput sgr0)"
      else
         echo "-${CAT_NAMES[$a]}-"
      fi
      let a+=1
   done
   echo "----------------------------------------"
   a=0
   while [ "x${SCR_CATS[$a]}" != "x" ]; do
      if [ ${SCR_CATS[$a]} -eq ${CUR_CHOICE[0]} ]; then
         if [ $a -eq ${CUR_CHOICE[1]} ]; then
            echo "$(tput rev)${SCR_NAMES[$a]}$(tput sgr0)"
         else
            echo "${SCR_NAMES[$a]}"
         fi
      fi
      let a+=1
   done
   echo "----------------------------------------"
   if [ ${CUR_CHOICE[1]} -gt -1 ]; then
      echo "${SCR_DESCS[${CUR_CHOICE[1]}]}" | fmt -w $COLS
   fi
}

# Handles input for category or script menu, depending on 2nd parameter passed in. Parameters:
# - Word for what is being picked
# - Index for CUR_CHOICE[]
# - Minimum index item
# - Maximum index item
function handleMenuInput()
{
   # Read first byte of input. If it's Enter, move to script menu. If it's the escape char, read
   # another two bytes of input to see the escaped code that follows (to catch the arrow keys). If
   # it's the A-Z keys, look for a menu item that starts with that letter and jump to it.
   read -rsn1 INPUT_FIRST_BYTE
   if [ "$INPUT_FIRST_BYTE" == "$ENTER_CHAR" ]; then
      if [ ${CUR_CHOICE[$2]} -lt $3 ] || [ ${CUR_CHOICE[$2]} -gt $4 ]; then
         echo "You need to pick a $1 before hitting Enter."
         sleep 1
      else
         MENU_DONE=1
      fi
   elif [[ "$INPUT_FIRST_BYTE" =~ [a-z] ]]; then
      a=$3
      while [ $a -le $4 ]; do
         if [ $2 -eq 0 ]; then
            if [[ "${CAT_NAMES[$a]}" =~ ^"$INPUT_FIRST_BYTE" ]]; then
               CUR_CHOICE[$2]=$a
               break
            fi
         else
            if [[ "${SCR_NAMES[$a]}" =~ ^"$INPUT_FIRST_BYTE" ]]; then
               CUR_CHOICE[$2]=$a
               break
            fi
         fi
         let a+=1
      done
   elif [ "$INPUT_FIRST_BYTE" == "$ESCAPE_CHAR" ]; then
      read -rsn2 INPUT_MORE_BYTES
      case $INPUT_MORE_BYTES in
         '[A' ) let CUR_CHOICE[$2]-=1; if [ ${CUR_CHOICE[$2]} -lt $3 ]; then CUR_CHOICE[$2]=$4; fi;;
         '[B' ) let CUR_CHOICE[$2]+=1; if [ ${CUR_CHOICE[$2]} -gt $4 ]; then CUR_CHOICE[$2]=$3; fi;;
         #'[D' ) echo "left arrow";;
         #'[C' ) echo "right arrow";;
         * ) echo "Unknown multibyte input."; sleep 1;;
      esac
   elif [ "$INPUT_FIRST_BYTE" == " " ]; then
      QUIT_SCRIPT=1
   else
      echo "Unknown input."
      sleep 1
   fi
}

# The script having finished by the time the sleep call below ends, this forked function uses
# 'osascript' to type on the bash prompt an invocation of the script that the user selected. Uses
# my personal Bash alias 'rb', which takes the name of a supplied script file and converts it to
# the command "bash [full path to script]", in order to save space on the command prompt.
function typeScriptCall()
{
   sleep 0.1
   osascript -e 'on run argv
tell application "System Events"
keystroke "rb " & item 1 of argv
end tell
end run' $1
}

## PROGRAM START ##
# Create table of scripts and count categories
a=0
while [ "x${README_PATHS[$a]}" != "x" ]; do
   collectScripts ${README_PATHS[$a]}
   let a+=1
done

# If we're in debug mode 1, print the table we built and quit
if [ $DEBUG_MODE -eq 1 ]; then
   printScripts
   exit 0
fi

# Reconcile read-me to directory and quit if there's a problem
compareTableToDir
if [ $QUIT_SCRIPT -eq 1 ]; then
   exit
fi

# If we're in debug mode 2, quit now
if [ $DEBUG_MODE -eq 2 ]; then
   exit 0
fi

# Present category menu
while [ $MENU_DONE -ne 1 ] && [ $QUIT_SCRIPT -ne 1 ]; do
   clear
   drawMenuTitle category
   drawMenuBody
   handleMenuInput category 0 0 $((NUM_CATS - 1))
done

# Quit if user desires
if [ $QUIT_SCRIPT -eq 1 ]; then
   echo "Goodbye."
   exit
fi

# Find index numbers of first and last script
NUM_SCR=${NUM_SCRS[${CUR_CHOICE[0]}]}
a=0
while [ "x${SCR_CATS[$a]}" != "x" ]; do
   if [ ${SCR_CATS[$a]} -eq ${CUR_CHOICE[0]} ]; then
      LOW_SCR=$a
      HIGH_SCR=$((LOW_SCR + NUM_SCR - 1))
      break
   fi
   let a+=1
done

# Present script menu
INPUT_FIRST_BYTE=""
INPUT_MORE_BYTES=""
MENU_DONE=0
CUR_CHOICE[1]=$LOW_SCR
while [ $MENU_DONE -ne 1 ] && [ $QUIT_SCRIPT -ne 1 ]; do
   clear
   drawMenuTitle script
   drawMenuBody
   handleMenuInput script 1 $LOW_SCR $HIGH_SCR
done

# Quit if user desires
if [ $QUIT_SCRIPT -eq 1 ]; then
   echo "Goodbye."
   exit
fi

# Send keystrokes containing chosen script to command line as script ends
clear
echo "Script:  ${SCR_NAMES[${CUR_CHOICE[1]}]}."
printParams ${CUR_CHOICE[1]} 0
typeScriptCall "${SCR_FILES[${CUR_CHOICE[1]}]}$PARAM_SPACE" &
shopt -u nocasematch