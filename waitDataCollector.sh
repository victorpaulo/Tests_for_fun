#!/bin/sh
#
# Copyright IBM 2009 (c)
# All Rights Reserved
#
# This script is used as the waitDataCollector script, as well as
# 'MustGather: Performance, Hang or High CPU Issues on Linux and AIX'
#
# ./perfMustGather.sh [PID(s)_of_the_problematic_JVM(s)_separated_by_spaces]
#
# Run this script with no options to see full usage
#
# Contact: Matthew Arnold (marnold@us.ibm.com)
#
#

VERSION="7.6"

#############################################################
#
# BEGIN M4 MACROS
#






#echo $LINENO
# NOTE: The first parameter to the math macros is an L-value, and should NOT 
# have the "$".  All other parameters MUST '











# Dump iter to given file

# Dump date to given file


# Dump OS to given file











# These silly macros are to get around that m4 can't escape \$1
# The result of using "$NUMBER_ONE_MACRO in a macro is that it outputs $1 (useful for awk!



# These macros are needed because on solaris the result of WC have whitespace around the number
# This pipe to awk simply trims it



# Use awk to get rid of white space in front and back of prog output











# IF you are "HIDDEN" then you have the WAIT_FILES_DIR variable, which is set only when MUST_GATHER is true









# Files specific to a PID
















# Files not specific to a PID






































#
# END M4 MACROS
#
#############################################################


# For now, errorlog is /dev/null, until it is initialized later when the dir is created
ERRORLOG="/dev/null"
DEBUG_LOG="/dev/null"
CONSOLE_LOG="/dev/null";

MUSTGATHER="";

# Test if command exists on path
checkCommandExists() {
    WHICH_OUTPUT=`which $1 2>/dev/null`;
    if [ $? = "0" ]; then
	# If we get here then the return status indicated no error
	# Unfortunatly on solaris you get return status 0 even if 
	# if it reports "not found in blah"
	# So test if you can successfully "ls" the file
	ls "$WHICH_OUTPUT" 2>/dev/null 1>/dev/null
	if [ $? = "0" ]; then
	    echo "Command exists: $1" 2>/dev/null >> "$DEBUG_LOG" ;
	    return 1;
	fi
    fi
    echo "Command does NOT exist: $1" 2>/dev/null >> "$DEBUG_LOG" ;
    return 0;
}

# awk and grep are required
REQUIRED_COMMAND_ERROR="It is required to run the full WAIT data collector.  You may consider downloading the Simple WAIT data collector instead";

checkCommandExists awk
HAVE_AWK=$?
if [ $HAVE_AWK = "0" ]; then
    echo "Cannot find command 'awk' on your path.  $REQUIRED_COMMAND_ERROR";
    exit;
fi

checkCommandExists grep
HAVE_GREP=$?

if [ $HAVE_GREP = "0" ]; then
    echo "WARNING: Cannot find command 'grep' on your path.  $REQUIRED_COMMAND_ERROR";
    exit;
fi

which ps 2>/dev/null > /dev/null
MISSING_PS=$?
CURRENT_SHELL="/bin/sh"
if [ $MISSING_PS = "0" ]; then
    USING_BASH=`ps -p $$|grep bash| wc -l 2>>"$ERRORLOG" | awk '{ print $1; exit; }' 2>>"$ERRORLOG"  `;
    if [ $USING_BASH = "0" ]; then
        # Check if bash is on this system 
	HAVE_GNU_BASH=0;
	which bash 2>/dev/null > /dev/null
	if [ $? = "0" ]; then
	    BASH_IS_GNU=`eval bash --version 2>/dev/null | grep "GNU" | wc -l 2>>"$ERRORLOG" | awk '{ print $1; exit; }' 2>>"$ERRORLOG" `
	    if [ $BASH_IS_GNU -gt "0" ]; then
		HAVE_GNU_BASH=1;
	    fi
	fi
	
	if [ $HAVE_GNU_BASH = "1" ]; then
            # This means we have bash available.  Restart script with bash
	    echo "Switching to bash"
	    exec bash $0 $*
	else
	    # If you don't have bash, but you have the xpg4 version of sh, use it
	    USING_XPG4_SH=`ps -f -p $$|grep "/usr/xpg4/bin/sh" | wc -l 2>>"$ERRORLOG" | awk '{ print $1; exit; }' 2>>"$ERRORLOG" `;
	    if [ "$USING_XPG4_SH" = "0" ]; then
		if [ -f "/usr/xpg4/bin/sh" ]; then
		    echo "Switching to /usr/xpg4/bin/sh"
		    exec /usr/xpg4/bin/sh $0 $*
		fi
	    else
		CURRENT_SHELL="/usr/xpg4/bin/sh";
	    fi
	fi
    else
	CURRENT_SHELL="bash";
    fi
else
    USING_BASH=0;
    USING_XPG4_SH=0;
    echo "Command 'ps' not found.  Process utilization information not collected"
fi

WDCPID=$$;

CWD=`pwd`;

NUM_PIDS=0;

# This ensures that piped command propagate the error codes forward for easy error checking
OS=`uname`;
if [ "$OS" = "SunOS" ]; then
    if [ "$CURRENT_SHELL" = "/bin/sh" ]; then
	echo ""
	echo "The default /bin/sh on solaris is limited and cannot run this script."
	echo "bash was not found on your path, nor was /usr/xpg4/bin/sh."
	echo "Please either:"
	echo "   a) Install bash or /usr/xpg4/bin/sh shells"
	if [ -n "$MUSTGATHER" ]; then
	    echo "   b) Download the sunperf.sh mustgather script"
	    echo ""
	else
	    echo "   b) Download and use the TrivialWaitDataCollector.sh data collection script, or"
	    echo "   c) Manually trigger javacores using jstack or \"kill -e\" and upload the stack "
	    echo "      dumps to the WAIT server"
	    echo ""
	fi
	exit 1;
    fi
else
    if [ "$USING_BASH" = "1" ]; then
	set -o pipefail 2>/dev/null
    fi
fi


usage() {
    set +x
    echo "USAGE:  $SCRIPT_NAME [options] [PID_1] [PID_2] [... PID_N]";
    echo "  Options:";
    echo "    --sleep  N:   Number of seconds to sleep between javacore samples.  Default is $DEFAULT_SLEEP_INTERVAL seconds";
    echo "                  A sleep interval of less than 15 seconds is not recommended.";
    echo 
    echo "    --iters  N:   Number of javacores to triggering before exiting.  ";
    if [ -n "$MUSTGATHER" ]; then
	echo "                  Default for mustgather is 3."
	echo "                  Leave blank to continue collecting until CTRL-C is pressed.";
	echo 
	echo "    --topInterval  N:   Modify the number of seconds between updates to top.  Default is 60. "
	echo
	echo "    --topDashHInterval  N:   Modify the number of seconds between updates to top-dash-h.  Default is 5. "
	echo
	echo "    --vmstatInterval  N:   Modify the number of seconds between vmstat updates.  Default is 1. "
	echo
	echo "    --tprofSpan  N:   Modify the number of seconds that tprof runs for.  Default is 60. "
    else
	echo "                  Leave blank to continue collecting until CTRL-C is pressed.";
    fi
	echo 
    echo "    --javacoreDir  DIR:   Full path to the directory where javacores are written  ";
    echo "                          by the JVM.  If not specified, this directory is computed";
    echo "                          based on the CWD of the JVM PID ";
    echo

    if [ -z "$MUSTGATHER" ]; then
	echo "    --skipJvmVersionCheck:   Do not check the the JVM version and issue warnings for older JVMs"
	echo
	echo "    --continueIfHeapdumpsOccur:   Force the wait collector to continue even if heap dumps are occuring"
	echo
	echo "    --psInterval  N:   Modify the number of seconds to sleep between invocations of the ps command. "
	echo "                       If unspecified this value is computed based on the sleep interval. "
	echo
    fi
    echo "    --outputDir  DIR:  Directory that the WAIT data collector can use to store the collected data.  Must be empty, or nonexistant. "
    echo
    echo "    --outputZip  FILE_PREFIX:   The prefix of the tar.gz file produced.  (default is $ZIP_PREFIX.tar.gz)"
    echo 
    echo "    --noDelete:  Do not delete the raw datafiles from /tmp"
    echo
    echo "    --noJstack:  Do not use jstack for Oracle JVMs even if it is available"
    echo
    echo "    --noZip:       Do not zip up the output produced by the data collector.  "
    echo
#    echo "    --updateZipEveryIter:   Add files to the zip file ever iteration";
#    echo
    echo "    --noJavacoreTriggers:   Do not trigger javacores, but still look for and archive them"
    echo
    echo "    --processName  NAME:   Monitor all processes with this name  "
    echo
#    echo "    --grep  PATH:   Full path to a grep that supports 'grep -f'";
#    echo 
    if [ -z "$MUSTGATHER" ]; then
	echo "    --mustGather:   Run with the behavior of the WAS performance must gather script"
    fi
    echo 
    exit;
}





math_add() {
    RET_VAL=$(($1 + $2));
#    RET_VAL=`echo "$1 $2" | awk '{ print $1 + $2 }'`;
}

math_subtract() {
    RET_VAL=$(($1 - $2));
#    RET_VAL=`echo "$1 $2" | awk '{ print $1 - $2 }'`;
}
math_divide() {
    RET_VAL=$(($1 / $2));
#    RET_VAL=`echo "$1 $2" | awk '{ print $1 / $2 }'`;
}


##
## Helper subroutines
## 

seeIfWeAreSun () {
    for PID_INDEX in ${PID_INDICES[@]}
    do 
      PID=${PIDS[$PID_INDEX]};

     # No sun on AIX!
      if [ "$IS_AIX" = "1" ] || [ "$DO_NOT_USE_JSTACK" = "1" ]; then 
	  JSTACK_FOUND[$PID_INDEX]=0;
	  continue;
      fi

      EXE_FILE="/proc/$PID/exe";

      if [ -e "$EXE_FILE" ];then
	  exe=`file /proc/$PID/exe | $AWK -F '\`' '{path = substr($2,1,length($2)-1); print path}'`
      else
	  # Solaris
	  # Note, I could not get a multiple character field separator working in solaris
	  # so the line below uses the character ">" as the field separator 
	  # To attempt to find the whole file name (even if it has spaces) from
	  # /proc/7375/path/a.out -> /usr/lib/ssh/sshd
	  exe=`ls -l /proc/$PID/path/a.out | $AWK -F'>' '{print $2}'`
     fi
      
      jstackLocation=`dirname "$exe" | $AWK '{ print $1; exit; }'  `

      FOUND_JSTACK=0;
      if [ -d "$jstackLocation" ]; then
	  jstack="$jstackLocation/jstack"
	  if [ -x "$jstack" ]; then
	      FOUND_JSTACK=1;
	  else
	      # Try again without jre in the path (if it exists)
	      jstackLocation=`echo $jstackLocation | $AWK '{ str = $1; sub(/jre\//,"",str); print str;}'` 
	      jstack="$jstackLocation/jstack";
	      if [ -x "$jstack" ]; then
		  FOUND_JSTACK=1;
	      fi 
	  fi
      else
	  echo "-d failed on jstack location: [$jstackLocation]" 2>/dev/null >> "$DEBUG_LOG" 
      fi
      
      if [ "$FOUND_JSTACK" = 1 ]; then
	  JSTACK_FOUND[$PID_INDEX]=1;
	  JSTACK_EXE[$PID_INDEX]=$jstack;
	  echo "Found jstack for PID [$PID_INDEX]:  [$jstackLocation]" 2>/dev/null >> "$DEBUG_LOG" 

	  # Now look for jstat
	  jstat="$jstackLocation/jstat";
	  if [ -x "$jstat" ]; then
	      JSTAT_EXE[$PID_INDEX]=$jstat;
	      echo "Found jstat for PID [$PID_INDEX]:  [$jstat]" 2>/dev/null >> "$DEBUG_LOG" 
	  fi

	  continue;
      fi
      
#      # Otherwise, use kill -3
      
      JSTACK_FOUND[$PID_INDEX]=0;

    done
 
}

trappedCtrlC () {

    echo "Trapped CTRL-C" 2>/dev/null >> "$DEBUG_LOG" ;
    echo "Time: $DATE" >> "$DEBUG_LOG"

    terminateGracefully

}

terminateGracefully() {

    echo "TERMINATE GRACEFULLY" 2>/dev/null >> "$DEBUG_LOG" ;
    echo "Time: $DATE" >> "$DEBUG_LOG"

    # If you have any background processes, kill them
    killProcessIfExists $VMSTAT_PID
    killProcessIfExists $TOP_CMD_PID

    captureVerboseGcForPrevIter

    moveNewJavacores

    if [ "$STARTED_TPROF" = "1" ]; then
	# If we started tprof then it creates a file in the CWD that we need to grab
	mv sleep.prof $OUTPUT_DIR/sleep.prof 2>>"$ERRORLOG" >> "$CONSOLE_LOG" 

	# If we are mustgather and we notice that tprof didn't gather the information propery because we're not root
	# Than issue a warning
	if [ -n "$MUSTGATHER" ]; then
	    if [ "$WHOAMI" != "root" ]; then
		NON_ROOT_WARNING=`grep "Warning: executed in non-root mode" $OUTPUT_DIR/tprof.out 2> /dev/null | wc -l 2>>"$ERRORLOG" | awk '{ print $1; exit; }' 2>>"$ERRORLOG" `
		if [ -n "$NON_ROOT_WARNING" ] && [ "$NON_ROOT_WARNING" -gt "0" ]; then
		    echo " " | tee -a "$CONSOLE_LOG";
		    echo "WARNING:  tprof data could not be collected because this script was not run as root. " | tee -a "$CONSOLE_LOG";
		    echo "          It is recommended that $SCRIPT_NAME be run again as root so that tprof data can be " | tee -a "$CONSOLE_LOG";
		    echo "          used in the problem diagnosis. " | tee -a "$CONSOLE_LOG";
		fi
	    fi
	fi
    fi


    zipData
    
    finalChecks
    
    exit;
}

