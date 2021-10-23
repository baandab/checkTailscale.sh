# checkTailscale.sh
Used to check if Tailscale is working; testing on macOS


Purpose:
--------
Script to restart the Tailscale connection if it is not working. Requires two machines in a network to run.

Dependencies:
-------------

See Tailscale at https://tailscale.com/

Usage
--------------
./checkTailscale.sh  [ -p [ADDRESS] -o [ADDRESS] -n [NAME] [-e] [-i] ]

OPTIONS:
</br>   -o   set the IP address of a second system that is running tailscale to verify that tailscale is working
</br>   -n   set the user-friendly name of that second system that is running tailscale to verify that tailscale is working
</br>   -p   set IP address to ping
</br>   -e   send an email every time this script runs
</br>   -i   send an email only if there was a problem with the Internet or tailscale



Customization:
--------------
Edit the script and change these variables:
</br>
| Variable|Description|
|---|---|
| VERFILE                      | Location of where the version of Tailscale is stored, should not be a temporary location 						   |
| PUBLIC_IP_ADDRESS            | The public IP that you want to ping to test if tailscale is working											   |
| AUTH_KEY                     | Location of the tailscale AUTH_KEY, get this from the Admin console, see https://tailscale.com/kb/1085/auth-keys/ |
| EMAIL_ADDRESS                | The email address to send error reports, if enabled via -i or -e when invoking this script						   |
| TMPFILE                      | Where to store the temporary file, will be deleted after running												   |
| TAILSCALE_OTHER_IP_ADDRESS   | The IP address of a second system that is running tailscale to verify that tailscale is working				   |
| TAILSCALE_OTHER_MACHINE_NAME | The user-friendly name of that second system that is running tailscale to verify that tailscale is working		   |

Crontab Example:
----------------
This example checks every 15 minutes to see if TailScale is running 

<code>##MIN          HOUR   MDAY     MON     DOW      COMMAND<p>
0,15,30,45     *      *       *       *       /Users/me/bin/checkTailscale.sh -i       	&> /dev/null</code>


