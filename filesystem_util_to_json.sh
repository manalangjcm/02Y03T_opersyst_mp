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
	filesystem_utilization=`$filesystem_util_command | awk 'NR>1 {printf "{\"filesystem_no\":\"%d\",\"filesystem\":\"%s\",\"disk_size\":\"%s\",\"disk_used\":\"%s\",\"disk_available\":\"%s\",\"disk_used_pct\":\"%s\",\"directory\":\"%s\"}\n", NR-1, $1, $2, $3, $4, $5, $6}' | jq -s '{ "filesystem_utilization": . }'`
	
	echo "Converting filesystem utilization to JSON..."
	ConvertToJSON "$filesystem_utilization"
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

#==========================================================#
# RUNTIME FUNCTIONS
#==========================================================#

Main

#==========================================================#