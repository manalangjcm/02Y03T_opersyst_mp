#!/bin/bash

#//////////////////////////////////////////////////////////#
# MANALANG, JEREMY CHRISTIAN J.
# IT-222
#//////////////////////////////////////////////////////////#

#==========================================================#
# VARIABLES
#==========================================================#

server_password="admin"

#current_date=`date '+%Y%m%d_%H%M%S'`
current_date="20240210_123606"

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

function InsertToFile()
{
	local value_to_insert=$1
	local file_destination=$2
	
	echo -e "$value_to_insert" >> $file_destination
}

function ConvertJSON()
{
	# Debug
	truncate -s 0 "$file_name_active"
	truncate -s 0 "$file_name_inactive"
	
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
	
	# Check if directory exists, create if not
    if [[ ! -d $file_directory ]]; then
        mkdir -p "$file_directory"
    fi
	
	for ((index=0; index<service_length; index++)); do
        current_service=$(jq -r ".services_state_${service_to_convert}[$index].service" <<< "$converted_json_file")
        current_description=$(jq -r ".services_state_${service_to_convert}[$index].description" <<< "$converted_json_file")
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

        # Write to file
        InsertToFile "$file_text_format" "$file_name"

        # Output message
        echo -e "[#] $current_status service: $current_service\n ► Saved to '$file_directory$file_name'\n"
    done
}

function Main()
{
	# Check if SSHPASS is installed on the server
	if ! command -v sshpass &> /dev/null; then
		echo "SSHPASS not installed! Installing..."
		sudo install -y sshpass
	else
		echo "SSHPASS already installed!"
	fi

	# Check if a latest systemctl services JSON file can be found under /opt/services/
	if [ -n "$(ls -A "$services_directory"/$file_name_pattern 2>/dev/null)" ]; then
		#file_latest=$(ls -t1 "$services_directory"/$file_name_pattern | head -n 1)
		file_latest="test.json"
		converted_json_file=$(<$file_latest)
		
		echo "Latest JSON file found '$file_latest'"
		
		# Convert the JSON file
		echo "Converting JSON..."
		ConvertJSON
		echo "Successfully converted JSON!"
	else
		echo "No JSON file found under directory '$services_directory'"
	fi
}

#==========================================================#
# RUNTIME FUNCTIONS
#==========================================================#

Main

#==========================================================#