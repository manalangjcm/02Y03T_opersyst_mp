#!/bin/bash

set -e

#//////////////////////////////////////////////////////////#
# MANALANG, JEREMY CHRISTIAN J.
# IT-222
#//////////////////////////////////////////////////////////#

#==========================================================#
# VARIABLES
#==========================================================#

current_date=`date '+%Y%m%d_%H%M%S'`

ip_server02=$(echo `hostname -I`)

email_address="dummystain@gmail.com"
email_subject="[CRITICAL] ALMALINUX SERVER FILESYSTEM"

filesystem_directory_critical="/opt/filesystem/critical/"

#==========================================================#
# SCRIPT CONTENT
#==========================================================#

function PrintMessage()
{
	local message=$1
	local log_mode=$2
	
	local log_level
	
	case $log_mode in
		0)
			log_level="INFO"
			;;
		1)
			log_level="ERROR"
			;;
	esac
	
	echo -e "[`date '+%Y-%m-%d %H:%M:%S'`] [$log_level] : $message"
}

function InsertToFile()
{
	local value_to_insert=$1
	local file_destination=$2
	
	echo -e "$value_to_insert" >> $file_destination
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
				
				PrintMessage "Successfully processed $current" 0
			done < "$file"
			
			PrintMessage "Finished processing file '$file'" 0
		fi
	done
	
	PrintMessage "Composing message for emailing...'$file'" 0
	email_body_text=$(cat <<EOF
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
	
	send_mail_command=$(echo "$email_body_text" | mail -v -s "$email_subject" "$email_address")
	exit_status=$?
	
	if [ "$exit_status" -ne 0 ]; then
		PrintMessage "Failed to send email to '$email_address'!" 1
	else
		PrintMessage "Successfully sent email to '$email_address'!" 0
	fi
}

function Main()
{
	file_name_log="send_email_filesystem_${current_date}.log"
	
	{
		if [ -n "$(ls -A "$filesystem_directory_critical"/*.csv 2>/dev/null)" ]; then
			PrintMessage "Critical filesystems found under '$filesystem_directory_critical'!" 0
			PrintMessage "Processing critical filesystem files for emailing..." 0
			SendEmail
		else
			PrintMessage "No critical filesystems found under '$filesystem_directory_critical'." 1
		fi
	} 2>&1 | tee -a "$file_name_log"
}

#==========================================================#
# RUNTIME FUNCTIONS
#==========================================================#

Main

#==========================================================#