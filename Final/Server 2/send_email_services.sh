#!/bin/bash

#//////////////////////////////////////////////////////////#
# MANALANG, JEREMY CHRISTIAN J.
# IT-222
#//////////////////////////////////////////////////////////#

# Script: send_email_services.sh

#==========================================================#
# VARIABLES
#==========================================================#

current_date=$(date '+%Y%m%d_%H%M%S')
current_date_log=$(date '+%Y%m%d%H%M%S')

ip_server02=$(hostname -I)
email_address="dummystain@gmail.com"
email_subject="[FAILED] ALMALINUX SERVER SERVICES"

# File Names
file_name_pattern="services_*.csv"
file_name_log="send_email_services_${current_date_log}.log"

# File Directories
filesystem_directory_inactive="/opt/services/inactive/"

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
	
	# Formatting of email body message.
	local email_body_text=$(cat <<EOF
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
	
	# Send email.
	local send_mail_command=$(echo "$email_body_text" | mail -v -s "$email_subject" "$email_address")
	
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
		# Check if directory '/opt/services/inactive/' and its content .csv exists.'
		if [ -n "$(ls -A "$filesystem_directory_inactive"/*.csv 2>/dev/null)" ]; then
			file_latest=$(ls -t1 $filesystem_directory_inactive$file_name_pattern | head -n 1)
			
			PrintMessage "Latest services file found '$file_latest'" 0
			
			PrintMessage "Checking if file has failed services..." 0
			
			# Check if there are failed services on latest file.
			if grep -q "failed" "$file_latest"; then
				formatted_file_latest=$(<$file_latest)
				
				PrintMessage "File '$file_latest' has failed services!" 0
				
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
				PrintMessage "File '$file_latest' does not have any failed services. Terminating the script..." 1
				exit
			fi
		else
			PrintMessage "No file found under directory '$filesystem_directory_inactive'" 1
		fi
	} 2>&1 | tee -a "$file_name_log" # Generate log for this script.
}

#==========================================================#
# RUNTIME FUNCTIONS
#==========================================================#

Main

#==========================================================#
