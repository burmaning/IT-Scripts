# Present user with info on what they're about to do - offer bailout
title="Grant me admin access"
description="You are requesting administrative privileges on your Mac. You must supply a reason for the request before proceeding."
acceptText="OK"
closeText="Cancel"
timeOut="600"

if /Library/Addigy/macmanage/MacManage.app/Contents/MacOS/MacManage action=notify title="${title}" description="${description}" closeLabel="${closeText}" acceptLabel="${acceptText}" timeout="$timeOut" forefront="true"; then
    echo "User proceeding"
else
    echo "User cancelled, exiting 1"
    exit 1 
fi

# 1 - Popup request for justification window
# Popup variables
PROMPT_TITLE="Grant me admin access"
PROMPT_TEXT="Tell us why you're requesting temporary administrator access"
FAIL_TEXT="Unable to process your request - please contact your support desk for assistance."

LOGO="/Library/Addigy/ansible/packages/Addigy Self Service Admin Request (1.0)/AppIcon.icns"

#Grab current user and set parameters
uid= stat -f%Su /dev/console
loggedInUser=$( echo "show State:/Users/ConsoleUser" | scutil | awk '/Name :/ && ! /loginwindow/ { print $3 }' )
USER=$loggedInUser

logPath=~/log.txt

LOGO_POSIX="$(/usr/bin/osascript -e 'tell application "System Events" to return POSIX file "'"$LOGO"'" as text')"

response1="$(/bin/launchctl asuser "$uid" sudo -u "$USER" /usr/bin/osascript -e 'display dialog "'"${PROMPT_TEXT//\"/\\\"}"'" default answer "" with title "'"${PROMPT_TITLE//\"/\\\"}"'" with text buttons {"Cancel","OK"} default button {"OK"} with icon file "'"${LOGO_POSIX//\"/\\\"}"'"' -e 'return text returned of result')"

echo "$timestamp [REQUEST] User supplied the following justification for promotion: $response1" >> ${logPath} 2>&1


# Catch invalid user input
if [[ "$response1" == "" ]]; then
  response1="User left text box empty"
fi

# Remove bad characters
# TO REMOVE: Double quotes, single quotes, backslashes
# TO KEEP: Forward slashes, colon, exclamation point, dollar sign, asterisk, parentheses, brackets, braces
response1="$(echo "$response1" | tr -d \'\"\\ )"
echo "User response with special characters removed: $response1"

