#!/bin/bash

#//////////////////////////////////////////////////////////#
# MANALANG, JEREMY CHRISTIAN J.
# IT-222
#//////////////////////////////////////////////////////////#

# Script: send_email_filesystem.sh

#==========================================================#
# VARIABLES
#==========================================================#

current_date=$(date '+%Y%m%d_%H%M%S')
current_date_log=$(date '+%Y%m%d%H%M%S')

# Authentication
ip_server02=$(echo `hostname -I`)

email_address="dummystain@gmail.com"
email_subject="[CRITICAL] ALMALINUX SERVER FILESYSTEM"

# File Names
file_name_log="send_email_filesystem_${current_date_log}.log"

# File Directories
filesystem_directory_critical="/opt/filesystem/critical/"

#==========================================================#
# SCRIPT CONTENT
#==========================================================#

function PrintMessage()
{
	local message=$1
	local log_level=$2
	
	local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
	
	case $log_level in
		0) log_level="INFO" ;;
		1) log_level="ERROR" ;;
		2) log_level="WARNING" ;;
	esac
	
	echo -e "[$timestamp] [$log_level] : $message"
}

function SendEmail()
{
	local filesystem_array=()
	
	for file in "$filesystem_directory_critical"/*; do
		if [[ -f "$file" ]]; then
			while IFS= read -r line; do
				current="$line"
				current_directory=$(echo "$current" | awk -F',' '{print $3}')
				current_disk_used_pct=$(echo "$current" | awk -F',' '{print $7}')
				
					formatted_text=$(cat <<EOF
Directory: $current_directory
Disk Used Percentage: $current_disk_used_pct
EOF
)

				filesystem_array+=("$formatted_text")
				
				PrintMessage "Successfully processed '$current'" 0
			done < "$file"
			
			PrintMessage "Finished processing file '$file'" 0
		fi
	done
	
	PrintMessage "Composing message for emailing..." 0
	
	# Formatting of email body message.
	local email_body_text=$(cat <<EOF
Hi,

Please address the following filesystem immediately.

Hostname IP address: $ip_server02

$(printf '%s\n\n' "${filesystem_array[@]}")

-------------------------------------------------------
Do Not Reply, this is an Automated Email.

Thank you.
EOF
)

	PrintMessage "Sending email to '$email_address'..." 0
	
	# Send email.
	send_mail_command=$(echo "$email_body_text" | mail -v -s "$email_subject" "$email_address")
	
	# Check if command for sending mail was executed successfully
	if [ $? -ne 0 ]; then
		PrintMessage "Failed to send email to '$email_address'! Terminating the script..." 1
		exit
	else
		PrintMessage "Successfully sent email to '$email_address'!\nPlease check for email on 'Inbox' or 'Spam' folder." 0
	fi
}

function Main()
{
	{
		# Check if directory '/opt/filesystem/critical/' and its content .csv exists.'
		if [ -n "$(ls -A "$filesystem_directory_critical"/*.csv 2>/dev/null)" ]; then
			PrintMessage "Critical filesystems found under '$filesystem_directory_critical'!" 0
			PrintMessage "Processing critical filesystem files for emailing..." 0
			
			# Check if email address is null or empty.
			if [[ "$email_address" == "" || -z "$email_address" ]]; then
				PrintMessage "Email address is null or empty! Terminating the script..." 1
				exit
			fi
			
			# Check if email address is valid.
			if echo "$email_address" | grep -P "^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$" >/dev/null; then
				# Check if email address' domain is valid.
				local email_domain=$(echo "$email_address" | awk -F'@' '{print $2}')
				if nslookup "$email_domain" >/dev/null; then
					PrintMessage "Email address '$email_address' & domain '$email_domain' is valid or is active!" 0
				else
					PrintMessage "Email address '$email_address' & domain '$email_domain' is not valid or is inactive! Terminating the script..." 1
					exit
				fi
			else
				PrintMessage "Email address '$email_address' is not valid! Terminating the script..." 1
				exit
			fi
			
			SendEmail
		else
			PrintMessage "No critical filesystems found under '$filesystem_directory_critical'! Terminating the script..." 1
			exit
		fi
	} 2>&1 | tee -a "$file_name_log" # Generate log for this script.
}

#==========================================================#
# RUNTIME FUNCTIONS
#==========================================================#

Main

#==========================================================#
