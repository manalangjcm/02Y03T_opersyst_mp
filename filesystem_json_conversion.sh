#!/bin/bash

#//////////////////////////////////////////////////////////#
# MANALANG, JEREMY CHRISTIAN J.
# IT-222
#//////////////////////////////////////////////////////////#

#==========================================================#
# VARIABLES
#==========================================================#

server_password="admin"

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

function InsertToFile()
{
	local value_to_insert=$1
	local file_destination=$2
	
	echo "$value_to_insert" > $file_destination
}

function ConvertJSON()
{
	index=0
	filesystem_ctr=1
	
	while [[ $index -lt $(jq '.filesystem_utilization | length' <<< "$converted_json_file") ]]; do
		current=$(jq ".filesystem_utilization[$index]" <<< "$converted_json_file")
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
			
			echo -e "[#] Found normal filesystem with $current_disk_percentage% disk percentage. \n ► Saved to '$file_directory_normal$file_name_normal'\n"
		
		# Check if disk percentage is greater than or equal to 85%
		elif [ $current_disk_percentage -ge $percentage_threshold ]; then
			if [[ ! -d $file_directory_critical ]]; then
				mkdir $file_directory_critical
			fi
			
			current_date_formatted=$(echo "$current_date" | awk 'BEGIN { FS = "" } ; { print substr($0, 1, 4) "-" substr($0, 5, 2) "-" substr($0, 7, 2) }')
			current_time_formatted=$(echo "$current_time" | awk 'BEGIN { FS = "" } ; { print substr($0, 1, 2) ":" substr($0, 3, 2) ":" substr($0, 5, 2) }')
			
			converted_text_block=`echo "$current_no","$current_name","$current_directory","$current_disk_size","$current_disk_used","$current_disk_available","$current_disk_used_pct",CRITICAL,"$current_date_formatted","$current_time_formatted"`
			
			InsertToFile "$converted_text_block" $file_directory_critical$file_name_critical
			
			echo -e "[!] Found critical filesystem with $current_disk_percentage% disk percentage. \n ► Saved to '$file_directory_critical$file_name_critical'\n"
		fi
		
		((index++))
		((filesystem_ctr++))
	done
}

function ArchiveJSON()
{
	# Check if /opt/json_archives/ directory exists on the server
	if [[ ! -d $archive_directory ]]; then
		echo "Directory '$archive_directory' does not exist!"
		echo $server_password | sudo -S chown -R admin:admin /opt/
		echo $server_password | sudo -S mkdir $archive_directory
		echo $server_password | sudo -S mv $file_latest $archive_directory
	fi
	
	echo "Directory '$archive_directory' exists! Archiving..."
	echo $server_password | sudo -S mv $file_latest $archive_directory
	echo "Successfully archived JSON file to '$archive_directory'"
}

function CheckExternalLibraries()
{
	# Check if SSHPASS is installed on the server
	if ! command -v sshpass &> /dev/null; then
		echo "SSHPASS not installed! Installing..."
		sudo install -y sshpass
	else
		echo "SSHPASS already installed!"
	fi
}

function Main()
{
	# Check for external libraries needed for the script
	CheckExternalLibraries
	
	# Check if a latest filesystem utilization JSON file can be found under /opt/filesystem/
	if [ -n "$(ls -A "$filesystem_directory"/$file_name_pattern 2>/dev/null)" ]; then
		file_latest=$(ls -t1 "$filesystem_directory"/$file_name_pattern | head -n 1)
		converted_json_file=$(<$file_latest)
		
		echo "Latest JSON file found '$file_latest'"
		
		# Convert the JSON file
		echo "Converting JSON..."
		ConvertJSON
		echo "Successfully converted JSON!"
		
		# Archive the JSON file to /opt/json_archives/
		echo "Archiving JSON to '$archive_directory'"
		ArchiveJSON
	else
		echo "No JSON file found under directory '$filesystem_directory'"
	fi
}

#==========================================================#
# RUNTIME FUNCTIONS
#==========================================================#

Main

#==========================================================#