# Copy the specified log dir if it has not already been copied
# We need to check because ffdc could be common among multiple processesn
copyLogDir () {

    LOG_BASE_DIR="$1"
    SUBDIR="$2"
    LOG_DIR="$LOG_BASE_DIR/$SUBDIR"

    if [ ! -d "$LOG_DIR" ]; then
	echo "Warning: Log dir did not exist: [$LOG_DIR]" 2>/dev/null >> "$DEBUG_LOG" 
	return;
    fi
    
    DEST_BASE_DIR="$OUTPUT_DIR/logs$LOG_BASE_DIR";
    DEST_SUBDIR="$DEST_BASE_DIR/$SUBDIR";

    echo copyLogDir: LOG_BASE_DIR=[$LOG_BASE_DIR]  SUBDIR=[$SUBDIR]  LOG_DIR=[$LOG_DIR] DEST_BASE_DIR=[$DEST_BASE_DIR] DEST_SUBDIR=[$DEST_SUBDIR] 2>/dev/null >> "$DEBUG_LOG" ;


    # If it already exists, return
    if [ -d "$DEST_SUBDIR" ]; then
	echo "Skipping copy of log dir [$DEST_SUBDIR] because it was already copied" 2>/dev/null >> "$DEBUG_LOG" ;
	return;
    fi

    # Otherwise, copy it over
    # Make the base directory
    mkdir -p "$DEST_BASE_DIR"
    # Copy, recursively and preserving dates
    ln -s "$LOG_DIR" "$DEST_BASE_DIR"

# Don't copy it.  Just let tar suck it in when the final tar is created
#    cp -Rp "$LOG_BASE_DIR/$SUBDIR" "$DEST_BASE_DIR"

    # Now Take a listing of the dir so we know what to expect at the time the dir was found
    find "$LOG_DIR" -ls > "dirListing.$DEST_BASE_DIR.txt"  2>>"$ERRORLOG" >> "$CONSOLE_LOG" 


}


# Grab the websphere logs
gatherWasLogs () {
    
    echo "Gathering Websphere log files"
    
    for PID_INDEX in ${PID_INDICES[@]}
      do
      PID=${PIDS[$PID_INDEX]};
      
      LOGDIR="${WAS_LOG_DIR[$PID_INDEX]}"
      SERVER_NAME="${WAS_SERVER_NAME[$PID_INDEX]}"

      echo Gathering logs for PID: $PID, LOGDIR=[$LOGDIR] and SERVER_NAME=[$SERVER_NAME] 2>/dev/null >> "$DEBUG_LOG" 

      if [ -n "$LOGDIR" ]; then
	  copyLogDir "$LOGDIR" "$SERVER_NAME"
	  copyLogDir "$LOGDIR" "ffdc"
      fi
    done
}

collectFinalMustGatherData() {
    if [ -n "$MUSTGATHER" ]; then

	if [ "$IS_AIX" = "1" ]; then
	
	    echo " " | tee -a "$CONSOLE_LOG"
	    echo "Collecting other data.  This may take a few moments..." | tee -a "$CONSOLE_LOG"
	    OSLEVEL_S=`oslevel -s 2>>"$ERRORLOG"` 
	     echo AIX OSLEVEL-S: $OSLEVEL_S >> "$OUTPUT_DIR/info.txt"
	    /usr/sbin/emgr -lv3 >> "$OUTPUT_DIR/emgr-lv3.out" 2>&1 
	    lslpp -la >> "$OUTPUT_DIR/lslpp-la.out" 2>&1 
	    instfix -i >> "$OUTPUT_DIR/instfix-i.out" 2>&1 
	    prtconf >> "$OUTPUT_DIR/prtconf.out" 2>&1 
	    lsattr -El sys0 >> "$OUTPUT_DIR/lsattr.out" 2>&1 
	    echo "" | tee -a "$CONSOLE_LOG";
	fi

	    
	gatherWasLogs
    fi
}

# Print warning if prev command failed
warnCommandSuccess() {
    return assertCommandSuccess $1 NOFAIL
}

# Die if pref command failed
# Arg $1 is error message to print
# Arg $2, if exists, specifies to not fail and just print the error
# Return 0 if command successful, 1 otherwise
assertCommandSuccess() {
    if [ $? != "0" ]; then
	ERROR_MESG=$1;
	echo "" | tee -a "$CONSOLE_LOG"
	echo "ERROR: $ERROR_MESG" | tee -a "$CONSOLE_LOG"
	echo "" | tee -a "$CONSOLE_LOG"

	# If parameter #2 is set then we don't fail
	# If it's not set, fail
	if [ -z "$2" ]; then
	    exit
	fi

	return 1;
    fi
    return 0;
}

# Some commands need to be executed to see if they exist.  Aliases, etc
checkIfDisownExists() {
    # If the built-in disown exists, the bogus PID will occur in the output:  "PID xxx does not exist"
    DISOWN_COUNT=`$DISOWN qqqqq 2>&1 | grep -c qqqqq`;
#    echo "DISOWN: [$DISOWN]  DISOWN_COUNT: [$DISOWN_COUNT]";
    if [ "$DISOWN_COUNT" -gt "0" ]; then
	echo "Command disown exists" 2>/dev/null >> "$DEBUG_LOG" ;
	RET_VAL=1;
	return;
    fi
    echo "Command disown does NOT exist" 2>/dev/null >> "$DEBUG_LOG" ;
    RET_VAL=0;
    return;
    
}

initJavacoreCounts() {
    SUN_JAVACORE_COUNT=0
    IBM_JAVACORE_COUNT=0
    JSTACK_JAVACORE_COUNT=0
    TOTAL_JAVACORE_COUNT=0
    resetJavacoreCountsForNewIter
}
resetJavacoreCountsForNewIter() {
    SUN_JAVACORE_COUNT_THIS_ITER=0
    IBM_JAVACORE_COUNT_THIS_ITER=0
    JSTACK_JAVACORE_COUNT_THIS_ITER=0
    TOTAL_JAVACORE_COUNT_THIS_ITER=0
}
incIbmJavacores() {
    INC=$1
    math_add $IBM_JAVACORE_COUNT $INC; IBM_JAVACORE_COUNT=$RET_VAL
    math_add $IBM_JAVACORE_COUNT_THIS_ITER $INC; IBM_JAVACORE_COUNT_THIS_ITER=$RET_VAL
    incTotalJavacores $INC;
}
incJstackJavacores() {
    INC=$1
    math_add $JSTACK_JAVACORE_COUNT $INC; JSTACK_JAVACORE_COUNT=$RET_VAL
    math_add $JSTACK_JAVACORE_COUNT_THIS_ITER $INC; JSTACK_JAVACORE_COUNT_THIS_ITER=$RET_VAL
    incHotspotJavacores $INC
}
incHotspotJavacores() {
    INC=$1
    math_add $SUN_JAVACORE_COUNT $INC; SUN_JAVACORE_COUNT=$RET_VAL
    math_add $SUN_JAVACORE_COUNT_THIS_ITER $INC; SUN_JAVACORE_COUNT_THIS_ITER=$RET_VAL
    incTotalJavacores $INC;
}

incTotalJavacores() {
    INC=$1
    math_add $TOTAL_JAVACORE_COUNT $INC; TOTAL_JAVACORE_COUNT=$RET_VAL
    math_add $TOTAL_JAVACORE_COUNT_THIS_ITER $INC; TOTAL_JAVACORE_COUNT_THIS_ITER=$RET_VAL
    math_add $COUNT_THIS_PID_THIS_ITER $INC; COUNT_THIS_PID_THIS_ITER=$RET_VAL
}

countTotalJavacores() {
    echo "Collected $TOTAL_JAVACORE_COUNT javacores total" | tee -a "$CONSOLE_LOG"
}

# Get the file size in bytes
# UGLY: Return the value in global variable "SIZE_BYTES" since you can't return values in bash.
getFileSizeBytes() {
    FILENAME="$1";

    RET_VAL=`wc -c "$FILENAME" 2>/dev/null | $AWK '{ print $1; exit; }' `
}

# Get the file size in bytes
# UGLY: Return the value in global variable "SIZE_BYTES" since you can't return values in bash.
getFileSizeBytesBackground() {
    FILENAME="$1";

    # All of this hoopla is to basically do "wc -c $FILENAME".  HOWEVER, 
    # for fd/PID/1 and 2, it sometimes hangs indefinitely.
    # So it must go to the background, with a timeout.  Sigh.

#    RET_VAL=`wc -c $FILENAME | AWK_TRIM() 2>/dev/null`

    wc -c $FILENAME 2>/dev/null > $OUTPUT_DIR/PID_$PID/.fileSizeTempDir  &
    WC_PID=$!
    (sleep 2 ; kill -9 $WC_PID 2>/dev/null ) 2>/dev/null &
    $DISOWN  2>>"$ERRORLOG" >> "$CONSOLE_LOG" 
    wait $WC_PID
    
    SIZE_BYTES=`cat $OUTPUT_DIR/PID_$PID/.fileSizeTempDir 2>>"$ERRORLOG"` 

    rm $OUTPUT_DIR/PID_$PID/.fileSizeTempDir 2>/dev/null >/dev/null
    
    if [ -n "$SIZE_BYTES" ]; then
	RET_VAL=`echo $SIZE_BYTES | $AWK '{ print $1; exit; }' `;
    else
	RET_VAL="-1";
    fi
}

# Do some final error checking 
finalChecks() {

    countTotalJavacores

    # Check that the zip file variable is set, and the file exists
    if [ -n "$ZIP_FILE" ] && [ -f "$ZIP_FILE" ]; then

	# If the raw data is in /tmp, then clean it up
	IS_IN_TMP=`echo "$OUTPUT_DIR" | $GREP -c '^/tmp'`

	if [ "$DO_NOT_DELETE_RAW_FILES" = "1" ]; then
	    echo "Raw data NOT deleted from [$OUTPUT_DIR] because option --noDelete was used"
	else
	    if [ "$IS_IN_TMP" = "1" ]; then
		echo "Cleaning up raw data dir from [$OUTPUT_DIR]"
		rm -rf "$OUTPUT_DIR"
	    else
		echo "Raw data NOT deleted from [$OUTPUT_DIR] since not in /tmp"
	    fi
	fi

	# TODO: This check should be moved before zipping, so this message can be logged.
	if [ $TOTAL_JAVACORE_COUNT = "0" ]; then

	    echo ""
	    echo ""
	    echo "  *************************************  ERROR ****************************************************"

	    if [ "$JAVACORE_FAILURE_CAUSED_EARLY_TERMINATION" = "1" ]; then
		echo "  Javacore generation failed.  Please ensure that the process being monitored exists and "
		echo "  that you have permission to trigger javacores against it.  This requires running "
		echo "  $SCRIPT_NAME as the same user of the JVM process being monitored, or as root."
	    else
                echo "  There were no javacores collected by this collecion. "
		echo "  Please find the directory where the JVM is putting the javacores and either a) manually add these "
		echo "  files to $ZIP_FILE file, or b) rerun $SCRIPT_NAME using the "
		echo "  option --javacoreDir JAVACORE_DIR"
	    fi
	    echo "  ***************************************************************************************************"
	    echo ""
	else
	    if [ -n "$MUSTGATHER" ]; then
		echo ""
		echo "Be sure to submit $ZIP_FILE and the server logs as noted in the MustGather."
		echo ""
	    else
		echo ""
		echo "Please submit $ZIP_FILE to the wait server to see a WAIT report"
		echo ""
	    fi
	fi

    else
	if [ "$NOZIP" = "0" ]; then
	    # Unless noZip was specified, then it's an error to get here witout a zip file produced
	    echo "ERROR:  Error zipping data.  "
	fi

        echo "Please manually zip or gzip data in $OUTPUT_DIR"
	echo "and submit the resulting file."

    fi
    
}

# Zip up the javacores and data that we have collected
zipData() {
    
    # Just in case the script has a bug and CWD has changed
    cd "$CWD"

    echo " " | tee -a "$CONSOLE_LOG"
    if [ "$NOZIP" = "1" ]; then
	echo "Raw data is in $OUTPUT_DIR" | tee -a "$CONSOLE_LOG"
	echo "Data not zipped because --noZip was specified" | tee -a "$CONSOLE_LOG"
    else
	echo "Zipping up wait data found in $OUTPUT_DIR" | tee -a "$CONSOLE_LOG"

        if [ "$UPDATE_ZIP_EVERY_ITER" = "1" ]; then
	    if [ "$HAVE_ZIP" = "1" ]; then
		ZIP_FILE="$ZIP_PREFIX.zip"
                zip -ruq $ZIP_FILE $OUTPUT_DIR 2>>"$ERRORLOG" | tee -a "$CONSOLE_LOG" 
		"pwd" 2>>"$ERRORLOG" | tee -a "$CONSOLE_LOG" ;
	    else
		echo ERROR: Must have zip to use --updateZipEveryIter | tee -a "$CONSOLE_LOG"
	    fi
	elif [ "$HAVE_TAR" = "1" ]; then
#	    PRINT_CONSOLE("Trying tar")

	    ZIP_FILE="$ZIP_PREFIX.tar"

	    cd "$OUTPUT_DIR" && tar cfh "$CWD/$ZIP_FILE" * 
	    TAR_ERR_CODE=$?
	    cd "$CWD"
	    if [ $TAR_ERR_CODE = "0" ]; then
                # Tar completed successfully
		# If gzip is available, then gzip it
		if [ "$HAVE_GZIP" = "1" ]; then
		    echo "Trying gzip" | tee -a "$CONSOLE_LOG"
		    gzip $ZIP_FILE
		    if [ $? = "0" ]; then
		        # gzip completed successfully
			ZIP_FILE="$ZIP_FILE.gz"
		    else
			echo "gzip failed" | tee -a "$CONSOLE_LOG"
		    fi
		fi
	    else
		echo "" | tee -a "$CONSOLE_LOG"
		echo "ERROR: tar command FAILED" | tee -a "$CONSOLE_LOG"
		echo "" | tee -a "$CONSOLE_LOG"

		# Unset the ZIP_FILE var to make it clear there is no zip
		ZIP_FILE=""
	    fi
	fi

	if [ -n "$ZIP_FILE" ]; then
	    echo "Collected data stored in $ZIP_FILE" | tee -a "$CONSOLE_LOG"
	fi
    fi
}


# Input:  
#   - A directory in which javacores might appear
#   - A filename, in which we store the preexisting list of directory
#
# Store the contents of the directory in the given output file.
# However, put a '^' at the beginning of each line, and a '$' at the
# end.  This makes it easy use grep to find new files by doing a whole line match
recordExistingFiles() {

    DIR="$1"
    OUTPUT_FILE="$2"
    PATTERN="$3"
    if [ -z "$DIR" ]; then
	echo "SEVERE ERROR: Directory [$DIR] empty.   OUTPUT_FILE: $OUTPUT_FILE" >>"$ERRORLOG"
	return;
    fi
    ( cd "$DIR" 2>/dev/null && ls $PATTERN 2>>"$ERRORLOG" | $AWK ' { print "^"$0"$" } ' > "$OUTPUT_FILE" )
}



