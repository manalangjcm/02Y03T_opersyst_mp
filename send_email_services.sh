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
email_subject="[FAILED] ALMALINUX SERVER SERVICES"

file_name_pattern="services_*.csv"
filesystem_directory_inactive="/opt/services/inactive/"

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
	local services_array=()

	while IFS= read -r line; do
		current="$line"
		current_service=$(echo "$current" | awk -F',' '{print $1}')
		current_description=$(echo "$current" | awk -F',' '{print $2}')
		
		formatted_text=$(cat <<EOF
Service Name: $current_service
Description: $current_description
EOF
)
		services_array+=("$formatted_text")
		
		PrintMessage "Successfully processed '$current'" 0

	done < <(echo "$formatted_file_latest" | grep failed)
	
	PrintMessage "Composing message for emailing..." 0
	email_body_text=$(cat <<EOF
Hi,

Please start the following services immediately:

Hostname IP address: $ip_server02

$(printf '%s\n\n' "${services_array[@]}")

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
	file_name_log="send_email_services_${current_date}.log"
	
	{
		# Check if directory '/opt/services/inactive/ exists.'
		if [ -n "$(ls -A "$filesystem_directory_inactive"/*.csv 2>/dev/null)" ]; then
			file_latest=$(ls -t1 $filesystem_directory_inactive$file_name_pattern | head -n 1)
			formatted_file_latest=$(<$file_latest)
			
			PrintMessage "Latest services file found '$file_latest'" 0
			
			SendEmail
		fi
	} 2>&1 | tee -a "$file_name_log"
}

#==========================================================#
# RUNTIME FUNCTIONS
#==========================================================#

Main

#==========================================================#