# Set maximum character length to 1024
if [ ${#response1} -ge 1024 ]; then
  echo "Shortening string to 1024 characters"
  response1=$( echo "$response1" | cut -c 1-1024)
  echo "Truncated response: $response1"
fi

# 2 - Submit ticket - submit $response1
ticketDescription="--- EVENT --- \n User ran Admin Promotion script with the following request: \n \n $response1"
# Harvest ticket information
ticketDevice=$(hostname | awk -F'.' '{print $1}')
ticketSerialNumber="$(system_profiler SPHardwareDataType | awk '/Serial/ {print $4}')"
ticketUserName="$(/usr/bin/stat -f%Su /dev/console)"
     echo "ticketUserName is $ticketUserName"
ticketTime="$(date +%r)"
ticketDate="$(date +%x)"

# Create ticket
ticketRequest="$(curl -X POST https://$(/Library/Addigy/go-agent agent realm).addigy.com/submit_ticket/ -H 'content-type: application/json' -d "{\"agentid\": \"$(/Library/Addigy/go-agent agent agentid)\", \"orgid\":\"$(/Library/Addigy/go-agent agent orgid)\", \"name\":\"$ticketUserName\", \"description\":\"\n ___________________________________________________________\n Device name: $ticketDevice \n Serial number: $ticketSerialNumber \n Username: $ticketUserName \n Date: $ticketDate, $ticketTime \n ____________________________________________________________ \n $ticketDescription \"}")"

# If ticket creation fails, halt - user will have to contact suppport Support Desk
if [[ "$ticketRequest" == *"Something went wrong, we are looking into this issue."* ]]; then
  echo "$timestamp [RESULT] Ticket not sent, display error and exit"
  title="Ticket submission failed"
  description="$FAIL_TEXT"
  closeText="OK"
  timeOut="600"

  if /Library/Addigy/macmanage/MacManage.app/Contents/MacOS/MacManage action=notify title="${title}" description="${description}"  closeLabel="${closeText}" timeout="$timeOut" forefront="true"; then
      # These commands can be changed to detemine what happens when the user clicks the "Accept" label.
      echo "$timestamp [Ticket creation failed, halting]" >> "${logPath}" 2>&1
      exit 1
    else
      echo "$timestamp [Ticket creation failed, halting]" >> "${logPath}" 2>&1
      exit 1
  fi
  exit 1
else
  echo "$timestamp [RESULT] Ticket created successfully, promoting." >> "${logPath}" 2>&1
fi


#find current user
loggedInUser="$(stat -f "%Su" /dev/console)"
uid=$(id -u "$loggedInUser")

#Set current user to admin
sudo dscl . -merge /Groups/admin GroupMembership $loggedInUser
echo "[Promotion complete]"

# SETUP SAFEGUARDS
# Create failsafe flag. If flag detected in maintenance script, account will be demoted.
touch /Users/$loggedInUser/.tempPromoted
echo "Created flag file"

# Create the demotion shellscript
shellscriptPath="/Users/$loggedInUser/Library/Application Support/maintenance_demotion.sh"

echo '#!/bin/bash
# Remove temporary admin status if detected
# Ross Matsuda | Ntiva, Inc | December 2020

# Perform action on all detected user accounts
for user in $(dscl . list /Users UniqueID | awk '$2 >= 500 {print $1}'); do
    userHome=$(dscl . read /Users/"$user" NFSHomeDirectory | sed 's/NFSHomeDirectory://' | grep "/" | sed 's/^[ \t]*//')
    echo "$user:$userHome"
    FILE="$userHome/.tempPromoted"
    if [[ -f "$FILE" ]]; then
        echo "$FILE exists, demoting and removing flag"
        sudo dseditgroup -o edit -d $user -t user admin
        rm "$FILE"
        launchctl unload "$pathPlist" &>/dev/null
        rm "$shellscriptPath"
        rm "$pathPlist"
      else
        echo "$FILE not found"
    fi
done
' > "$shellscriptPath"

# Set the correct permissions for shell script

chmod 777 "$shellscriptPath"
chmod a+x "$shellscriptPath"
echo "Created shellscript"


# Create LaunchAgent
pathPlist="/Users/$loggedInUser/Library/LaunchAgents/com.user.tempPromoted.plist"

# Ensure destination directory exists
userLA="/Users/$loggedInUser/Library/LaunchAgents"
if [ -d "$userLA" ]; then
    echo "User launchAgent directory detected"
else
    echo "User launchAgent directory not detected, creating"
    mkdir -p "$userLA"
    chmod 777 "$userLA"
fi

# Create the LaunchAgent.

cat >> "$pathPlist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple Computer//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
   <key>Label</key>
   <string>com.user.loginscript</string>
   <key>ProgramArguments</key>
   <array><string>$shellscriptPath</string></array>
   <key>RunAtLoad</key>
   <true/>
</dict>
</plist>
EOF

# Set the correct permissions and load current LaunchAgent.
chmod 644 "$pathPlist"
launchctl load "$pathPlist" &>/dev/null
echo "Created launchagent"

# Update the text fields for the final notification window
title="Admin Status Enabled"
description="Once you've authenticated your installer, settings change, or update, please click Restore"
# acceptText="Restore"
closeText="Restore"
timeOut="600"

if /Library/Addigy/macmanage/MacManage.app/Contents/MacOS/MacManage action=notify title="${title}" description="${description}"  closeLabel="${closeText}" forefront="true" timeout="$timeOut"; then
    # These commands can be changed to detemine what happens when the user
    #   clicks the "Accept" label.
    sudo dseditgroup -o edit -d $loggedInUser -t user admin
    rm /Users/$loggedInUser/.tempPromoted
    launchctl unload "$pathPlist" &>/dev/null
    rm "$shellscriptPath"
    rm "$pathPlist"
    echo "[Demotion complete]"
    exit 0
else
    # These commands can be changed to detemine what happens when the user
    #   clicks the "Close" label.
    sudo dseditgroup -o edit -d $loggedInUser -t user admin
    rm /Users/$loggedInUser/.tempPromoted
    launchctl unload "$pathPlist" &>/dev/null
    rm "$shellscriptPath"
    rm "$pathPlist"
    echo "[Demotion complete]"
    exit 0
fi