reportJavacoreDir() {
    DIR="$1";

    # Print it only if you've never seen it
    for prevDir in ${PREV_JAVACORE_DIRS[@]}
      do 
      if [ "$prevDir" == "$DIR" ]; then
	  return;
      fi
    done

    # Add this to the list of dirs seen
    NUM_ELEMS=${#PREV_JAVACORE_DIRS[@]};
    PREV_JAVACORE_DIRS[$NUM_ELEMS]=$DIR;
    echo "Found javacore in directory: [$DIR]." | tee -a "$CONSOLE_LOG"
}


#
# Given the directory and filename, get the javacore file and move it to the collector's output dir
#
getJavacoreFile() {
    DIR="$1"
    JAVACORE_FILE="$2"
    PREEXISTING_FILES="$3"

    echo "MOVING javacores from dir: $DIR/$JAVACORE_FILE" 2>/dev/null >> "$DEBUG_LOG" 

    getFileSizeBytes "$DIR/$JAVACORE_FILE"
    FILE_SIZE=$RET_VAL
#    echo "JAVACORE FILE SIZE: [$FILE_SIZE]"

    if [ "$FILE_SIZE" = "0" ]; then
	echo "" | tee -a "$CONSOLE_LOG";
	echo "WARNING:  Javacore is empty.  Check for disk space or other errors generating javacore." | tee -a "$CONSOLE_LOG"
	echo "" | tee -a "$CONSOLE_LOG";
    fi

    # Check the JVM version.  Non-mustgather only
    if [ -z "$MUSTGATHER" ] && [ "$SKIP_JVM_VERSION_CHECK" = "0" ]; then
	if [ -z "${CHECKED_JVM_VERSION[$PID_INDEX]}" ]; then
	    CHECKED_JVM_VERSION[$PID_INDEX]=1
            # Take the first 100 lines for the javacore, grep for VMVERSION, 
	    # then grep out the 8 digit date sequence (ex: 20110519), 
	    # then see if it's greater than the magic date where they fixed J9
	    VM_DATE=`head -n 100 "$DIR/$JAVACORE_FILE"| grep VMVERSION | grep -o "[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]"`;
#           echo "VM DATE: $VM_DATE"
	    if [ "$VM_DATE" -lt "20101017" ]; then
		echo "" | tee -a "$CONSOLE_LOG"
		echo "WARNING: Your J9 JVM version is old (date $VM_DATE) and javacore generation may produce JVM instability." | tee -a "$CONSOLE_LOG"
		echo "         Please use a version of J9 where \"java -version\" produces a J9VM date of 20100117 or newer," | tee -a "$CONSOLE_LOG"
		echo "         or use data collector option --skipJvmVersionCheck if you are in a development or testing environment." | tee -a "$CONSOLE_LOG"
		echo "" | tee -a "$CONSOLE_LOG"
		echo "Exiting" | tee -a "$CONSOLE_LOG"
		exit
	    fi
	fi
    fi
    

    # If the user messed with the javacore filename, then force it to contain a structure we recognize
    KNOWN_JAVACORE_NAMING=`echo $JAVACORE_FILE | $GREP -c "^javacore.*$PID.*txt$"`;
    GREP_WILL_FIND_FILENAME="1";
    if [ "$KNOWN_JAVACORE_NAMING" = 1 ]; then
	mv "$DIR/$JAVACORE_FILE" "$OUTPUT_DIR/PID_$PID/$JAVACORE_FILE.ITER_$ITER.txt"
    else
	# Otherwise rename it to a format we will recognize
	GREP_WILL_FIND_FILENAME="0";
	mv "$DIR/$JAVACORE_FILE" "$OUTPUT_DIR/PID_$PID/wdcRenamedjavacore$PID.0.txt.$JAVACORE_FILE.ITER_$ITER.txt"
    fi

    # If command successful
    if [ $? = "0" ]; then
	math_add $COUNT 1; COUNT=$RET_VAL

	if [ "$DIR" != "${CONFIRMED_JAVACORE_DIR[$PID_INDEX]}" ]; then
	    # We seem to have found javacores in a new dir
            # Remember this dir as the confirmed javacore dir

	    reportJavacoreDir "$DIR"

	    if [ "$GREP_WILL_FIND_FILENAME" = "1" ]; then
		# If the filename was one we will recognize with our grep and ls tricks, 
		# Then mark this dir as confirmd so we don't keep using tail
		CONFIRMED_JAVACORE_DIR[$PID_INDEX]="$DIR";
		CONFIRMED_JAVACORE_DIR_PREEXISTING_FILES[$PID_INDEX]="$PREEXISTING_FILES"
	    fi
	fi
    fi
}

# INPUT
#    1: a directory
#    2: a file that contains the ls output of that directory before javacores were generated
#
# If a new file is found in the directory, it is moved to the data collector's dir, and 
# this directory is recorded as a "confirmed" dir
#    
moveJavacoresFromDir() {

    JAVACORE_DIR="$1";
    PREEXISTING_FILES="$2"

    # MRA BUG: Don't report this for each pid
    if [ -z "$CONFIRMED_JAVACORE_DIR[$PID_INDEX]" ]; then
	echo "Checking for javacores in [$JAVACORE_DIR]" | tee -a "$CONSOLE_LOG"
    fi

    # Check default javacore dir
    NEW_JAVACORES=`cd "$JAVACORE_DIR" 2> /dev/null && ls $JAVACORE_FILE_PATTERN 2>>"$ERRORLOG" | $GREP \\.$PID\\. 2>>"$ERRORLOG" | $GREP -v -f "$PREEXISTING_FILES" 2>>"$ERRORLOG"`
    for corefile in $NEW_JAVACORES 
      do
      getJavacoreFile "$JAVACORE_DIR" "$corefile" "$PREEXISTING_FILES"
    done
}

# If available, look in the STDERR of the process being monitored and try to find if 
# it logged the javacore produced
#
# No parameters, however we assume that we logged the size of the STDERR file before each javacore, to make tail efficient
findJavacoreFromStderr() {


    # J9: Java Dump written to /opt/IBM/WebSphere/AppServer/profiles/AppSrv01/javacore.20100329.175102.10160.txt
    JAVACORE_FILENAME_FROM_STDERR=`$GREP -i "Java Dump written to"  "$OUTPUT_DIR/PID_$PID$WAIT_FILES_DIR/stderrTailLog.ITER_$ITER.txt" 2>/dev/null | $AWK -F "written to " '{ print $NF }' 2>/dev/null`;

    echo "Javacore filename from stderr: [$JAVACORE_FILENAME_FROM_STDERR]" 2>/dev/null >> "$DEBUG_LOG" 

    # Check if this produced a valid file
    if [ ! -f "$JAVACORE_FILENAME_FROM_STDERR" ]; then
	# IF not, try again
        # Soverign and J9:  Java core file written to /tmp/javacore.20100504.153633.445.txt
	JAVACORE_FILENAME_FROM_STDERR=`$GREP -i "Java core file written to"  "$OUTPUT_DIR/PID_$PID$WAIT_FILES_DIR/stderrTailLog.ITER_$ITER.txt" 2>/dev/null | $AWK -F "written to " '{ print $NF }' 2>/dev/null`;
    fi

    # See if we see heapdumps being logged in stderr
    HEAPDUMPS_IN_STDERR=`$GREP -ci heapdump "$OUTPUT_DIR/PID_$PID$WAIT_FILES_DIR/stderrTailLog.ITER_$ITER.txt" 2>/dev/null`
    if [ -z "$HEAPDUMPS_IN_STDERR" ]; then
	HEAPDUMPS_IN_STDERR=0;
    fi

    echo "HEAPDUMPS_IN_STDERR: [$HEAPDUMPS_IN_STDERR]" 2>/dev/null >> "$DEBUG_LOG" 
    echo "Javacore from stderr: [$JAVACORE_FILENAME_FROM_STDERR]" 2>/dev/null >> "$DEBUG_LOG" 

    # Check if file exists
    if [ -f "$JAVACORE_FILENAME_FROM_STDERR" ]; then

	# Now extract the directory from the filename, so we can get things more efficiently next time
	# How: Do a search for the regexp "/.+/" then take the substring that matches 
	DIR_FROM_JAVACORE_PATH=`echo $JAVACORE_FILENAME_FROM_STDERR | $AWK '{ where = match($0,"/.+/"); print substr($0,where,RLENGTH-1)}'`;

	# Get the filename without path
	# How: Tokenize by '/' then get the last token
	FILENAME=`echo $JAVACORE_FILENAME_FROM_STDERR | $AWK -F "/" '{ print $NF }'`;

	# Check directory exists (ie, we parsed it right)
	if [ -f "$DIR_FROM_JAVACORE_PATH/$FILENAME" ]; then
	    echo "Javacore dir: [$DIR_FROM_JAVACORE_PATH] exists with file [$FILENAME]!" 2>/dev/null >> "$DEBUG_LOG" 

	    # First, record the list of files in the dir, so we have it for later for more efficient access
	    recordExistingFiles "$DIR_FROM_JAVACORE_PATH" "${PREEXISTING_STDERR_FILE_LIST[$PID_INDEX]}" "$JAVACORE_FILE_PATTERN"

	    # Now grab the javacores from there
	    getJavacoreFile "$DIR_FROM_JAVACORE_PATH" "$FILENAME" "${PREEXISTING_STDERR_FILE_LIST[$PID_INDEX]}"
	fi	
    else
	# See fi the javacore itself was written to STDERR
	IBM_JAVACORE_DUMPED_TO_STDERR=`$GREP -ci "Java Dump written to stderr" "$OUTPUT_DIR/PID_$PID$WAIT_FILES_DIR/stderrTailLog.ITER_$ITER.txt" 2>/dev/null`;
	if [ -n "$IBM_JAVACORE_DUMPED_TO_STDERR" ] && [ "$IBM_JAVACORE_DUMPED_TO_STDERR" -gt 0 ]; then
	    $AWK '/JVM Requesting Java Dump/,/END OF DUMP/' "$OUTPUT_DIR/PID_$PID$WAIT_FILES_DIR/stderrTailLog.ITER_$ITER.txt" 2>/dev/null | $GREP -v "JVM Requesting Java Dump" > "$OUTPUT_DIR/PID_$PID/ibmFromStderr_javacore$PID.0.txt.ITER_$ITER.txt";

	    # MRA TODO: Get rid of this hack counter.  But for now it's used to mark if we've found anything yet
	    math_add $COUNT 1; COUNT=$RET_VAL
	fi
    fi
}

moveNewJavacores() {

    IBM_JAVACORE_COUNT=0;
    for PID_INDEX in ${PID_INDICES[@]}
      do 
      PID=${PIDS[$PID_INDEX]};

      COUNT_THIS_PID_THIS_ITER=0
      if [ "${JSTACK_FOUND[$PID_INDEX]}" = "1" ]; then 
          # Increment the number of sun javcores gathered by looking for them on disk
          # They can't be counted when triggered with jstack because that is now done
          # in parallel in a background process
	  newSunDumps=`ls $OUTPUT_DIR/PID_$PID/$HOTSPOT_FILE_PREFIX.*.ITER_$ITER.* 2>/dev/null | wc -l 2>>"$ERRORLOG" | awk '{ print $1; exit; }' 2>>"$ERRORLOG" `;
	  incJstackJavacores $newSunDumps
      else
	  # IBM Javacores
	  AT_LEAST_ONE_IBM_JVM=1;
	  moveNewJavacoresForPID
	  incIbmJavacores $COUNT
      fi

      if [ "$COUNT_THIS_PID_THIS_ITER" != "0" ]; then
	  # You found javacores for this PID
	  HAD_SUCCESS_FOR_PID[$PID_INDEX]="1";
      fi
    done

    if [ $IBM_JAVACORE_COUNT_THIS_ITER -gt 0 ]; then
	echo "Collected $IBM_JAVACORE_COUNT_THIS_ITER IBM javacores" | tee -a "$CONSOLE_LOG"
    fi
    if [ $SUN_JAVACORE_COUNT_THIS_ITER -gt 0 ] && [ $SUN_JAVACORE_COUNT_THIS_ITER -ne $JSTACK_JAVACORE_COUNT_THIS_ITER ]; then
	echo "Collected $SUN_JAVACORE_COUNT_THIS_ITER Hotspot javacores total" | tee -a "$CONSOLE_LOG"
    fi

    # ERROR REPORTING
        
    if [ "$TOTAL_JAVACORE_COUNT_THIS_ITER" = "0" ] && [ -z "${HAD_SUCCESS_FOR_PID[$PID_INDEX]}" ]; then
	# We found no javacores
	if [ -n "$STDERR_READ_FAILED" ] || [ -n "$STDOUT_READ_FAILED" ]; then
	    # And we failed to read STDERR or STDOUT
	    if [ -z "$ALREADY_REPORTED_STDERR_STDOUT_FAILURES" ]; then
		# And we haven't yet reported an error, so report one
		if [ -n "$STDERR_READ_FAILED" ]; then 
		    PROBLEMATIC_STREAM="STDERR"
		    PROBLEMATIC_PID_INDEX="$STDERR_READ_FAILED"
		else
		    PROBLEMATIC_STREAM="STDOUT"
		    PROBLEMATIC_PID_INDEX="$STDOUT_READ_FAILED"
		fi
		PROBLEMATIC_PID=${PIDS[$PROBLEMATIC_PID_INDEX]};
		
		if [ -z "$PROBLEMATIC_PID" ]; then
		    echo "Tried to report error for bogus problematic PID: [$PROBLEMATIC_PID]  PID_INDEX: [$PROBLEMATIC_PID_INDEX]" 2>/dev/null >> "$DEBUG_LOG" ;
		    return
		fi
		if [ -n "${SIGNAL_FAILED_FOR_PID[$PROBLEMATIC_PID_INDEX]}" ]; then
                    # We know why we failed.  It was a bad signal. Don't print again
		    return
		fi


		ALREADY_REPORTED_STDERR_STDOUT_FAILURES="1";
		echo " " | tee -a "$CONSOLE_LOG"
		echo WARNING:  No javacores were found for $PROBLEMATIC_PID, possibly because the collector could not access $PROBLEMATIC_STREAM. | tee -a "$CONSOLE_LOG"
		    
		# If we're on AIX or Solaris and we're not root, then that's the problem
		PRINTED_MESSAGE=""
		if [ "$WHOAMI" != "root" ]; then
		    if [ "$IS_SOLARIS" = "1" ]; then
			echo "         On Solaris, please either rerun the collector as root, or switch your application to run "  | tee -a "$CONSOLE_LOG"
			echo "         with a full JDK so that the jstack command is available." | tee -a "$CONSOLE_LOG"
			PRINTED_MESSAGE="1"
			echo ""  | tee -a "$CONSOLE_LOG"
		    else
			if [ "$IS_AIX" = "1" ]; then
			    echo "         On AIX, please either rerun the collector as root, or use the collector's --javacoreDir argument to specify " | tee -a "$CONSOLE_LOG"
                            #'
			    echo "         the directory where the JVM is writing the javacores." | tee -a "$CONSOLE_LOG"
			    echo " " | tee -a "$CONSOLE_LOG"
			    PRINTED_MESSAGE="1"
			fi
		    fi
		fi
		if [ -z "$PRINTED_MESSAGE" ]; then
		    # Didnt print message with known special cases above, so print the generic one
		    echo "         If $PROBLEMATIC_STREAM of the JVM is not being output to a file, please either " | tee -a "$CONSOLE_LOG"
		    echo "            a. Restart the JVM with output directed to a file." | tee -a "$CONSOLE_LOG"
		    echo "            b. Use the data collector's --javacoreDir argument to specify the directory where the JVM is writing the javacores (IBM JVMs)" | tee -a "$CONSOLE_LOG"
                    #' 
		    echo "            c. Use a Hotspot JDK rather than Hostspot JRE,  so that the jstack command is available" | tee -a "$CONSOLE_LOG"
		    echo " "  | tee -a "$CONSOLE_LOG"
		fi
	    fi
	fi
    fi
}

# move in javacores from the previous iteration, if there are any
# Be sure to ignore the ones that existed before you started
moveNewJavacoresForPID() {

    COUNT=0;

    echo "Getting javacores for PID: $PID" 2>/dev/null >> "$DEBUG_LOG" 

    if [ -n "${CONFIRMED_JAVACORE_DIR[$PID_INDEX]}" ]; then
	echo "CONFIRMED_JAVACORE_DIR for PID $PID: [${CONFIRMED_JAVACORE_DIR[$PID_INDEX]}]" 2>/dev/null >> "$DEBUG_LOG" 
	moveJavacoresFromDir "${CONFIRMED_JAVACORE_DIR[$PID_INDEX]}" "${CONFIRMED_JAVACORE_DIR_PREEXISTING_FILES[$PID_INDEX]}"
    fi

    if [ $COUNT = "0" ] && [ -n "$USER_SPECIFIED_JAVACORE_DIR" ]; then
	echo "USER_SPECIFIED_JAVACORE_DIR: [$USER_SPECIFIED_JAVACORE_DIR]" 2>/dev/null >> "$DEBUG_LOG" 
	moveJavacoresFromDir "$USER_SPECIFIED_JAVACORE_DIR" "$OUTPUT_DIR$WAIT_FILES_DIR/preexistingUserSpecifiedDir.txt"
	if [ $COUNT = "0" ]; then
	    echo "" | tee -a "$CONSOLE_LOG"
	    echo "WARNING:  No javacores found in user directory specified: [$USER_SPECIFIED_JAVACORE_DIR];" | tee -a "$CONSOLE_LOG"
	    echo "          Looking in alternate locations." | tee -a "$CONSOLE_LOG"
	fi
    fi
    
    # If environment variable specified a location, check here first
    if [ $COUNT = "0" ] && [ -n "${ALT_JAVACORE_DIR[$PID_INDEX]}" ]; then
	echo "ALT_JAVACORE_DIR for PID $PID: [${ALT_JAVACORE_DIR[$PID_INDEX]}]" 2>/dev/null >> "$DEBUG_LOG" 
	moveJavacoresFromDir "${ALT_JAVACORE_DIR[$PID_INDEX]}" "${PREEXISTING_JAVACORE_LIST_ALT[$PID_INDEX]}"
    fi

    # if none found still, look in CWD
    if [ $COUNT = "0" ]; then
	echo "PROCESS_CWD for PID: $PID: [${PROCESS_CWD[$PID_INDEX]}]" 2>/dev/null >> "$DEBUG_LOG" 
	moveJavacoresFromDir ${PROCESS_CWD[$PID_INDEX]} ${PREEXISTING_FILE_LIST_CWD[$PID_INDEX]}
    fi
    
    # Move things out of /tmp
    if [ $COUNT = "0" ] && [ -n "$TMP_DIR" ]; then
	echo "TMP_DIR: [$TMP_DIR]" 2>/dev/null >> "$DEBUG_LOG" 
	moveJavacoresFromDir "$TMP_DIR" "$OUTPUT_DIR$WAIT_FILES_DIR/preexistingJavacoreFilesSlashTmp.txt"
    fi

    # if none found still, use stderr to try to find out where it went
    if [ $COUNT = "0" ]; then
	if [ -z "${STDERR_FAILED_PREVIOUSLY[$PID_INDEX]}" ]; then
	    findJavacoreFromStderr
	fi
    fi

    if [ $COUNT = "0" ]; then
	if [ -z "${STDOUT_FAILED_PREVIOUSLY[$PID_INDEX]}" ]; then
	    HOTSPOT_JAVACORE_DUMPED_TO_STDOUT=`$GREP -ci "Full thread dump Java Hot" "$OUTPUT_DIR/PID_$PID$WAIT_FILES_DIR/stdoutTailLog.ITER_$ITER.txt" 2>/dev/null`;
	    echo "Looking for javacore in stdout [$HOTSPOT_JAVACORE_DUMPED_TO_STDOUT]  [$OUTPUT_DIR/PID_$PID$WAIT_FILES_DIR/stdoutTailLog.ITER_$ITER.txt]" 2>/dev/null >> "$DEBUG_LOG" 
	    if [ -n "$HOTSPOT_JAVACORE_DUMPED_TO_STDOUT" ] && [ "$HOTSPOT_JAVACORE_DUMPED_TO_STDOUT" -gt 0 ]; then
		$AWK '/Full thread dump Java Hot/,EOF { print p }  { p=$0 }' "$OUTPUT_DIR/PID_$PID$WAIT_FILES_DIR/stdoutTailLog.ITER_$ITER.txt" >> ""$OUTPUT_DIR/PID_$PID/sunDumpFromStderr_sunDump.$PID.ITER_$ITER.txt"" 2>&1 
		incHotspotJavacores 1
	    fi
	fi
    fi


    echo "Collected $COUNT javacores for PID: $PID" 2>/dev/null >> "$DEBUG_LOG" 

    if [ $ALLOW_HEAPDUMPS = "0" ]; then
	# Heap dumps not allowed.  If you see one, exit immediately
	# file identified by starting with "heapdump" and having the pid in it
	HEAPDUMPS=`cd "$JAVACORE_DIR" 2>/dev/null && ls heapdump*.$PID.* 2>>"$ERRORLOG" | $GREP -v -f "${PREEXISTING_FILE_LIST_CWD[$PID_INDEX]}" 2>>"$ERRORLOG"`

	if [ -n "${ALT_HEAPDUMP_DIR[$PID_INDEX]}" ]; then
	    HEAPDUMPSALT=`cd "${ALT_HEAPDUMP_DIR[$PID_INDEX]}" 2>/dev/null && ls heapdump*.$PID.* 2>>"$ERRORLOG" | $GREP -v -f "${PREEXISTING_HEAPDUMP_LIST_ALT[$PID_INDEX]}" 2>>"$ERRORLOG"`
	fi 

	HEAPDUMPSTMP=`cd $TMP_DIR 2>/dev/null && ls heapdump*.$PID.* 2>>"$ERRORLOG" | $GREP -v -f "$OUTPUT_DIR$WAIT_FILES_DIR/preexistingHeapdumpFilesSlashTmp.txt" 2>>"$ERRORLOG"`;

        # Cat the two together so if anything occurs we have a problem
	NEW_HEAPDUMPS=$HEAPDUMPS$HEAPDUMPSALT$HEAPDUMPSTMP

	if [ "$HEAPDUMPS_IN_STDERR" -gt "0" ] || [ -n "$NEW_HEAPDUMPS" ]; then


	    if [ -z "$ALREADY_WARNED_ABOUT_HEAPDUMPS" ]; then
		ALREADY_WARNED_ABOUT_HEAPDUMPS=1;

		echo " " | tee -a "$CONSOLE_LOG"
		echo " WARNING:  A heapdump was generated so the WAIT colletor is exiting.  Heap dumps are very expensive " | tee -a "$CONSOLE_LOG"
		echo "           and can be disabled by unsetting the environment variable IBM_HEAPDUMP in the JVM process." | tee -a "$CONSOLE_LOG"
	    fi

	    # The mustgather script does NOT exit in the presence of heapdumps, as per their request
	    # Thus only exit if non-mustgather
	    if [ -z "$MUSTGATHER" ]; then
		echo "           To force the WAIT collector to continue despite heapdumps being generated,use option --continueIfHeapdumpsOccur" | tee -a "$CONSOLE_LOG"
		echo "  " | tee -a "$CONSOLE_LOG"

		countTotalJavacores

		echo "Exiting." | tee -a "$CONSOLE_LOG"
		exit;
	    fi
	fi
    fi
}

# See if we are websphere, and if so, find the log dir
seeIfWebsphere() {

    FOUND_LOG_DIR="";

    # Get the value of user.install.root from command line argument.
    # Example: -Duser.install.root=/opt/IBM/WebSphere/AppServer/profiles/AppSrv01
    # Note: failes if there's a space in the name.
    USER_INSTALL_ROOT=`cat "$OUTPUT_DIR/PID_$PID/cmdLine.txt" | tr " " "\n" | awk -F'=' '/-Duser.install.root/ { print $2; exit; }'`

    if [ -n "$USER_INSTALL_ROOT" ]; then
	# If we found the user install root, then we we are (likely) websphere and we'll try to find the log dir
	# We need to know the server name, since the log dir is in $USER_INSTALL_ROOT/logs/SERVER_NAME
	# The server is (always?) the last parameter when invoking WAS.
	
	SERVER_NAME=`cat "$OUTPUT_DIR/PID_$PID/cmdLine.txt" | awk '/-Duser.install.root/ { print $NF } '`

	LOGDIR="$USER_INSTALL_ROOT/logs/$SERVER_NAME";
	
	if [ -d "$LOGDIR" ]; then
	    echo "" | tee -a "$CONSOLE_LOG"
	    echo "Found websphere log directory for PID $PID: [$LOGDIR]" | tee -a "$CONSOLE_LOG"
	    FOUND_LOG_DIR=1
	    WAS_LOG_DIR[$PID_INDEX]="$USER_INSTALL_ROOT/logs";
	    WAS_SERVER_NAME[$PID_INDEX]="$SERVER_NAME";
	fi
    fi

    # Only print that logs couldn't be found if we're must gather
    if [ -n "$MUSTGATHER" ] && [ -z "$FOUND_LOG_DIR" ]; then
	echo "" | tee -a "$CONSOLE_LOG"
	echo "ERROR: Could not locate WebSphere log file directory for PID: $PID.  Log files must be gathered manually" | tee -a "$CONSOLE_LOG"
    fi


}

# Initialization upon a new pid
initPidDirs() {

    seeIfWeAreSun

    # Create the output directories for each PID
    for PID_INDEX in ${PID_INDICES[@]}
      do
      PID=${PIDS[$PID_INDEX]};

      PID_SUBDIR="$OUTPUT_DIR/PID_$PID"
      if [ ! -d "$PID_SUBDIR" ]; then
	  mkdir -p "$PID_SUBDIR" 2>>"$ERRORLOG" | tee -a "$CONSOLE_LOG" ;
	  echo "Making direcory for PID $PID" 2>/dev/null >> "$DEBUG_LOG" ;
	  # If must gather than make subdir for all the WAIT files
	  if [ -n "$MUSTGATHER" ]; then
	      mkdir -p "$PID_SUBDIR/$WAIT_FILES_DIR" 2>>"$ERRORLOG" | tee -a "$CONSOLE_LOG" ;
	  fi

          # Get the command line args and env vars for this process
          $PS_CMD_LINE_CMD $PID >> "$OUTPUT_DIR/PID_$PID/cmdLine.txt" 2>&1 
          $PS_ENV_VARS_CMD $PID >> "$OUTPUT_DIR/PID_$PID/envVars.txt" 2>&1 
#	  PRINT_CONSOLE("Found PID: $PID")

	  if [ -n "$MUSTGATHER" ]; then
	      seeIfWebsphere
	  fi

      fi

      
      # Dirs specific to the process
      PREEXISTING_FILE_LIST_CWD[$PID_INDEX]="$OUTPUT_DIR$WAIT_FILES_DIR/preexistingFiles.txt"
      PREEXISTING_JAVACORE_LIST_ALT[$PID_INDEX]="$OUTPUT_DIR$WAIT_FILES_DIR/preexistingJavacoreFilesAlternate.txt"
      PREEXISTING_HEAPDUMP_LIST_ALT[$PID_INDEX]="$OUTPUT_DIR$WAIT_FILES_DIR/preexistingHeapdumpFilesAlternate.txt"
      PREEXISTING_STDERR_FILE_LIST[$PID_INDEX]="$OUTPUT_DIR$WAIT_FILES_DIR/preexistingFilesStderrDir.txt"

      unset CONFIRMED_JAVACORE_DIR;

      JSTACK_FOUND=${JSTACK_FOUND[$PID_INDEX]};

      if [ "$JSTACK_FOUND" = "0" ]; then

         # Figure out the working directory of each PID
	 PROCESS_CWD[$PID_INDEX]="/proc/$PID/cwd";
      
	 LINKED_CWD_DIR=`ls -l /proc/$PID/cwd 2>/dev/null | $AWK '{ print $NF }'`;  
	 
         # If we parsed the dir correctly that the link points to, then use it since it's less cryptic.  
         # Otherwise stik with the /proc/PID/cwd link since it works
	 if [ -e "$LINKED_CWD_DIR" ]; then
	     PROCESS_CWD[$PID_INDEX]="$LINKED_CWD_DIR";
	 fi
	 
	 if [ -z "$USER_SPECIFIED_JAVACORE_DIR" ]; then
             # MRA BUG:  This is no longer right after the prev command
             # If we haven't specified a javacore dir, then we need this command to succeed
	     assertCommandSuccess "Unable to access /proc/$PID.  Check that you are the same user of process $PID.  If this is not the problem, try command line option  --javacoreDir to specify where to find the javacores.";
	 fi
      
         # Rec ord the javacores that exist before we start, so we don't touch them
	 recordExistingFiles "${PROCESS_CWD[$PID_INDEX]}" "${PREEXISTING_FILE_LIST_CWD[$PID_INDEX]}"  "$JAVACORE_FILE_PATTERN"
      
         # See if an environment variable tells us where the javacores are going
         # If so, snapshot those files too

         if [ "$HAVE_TR" = "1" ]; then
	     # The following AWK voodoo is because the PS output doesn't put the filenames in any kind of quotes, and they may contain spaces
	     # This code uses tr to break the line at the "=" sign, then looks at the line after the matching variable name, and removes the last column bcause it's the next line's var name
             # The only scenario where this code fails is where the variable has spaces (NF > 1) AND the variable is last in the list, because the last column shouldn't be removed. Oh well.
	     ALT_JAVACORE_DIR[$PID_INDEX]=`cat "$OUTPUT_DIR/PID_$PID/envVars.txt" | tr "=" "\n" 2>>"$ERRORLOG" | $AWK '/IBM_JAVACOREDIR/ { getline; if (NF > 1) { $NF=""; NF--; } print $0 }'`;
	     if [ -n "${ALT_JAVACORE_DIR[$PID_INDEX]}" ]; then
		 recordExistingFiles "${ALT_JAVACORE_DIR[$PID_INDEX]}" "${PREEXISTING_JAVACORE_LIST_ALT[$PID_INDEX]}"  "$JAVACORE_FILE_PATTERN"
	     fi
	   
	     ALT_HEAPDUMP_DIR[$PID_INDEX]=`cat "$OUTPUT_DIR/PID_$PID/envVars.txt" | tr " " "\n" 2>>"$ERRORLOG" | $AWK '/IBM_HEAPDUMPDIR/ { getline; if (NF > 1) { $NF=""; NF--; } print $0 }'`;
	     if [ -n "${ALT_HEAPDUMP_DIR[$PID_INDEX]}" ]; then
		 recordExistingFiles "${ALT_HEAPDUMP_DIR[$PID_INDEX]}" "${PREEXISTING_HEAPDUMP_LIST_ALT[$PID_INDEX]}"  "$HEAPDUMP_FILE_PATTERN"
	     fi
	 fi
	 
      fi
    done

}    


# Use PS to find all PIDS
findPidsByName() {
    
    clearAllPids
    
    PID_LIST=`ps -eo pid,args | $AWK '{ print $1 " " $2 }' | $GREP "[ /]$PROCESS_NAME\$" | $AWK '{ print $1 }'`;
    for pid in $PID_LIST
      do
      addPid $pid
    done


    initPidDirs
}

clearAllPids() {
    unset PIDS
    unset PID_INDICES
    unset JSTACK_FOUND
    unset JSTACK_EXE
    unset CHECKED_JVM_VERSION
    unset CONFIRMED_JAVACORE_DIR
    unset CONFIRMED_HEAPDUMP_DIR
    unset CONFIRMED_JAVACORE_DIR_PREEXISTING_FILES
    NUM_PIDS=0;
}

addPid() {

    PID="$1";

    # Only add this PID if you have permission to access it
    ls -l /proc/$PID/cwd 2>/dev/null >/dev/null
    if [ $? != "0" ]; then

	# We are unable to access the info for this pid.  Try to figure out if it's because
	# you don't have permissions, or if it's because it doesn't exist
	ls -d /proc/$PID 2>/dev/null >/dev/null

	# NOTE: This check has race conditions (this PID could have been created since the above) but this is just to get the 
	# error messages most helpful in the dominant case.
	if [ $? == "0" ]; then
	    # Directory /proc/PID exists, so if you can't access /proc/PID/cwd you must not have permissions
            # NOTE: Output dir not initized yet, so don't use logging calls
	    echo ""
	    echo "ERROR: unable to access PID $PID, likely due to insufficient permissions. Skipping."
	    echo "This script must be run as the same user as the process monitored, or as root.  "
	    echo ""
	else
	    # Directory /proc/PID doesn't seem to exist 
	    echo ""
	    echo "PID: $PID cannot be found.  Skipping";
	    echo ""
	fi

	return;
    fi

    # Track the set of pids
    PIDS[NUM_PIDS]=$1;
    
    # For simplified iteration, create an array of the indices themselves
    PID_INDICES[NUM_PIDS]=$NUM_PIDS;
    math_add $NUM_PIDS 1; NUM_PIDS=$RET_VAL

#    PRINT_CONSOLE("ADDED PID: $PID")
}

# Common place to set the current date timestamp
setDate() {
    DATE=`$DATE_CMD '+ %Y%m%d %H:%M:%S:%N %Z' 2>/dev/null`;
}
setDateLocal() {
    DATE=`date '+ %Y%m%d %H:%M:%S:%N %Z' 2>/dev/null`;
}
setDateUtc() {
    DATE=`date -u '+ %Y%m%d %H:%M:%S:%N %Z' 2>/dev/null`;
}

# "tail -f" a file in the background, however
# Implement it by getting the size fo the file, then sleeping, then tailing from that number of bytes
# This avoids race conditions regarding how long it takes tail -f to start up, and other weirdnesses
# that made tail -f unreliable
backgroundCaptureTailDashF() {
    FILE_TO_CAPTURE="$1";
    TAIL_OUTPUT_FILE="$2";
    TAIL_SLEEP_TIME=$3;

    # Capture the size of the file in bytes
    getFileSizeBytesBackground "$FILE_TO_CAPTURE";
    BYTES=$RET_VAL;

    if [ "$BYTES" -lt "0" ]; then
	RET_VAL="-1"
	return;
    fi


    echo "Tailing file [$FILE_TO_CAPTURE] to output file: [$TAIL_OUTPUT_FILE] for [$TAIL_SLEEP_TIME] seconds from position [$SIZE_BYTES]" 2>/dev/null >> "$DEBUG_LOG" ;

#    ( COMMAND_TO_FILE(''$TAIL -c +$BYTES -f "$FILE_TO_CAPTURE" '',''$TAIL_OUTPUT_FILE'') ) 2>/dev/null &
    ( $TAIL -c +$BYTES -f "$FILE_TO_CAPTURE"  2>/dev/null > $TAIL_OUTPUT_FILE ) 2>/dev/null  & 
    $DISOWN  2>>"$ERRORLOG" >> "$CONSOLE_LOG" 
    TAIL_PID=$!

    # If limited by time, start background process to kill it
    if [ "$TAIL_SLEEP_TIME" != "-1" ]; then
	( sleep $TAIL_SLEEP_TIME 2>/dev/null >/dev/null ; kill -9 $TAIL_PID 2>/dev/null >/dev/null ) & 2>/dev/null
	$DISOWN  2>>"$ERRORLOG" >> "$CONSOLE_LOG" 
    fi

    RET_VAL=$TAIL_PID
    return 
}

# Tail the verbose gc file, from the previously marked position, for a given PID
# The optional argument specifies whether there are more iters to go after this one
captureVerboseGcForPrevIter() {

    MORE_ITERS_LEFT=$1;
    # Need these two to check for verbose GC file
    if [ "$HAVE_TR" = "1" ]; then

      # If verbose GC is being written to a file, we need to grab it with a tail -f
      GC_FILE=${VERBOSE_GC_FILE[$PID_INDEX]};
      if [ -z "$GC_FILE" ]; then
          # if this isn't set, then we need to look at the command line args for the process to check for the existence of 
          # -Xverbosegclog:filepath
          # This command below reports the part after the ":"
          # KNOWN BUG: Will not work for filename with space
	  echo "Checking for verbose GC" 2>/dev/null >> "$DEBUG_LOG" ;
	  GC_FILE="-1";

	  if [ -f "$OUTPUT_DIR/PID_$PID/cmdLine.txt" ]; then
	      # Xverbosegclog is J9,  Xloggc is Sun
	      FILE=`cat "$OUTPUT_DIR/PID_$PID/cmdLine.txt" | tr " " "\n" | awk -F':' '/Xverbosegclog/ || /Xloggc/ { print $2; exit; }'`;
	      echo "GC FILE: [$FILE]" 2>/dev/null >> "$DEBUG_LOG" ;
	      if [ -n "$FILE" ]; then
		  if [ -f "$FILE" ]; then
		      echo "Capturing verbose GC information from file: [$FILE]" | tee -a "$CONSOLE_LOG";
		      GC_FILE="$FILE"
		      # We need to record whether it was sun or not by looking at which cmd line we found above
		      GC_FILE_IS_SUN=`cat "$OUTPUT_DIR/PID_$PID/cmdLine.txt" | grep -c Xloggc: `;
		      if [ "$GC_FILE_IS_SUN" == "1" ] || [ "$IS_SOLARIS" = "1" ]; then 
			  VERBOSE_GC_OUTPUT_FILENAME[$PID_INDEX]="$OUTPUT_DIR/PID_$PID/sunverbosegc.txt"
		      else
			  VERBOSE_GC_OUTPUT_FILENAME[$PID_INDEX]="$OUTPUT_DIR/PID_$PID/ibmverbosegc.txt"
		      fi
		  else
		      echo "Found verbose GC filename from cmd line args for pid $PID,but it does not exist. File: [$FILE]" >> "$ERRORLOG" ;
		  fi
	      fi
	  fi
          # Remember the file for next time so we don't have to do this again
          VERBOSE_GC_FILE[$PID_INDEX]="$GC_FILE";
      fi


      # If we have an actual file
      if [ "$GC_FILE" != "-1" ]; then 
	  WAIT_GC_LOG_FILE=${VERBOSE_GC_OUTPUT_FILENAME[$PID_INDEX]};

	  if [ "$ITER" = "1" ]; then
              # Collect some history from before the first iter
	      $TAIL -n 1000 "$GC_FILE"  >> ""$WAIT_GC_LOG_FILE"" 2>&1 ;
	  else 
              # We should have recorded the "current position" in bytes within the GC file last time. 
              # If it's set, then we should tail from that point forward right now.
	      PREV_BYTES_MARKER=${GC_TAIL_CUR_POS[$PID_INDEX]};
	      if [ -n "$PREV_BYTES_MARKER" ]; then 
		  echo "Tailing file [$GC_FILE] starting at position in bytes: [$PREV_BYTES_MARKER]" 2>/dev/null >> "$DEBUG_LOG" ;
		  $TAIL -c +$PREV_BYTES_MARKER "$GC_FILE"  >> "$WAIT_GC_LOG_FILE" 2>&1 ;
	      fi
	  fi

	  # Record the size in bytes of the GC file.  This is where we start tailing next iter
	  getFileSizeBytes "$GC_FILE";
	  NEW_FILE_POS=$RET_VAL
	  GC_TAIL_CUR_POS[$PID_INDEX]=$NEW_FILE_POS
	  
	  if [ -n "$MORE_ITERS_LEFT" ]; then
	      echo "ITER_$ITER" >> ""$WAIT_GC_LOG_FILE""  ; echo "Time: $DATE" >> ""$WAIT_GC_LOG_FILE"";
	  fi
      fi
  fi
}

# Top runs in the background
killProcessIfExists() {
    THE_PID=$1;

    if [ -n "$THE_PID" ]; then
        # Just kill it quietly.  Will fail if nonexistant
	kill -9 $THE_PID 2>/dev/null >/dev/null
    fi
}

# Called from main loop of data collector, with "$PID" set to the PID to collect
gatherDataForProcess() {

  if [ "$USE_TOP" = "1" ]; then
      killProcessIfExists ${TOP_DASH_H_CMD_PID[$PID_INDEX]}
      echo "ITER_$ITER" >> "$OUTPUT_DIR/PID_$PID/topDashHOutput.txt"  ; echo "Time: $DATE" >> "$OUTPUT_DIR/PID_$PID/topDashHOutput.txt"
      top -bH -d $TOP_DASH_H_INTERVAL -n $TOP_DASH_H_ITERS -p $PID >> "$OUTPUT_DIR/PID_$PID/topDashHOutput.txt" 2>&1 &
      THE_PID=$!
      $DISOWN $THE_PID 2>>"$ERRORLOG" >> "$CONSOLE_LOG" 
      TOP_DASH_H_CMD_PID[$PID_INDEX]=$THE_PID
  fi

  # Get PS data
  if [ $HAVE_PS = "1" ]; then
      echo "ITER_$ITER" >> "$OUTPUT_DIR/PID_$PID$WAIT_FILES_DIR/psProcessOutput.txt"  ; echo "Time: $DATE" >> "$OUTPUT_DIR/PID_$PID$WAIT_FILES_DIR/psProcessOutput.txt"
      # TODO: Is this 'eval' still needed?
      eval "$PS_PROCESS_CMD $PID" >> $OUTPUT_DIR/PID_$PID$WAIT_FILES_DIR/psProcessOutput.txt
    
    if [ -n "$PS_THREADS_CMD" ]; then
	$PS_THREADS_CMD $PID >> "$OUTPUT_DIR/PID_$PID$WAIT_FILES_DIR/psThreadsOutput.ITER_$ITER" 2>&1 
    fi
  fi
  
  # svmon data (memory) about this proc
  if [ $HAVE_SVMON = "1" ]; then
      echo "ITER_$ITER" >> "$OUTPUT_DIR/PID_$PID$WAIT_FILES_DIR/svmonProc.txt"  ; echo "Time: $DATE" >> "$OUTPUT_DIR/PID_$PID$WAIT_FILES_DIR/svmonProc.txt"
      svmon -P $PID >> "$OUTPUT_DIR/PID_$PID$WAIT_FILES_DIR/svmonProc.txt" 2>&1 
  fi
  
  # Get process map file
  PROC_MAP_FILE="$OUTPUT_DIR/PID_$PID$WAIT_FILES_DIR/procMap.ITER_$ITER";
  cp /proc/$PID/$MEM_MAP_FILE "$PROC_MAP_FILE" 2>/dev/null >/dev/null;

  # If we don't yet have a confirmed javacore dir, then start tailing STDERR to find where they go
  if [ "${JSTACK_FOUND[$PID_INDEX]}" = "0" ] && [ -z "${CONFIRMED_JAVACORE_DIR[$PID_INDEX]}" ]; then 

      ERROR_MESSAGE=""

      if [ -z "${STDOUT_FAILED_PREVIOUSLY[$PID_INDEX]}" ]; then
          # Capture stdout
	  backgroundCaptureTailDashF "/proc/$PID/fd/1" "$OUTPUT_DIR/PID_$PID$WAIT_FILES_DIR/stdoutTailLog.ITER_$ITER.txt" $STDERR_TAIL_DURATION 

	  if [ "$RET_VAL" = "-1" ]; then
	      STDOUT_READ_FAILED="$PID_INDEX"
	      STDOUT_FAILED_PREVIOUSLY[$PID_INDEX]="1"
	  fi
      fi
      
      if [ -z "${STDERR_FAILED_PREVIOUSLY[$PID_INDEX]}" ]; then
	  # Capture stderr
	  backgroundCaptureTailDashF "/proc/$PID/fd/2" "$OUTPUT_DIR/PID_$PID$WAIT_FILES_DIR/stderrTailLog.ITER_$ITER.txt" $STDERR_TAIL_DURATION 

	  if [ "$RET_VAL" = "-1" ]; then
	      STDERR_READ_FAILED="$PID_INDEX"
	      STDERR_FAILED_PREVIOUSLY[$PID_INDEX]="1"
	  fi
      fi
  fi

  # Snapshot the verbose GC log file, if it exists
  captureVerboseGcForPrevIter 1

  # Trigger the javacore    
  if [ "$NOJAVACORETRIGGERS" = "0" ]; then
      JSTACK_OUT_FILE="$OUTPUT_DIR/PID_$PID/$HOTSPOT_FILE_PREFIX.$PID.ITER_$ITER.$HOTSPOT_FILE_SUFFIX";
      PID_IS_SUN="${JSTACK_FOUND[$PID_INDEX]}";
      if [ "$PID_IS_SUN" = "1" ]; then
	  echo "Triggering jstack for PID $PID" | tee -a "$CONSOLE_LOG"
	  jstackExe=${JSTACK_EXE[$PID_INDEX]};
	  echo About to execute jstack exe: [$jstackExe] on PID $PID to output file [$JSTACK_OUT_FILE] 2>/dev/null >> "$DEBUG_LOG" 
	  "$jstackExe" $PID >> "$JSTACK_OUT_FILE" 2>&1 
      else
	  echo "Triggering kill -3 for $PID" | tee -a "$CONSOLE_LOG"
	  # NOTE: The use of "QUIET_COMMAND" is important below.  If you use "COMMAND", then 'tee' is the last command in the pipe
	  # and the exit status of the kill is not detected properly on Solaris
	  kill -3 $PID 2>>"$ERRORLOG" >> "$CONSOLE_LOG" 
      fi
      #assertCommandSuccess "Triggering javacore via kill -3 failed.  Check that you are the same user of process $PID." 
      if [ $? != "0" ]; then
          # then the kill -3/jstack failed, so make sure to remove that last file
	  SIGNAL_FAILED_FOR_PID[$PID_INDEX]="1"
	  if [ "$PID_IS_SUN" = "1" ]; then
	      echo "Jstack failed for pid: $PID.  Consider using --noJstack option" | tee -a "$CONSOLE_LOG"
#	      rm -f "$JSTACK_OUT_FILE";
	  else
	      echo "Kill -3 failed for pid: $PID" | tee -a "$CONSOLE_LOG"
	  fi
	  if [ "$MULTIPLE_PID_MODE" = "0" ]; then
	      # If in single JVM mode and you can't get to the pid, then exit
              # Then break out of all loops
	      BREAK_OUTER_LOOP=1
	      JAVACORE_FAILURE_CAUSED_EARLY_TERMINATION=1
	      break
	  fi
      fi
  fi
}


setSleepInterval () {

    SLEEP_INTERVAL=$1;

    if [ -n "$MUSTGATHER" ]; then
    
        # TOP
	if [ "$TOP_INTERVAL" -gt "$SLEEP_INTERVAL" ]; then
	    TOP_INTERVAL=$SLEEP_INTERVAL
	fi

        # Compute the iters per javacore
	math_divide $SLEEP_INTERVAL $TOP_INTERVAL; TOP_ITERS=$RET_VAL
	math_add $TOP_ITERS 1; TOP_ITERS=$RET_VAL;
	
	echo "TOP_DASH_H_INTERVAL: $TOP_INTEVAL" 2>/dev/null >> "$DEBUG_LOG" 
	echo "TOP_DASH_H_ITERS: $TOP_ITERS" 2>/dev/null >> "$DEBUG_LOG" 
	
	
        # TOP_DASH_H
	if [ "$TOP_DASH_H_INTERVAL" -gt "$SLEEP_INTERVAL" ]; then
	    TOP_DASH_H_INTERVAL=$SLEEP_INTERVAL
	fi
        # Compute the iters per javacore
	math_divide $SLEEP_INTERVAL $TOP_DASH_H_INTERVAL; TOP_DASH_H_ITERS=$RET_VAL
	math_add $TOP_DASH_H_ITERS 1; TOP_DASH_H_ITERS=$RET_VAL;
	
	echo "TOP_DASH_H_INTERVAL: $TOP_DASH_H_INTEVAL" 2>/dev/null >> "$DEBUG_LOG" 
	echo "TOP_DASH_H_ITERS: $TOP_DASH_H_ITERS" 2>/dev/null >> "$DEBUG_LOG" 
    fi
    
    
    # PS Interval must alway be less than sleep interval
    if [ "$PS_INTERVAL" -gt "$SLEEP_INTERVAL" ]; then
	PS_INTERVAL=$SLEEP_INTERVAL
    fi
    
    if [ "$VMSTAT_INTERVAL" -gt "$SLEEP_INTERVAL" ]; then
	VMSTAT_INTERVAL=$SLEEP_INTERVAL
    fi
    
    if [ "$TPROF_SPAN" -gt "$SLEEP_INTERVAL" ]; then
	TPROF_SPAN=$SLEEP_INTERVAL;
    fi
}

# MAIN ENTRY


# trap ctrl-c and call ctrl_c()
trap trappedCtrlC INT

# This is the associative array that are all indexed by PID
#declare -a PID2CWD
#declare -a PROCESS_CWD

initJavacoreCounts

# Default values for variables, before parsing args
TPROF_SPAN=60
TOP_INTERVAL=60
VMSTAT_INTERVAL=1
TOP_DASH_H_INTERVAL=5
SLEEP_INTERVAL=0
MAX_ITERS=0
ALLOW_HEAPDUMPS=0
CONFIRMED_JAVACORE_DIR=""
CONFIRMED_HEAPDUMP_DIR=""
OUTPUT_DIR="/tmp/waitCollectionData.CollectorPid_$WDCPID"
USER_SPECIFIED_JAVACORE_DIR=""
USER_SPECIFIED_OUTPUT_DIR=""
UPDATE_ZIP_EVERY_ITER=0
DO_NOT_DELETE_RAW_FILES=0
DO_NOT_USE_JSTACK=0
HEAPDUMPS_IN_STDERR=0
ZIP_CMD="zip"
NOZIP=0
SKIP_JVM_VERSION_CHECK=0
NOJAVACORETRIGGERS=0
USER_SPECIFIED_PS_INTERVAL=0
PROCESS_NAME=""
DATA_COLLECTOR_ARGS="$*"

# Parse command line args
while [ -n "$1" ]; do
    case $1 in
        --iters )    shift
	    MAX_ITERS=$1
            ;;
        --sleep_interval | --sleep )    shift
	    SLEEP_INTERVAL=$1
            ;;
        --topInterval )    shift
	    TOP_INTERVAL=$1
            ;;
        --topDashHInterval )    shift
	    TOP_DASH_H_INTERVAL=$1
            ;;
        --vmstatInterval )    shift
	    VMSTAT_INTERVAL=$1
            ;;
        --tprofSpan )    shift
	    TPROF_SPAN=$1
            ;;
        --psInterval )    shift
	    USER_SPECIFIED_PS_INTERVAL=$1
            ;;
        --javacoreDir )    shift
	    USER_SPECIFIED_JAVACORE_DIR="$1"
            ;;
        --processName )    shift
	    PROCESS_NAME="$1";
            ;;
        --outputZip )    shift
	    ZIP_PREFIX="$1";
            ;;
        --updateZipEveryIter )    
	    UPDATE_ZIP_EVERY_ITER=1
            ;;
        --continueIfHeapdumpsOccur )    
	    ALLOW_HEAPDUMPS=1
            ;;
        --skipJvmVersionCheck )
	    SKIP_JVM_VERSION_CHECK=1
            ;;
        --outputDir )    shift
	    USER_SPECIFIED_OUTPUT_DIR=1;
	    OUTPUT_DIR=$1;
            ;;
        --grep )    shift
	    USER_SPECIFIED_GREP=$1;
            ;;
	--noDelete )
	    DO_NOT_DELETE_RAW_FILES=1;
	    ;;
	--noJstack )
	    DO_NOT_USE_JSTACK=1;
	    ;;
	--disableDisown )
	    FORCE_DISABLE_DISOWN=1;
	    ;;
        --noZip | --nozip)
	    NOZIP=1;
	    ;;
        --mustGather|--mustgather )
	    MUSTGATHER=1;
	    ;;
        --noJavacoreTriggers )
	    NOJAVACORETRIGGERS=1;
            ;;
        --debug )
	    DEBUG=1;
            ;;
        *)

	    addPid $1;
            ;;
    esac
    shift
