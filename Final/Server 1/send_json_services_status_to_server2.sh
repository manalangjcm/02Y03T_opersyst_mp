#!/bin/bash

#//////////////////////////////////////////////////////////#
# MANALANG, JEREMY CHRISTIAN J.
# IT-222
#//////////////////////////////////////////////////////////#

# Script: send_json_services_status_to_server2.sh

#==========================================================#
# VARIABLES
#==========================================================#

current_date=$(date '+%Y%m%d_%H%M%S')
current_date_log=$(date '+%Y%m%d%H%M%S')

# Authentication
username_server02="admin"
ip_server02="192.168.47.132"
password_server02="admin"

# File Names
file_name_pattern="services*"
file_name_log="send_json_services_status_to_server2_${current_date_log}.log"

# File Directories
tmp_directory="/tmp"
file_destination="/opt/services"

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

function CheckServerStatus()
{
	local username=$1
	local ip_address=$2
	
	# Check if username, IP address, and password is not null.
	if [[ -z "$username" && -z "$ip_address" ]]; then
		PrintMessage "Username and IP address is null! Terminating the script..." 1
		exit
	elif [[ -z "$username" ]]; then
		PrintMessage "Username is null! Terminating the script..." 1
		exit
	elif [[ -z "$ip_address" ]]; then
		PrintMessage "IP address is null! Terminating the script..." 1
		exit
	fi
	
	PrintMessage "Checking for server status '$username $ip_address'..." 0
	
	if ssh -q "$username@$ip_address" exit; then
		PrintMessage "Server is active!" 0
	else
		PrintMessage "Server is not active! Terminating script..." 1
		exit
	fi
}

function CheckJSONFile()
{
	# Check if a latest systemctl JSON file can be found under /tmp/
	if [ -n "$(ls -A "$tmp_directory"/$file_name_pattern 2>/dev/null)" ]; then
		file_latest=$(ls -t1 "$tmp_directory"/$file_name_pattern | head -n 1)
		
		PrintMessage "Latest JSON file found '$file_latest'" 0
	else
		PrintMessage "JSON file not found under '/tmp'!" 1
		exit
	fi
}

function TransferToRemoteServer()
{
	local username=$1
	local ip_address=$2
	local password=$3
	
	# Check if '/opt/services' exists on Server 2. If yes, change directory owner to root. If not, create one.
	# The script uses auto password for sudo commands. Ignore any sudo printed messages asking for input.
	if ssh admin@$ip_address "ls $file_destination >/dev/null 2>&1" ; then
		PrintMessage "Password for 'sudo' command is not required. Ignore this message!" 0
		ssh admin@$ip_address "echo $password | sudo -S chown -R $username:$username $file_destination"
	else
		PrintMessage "Not existing! Creating one..." 0
		PrintMessage "Password for 'sudo' command is not required. Ignore this message!" 0
		ssh admin@$ip_address "echo $password | sudo -S mkdir $file_destination"
		ssh admin@$ip_address "echo $password | sudo -S chown -R $username:$username /opt/"
	fi
	
	# Upload file to Server 2.
	sftp admin@$ip_address << EOF
		put -R $file_latest $file_destination
		quit
EOF

	PrintMessage "Successfully transferred '$file_latest' to server '$username@$ip_address (Server 02)'" 0
}

function RemoveJSONFile()
{
	local file_to_remove=$1
	local file_destination=$2
	
	# Check if file to remove is not null.
	if [[ ! -z "$file_to_remove" && ! -z "$file_destination" ]]; then
		rm "$file_to_remove"
		PrintMessage "Successfully removed JSON file '$file_to_remove' under '$file_destination'" 0
	else
		PrintMessage "File to remove or file destination is null. Please assign a value." 1
	fi
}

function Main()
{
	{
		CheckServerStatus "$username_server02" "$ip_server02"
		CheckJSONFile
		TransferToRemoteServer "$username_server02" "$ip_server02" "$password_server02"
		RemoveJSONFile "$file_latest" "$tmp_directory"
	} 2>&1 | tee -a "$file_name_log" # Generate log for this script.
}

#==========================================================#
# RUNTIME FUNCTIONS
#==========================================================#

Main	

#==========================================================#
