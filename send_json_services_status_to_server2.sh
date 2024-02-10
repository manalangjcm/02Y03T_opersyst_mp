#!/bin/bash

#//////////////////////////////////////////////////////////#
# MANALANG, JEREMY CHRISTIAN J.
# IT-222
#//////////////////////////////////////////////////////////#

#==========================================================#
# VARIABLES
#==========================================================#

current_date=`date '+%Y%m%d_%H%M%S'`

username_server02="admin"
ip_server02="192.168.47.132"
password_server02="admin"

# File Names
file_name_pattern="services*"

# File Directories
tmp_directory="/tmp"
file_destination="/opt/services"

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

function CheckServerStatus()
{
	local username=$1
	local ip_address=$2
	local password=$3
	
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
	
	if ssh admin@$ip_address "ls $file_destination >/dev/null 2>&1" ; then
		PrintMessage "Password for 'sudo' command is not required. Ignore this message!" 0
		ssh admin@$ip_address "echo $password | sudo -S chown -R $username:$username $file_destination"
	else
		PrintMessage "Not existing! Creating one..." 0
		PrintMessage "Password for 'sudo' command is not required. Ignore this message!" 0
		ssh admin@$ip_address "echo $password | sudo -S mkdir $file_destination"
		ssh admin@$ip_address "echo $password | sudo -S chown -R $username:$username /opt/"
	fi
	
	sftp admin@$ip_address << @
		put -R $file_latest $file_destination
		quit
@

	PrintMessage "Successfully transferred '$file_latest' to server '$username@$ip_address (Server 02)'" 0
}

function RemoveJSONFile()
{
	local file_to_remove=$1
	local file_destination=$2
	
	# Check if a latest systemctl JSON file can be found under /tmp/
	if [ ! -z $file_to_remove ]; then
		rm $file_to_remove
		PrintMessage "Removed JSON file '$file_to_remove' under '$file_destination'" 0
	else
		PrintMessage "No JSON file found under directory '$file_destination" 1
	fi
}

function Main()
{
	file_name_log="send_json_services_status_to_server2_${current_date}.log"
	
	{
		CheckServerStatus $username_server02 $ip_server02
		CheckJSONFile
		TransferToRemoteServer $username_server02 $ip_server02 $password_server02
		RemoveJSONFile $file_latest $tmp_directory
	} 2>&1 | tee -a "$file_name_log"
}

#==========================================================#
# RUNTIME FUNCTIONS
#==========================================================#

Main	

#==========================================================#