done


#
#MUSTGATHER=1;
SCRIPT_NAME=$0  
if [ -n "$MUSTGATHER" ]; then
    if [ -z "$ZIP_PREFIX" ]; then
	ZIP_PREFIX="mustGather_RESULTS"
    fi
    DEFAULT_SLEEP_INTERVAL=120
    DATE_CMD="date";  # mustgather requested local time, not UTC
else
    if [ -z "$ZIP_PREFIX" ]; then
	ZIP_PREFIX="waitData"
    fi
    DEFAULT_SLEEP_INTERVAL=30
    DATE_CMD="date -u";  # Use UTC for non-must gather
fi



if [ "$MAX_ITERS" = "0" ]; then
    if [ -n "$MUSTGATHER" ]; then
	# Mustgather default is 3 iters
	MAX_ITERS=3;
    else 
	MAX_ITERS=300;
    fi
fi



if [ $MISSING_PS = "1" ]; then
  HAVE_PS=0;
else
  HAVE_PS=1;
fi

GREP="grep"
# BUG for solaris:  "$GREP" isn't yet established on solaris
EGREP_RESULT=`echo 123 | $GREP -E "[123]+" 2>/dev/null`;

if [ "$EGREP_RESULT" = "123" ]; then
    HAVE_EGREP=1;
