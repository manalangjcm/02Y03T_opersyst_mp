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
file_name_pattern="filesystem_*"

# File Directories
filesystem_directory="/opt/filesystem"
archive_directory="/opt/json_archives/"
file_directory_normal="$filesystem_directory/normal/"
file_directory_critical="$filesystem_directory/critical/"

percentage_threshold=85

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
	
	echo "$value_to_insert" > $file_destination
}

function ConvertJSON()
{
	filesystem_utilization_length=$(jq '.filesystem_utilization | length' <<< "$converted_json_file")
	filesystem_ctr=1
	
	for ((index=0; index<filesystem_utilization_length; index++)); do
		current=$(jq -r --argjson index "$index" '.filesystem_utilization[$index].filesystem_details' <<< "$converted_json_file")
		current_no=$(echo "$current" | jq -r '.filesystem_no')
		current_name=$(echo "$current" | jq -r '.filesystem')
		current_disk_size=$(echo "$current" | jq -r '.disk_size')
		current_disk_used=$(echo "$current" | jq -r '.disk_available')
		current_disk_available=$(echo "$current" | jq -r '.disk_used')
		current_disk_used_pct=$(echo "$current" | jq -r '.disk_used_pct')
		current_directory=$(echo "$current" | jq -r '.directory')
		current_date=$(echo "$file_latest" | cut -d '_' -f 2)
		current_time=$(echo "$file_latest" | cut -d '_' -f 3 | cut -d '.' -f 1)
		
		current_disk_percentage=`echo "$current_disk_used_pct" | grep -o '[0-9]*'`
		
		file_name_normal="filesystem_${filesystem_ctr}_normal.txt"
		file_name_critical="filesystem_${filesystem_ctr}_critical.txt"
		
		# Check if disk percentage is less than 85%
		if [ $current_disk_percentage -lt $percentage_threshold ]; then
			if [[ ! -d $file_directory_normal ]]; then
				mkdir $file_directory_normal
			fi
			
			current_date_formatted=$(echo "$current_date" | awk 'BEGIN { FS = "" } ; { print substr($0, 1, 4) "/" substr($0, 5, 2) "/" substr($0, 7, 2) }')
			current_time_formatted=$(echo "$current_time" | awk 'BEGIN { FS = "" } ; { print substr($0, 1, 2) "-" substr($0, 3, 2) "-" substr($0, 5, 2) }')
		
			converted_text_block=`echo "filesystem_no:$current_no"
			echo "status:normal"
			echo "disk_percentage:$current_disk_used_pct"
			echo "directory:$current_directory"
			echo "date:$current_date_formatted"
			echo "time:$current_time_formatted"`
			
			InsertToFile "$converted_text_block" $file_directory_normal$file_name_normal
			
			PrintMessage "Successfully deserialized: Filesystem '$current_name' | Disk Percentage '$current_disk_percentage%'\n ► Filename: $file_name_normal\n ► File directory: $file_directory_normal'" 0
		
		# Check if disk percentage is greater than or equal to 85%
		elif [ $current_disk_percentage -ge $percentage_threshold ]; then
			if [[ ! -d $file_directory_critical ]]; then
				mkdir $file_directory_critical
			fi
			
			current_date_formatted=$(echo "$current_date" | awk 'BEGIN { FS = "" } ; { print substr($0, 1, 4) "-" substr($0, 5, 2) "-" substr($0, 7, 2) }')
			current_time_formatted=$(echo "$current_time" | awk 'BEGIN { FS = "" } ; { print substr($0, 1, 2) ":" substr($0, 3, 2) ":" substr($0, 5, 2) }')
			
			converted_text_block=`echo "$current_no","$current_name","$current_directory","$current_disk_size","$current_disk_used","$current_disk_available","$current_disk_used_pct",CRITICAL,"$current_date_formatted","$current_time_formatted"`
			
			InsertToFile "$converted_text_block" $file_directory_critical$file_name_critical
			
			PrintMessage "Successfully deserialized: Filesystem '$current_name' | Disk Percentage '$current_disk_percentage%'\n ► Filename: $file_name_critical\n ► File directory: $file_directory_critical'" 0
		fi

		((filesystem_ctr++))
	done
}

function ArchiveJSON()
{
	# Check if /opt/json_archives/ directory exists on the server
	if [[ ! -d $archive_directory ]]; then
		PrintMessage "Directory '$archive_directory' does not exist!" 2
		PrintMessage "Password for 'sudo' command is not required. Ignore this message!" 0
		echo $server_password | sudo -S chown -R admin:admin /opt/
		echo $server_password | sudo -S mkdir $archive_directory
		echo $server_password | sudo -S mv $file_latest $archive_directory
	fi
	
	PrintMessage "Directory '$archive_directory' exists! Archiving..." 0
	PrintMessage "Password for 'sudo' command is not required. Ignore this message!" 0
	echo $server_password | sudo -S mv $file_latest $archive_directory
	PrintMessage "Successfully archived JSON file to '$archive_directory'" 0
}

function CheckExternalLibraries()
{
	# Check if SSHPASS is installed on the server
	if ! command -v sshpass &> /dev/null; then
		PrintMessage "SSHPASS not installed! Installing..." 0
		sudo install -y sshpass
	else
		PrintMessage "SSHPASS already installed!" 0
	fi
}

function DeleteOldFiles()
{
	# Check for old files inside /opt/json_archives
	PrintMessage "Deleting files older than 15 days under $archive_directory..." 0
	if [[ $(find $archive_directory -type f -mtime +6) ]]; then
		PrintMessage "Files older than 15 days found under '$archive_directory'. Deleting..." 0
		find $archive_directory -type f -mtime +15 -exec rm {} \;
		PrintMessage "Successfully deleted older files under '$archive_directory'!" 0
	else
		PrintMessage "No files older than 15 days found under '$archive_directory'. Skipping deletion..." 0
	fi
}

function Main()
{
	file_name_log="filesystem_json_conversion_${current_date}.log"
	
	{
		# Check for external libraries needed for the script
		CheckExternalLibraries
		
		# Delete files older than 15 days
		DeleteOldFiles
		
		# Check if a latest filesystem utilization JSON file can be found under /opt/filesystem/
		if [ -n "$(ls -A "$filesystem_directory"/$file_name_pattern 2>/dev/null)" ]; then
			file_latest=$(ls -t1 "$filesystem_directory"/$file_name_pattern | head -n 1)
			converted_json_file=$(<$file_latest)
			
			PrintMessage "Latest JSON file found '$file_latest'" 0
			
			# Convert the JSON file
			PrintMessage "Converting JSON..." 0
			ConvertJSON
			PrintMessage "Successfully converted JSON!" 0
			
			# Archive the JSON file to /opt/json_archives/
			PrintMessage "Archiving JSON to '$archive_directory'" 0
			ArchiveJSON
		else
			PrintMessage "No JSON file found under directory '$filesystem_directory'" 1
		fi
	} 2>&1 | tee -a "$file_name_log"
}

#==========================================================#
# RUNTIME FUNCTIONS
#==========================================================#

Main

#==========================================================#
