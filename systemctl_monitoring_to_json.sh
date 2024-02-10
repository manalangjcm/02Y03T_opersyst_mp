#!/bin/bash

#//////////////////////////////////////////////////////////#
# MANALANG, JEREMY CHRISTIAN J.
# IT-222
#//////////////////////////////////////////////////////////#

#==========================================================#
# VARIABLES
#==========================================================#

current_date=`date '+%Y%m%d_%H%M%S'`

# File Names
file_name="services_${current_date}.json"

# File Directories
file_directory="/tmp/"

# Command
systemctl_main_command="systemctl"

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
	
	echo "$value_to_insert" > $file_destination
}

function GenerateSystemCtl()
{	
	systemctl_command=$(systemctl list-units --all --no-pager --plain | grep -E "running|exited|failed|dead")
	
	PrintMessage "Converting systemctl to JSON..." 0
	
	running_array=()
	exited_array=()
	failed_array=()
	dead_array=()
	
	json_format=""
	
	running_index=1
	exited_index=1
	failed_index=1
	dead_index=1
	
	while IFS= read -r line; do
		service_name=$(echo "$line" | awk '{print $1}' | tr -dc '[:print:]\n' | sed -e 's/\\x[[:xdigit:]][[:xdigit:]]//g')
		service_description=$(echo "$line" | awk '/running|exited|dead/ { for (i=5; i<=NF; i++) { printf "%s%s", (i > 5 ? " " : ""), $i } printf "\n" }')
		service_status=$(echo "$line" | awk '{print $3}')
		service_state=$(echo "$line" | awk '{print $4}')
		
		case $service_state in
			"running")
				json_object="{\"service\":\"$service_name\",\"description\":\"$service_description\",\"status\":\"$service_status\",\"id_number\":\"$running_index\"}"
				final_json_object="{\"service\":$json_object},"
				
				running_array+=("$final_json_object")
				
				((running_index++))
				;;
			"exited")
				json_object="{\"service\":\"$service_name\",\"description\":\"$service_description\",\"status\":\"$service_status\",\"id_number\":\"$exited_index\"}"
				final_json_object="{\"service\":$json_object},"
				
				exited_array+=("$final_json_object")
				
				((exited_index++))
				;;
			"failed")
				json_object="{\"service\":\"$service_name\",\"description\":\"$service_description\",\"status\":\"$service_status\",\"id_number\":\"$failed_index\"}"
				final_json_object="{\"service\":$json_object},"
				
				failed_array+=("$final_json_object")
				
				((failed_index++))
				;;
			"dead")
				json_object="{\"service\":\"$service_name\",\"description\":\"$service_description\",\"status\":\"$service_status\",\"id_number\":\"$dead_index\"}"
				final_json_object="{\"service\":$json_object},"
				
				dead_array+=("$final_json_object")
				
				((dead_index++))
				;;
		esac
		
		PrintMessage "Successfully parsed: Service '$service_name' | Status: '$service_status'" 0
		
	done < <(echo "$systemctl_command")
	
	final_running_array=$(echo "${running_array[@]}" | sed 's/,\([^,]*\)$/\1/')
	final_exited_array=$(echo "${exited_array[@]}" | sed 's/,\([^,]*\)$/\1/')
	final_failed_array=$(echo "${failed_array[@]}" | sed 's/,\([^,]*\)$/\1/')
	final_dead_array=$(echo "${dead_array[@]}" | sed 's/,\([^,]*\)$/\1/')
	
	combined_json=$(echo "{\"services_state_running\":[${final_running_array[@]}],\"services_state_exited\":[${final_exited_array[@]}], \"services_state_failed\":[${final_failed_array[@]}], \"services_state_dead\":[${final_dead_array[@]}]}" | jq '.')
	
	ConvertToJSON "$combined_json"
}

function ConvertToJSON()
{
	local value_to_convert=$1
	
	InsertToFile "$value_to_convert" $file_directory$file_name
	
	PrintMessage "Successfully converted systemctl to JSON!\n ► Filename: $file_name\n ► File directory: $file_directory" 0
}

function Main()
{
	file_name_log="systemctl_monitoring_to_json_${current_date}.log"
	
	{
		PrintMessage "Generating systemctl..." 0
		GenerateSystemCtl
	} 2>&1 | tee -a "$file_name_log"
}

#==========================================================#
# RUNTIME FUNCTIONS
#==========================================================#

Main	

#==========================================================#
