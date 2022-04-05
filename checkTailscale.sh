#!/bin/bash

#
# Name:
# -----
# checkTailscale .sh
#
# Purpose:
# --------
# Script to restart the Tailscale connection if it is not working. Requires two machines in a network to run.
#
# Dependencies:
# -------------
#
# Tailscale                     https://tailscale.com/
#
# Customization:
# --------------
# 
# LOGFILE                       Location of where the log is updated showing actions are taken (should be the same location for all scripts) 
# VERFILE                       Location of where the version of Tailscale is stored, should not be a temporary location 
# PUBLIC_IP_ADDRESS             The public IP that you want to ping to test if TailScale is working
# AUTH_KEY                      Location of the TailScale AUTH_KEY, get this from the Admin console, see https://tailscale.com/kb/1085/auth-keys/ 
# EMAIL_ADDRESS                 The email address to send error reports, if enabled via -i or -e when invoking this script
# TMPFILE                       Where to store the temporary file which will be deleted after running
#
# TAILSCALE_OTHER_IP_ADDRESS    The IP address of a second system that is running TailScale to verify that TailScale is working
# TAILSCALE_OTHER_MACHINE_NAME  The user-friendly name of that second system that is running TailScale to verify that TailScale is working
#
#
# Crontab Example:
# ----------------
# This example checks every 15 minutes to see if Tailscale is running 
#
# MIN          HOUR   MDAY     MON     DOW      COMMAND
#0,15,30,45     *      *       *       *       /Users/me/bin/checkTailscale.sh -i -s 3      	&> /dev/null
# 
#


