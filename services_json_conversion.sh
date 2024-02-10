#!/bin/bash

#//////////////////////////////////////////////////////////#
# MANALANG, JEREMY CHRISTIAN J.
# IT-222
#//////////////////////////////////////////////////////////#

#==========================================================#
# VARIABLES
#==========================================================#

server_password="admin"

current_date=`date '+%Y%m%d_%H%M%S'`

# File Names
file_name_pattern="services_*"
file_name_active="services_active_${current_date}.txt"
file_name_inactive="services_inactive_${current_date}.csv"

# File Directories
services_directory="/opt/services"
file_directory_active="$services_directory/active/"
file_directory_inactive="$services_directory/inactive/"

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
		2)
			log_level="WARNING"
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

function ConvertJSON()
{
	running_length=$(jq '.services_state_running | length' <<< "$converted_json_file")
	exited_length=$(jq '.services_state_exited | length' <<< "$converted_json_file")
	failed_length=$(jq '.services_state_failed | length' <<< "$converted_json_file")
	dead_length=$(jq '.services_state_dead | length' <<< "$converted_json_file")
	
	ConvertService "running" "$running_length"
	ConvertService "exited" "$exited_length"
	ConvertService "failed" "$failed_length"
	ConvertService "dead" "$dead_length"
}

function ConvertService()
{
	local service_to_convert=$1
	local service_length=$2
	
	local file_directory
    local file_name
	local file_text_format
	
	for ((index=0; index<service_length; index++)); do
		current=$(jq -r --arg service_to_convert "$service_to_convert" --argjson index "$index" ".services_state_${service_to_convert}[$index].service" <<< "$converted_json_file")
		current_service=$(echo "$current" | jq -r '.service')
        current_description=$(echo "$current" | jq -r '.description')
        current_status="$service_to_convert"
		
		case $service_to_convert in
			"running" | "exited")
				file_directory=$file_directory_active
				file_name=$file_name_active
				file_text_format="name: $current_service\ndescription: $current_description\n"
				;;
			"failed")
				file_directory=$file_directory_inactive
				file_name=$file_name_inactive
				file_text_format="$current_service,$current_description,failed,failed"
				;;
			"dead")
				file_directory=$file_directory_inactive
				file_name=$file_name_inactive
				file_text_format="$current_service,$current_description,dead,inactive"
				;;
		esac
		
		# If directory does not exist, create one
		if [[ ! -d $file_directory ]]; then
			mkdir "$file_directory"
		fi

        InsertToFile "$file_text_format" "$file_directory$file_name"

        PrintMessage "Successfully deserialized: Service '$current_service' | Status: '$current_status'\n ► Filename: $file_name\n ► File directory: $file_directory" 0
    done
}

function DeleteOldFiles()
{
	# Check for old files inside /opt/services/active/
	PrintMessage "Deleting files older than 7 days under $file_directory_active..." 0
	if [[ $(find $file_directory_active -type f -mtime +6) ]]; then
		PrintMessage "Files older than 7 days found under '$file_directory_active'. Deleting..." 0
		find $file_directory_active -type f -mtime +7 -exec rm {} \;
		PrintMessage "Successfully deleted older files under '$file_directory_active'!" 0
	else
		PrintMessage "No files older than 7 days found under '$file_directory_active'. Skipping deletion..." 0
	fi
	
	# Check for old files inside /opt/services/inactive/
	PrintMessage "Deleting files older than 7 days under $file_directory_inactive..." 0
	if [[ $(find $file_directory_inactive -type f -mtime +6) ]]; then
		PrintMessage "Files older than 7 days found under '$file_directory_inactive'. Deleting..." 0
		find $file_directory_inactive -type f -mtime +7 -exec rm {} \;
		PrintMessage "Successfully deleted older files under '$file_directory_inactive'!" 0
	else
		PrintMessage "No files older than 7 days found under '$file_directory_inactive'. Skipping deletion..." 0
	fi
}

function Main()
{
	file_name_log="services_json_conversion_${current_date}.log"
	
	{
		# Check if SSHPASS is installed on the server
		if ! command -v sshpass &> /dev/null; then
			PrintMessage "SSHPASS not installed! Installing..." 0
			PrintMessage "Please do not exit or close the window during installation!" 2
			sudo install -y sshpass
		else
			PrintMessage "SSHPASS already installed!" 0
		fi
		
		# Delete files older than 7 days
		DeleteOldFiles

		# Check if a latest systemctl services JSON file can be found under /opt/services/
		if [ -n "$(ls -A "$services_directory"/$file_name_pattern 2>/dev/null)" ]; then
			file_latest=$(ls -t1 "$services_directory"/$file_name_pattern | head -n 1)
			converted_json_file=$(<$file_latest)
			
			PrintMessage "Latest JSON file found '$file_latest'" 0
			
			# Convert the JSON file
			PrintMessage "Deserializing JSON file..." 0
			ConvertJSON
			PrintMessage "Successfully deserialized systemctl JSON!" 0
		else
			PrintMessage "No JSON file found under directory '$services_directory'" 1
		fi
	} 2>&1 | tee -a "$file_name_log"
}

#==========================================================#
# RUNTIME FUNCTIONS
#==========================================================#

Main

#==========================================================#
