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
file_name="filesystem_${current_date}.json"

# File Directories
file_directory="/tmp/"

# Filesystem Utilization Naming
filesystem_util_object_name="filesystem_utilization"

# Command
filesystem_util_command="df -k"

#==========================================================#
# SCRIPT CONTENT
#==========================================================#

function InsertToFile()
{
	local value_to_insert=$1
	local file_destination=$2
	
	echo "$value_to_insert" > $file_destination
}

function GenerateFileSystemUtilization()
{	
	filesystem_utilization=$(df -k | awk 'NR>1')
	
	filesystem_array=()
	
	filesystem_no=1
	json_format=""
	
	while IFS= read -r line; do
		current_filesystem=$(echo "$line" | awk '{print $1}' | tr -dc '[:print:]\n' | sed -e 's/\\x[[:xdigit:]][[:xdigit:]]//g')
		current_disk_size=$(echo "$line" | awk '{print $2}')
		current_disk_used=$(echo "$line" | awk '{print $3}')
		current_disk_available=$(echo "$line" | awk '{print $4}')
		current_disk_used_pct=$(echo "$line" | awk '{print $5}' | tr -dc '[:print:]\n' | sed -e 's/\\x[[:xdigit:]][[:xdigit:]]//g')
		current_directory=$(echo "$line" | awk '{print $6}' | tr -dc '[:print:]\n' | sed -e 's/\\x[[:xdigit:]][[:xdigit:]]//g')
		
		json_object="{\"filesystem_no\":\"$filesystem_no\",\"filesystem\":\"$current_filesystem\",\"disk_size\":\"$current_disk_size\",\"disk_used\":\"$current_disk_used\",\"disk_available\":\"$current_disk_size\",\"disk_used_pct\":\"$current_disk_used_pct\",\"directory\":\"$current_directory\"}"
		final_json_object="{\"filesystem_details\":$json_object},"
		
		filesystem_array+=("$final_json_object")
		
		((filesystem_no++))
	done < <(echo "$filesystem_utilization")
	
	final_filesystem_array=$(echo "${filesystem_array[@]}" | sed 's/,\([^,]*\)$/\1/')
	
	combined_json=$(echo "{\"filesystem_utilization\":[${final_filesystem_array[@]}]}" | jq '.')

	echo "Converting filesystem utilization to JSON..."
	ConvertToJSON "$combined_json"
}

function ConvertToJSON()
{
	local value_to_convert=$1
	
	InsertToFile "$value_to_convert" $file_directory$file_name
	echo -e "Successfully converted filesystem utilization to JSON!\n ► Filename: $file_name\n ► File directory: $file_directory"
}

function Main()
{
	echo "Generating filesystem utilization..."
	GenerateFileSystemUtilization
}

file_name_log="filesystem_util_to_json_${current_date}.log"
Main 2>&1 | tee -a "$file_name_log"