usage()
{

echo "Usage:		"${0##*/}"  [ -p [ADDRESS] -o [ADDRESS] -n [NAME] [-e] [-i] [-s [COUNT] ] 
	
OPTIONS:
   -o   set the IP address of a second system that is running TailScale to verify that TailScale is working 
   -n   set the user-friendly name of that second system that is running TailScale to verify that TailScale is working
   -p   set IP address to ping 
   -e   send an email every time this script runs
   -i   send an email only if there was a problem with the Internet or TailScale
   -s   skip every COUNT errors
"
}


FUNCTION_get_public_ip_from_tailscale()
{
	/Applications/Tailscale.app/Contents/MacOS/Tailscale netcheck 2>&1 | grep "IPv4" | cut -f2 -d"," | cut -f1 -d":" | sed "s/^ //g"
}

FUNCTION_get_tailscale_ip()
{	
	TAL0=`/sbin/ifconfig | grep inet | grep "100." `
	if [ "$TAL0" != "" ]
	then 
		/sbin/ifconfig | grep inet | grep "100." | awk '{print $2}'
	else
		echo "Tailscale not running"
	
	fi
}

FUNCTION_get_tailscale_status()
{
	/Applications/Tailscale.app/Contents/MacOS/Tailscale status		
}

FUNCTION_get_tailscale_version()
{
	/Applications/Tailscale.app/Contents/MacOS/Tailscale version | head -1
}

FUNCTION_send_tailscale_up_command()
{
	echo "         tailscale up" 											
	/Applications/Tailscale.app/Contents/MacOS/Tailscale up	2>&1	
	sleep 20
}

FUNCTION_open_tailscale_application()
{
	echo "         /usr/bin/open /Applications/Tailscale.app" 				
	/usr/bin/open /Applications/Tailscale.app						
	sleep 20
}

FUNCTION_send_tailscale_reset_command()
{
	echo "         Tailscale up --accept-routes	--reset --auth-key=###" 														
	/Applications/Tailscale.app/Contents/MacOS/Tailscale up --accept-routes	--reset --auth-key "$AUTH_KEY" 2>&1	
	sleep 20
}

FUNCTION_perform_full_reset_of_tailscale() 
{
	PID=`ps -eaf | grep "/Applications/Tailscale.app/Contents/MacOS/Tailscale" | grep -v grep | awk -F' ' '{print $2}'`
	if [ "$PID" != "" ]
	then
		echo "         Killing current running version of Tailscale"		
		kill -9 $PID
		sleep 10
	fi
	
	FUNCTION_open_tailscale_application

	FUNCTION_send_tailscale_reset_command
}

FUNCTION_check_if_tailscale_is_down()
{
	/Applications/Tailscale.app/Contents/MacOS/Tailscale status 2>&1 | grep -c -e "Logged out" -e "stopped" -e "failed"
}

FUNCTION_ping_ip_address_with_tailscale()
{
	/Applications/Tailscale.app/Contents/MacOS/Tailscale ping $2	
}

FUNCTION_ping_ip_address_multiple_times()
{
		
# $1 = # of times to ping
# $2 = IP address to ping

# if I=99, then the ping worked!

	IS=`/sbin/ping -o -i 10 -c $1 $2 2>&1`
	IC=`echo "$IS" | grep -c "100.0% packet loss"`			
	if [ "$IC" -eq 1 ] 
	then
		I=0
	else		
		I=99
	fi

}

FUNCTION_perform_check()
{
	
	echo "$NAME (v. $VER) - $d"								 										
	echo "Checking Tailscale network connectivity..." 												
	echo 																							
	
	if [ "$OLD_VERSION" != "$CUR_VERSION" ]
	then
		echo "Tailscale version changed: OLD: $OLD_VERSION | NEW: $CUR_VERSION"						
		echo "$CUR_VERSION" > "$VERFILE"
		echo "$d - $MY_HOSTNAME - $NAME - NOTICE Tailscale version changed: OLD: $OLD_VERSION | NEW: $CUR_VERSION" >> $LOGFILE
	else
		echo "Tailscale version: $CUR_VERSION"														
	fi
	
	echo 																							
	echo "Tailscale Status:" 																		
	echo "----------------" 																		
	FUNCTION_get_tailscale_status 	
	
	
																	
	echo "----------------" 																		
	
	echo "You are using [$MACHINE_NAME] - `FUNCTION_get_tailscale_ip`." 	
	
	if [ "$ERRCOUNT_CUMULATIVE" != 0 ]
	then
		echo
		echo "There have been $ERRCOUNT_CUMULATIVE cumulative errors, skipping emails (if any) every $SKIPCOUNT consecutive errors"
	fi
	
	echo																							
	echo "Step 1: Checking that internet connection is working by ping'ing $PUBLIC_IP_ADDRESS..."							
	
	FUNCTION_ping_ip_address_multiple_times 5 $PUBLIC_IP_ADDRESS
 
 	if [ "$I" -ne 99 ] 
	then
	   	ERROR_FOUND=99

	   	echo "        Your internet connection does not appear to be working. Aborting check:" 				
	   	echo "$IS"	| sed "s/^/        /g"																			
	   	echo
		echo "$d - $MY_HOSTNAME - $NAME - WARNING no internet connection" >> $LOGFILE
	else
	
		echo																							
		echo "        Your internet connection appears to be working."
		echo 
		echo
		echo "Step 2: Checking if Tailscale has an error or is down..."				
		echo																							
		
		TAILSCALE_STATUS=`FUNCTION_check_if_tailscale_is_down`
		
		if [ "$TAILSCALE_STATUS" == "1" ]
		then
			ERROR_FOUND=99																					

			echo "        Ut oh! Tailscale is not working. Trying a reset." 									
			
			FUNCTION_open_tailscale_application			
		
			FUNCTION_send_tailscale_up_command			
		
			FUNCTION_send_tailscale_reset_command			
		
			echo "$d - $MY_HOSTNAME - $NAME - WARNING reset Tailscale" >> $LOGFILE
	
			STATUS_RESULTS="is now working (after starting Tailscale and running 'tailscale up')."
		
			TAILSCALE_STATUS=`FUNCTION_check_if_tailscale_is_down`
			
			case "$TAILSCALE_STATUS" in 
				1)
							echo "        Ut oh!  Tailscale still does not appear to be running.  Trying to fix again..."	
							STATUS_RESULTS="is now working (after starting Tailscale and running 'tailscale up')."
			
							echo "         Resetting Tailscale..."
			
							FUNCTION_perform_full_reset_of_tailscale 
							;;
				*)	
							echo "        Good! Tailscale is running. Checking Tailscale connectivity..."			
							;;
			esac
		else 
			echo "        Tailscale is working." 									
		fi
		
		echo
		echo 
		echo "Step 3: Getting your IP addresses from TailScale..."				
		echo 
		
		TAILSCALE_IP=`FUNCTION_get_public_ip_from_tailscale`
		
		echo "        Your public IP is    $TAILSCALE_IP"															
		echo "        Your tailsacle IP is `FUNCTION_get_tailscale_ip`"										
		echo																							
		
		echo 
		echo "Step 4: Trying to ping the second system running TailScale..."				
		
		TIMES=10
		