else
    HAVE_EGREP=0;
fi

# If using must gather we store the WAIT files in subdirs
WAIT_FILES_DIR="";
if [ -n "$MUSTGATHER" ]; then
    WAIT_FILES_DIR="/waitToolFiles";
fi

# Setup output dir
if [ -n "$USER_SPECIFIED_OUTPUT_DIR" ]; then
    # IF using user specified output dir, make sure it exists and is
    # empty, or can be created

    # Create with subdirs, no errors if exists
    mkdir -p "$OUTPUT_DIR" 2>>"$ERRORLOG" | tee -a "$CONSOLE_LOG" 

    # Make sure empty
    if [ "$(ls -A $OUTPUT_DIR)" ]; then
	echo
	echo "Output directory is not empty: $OUTPUT_DIR."
	echo "Please remove all content, specify another directory, or do not use the --outputDir option"
	echo "Exiting."
	echo
	exit;
    fi

else
    # User outputDir not specified. Using /tmp for output.  Try to make the
    # temp dir.  
    DIR_NUM=0;
    NEW_OUTPUT_DIR="$OUTPUT_DIR"
    mkdir  "$NEW_OUTPUT_DIR" 
    # Check error code
    while [ $? != "0" ]; do
        # Directory exists. 
        # If we've tried to many, give up
	if [ $DIR_NUM -gt 1000 ]; then
	    echo "Could not create tmp dir for WAIT output: $OUTPUT_DIR";
	    echo "Use --outputDir to specify a temp directory name that can be created."
	    echo "Exiting."
	    exit 1;
	fi

        # Try some more.
	math_add $DIR_NUM 1; DIR_NUM=$RET_VAL
	NEW_OUTPUT_DIR="${OUTPUT_DIR}_$DIR_NUM";
	mkdir "$NEW_OUTPUT_DIR" 
    done
    OUTPUT_DIR="$NEW_OUTPUT_DIR";
