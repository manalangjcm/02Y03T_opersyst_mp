#!/bin/bash

#//////////////////////////////////////////////////////////#
# MANALANG, JEREMY CHRISTIAN J.
# IT-222
#//////////////////////////////////////////////////////////#

# Script: systemctl_monitoring_to_json.sh

#==========================================================#
# VARIABLES
#==========================================================#

current_date=$(date '+%Y%m%d_%H%M%S')

# File Names
file_name="services_${current_date}.json"
file_name_log="systemctl_monitoring_to_json_${current_date}.log"

# File Directories
file_directory="/tmp/"

# Command
systemctl_command=$(systemctl list-units --all --no-pager --plain | grep -E "running|exited|failed|dead")

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
	esac
	
	echo -e "[$timestamp] [$log_level] : $message"
}

function GenerateSystemCtl()
{
	PrintMessage "Converting systemctl to JSON..." 0
	
	# Arrays for each service objects.
	local running_array=()
	local exited_array=()
	local failed_array=()
	local dead_array=()

	# Index for services object.
	local running_index=1
	local exited_index=1
	local failed_index=1
	local dead_index=1
	
	while IFS= read -r line; do
		# tr & sed command will remove any invalid control characters
		current_service=$(echo "$line" | awk '{print $1}' | tr -dc '[:print:]\n' | sed -e 's/\\x[[:xdigit:]][[:xdigit:]]//g')
		current_description=$(echo "$line" | awk '/running|exited|dead/ { for (i=5; i<=NF; i++) { printf "%s%s", (i > 5 ? " " : ""), $i } printf "\n" }')
		current_status=$(echo "$line" | awk '{print $3}')
		current_state=$(echo "$line" | awk '{print $4}')
		
		# Format variables to JSON by each state
		case $current_state in
			"running")
				local json_object="{\"service-name\":\"$current_service\",\"description\":\"$current_description\",\"status\":\"$current_status\",\"id_number\":$running_index}"
				local final_json_object="{\"service\":$json_object},"
				
				running_array+=("$final_json_object")
				
				((running_index++))
				;;
			"exited")
				local json_object="{\"service-name\":\"$current_service\",\"description\":\"$current_description\",\"status\":\"$current_status\",\"id_number\":$exited_index}"
				local final_json_object="{\"service\":$json_object},"
				
				exited_array+=("$final_json_object")
				
				((exited_index++))
				;;
			"failed")
				local json_object="{\"service-name\":\"$current_service\",\"description\":\"$current_description\",\"status\":\"$current_status\",\"id_number\":$failed_index}"
				local final_json_object="{\"service\":$json_object},"
				
				failed_array+=("$final_json_object")
				
				((failed_index++))
				;;
			"dead")
				local json_object="{\"service-name\":\"$current_service\",\"description\":\"$current_description\",\"status\":\"$current_status\",\"id_number\":$dead_index}"
				local final_json_object="{\"service\":$json_object},"
				
				dead_array+=("$final_json_object")
				
				((dead_index++))
				;;
		esac
		
		PrintMessage "Successfully parsed: Service '$current_service' | Status: '$current_status'" 0
		
	done < <(echo "$systemctl_command")
	
	# Remove commas per each last element of each arrays
	final_running_array=$(echo "${running_array[@]}" | sed 's/,\([^,]*\)$/\1/')
	final_exited_array=$(echo "${exited_array[@]}" | sed 's/,\([^,]*\)$/\1/')
	final_failed_array=$(echo "${failed_array[@]}" | sed 's/,\([^,]*\)$/\1/')
	final_dead_array=$(echo "${dead_array[@]}" | sed 's/,\([^,]*\)$/\1/')
	
	local combined_json=$(echo "{\"services_state_running\":[${final_running_array[@]}],\"services_state_exited\":[${final_exited_array[@]}], \"services_state_failed\":[${final_failed_array[@]}], \"services_state_dead\":[${final_dead_array[@]}]}" | jq '.')
	
	# Insert to .json file
	echo -e "$combined_json" > "$file_directory$file_name"
	PrintMessage "Successfully converted systemctl to JSON!\n ► Filename: $file_name\n ► File directory: $file_directory" 0
}

function Main()
{
	{
		PrintMessage "Generating systemctl..." 0
		GenerateSystemCtl
	} 2>&1 | tee -a "$file_name_log" # Generate log for this script.
}

#==========================================================#
# RUNTIME FUNCTIONS
#==========================================================#

Main	

#==========================================================#