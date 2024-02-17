#!/bin/bash

#//////////////////////////////////////////////////////////#
# MANALANG, JEREMY CHRISTIAN J.
# IT-222
#//////////////////////////////////////////////////////////#

# Script: services_json_conversion.sh

#==========================================================#
# VARIABLES
#==========================================================#

current_date=$(date '+%Y%m%d_%H%M%S')
current_date_log=$(date '+%Y%m%d%H%M%S')

# Authentication
server_password="admin"

# File Names
file_name_pattern="services_*"
file_name_active="services_active_${current_date}.txt"
file_name_inactive="services_inactive_${current_date}.csv"
file_name_log="services_json_conversion_${current_date_log}.log"

# File Directories
services_directory="/opt/services"
file_directory_active="$services_directory/active/"
file_directory_inactive="$services_directory/inactive/"

# Deletion Settings
file_day_threshold=7

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
	
	# Check if directory '/opt/services/active/' and '/opt/services/inactive/' exists. If not, create them.
	# Active & inactive
	if [[ ! -d "$file_directory_active" && ! -d "$file_directory_inactive" ]]; then
		mkdir "$file_directory_active"
		mkdir "$file_directory_inactive"
	# Active only
	elif [[ ! -d "$file_directory_active" ]]; then
		mkdir "$file_directory_active"
	# Inactive only
	elif [[ ! -d "$file_directory_inactive" ]]; then
		mkdir "$file_directory_inactive"
	fi
	
	for ((index=0; index<service_length; index++)); do
		current=$(jq -r --arg service_to_convert "$service_to_convert" --argjson index "$index" ".services_state_${service_to_convert}[$index].service" <<< "$converted_json_file")
		current_service=$(echo "$current" | jq -r '.["service-name"]')
        current_description=$(echo "$current" | jq -r '.description')
        current_status="$service_to_convert"
		
		case "$service_to_convert" in
			"running" | "exited")
				file_directory="$file_directory_active"
				file_name="$file_name_active"
				file_text_format="name: $current_service\ndescription: $current_description\n"
				;;
			"failed")
				file_directory="$file_directory_inactive"
				file_name="$file_name_inactive"
				file_text_format="$current_service,$current_description,failed,failed"
				;;
			"dead")
				file_directory="$file_directory_inactive"
				file_name="$file_name_inactive"
				file_text_format="$current_service,$current_description,dead,inactive"
				;;
		esac

		# Append to corresponding file.
        echo -e "$file_text_format" >> "$file_directory$file_name"

        PrintMessage "Successfully deserialized: Service '$current_service' | Status: '$current_status'\n ► Filename: $file_name\n ► File directory: $file_directory" 0
    done
}

function DeleteOldFiles()
{
	# Check if directory '/opt/services/active/' and '/opt/services/inactive/' exists. If not, create them.
	# Active & inactive
	if [[ ! -d "$file_directory_active" && ! -d "$file_directory_inactive" ]]; then
		PrintMessage "Directory '$file_directory_active' and '$file_directory_inactive' does not exist! Creating them..." 0
		mkdir "$file_directory_active"
		mkdir "$file_directory_inactive"
	# Active only
	elif [[ ! -d "$file_directory_active" ]]; then
		PrintMessage "Directory '$file_directory_active' does not exist! Creating one..." 0
		mkdir "$file_directory_active"
	# Inactive only
	elif [[ ! -d "$file_directory_inactive" ]]; then
		PrintMessage "Directory '$file_directory_inactive' does not exist! Creating one..." 0
		mkdir "$file_directory_inactive"
	fi
	
	# Check for old files inside /opt/services/active/
	PrintMessage "Deleting files older than $file_day_threshold days under '$file_directory_active'..." 0
	if [[ $(find $file_directory_active -type f -mtime +$file_day_threshold) ]]; then
		PrintMessage "Files older than $file_day_threshold days found under '$file_directory_active'. Deleting..." 0
		find "$file_directory_active" -type f -mtime +$file_day_threshold -exec rm {} \;
		PrintMessage "Successfully deleted older files under '$file_directory_active'!" 0
	else
		PrintMessage "No files older than $file_day_threshold days found under '$file_directory_active'. Skipping deletion..." 2
	fi
	
	# Check for old files inside /opt/services/inactive/
	PrintMessage "Deleting files older than $file_day_threshold days under '$file_directory_inactive'..." 0
	if [[ $(find $file_directory_inactive -type f -mtime +$file_day_threshold) ]]; then
		PrintMessage "Files older than $file_day_threshold days found under '$file_directory_inactive'. Deleting..." 0
		find "$file_directory_inactive" -type f -mtime +$file_day_threshold -exec rm {} \;
		PrintMessage "Successfully deleted older files under '$file_directory_inactive'!" 0
	else
		PrintMessage "No files older than $file_day_threshold days found under '$file_directory_inactive'. Skipping deletion..." 2
	fi
}

function Main()
{
	{
		# Check first if services directory exists. If not, create one.
		if [ ! -d "$services_directory" ]; then
			PrintMessage "Directory '$services_directory' does not exist! Creating one..." 0
			mkdir "$services_directory"
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
			PrintMessage "No JSON file found under directory '$services_directory'! Terminating the script..." 1
			exit
		fi
	} 2>&1 | tee -a "$file_name_log" # Generate log for this script
}

#==========================================================#
# RUNTIME FUNCTIONS
#==========================================================#

Main

#==========================================================#