fi

# If must gather than make subdir for all the WAIT files
if [ -n "$MUSTGATHER" ]; then
    mkdir -p "$OUTPUT_DIR/$WAIT_FILES_DIR" 2>>"$ERRORLOG" | tee -a "$CONSOLE_LOG" ;
fi


FIND_PROCESSES_BY_NAME=0;
MULTIPLE_PID_MODE=0;
# Now figure out the PID of the process to monitor
if [ "$NUM_PIDS" -gt "0" ]; then
    for PID in ${PIDS[@]}
      do
      # Check that user specified PID is an integer
      if [ "$HAVE_EGREP" = "1" ]; then
	  if [ ! $(echo "$PID" | $GREP -E "^[0-9]+$") ]; then
	      echo 
	      echo "ERROR:  Option not recognized or specified PID is not an integer: [$PID]";
	      echo 
	      usage;
	      exit;
	  fi
      fi 
      if [ $HAVE_PS = "1" ]; then
	  `ps -p $PID 2> /dev/null 1> /dev/null `;
	  assertCommandSuccess "Invalid process ID $PID"
      fi
      if [ "$NUM_PIDS" -gt "1" ]; then
	  MULTIPLE_PID_MODE=1;
      fi
    done
else
    if [ -n "$PROCESS_NAME" ]; then
	FIND_PROCESSES_BY_NAME=1;
	MULTIPLE_PID_MODE=1;
	if [ $HAVE_PS = "0" ]; then
	    echo 
	    echo "ERROR: Cannot use option --processName when ps cannot be found on your path."
	    echo
	    exit;
	fi
    else
	echo "ERROR: No valid PIDs specified.  You must either specify one or more valid PIDs, or use the option:  --processName NAME "
	echo
	usage	
    fi
fi



ITER=0;

HOTSPOT_FILE_PREFIX="sunDump"
HOTSPOT_FILE_SUFFIX="txt"

# These change throughout execution
CONSOLE_LOG="$OUTPUT_DIR/consoleLog.txt"
ERRORLOG="$OUTPUT_DIR$WAIT_FILES_DIR/errorLog.txt"
DEBUG_LOG="$OUTPUT_DIR$WAIT_FILES_DIR/debugLog.txt"


# PID-specific files
TOTAL_JAVACORE_COUNT=0;


# Clone STDERR and STDOUT to log files
if [ "$USING_BASH" = "1" ]; then
    eval "exec 2> >(tee $OUTPUT_DIR$WAIT_FILES_DIR/stderr.log) 1> >(tee $OUTPUT_DIR$WAIT_FILES_DIR/stdout.log)"