# to test failures, set:		
#		TIMES=1
#		TAILSCALE_OTHER_IP_ADDRESS=10.10.10.190
		
		echo																							
		echo "        Ping'ing [$TAILSCALE_OTHER_IP_ADDRESS] / [$TAILSCALE_OTHER_MACHINE_NAME] up to $TIMES times..."
		
		FUNCTION_ping_ip_address_multiple_times $TIMES $TAILSCALE_OTHER_IP_ADDRESS

		echo 
		echo "Results:"				
		
		if [ "$I" -eq 99 ] 
		then
			echo																						
			echo "Your Tailscale connection $STATUS_RESULTS"	 										
			echo																						
			echo "Your tailsacle IP is `FUNCTION_get_tailscale_ip`"	
			echo
		else
			ERROR_FOUND=99																						

			let "ERRCOUNT= $ERRCOUNT + 1"
			let "ERRCOUNT_CUMULATIVE= $ERRCOUNT_CUMULATIVE + 1"

			echo																						
			echo "Could not connect to [$TAILSCALE_OTHER_IP_ADDRESS]."										
			echo																						
			echo "It may also mean that $TAILSCALE_OTHER_MACHINE_NAME is down." 								
			echo																						
			echo "Your tailsacle IP is `FUNCTION_get_tailscale_ip`"	
			echo																						
			echo																							
			echo "$d - $MY_HOSTNAME - $NAME - WARNING $TAILSCALE_OTHER_MACHINE_NAME may be down" >> $LOGFILE
		fi
		
		echo
	fi		
}			


#### END OF FUNCTIONS



NAME=$(basename "$0")
VER=5
MY_HOSTNAME=`/bin/hostname -s`
MACHINE_NAME=`uname -n`
d=`date "+%Y-%m-%d - %H:%M:%S"`

#######################################################
#### SET VARIABLES HERE
#######################################################

# The email address to send error reports, if enabled via -i or -e when invoking this script

EMAIL_ADDRESS='ZZZZZNAME@gmail.com'

#
# Where to store the temporary file, will be deleted after running

TMPFILE="/tmp/$MY_HOSTNAME.checkTailscale.txt"

# The public IP that you want to ping to test if TailScale is working
# Can also be set by passing the "-p" option when invoking this script

PUBLIC_IP_ADDRESS='google.com'

# Location of where the version of Tailscale is stored, should not be a temporary location

VERFILE=$HOME/bin/Logfiles/tailscale_$MY_HOSTNAME.ver.txt

# Location of where the error counts is stored, should not be a temporary location

ERRCOUNTFILE=$HOME/bin/Logfiles/tailscale_$MY_HOSTNAME.errcount.txt

if [ -f "$ERRCOUNTFILE" ]; then
    ERRCOUNT=`cat "$ERRCOUNTFILE"`
else
    ERRCOUNT=0
fi

ERRCOUNTFILE_CUMULATIVE=$HOME/bin/Logfiles/tailscale_$MY_HOSTNAME.errcount_cumulative.txt

if [ -f "$ERRCOUNTFILE_CUMULATIVE" ]; then
    ERRCOUNT_CUMULATIVE=`cat "$ERRCOUNTFILE_CUMULATIVE"`
else
    ERRCOUNT_CUMULATIVE=0
fi


# Location of where the log is updated showing actions that are taken (should be the same location for all scripts) 

LOGFILE=$HOME/bin/Logfiles/tailscale_$MY_HOSTNAME.log

# Location of the TailScale AUTH_KEY, get this from the Admin console, see https://tailscale.com/kb/1085/auth-keys/ 

AUTH_KEY=`cat $HOME/Boxcryptor/Boxcryptor-Encrypted/Keys/tailscale_auth_key.txt`

