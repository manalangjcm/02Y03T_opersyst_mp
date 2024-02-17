#!/bin/bash

#//////////////////////////////////////////////////////////#
# MANALANG, JEREMY CHRISTIAN J.
# IT-222
#//////////////////////////////////////////////////////////#

# Script: filesystem_util_to_json.sh

#==========================================================#
# VARIABLES
#==========================================================#

current_date=$(date '+%Y%m%d_%H%M%S')

# File Names
file_name="filesystem_${current_date}.json"
file_name_log="filesystem_util_to_json_${current_date}.log"

# File Directories
file_directory="/tmp/"

# Filesystem Utilization Naming
filesystem_util_object_name="filesystem_utilization"

# Command
filesystem_util_command=$(df -k | awk 'NR>1')

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

function GenerateFileSystemUtilization()
{	
	PrintMessage "Converting filesystem utilization to JSON..." 0
	
	local filesystem_array=()
	local filesystem_no=1
	
	while IFS= read -r line; do
		# tr & sed command will remove any invalid control characters
		current_filesystem=$(echo "$line" | awk '{print $1}' | tr -dc '[:print:]\n' | sed -e 's/\\x[[:xdigit:]][[:xdigit:]]//g')
		current_disk_size=$(echo "$line" | awk '{print $2}')
		current_disk_used=$(echo "$line" | awk '{print $3}')
		current_disk_available=$(echo "$line" | awk '{print $4}')
		current_disk_used_pct=$(echo "$line" | awk '{print $5}' | tr -dc '[:print:]\n' | sed -e 's/\\x[[:xdigit:]][[:xdigit:]]//g')
		current_directory=$(echo "$line" | awk '{print $6}' | tr -dc '[:print:]\n' | sed -e 's/\\x[[:xdigit:]][[:xdigit:]]//g')
		
		# Format variables to JSON
		local json_object="{\"filesystem_no\":\"$filesystem_no\",\"filesystem\":\"$current_filesystem\",\"disk_size\":\"$current_disk_size\",\"disk_used\":\"$current_disk_used\",\"disk_available\":\"$current_disk_available\",\"disk_used_pct\":\"$current_disk_used_pct\",\"directory\":\"$current_directory\"}"
		local final_json_object="{\"filesystem_details\":$json_object},"
		
		filesystem_array+=("$final_json_object")
		
		PrintMessage "Successfully parsed: Filesystem '$current_filesystem'" 0
		
		((filesystem_no++))
	done < <(echo "$filesystem_util_command")
	
	# Remove comma per each last element of the array
	local final_filesystem_array=$(echo "${filesystem_array[@]}" | sed 's/,\([^,]*\)$/\1/')
	local combined_json=$(echo "{\"filesystem_utilization\":[${final_filesystem_array[@]}]}" | jq '.')
	
	# Insert to .json file
	echo -e "$combined_json" > "$file_directory$file_name"
	PrintMessage "Successfully converted filesystem utilization to JSON!\n ► Filename: $file_name\n ► File directory: $file_directory" 0
}

function Main()
{
	{
		PrintMessage "Generating filesystem utilization..." 0
		GenerateFileSystemUtilization
	} 2>&1 | tee -a "$file_name_log" # Generate log for this script.
}

#==========================================================#
# RUNTIME FUNCTIONS
#==========================================================#

Main

#==========================================================#