fi

if [ "$SLEEP_INTERVAL" = "0" ]; then
    # if sleep interval wasn't set, put it at the default
    if [ -n "$MUSTGATHER" ]; then
	SLEEP_INTERVAL=$DEFAULT_SLEEP_INTERVAL;
    else
	SLEEP_INTERVAL=$DEFAULT_SLEEP_INTERVAL;
    fi
fi

# We want to run PS frequently, while not filling up the disk
# By keeping PS to be a factor of the javacore interval, we ensure
# ps will never be the cause of filling up the disk.  
math_divide $SLEEP_INTERVAL 5; PS_INTERVAL=$RET_VAL
# Minimum PS interval is 4 seconds, since this script has overhead between invocations
math_add $PS_INTERVAL 2; PS_INTERVAL=$RET_VAL


setSleepInterval $SLEEP_INTERVAL

if [ "$USER_SPECIFIED_PS_INTERVAL" -gt "0" ]; then

    if [ "$USER_SPECIFIED_PS_INTERVAL" -gt "$SLEEP_INTERVAL" ]; then
	echo "" | tee -a "$CONSOLE_LOG"
	echo "ERROR: PS sample interval must be less than javacore sleep interval." | tee -a "$CONSOLE_LOG"
        echo "Exiting." | tee -a "$CONSOLE_LOG"
	echo "" | tee -a "$CONSOLE_LOG"
	exit;
    fi

    PS_INTERVAL=$USER_SPECIFIED_PS_INTERVAL;
fi

if [ "$SLEEP_INTERVAL" -lt "$TOP_DASH_H_INTERVAL" ]; then
    TOP_DASH_H_INTERVAL=$SLEEP_INTERVAL;
fi


# Check for the tools we need
if [ "$NOZIP" = "0" ]; then
    checkCommandExists $ZIP_CMD
    HAVE_ZIP=$?;
    checkCommandExists tar
    HAVE_TAR=$?;
    checkCommandExists gzip
    HAVE_GZIP=$?;

    if [ $HAVE_ZIP = "0" ] && [ $HAVE_TAR = "0" ]; then
	echo "Could not find 'tar' on your path. " | tee -a "$CONSOLE_LOG"
	echo "Please run with option --noZip option,and manually zip or gzip the data in the output dir when complete." | tee -a "$CONSOLE_LOG"
	echo "Exiting." | tee -a "$CONSOLE_LOG"
	exit 1;
    fi
fi


# Create a file to identify this file as a WAIT zip file
touch "$OUTPUT_DIR/WAIT_PERFORMANCE_TOOL_DATA_SET"

# Clean existing wait data files 
rm -f $ZIP_PREFIX.zip $ZIP_PREFIX.tar $ZIP_PREFIX.tar.gz 

# Filename patterns for what files we collect
JAVACORE_FILE_PATTERN="javacore* JAVADUMP*"
HEAPDUMP_FILE_PATTERN="heapdump*"


# Start showing the user some info.. so if we fail from here they could at least see what was happening
echo "" | tee -a "$CONSOLE_LOG"
if [ -n "$MUSTGATHER" ]; then
    echo "WAS Performance Must Gather!" | tee -a "$CONSOLE_LOG"
    echo "----------------------------" | tee -a "$CONSOLE_LOG"
else
    echo "WAIT data collector!" | tee -a "$CONSOLE_LOG"
    echo "-------------------" | tee -a "$CONSOLE_LOG"
fi
echo "Collector version $VERSION" | tee -a "$CONSOLE_LOG"
if [ -n "$PROCESS_NAME" ]; then
    echo "Collecting data for processes named: $PROCESS_NAME" | tee -a "$CONSOLE_LOG"
else
    echo "Collecting data for PIDs: ${PIDS[@]}" | tee -a "$CONSOLE_LOG"
fi
    echo "Sleep time between java cores: $SLEEP_INTERVAL" | tee -a "$CONSOLE_LOG"
echo "Number of iterations to collect: $MAX_ITERS" | tee -a "$CONSOLE_LOG"
if [ -z "$MUSTGATHER" ]; then
    echo "Sleep time between ps invocations: $PS_INTERVAL" | tee -a "$CONSOLE_LOG"
fi
echo "Raw data being stored in is in $OUTPUT_DIR" | tee -a "$CONSOLE_LOG"

# Gather a bunch of info
FULL_OS=`uname -a`;

setDate

# date is required for system to work properly
assertCommandSuccess "Cannot find command 'date' on your path.  $REQUIRED_COMMAND_ERROR"

#PS_ALL_PROCESSES_CMD="ps -eo %p,%U,%u,%g,%t,%x,%C,%z,%a"
PS_ALL_PROCESSES_CMD="ps -eo pid,user,ruser,rgroup,etime,time,pcpu,vsz,comm"
PS_PROCESS_CMD="ps -o 'pid time etime pcpu' -p"

# Get only the command line args, in super wide format (no truncating, no env vars)
PS_CMD_LINE_CMD="ps ww "  

# Get the command line as well as all env vars.  No truncating
PS_ENV_VARS_CMD="ps eww "  

# All platforms except solaris use default tail
TAIL="tail";
AWK="awk";
GREP="grep"
DF_CMD="df -hk"
DISOWN="disown"
WHOAMI_CMD="whoami"
IOSTAT_CMD="iostat"
# This is currently used for testing.  TODO: strip this out of production use
if [ -n "$FORCE_DISABLE_DISOWN" ]; then
    DISOWN="fakeDisown";
    echo "FAKE DISOWN" | tee -a "$CONSOLE_LOG";
fi
if [ "$OS" = "AIX" ]; then
#    PS_PROCESS_CMD='ps -o "%p %x %t %C" -L '
    echo "IS_AIX=1" 2>/dev/null >> "$DEBUG_LOG" ;
    IS_AIX=1;
    PS_THREADS_CMD="ps -m -o THREAD -L "
    VMSTAT_EXTRA=0
    MUSTGATHER_PS_CMD="ps avwwwg"
    MEM_MAP_FILE="map"
    DF_CMD="df "
    IOSTAT_CMD="iostat -D"
elif [ "$OS" = "SunOS" ]; then
    # Solaris
    echo "IS_SOLARIS=1" 2>/dev/null >> "$DEBUG_LOG" ;
    IS_SOLARIS=1;
#    PS_PROCESS_CMD='ps -o  "%p %x %t %C" '
#    PS_THREADS_CMD=   TODO: Figure this out.
    PS_ENV_VARS_CMD="/usr/ucb/ps eww " 
    PS_CMD_LINE_CMD="/usr/ucb/ps ww"  
    # In linux, you need to add one to the number of seconds you want it to run
    VMSTAT_EXTRA=1
    MEM_MAP_FILE="map"
    TAIL="/usr/xpg4/bin/tail"
    AWK="/usr/xpg4/bin/awk"
    GREP="/usr/xpg4/bin/grep"
    WHOAMI_CMD="/usr/xpg4/bin/id -un"
else
    # Linux
    echo "IS_LINUX=1" 2>/dev/null >> "$DEBUG_LOG" ;
    IS_LINUX=1;
#    PS_PROCESS_CMD='ps -o  "%p %x %t %C" '
    PS_THREADS_CMD="ps HS -o tid,stat,THREAD "
    MUSTGATHER_PS_CMD="ps -eLf"
    # In linux, you need to add one to the number of seconds you want it to run
    VMSTAT_EXTRA=1
    MEM_MAP_FILE="maps"
    IOSTAT_CMD="iostat -x"
fi 


# Get info on smt if the command is available
# Fail silently if not available
# Check for key commands
checkCommandExists smtctl
HAVE_SMTCTL=$?
checkCommandExists iostat
HAVE_IOSTAT=$?
checkCommandExists netstat
HAVE_NETSTAT=$?
checkCommandExists lparstat
HAVE_LPARSTAT=$?
checkCommandExists tr
HAVE_TR=$?
checkCommandExists svmon
HAVE_SVMON=$?
checkCommandExists top
HAVE_TOP=$?
checkCommandExists free
HAVE_FREE=$?

checkIfDisownExists disown
HAVE_DISOWN=$RET_VAL

# Top takes nontrivial CPU, so only use it with must-gather
if [ -n "$MUSTGATHER" ] && [ "$HAVE_TOP" = "1" ]; then
    USE_TOP="1"
else
    USE_TOP="0"
fi



# "Extended vmstat" runs vmstat in the background, in an attempt to cover gaps
# However, it relies on the command 'disown' to work properly, so don't do it
# unless you have disown
USE_EXTENDED_VMSTAT=0;
if [ $HAVE_DISOWN = "1" ]; then
    USE_EXTENDED_VMSTAT=1;
    VMSTAT_EXTRA=30;
fi

# This controls how long we tail stderr and stdout of the process in the background
# 
STDERR_TAIL_DURATION=10;
if [ "$HAVE_DISOWN" = "1" ]; then
    # If you have disown you can use the whole javacore sleep interval, but not more
    if [ "$STDERR_TAIL_DURATION" -gt "$SLEEP_INTERVAL" ]; then
	STDERR_TAIL_DURATION=$PS_INTERVAL;
    fi
else
    # If you don't have disown, then cap the tail by the ps interval
    # Otherwise the 'wait' in the inner loop will be waiting on the tail process!
    if [ "$STDERR_TAIL_DURATION" -gt "$PS_INTERVAL" ]; then
	STDERR_TAIL_DURATION=$PS_INTERVAL;
    fi
fi
echo "STDERR_TAIL_DURATION: $STDERR_TAIL_DURATION" 2>/dev/null >> "$DEBUG_LOG" ;


checkCommandExists vmstat
HAVE_VMSTAT=$?
if [ $HAVE_VMSTAT = "0" ]; then
    echo "" | tee -a "$CONSOLE_LOG"
    echo "WARNING: Cannot find command 'vmstat' on path.  Not collecting machine utilization information." | tee -a "$CONSOLE_LOG"
fi

initPidDirs

# If smtctl exists, use it to record how many way SMT 
if [ $HAVE_SMTCTL = "1" ]; then
    smtctl >> "$OUTPUT_DIR$WAIT_FILES_DIR/smtctl.txt" 2>&1 
fi

echo "OS: $OS" >> "$OUTPUT_DIR/vmstat.txt"
echo "OS: $OS" >> "$OUTPUT_DIR/info.txt"

 echo "SLEEP_INTERVAL: $SLEEP_INTERVAL" >> "$OUTPUT_DIR$WAIT_FILES_DIR/allProcessesUtilizations.txt"
 echo "PS_INTERVAL: $PS_INTERVAL" >> "$OUTPUT_DIR$WAIT_FILES_DIR/allProcessesUtilizations.txt"

 echo "Date: $DATE" >> "$OUTPUT_DIR/info.txt"

setDateUtc
 echo "UTC Date: $DATE" >> "$OUTPUT_DIR/info.txt"
setDateLocal
 echo "Local Date: $DATE" >> "$OUTPUT_DIR/info.txt"

# Now put it back to default
setDate

 echo "Data collector version $VERSION" >> "$OUTPUT_DIR/info.txt"
 echo "Platform: $FULL_OS" >> "$OUTPUT_DIR/info.txt"
 echo "data collector MAX_ITERS: $MAX_ITERS" >> "$OUTPUT_DIR/info.txt"
 echo "data collector PS_INTERVAL: $PS_INTERVAL" >> "$OUTPUT_DIR/info.txt"
 echo "data collector SLEEP_INTERVAL: $SLEEP_INTERVAL" >> "$OUTPUT_DIR/info.txt"
 echo "DO_NOT_USE_JSTACK: $DO_NOT_USE_JSTACK" >> "$OUTPUT_DIR/info.txt"

if [ -n "$MUSTGATHER" ]; then
     echo "data collector VMSTAT_INTERVAL: $VMSTAT_INTERVAL" >> "$OUTPUT_DIR/info.txt"
     echo "data collector TOP_INTERVAL: $TOP_INTERVAL" >> "$OUTPUT_DIR/info.txt"
     echo "data collector TOP_DASH_H_INTERVAL: $TOP_DASH_H_INTERVAL" >> "$OUTPUT_DIR/info.txt"
     echo "data collector TPROF_SPAN: $TPROF_SPAN" >> "$OUTPUT_DIR/info.txt"
fi
 
 echo "data collector arguments:    $DATA_COLLECTOR_ARGS" >> "$OUTPUT_DIR/info.txt"

 echo "MUST GATHER: $MUSTGATHER" >> "$OUTPUT_DIR/info.txt"
 echo "SHELL: $CURRENT_SHELL" >> "$OUTPUT_DIR/info.txt";

WHOAMI=`$WHOAMI_CMD`;
if [ -z "$WHOAMI" ]; then
    WHOAMI="unknown";
fi
``echo USER: $WHOAMI`` >> "$OUTPUT_DIR/info.txt" 2>&1 

if [ "$IS_AIX" = "1" ]; then

    OSLEVEL=`oslevel 2>>"$ERRORLOG"` 
     echo AIX OSLEVEL: $OSLEVEL >> "$OUTPUT_DIR/info.txt"

    if [ -n "$MUSTGATHER" ]; then
	echo " " | tee -a "$CONSOLE_LOG"

	if [ "$WHOAMI" != "root" ]; then
	    echo "WARNING:  It is recommended that mustgather scripts be run as root.  Attempting to proceeding anyway." | tee -a "$CONSOLE_LOG"
	    echo " " | tee -a "$CONSOLE_LOG"
	fi

	echo "Starting tprof..." | tee -a "$CONSOLE_LOG";
	date >> "$OUTPUT_DIR/tprof.out" 2>&1 

	# Run a fairly complicated tprof job here, so it checks the error code and retries if PURR (-R flag) is not available.
	# Be very careful making changes to this line.  Redirection is weird when within a subshell on different platforms
	( tprof -Rskex sleep $TPROF_SPAN 2>> $OUTPUT_DIR/tprof.err >> $OUTPUT_DIR/tprof.out ;  if [ "$?" != "0" ]; then echo "Retrying tprof without PURR (-R)" >> $OUTPUT_DIR/tprof.out; tprof -skex sleep $TPROF_SPAN 2>> $OUTPUT_DIR/tprof.err >> $OUTPUT_DIR/tprof.out ;  fi ) &
	STARTED_TPROF="1"
	echo " " | tee -a "$CONSOLE_LOG"
    fi

fi
if [ "$IS_LINUX" = "1" ]; then
    dmesg | grep -i virtual >> "$OUTPUT_DIR/dmesg.out" 2>&1 
fi