# The IP address of a second system that is running TailScale to verify that TailScale is working
# Can also be set by passing the "-o" option when invoking this script

TAILSCALE_OTHER_IP_ADDRESS="100.1.5.3"

# The user-friendly name of that second system that is running TailScale to verify that TailScale is workin
# Can also be set by passing the "-n" option when invoking this script

TAILSCALE_OTHER_MACHINE_NAME="OfficeMac"

#
# You can alternatively use this code to change the variables based on what server/computer this script is running on:

case `echo $MACHINE_NAME | tr '[:upper:]' '[:lower:]'` in 
	firstmac.local)
			TAILSCALE_OTHER_IP_ADDRESS="100.1.5.3"
			TAILSCALE_OTHER_MACHINE_NAME="officemac"
			;;	
	secondmac.local)  
			TAILSCALE_OTHER_IP_ADDRESS="100.1.5.3"
			TAILSCALE_OTHER_MACHINE_NAME="officemac"
			;;
	officemac.local) 
			TAILSCALE_OTHER_IP_ADDRESS="100.7.1.8"
			TAILSCALE_OTHER_MACHINE_NAME="firstmac"
			;;
	*) 		echo "You are using an unknown machine, named [$MACHINE_NAME]. Exiting"
			exit
			;;
esac


#######################################################
#######################################################
#######################################################


ERROR_MESSAGE=
STATUS_RESULTS="is working."
EMAIL=0
EMAIL_ERRORS=0
ERROR_FOUND=0
SKIPCOUNT=0

while getopts "p:o:n:s:eiq?" OPTION
do
     case $OPTION in
        p)
           PUBLIC_IP_ADDRESS="$OPTARG"
           ;;
        o)
           TAILSCALE_OTHER_IP_ADDRESS="$OPTARG"
           ;;
        n)
           TAILSCALE_OTHER_MACHINE_NAME="$OPTARG"
           ;;
        s)
           SKIPCOUNT="$OPTARG"
           ;;
        e)
           EMAIL=1
           ;;
        i)
           EMAIL_ERRORS=1
           ;;
		?)
           usage
           exit
           ;;
     esac
done


if [ ! -f "$VERFILE" ]
then
    FUNCTION_get_tailscale_version > "$VERFILE"
fi


OLD_VERSION=`cat "$VERFILE"`
CUR_VERSION=`FUNCTION_get_tailscale_version`

#
# if no email is needed, then just run the check
#

#
# check SKIP COUNT to see if should email


if [ "$ERRCOUNT" -gt "$SKIPCOUNT" ] 
then 
	ERRCOUNT=0
fi


if [ "$EMAIL" == 0  ] && [ "$EMAIL_ERRORS" == 0 ]
then
	FUNCTION_perform_check
else
	FUNCTION_perform_check > >( tee $TMPFILE )

#
# if an email is asked for, then email the result file
#
	if [ "$EMAIL" == 1  ]
	then
		cat $TMPFILE | mail -s "$MACHINE_NAME-Tailscale Connection Check Results - $(date '+%m/%d/%y @ %H:%M:%S')" $EMAIL_ADDRESS
		echo "email sent to $EMAIL_ADDRESS"
	fi
#
# only email if there was an error
#
	if [ "$EMAIL_ERRORS" == 1 ] && [ "$ERROR_FOUND" == 99 ]
	then 
		if [ $ERRCOUNT == 1 ]
		then
			cat $TMPFILE | mail -s "$MACHINE_NAME-Tailscale Connection Check Results - $(date '+%m/%d/%y @ %H:%M:%S')" $EMAIL_ADDRESS		
			echo "email sent to $EMAIL_ADDRESS"
		else
			echo "There now have been $ERRCOUNT_CUMULATIVE cumulative errors, skipping this email due to $ERRCOUNT consecutive errors"

		fi
	fi
	
fi

if [ "$ERROR_FOUND" != 99 ]
then
	ERRCOUNT=0
	ERRCOUNT_CUMULATIVE=0
fi

echo "$ERRCOUNT" > $ERRCOUNTFILE
echo "$ERRCOUNT_CUMULATIVE" > $ERRCOUNTFILE_CUMULATIVE


rm -f $TMPFILE