# Must use cat for these, not cp, because it's a special file
# using cp works sometimes, but not in all versions of linux
if [ -r /proc/cpuinfo ]; then
    cat /proc/cpuinfo >> "$OUTPUT_DIR$WAIT_FILES_DIR/cpuinfo" 2>&1 
fi
if [ -r /proc/meminfo ]; then
    cat /proc/meminfo >> "$OUTPUT_DIR$WAIT_FILES_DIR/meminfo" 2>&1 
fi

if [ "$IS_SOLARIS" = "1" ]; then 
     echo "Command: kstat cpu_info" >> "$OUTPUT_DIR$WAIT_FILES_DIR/cpuinfo_solaris.txt"
    kstat cpu_info >> "$OUTPUT_DIR$WAIT_FILES_DIR/cpuinfo_solaris.txt" 2>&1 

     echo "Command:  psrinfo -pv" >> "$OUTPUT_DIR$WAIT_FILES_DIR/cpuinfo_solaris.txt"
    psrinfo -pv >> "$OUTPUT_DIR$WAIT_FILES_DIR/cpuinfo_solaris.txt" 2>&1 
fi


 echo "Reporting granularity: $VMSTAT_INTERVAL second" >> "$OUTPUT_DIR/vmstat.txt"

TMP_DIR="/tmp";
recordExistingFiles "$TMP_DIR" "$OUTPUT_DIR$WAIT_FILES_DIR/preexistingJavacoreFilesSlashTmp.txt";
recordExistingFiles "$TMP_DIR" "$OUTPUT_DIR$WAIT_FILES_DIR/preexistingHeapdumpFilesSlashTmp.txt";

if [ -n "$USER_SPECIFIED_JAVACORE_DIR" ]; then
    recordExistingFiles "$USER_SPECIFIED_JAVACORE_DIR" "$OUTPUT_DIR$WAIT_FILES_DIR/preexistingUserSpecifiedDir.txt"  "$JAVACORE_FILE_PATTERN"
fi

echo "" | tee -a "$CONSOLE_LOG"

if [ -z "$MUSTGATHER" ]; then
    echo "Press CTRL-C to stop collection and gather data" | tee -a "$CONSOLE_LOG"
    echo "" | tee -a "$CONSOLE_LOG"
fi


MORE_ITERS=1;

# Main loop

while [ $MORE_ITERS -eq 1 ]; do 

    # Track all the background pids we start, so we can wait on them
    BACKGROUND_PIDS="";

    # We actually get the java cores for the PREVIOUS iter, because
    # they are generated asynchronously and aren't available
    # immediately
    if [ "$ITER" != "0" ]; then
	moveNewJavacores
	if [ "$UPDATE_ZIP_EVERY_ITER" = "1" ]; then
	    zipData
	fi
    fi
    

    resetJavacoreCountsForNewIter

    if [ $FIND_PROCESSES_BY_NAME = "1" ]; then
	findPidsByName
    fi

    math_add $ITER 1; ITER=$RET_VAL

    # If we're the last iter, adjust the sleep time to be no greater than 10 seconds
    # There's no reason to wait longer than that for a javacore
    if [ "$ITER" = "$MAX_ITERS" ] && [ $SLEEP_INTERVAL -gt 10 ]; then
	setSleepInterval 10
    fi

    setDate

    echo "" | tee -a "$CONSOLE_LOG"
    echo "Triggering snapshot $ITER: ($DATE)" | tee -a "$CONSOLE_LOG"

    echo "ITER_$ITER" >> "$DEBUG_LOG"  ; echo "Time: $DATE" >> "$DEBUG_LOG"


    if [ $HAVE_PS = "1" ]; then
	echo "ITER_$ITER" >> "$OUTPUT_DIR$WAIT_FILES_DIR/allProcessesUtilizations.txt" 
    fi

    if [ -n "$MUSTGATHER" ]; then
        # Output the PS command in the original mustgather format, becuase tools rely on it
	date >> "$OUTPUT_DIR/ps.out" 2>&1 
	$MUSTGATHER_PS_CMD >> "$OUTPUT_DIR/ps.out" 2>&1 
	echo >> "$OUTPUT_DIR/ps.out" 2>&1 
    fi

    # Use top to collect more human readable process info
    if [ "$USE_TOP" = "1" ]; then
	killProcessIfExists $TOP_CMD_PID
	echo "ITER_$ITER" >> "$OUTPUT_DIR/topOutput.txt"  ; echo "Time: $DATE" >> "$OUTPUT_DIR/topOutput.txt"
        # Top needs the extra iter for the count just like vmstat
        # The first iter is stats since machine reboot
	top -bc -d $TOP_INTERVAL -n $TOP_ITERS >> "$OUTPUT_DIR/topOutput.txt" 2>&1 &
	TOP_CMD_PID=$!
	$DISOWN $TOP_CMD_PID 2>>"$ERRORLOG" >> "$CONSOLE_LOG" 
    fi

    echo "ITER_$ITER" >> "$OUTPUT_DIR/df.out"  ; echo "Time: $DATE" >> "$OUTPUT_DIR/df.out"
    $DF_CMD >> "$OUTPUT_DIR/df.out" 2>&1 

    # Global svmon data (memory) about machine
    if [ $HAVE_SVMON = "1" ]; then
	echo "ITER_$ITER" >> "$OUTPUT_DIR$WAIT_FILES_DIR/svmon.txt"  ; echo "Time: $DATE" >> "$OUTPUT_DIR$WAIT_FILES_DIR/svmon.txt"
	svmon >> "$OUTPUT_DIR$WAIT_FILES_DIR/svmon.txt" 2>&1 
    fi

    # Global free mem stats
    if [ $HAVE_FREE = "1" ]; then
	echo "ITER_$ITER" >> "$OUTPUT_DIR$WAIT_FILES_DIR/freeMem.txt"  ; echo "Time: $DATE" >> "$OUTPUT_DIR$WAIT_FILES_DIR/freeMem.txt"
	free >> "$OUTPUT_DIR$WAIT_FILES_DIR/freeMem.txt" 2>&1 
    fi

    # vmstat -s gives memory stats
    if [ $HAVE_VMSTAT = "1" ]; then
	echo "ITER_$ITER" >> "$OUTPUT_DIR/vmstat_S.txt"  ; echo "Time: $DATE" >> "$OUTPUT_DIR/vmstat_S.txt"
	vmstat -s $PID >> "$OUTPUT_DIR/vmstat_S.txt" 2>&1 
    fi

    # Some stats for each process being monitored
    for PID_INDEX in ${PID_INDICES[@]}
      do
      PID=${PIDS[$PID_INDEX]};

      # Run in foreground if only one PID
#      if [ "$MULTIPLE_PID_MODE" = "0" ]; then
	  gatherDataForProcess 	  
#      else
#	  gatherDataForProcess &
#      fi
    done



    if [ "$JSTACK_JAVACORE_COUNT_THIS_ITER" -gt "0" ]; then
	echo "Collected $JSTACK_JAVACORE_COUNT_THIS_ITER javacores using jstack" | tee -a "$CONSOLE_LOG"
    fi

    # Force break to exit outer loop, gather data, and exit
    if [ -n "$BREAK_OUTER_LOOP" ]; then
	if [ "$MULTIPLE_PID_MODE" = "0" ]; then
	    echo "" | tee -a "$CONSOLE_LOG"
	    echo "Process no longer exists or you do not have permissions to access.  Exiting" | tee -a "$CONSOLE_LOG"
	    echo "" | tee -a "$CONSOLE_LOG"
	    break;
	fi
    fi


    if [ -n "$MUSTGATHER" ]; then
	echo "" | tee -a "$CONSOLE_LOG";
	echo Sleeping for $SLEEP_INTERVAL seconds... | tee -a "$CONSOLE_LOG"
    fi

    # Run jstat for all sun pids that have jstat
    for PID_INDEX in ${PID_INDICES[@]}
      do
	PID=${PIDS[$PID_INDEX]};
          # See if this VM has a jstat.  If so, use it to get GC
	jstat=${JSTAT_EXE[$PID_INDEX]};
	if [ -n "$jstat" ]; then
            echo "ITER_$ITER" >> "$OUTPUT_DIR/PID_$PID/jstatGC.txt" 
	fi
    done

    # netstat reports cumulative stats so run it instantaneously
    # It's pretty big too, so only once per javacore iter
# NO netstat for now.  It's been found to be too expensive
#    if [ $HAVE_NETSTAT = "1" ]; then
#	PRINT_ITER_AND_DATE(NETSTAT_FILE())
#	COMMAND_TO_FILE(''netstat -s'', NETSTAT_FILE())
#	COMMAND_TO_FILE(''netstat -i'', NETSTAT_FILE())
#	COMMAND_TO_FILE(''netstat -an'', NETSTAT_FILE())
#    fi

    
    echo "ITER_$ITER" >> "$OUTPUT_DIR/vmstat.txt" 

    if [ $HAVE_VMSTAT = "1" ]; then
        # Add this many seconds to the vmstat run time to ensure it covers the gap
	VMSTAT_TIME=$SLEEP_INTERVAL;
	
	vmstatIters=$VMSTAT_TIME
	if [ "$VMSTAT_INTERVAL" -gt "1" ]; then
	    math_divide $vmstatIters $VMSTAT_INTERVAL; vmstatIters=$RET_VAL
	    # Increment by 2 to fill the gap created by divide rounding down.
	    # If it goes too long, it's killed before the next iter
	    math_add $vmstatIters 1; vmstatIters=$RET_VAL
	fi

        # vmstat needs N+1 for the iters
	math_add $vmstatIters $VMSTAT_EXTRA; vmstatIters=$RET_VAL

        # Kill the previous one if it exists
	killProcessIfExists $VMSTAT_PID
	echo "Time: $DATE" >> "$OUTPUT_DIR/vmstat.txt"
	( vmstat $VMSTAT_INTERVAL $vmstatIters >> "$OUTPUT_DIR/vmstat.txt" 2>&1  ) 2>/dev/null &
	VMSTAT_PID=$!
	
	if [ $USE_EXTENDED_VMSTAT = "1" ]; then
	    $DISOWN $VMSTAT_PID 2>>"$ERRORLOG" >> "$CONSOLE_LOG" 
	fi
    fi

    # vmstat, lparstat, and iostat all must be run for an interval, otherwise
    # they give stats from the last reboot
    # Thus run them in parallel and in the background, then wait

    if [ $HAVE_IOSTAT = "1" ]; then
	echo "ITER_$ITER" >> "$OUTPUT_DIR$WAIT_FILES_DIR/iostat.txt"  ; echo "Time: $DATE" >> "$OUTPUT_DIR$WAIT_FILES_DIR/iostat.txt"
	( $IOSTAT_CMD $SLEEP_INTERVAL 2 >> "$OUTPUT_DIR$WAIT_FILES_DIR/iostat.txt" 2>&1  ) 2>/dev/null &
	IOSTAT_PID=$!
	BACKGROUND_PIDS="$BACKGROUND_PIDS $IOSTAT_PID"
    fi
    
    if [ $HAVE_LPARSTAT = "1" ]; then
	echo "ITER_$ITER" >> "$OUTPUT_DIR/lparstat.txt"  ; echo "Time: $DATE" >> "$OUTPUT_DIR/lparstat.txt"
	( lparstat $SLEEP_INTERVAL 1 >> "$OUTPUT_DIR/lparstat.txt" 2>&1  ) 2>/dev/null &
	LPARSTAT_PID=$!
	BACKGROUND_PIDS="$BACKGROUND_PIDS $LPARSTAT_PID"

	echo "ITER_$ITER" >> "$OUTPUT_DIR/lparstat-i.txt"  ; echo "Time: $DATE" >> "$OUTPUT_DIR/lparstat-i.txt"
	( lparstat -i >> "$OUTPUT_DIR/lparstat-i.txt" 2>&1  ) 2>/dev/null &
	LPARSTAT_I_PID=$!
	BACKGROUND_PIDS="$BACKGROUND_PIDS $LPARSTAT_I_PID"
    fi

    # For each PID that has jstat
    math_add $SLEEP_INTERVAL 1; jstatIters=$RET_VAL
    for PID_INDEX in ${PID_INDICES[@]}
      do
      PID=${PIDS[$PID_INDEX]};
      # See if this VM has a jstat.  If so, use it to get GC
      jstat=${JSTAT_EXE[$PID_INDEX]};
      if [ -n "$jstat" ]; then
	  echo "Time: $DATE" >> "$OUTPUT_DIR/PID_$PID/jstatGC.txt"
	  $jstat -gc -t $PID 1000 $jstatIters >> "$OUTPUT_DIR/PID_$PID/jstatGC.txt" 2>&1 &
	  BACKGROUND_PIDS="$BACKGROUND_PIDS $!"
      fi
    done

    # Inner loop for commands that must be executed 
    # More frequently than the javacore interval
    SECONDS_REMAINING=$SLEEP_INTERVAL;
    while [ $SECONDS_REMAINING -gt 0 ]; do 

	# Do ps for all procs
	setDate
	if [ $HAVE_PS = "1" ]; then
	    echo "Time: $DATE" >> "$OUTPUT_DIR$WAIT_FILES_DIR/allProcessesUtilizations.txt"
            # Take ps of all procs, and squish down whitespace and limit line length to 1000 characters
            # $PS_ALL_PROCESSES_CMD |  $AWK '{ gsub(/ +/," "); print substr($0,0,1000)}'  2>>"$ERRORLOG"  >> PS_ALL_PROCS_FILE()
	    $PS_ALL_PROCESSES_CMD 2>>"$ERRORLOG"  | $AWK '{ gsub(/ +/," "); print substr($0,0,1000)}'  >> "$OUTPUT_DIR$WAIT_FILES_DIR/allProcessesUtilizations.txt" 2>&1 
	fi

	sleep $PS_INTERVAL

	math_subtract $SECONDS_REMAINING $PS_INTERVAL; SECONDS_REMAINING=$RET_VAL
    done


    # If there were *stat commands, wait for them to finish.
    # We don't wait for vmstat because we instead kill it manually before restarting next iter
    # Todo: Do this with all commands!
    # echo before_wait
    if [ "$BACKGROUND_PIDS" != "" ]; then
	wait  $BACKGROUND_PIDS  
    fi
    # echo after_wait



    if [ $MAX_ITERS -le 0 ];  then 
	# No max iter specified.  Loop forever
        MORE_ITERS=1;
    elif [ $ITER -ge $MAX_ITERS ];  then
        MORE_ITERS=0;
    fi

done

collectFinalMustGatherData

terminateGracefully
