#!/bin/bash

#//////////////////////////////////////////////////////////#
# MANALANG, JEREMY CHRISTIAN J.
# IT-222
#//////////////////////////////////////////////////////////#

#==========================================================#
# VARIABLES
#==========================================================#

username_server02="admin"
ip_server02="192.168.47.132"
password_server02="admin"

# File Names
file_name_pattern="services*"

# File Directories
tmp_directory="/tmp"
file_destination="/opt/services"

#==========================================================#
# SCRIPT CONTENT
#==========================================================#

function CheckServerStatus()
{
	local username=$1
	local ip_address=$2
	local password=$3
	
	echo "Checking for server status: $username $ip_address ..."
	
	if ssh -q "$username@$ip_address" exit; then
		echo "Server is active!"
	else
		echo "Server is not active! Terminating script..."
		exit
	fi
}

function CheckJSONFile()
{
	if [ -n "$(ls -A "$tmp_directory"/$file_name_pattern 2>/dev/null)" ]; then
		file_latest=$(ls -t1 "$tmp_directory"/$file_name_pattern | head -n 1)
		
		echo "Latest JSON file found '$file_latest'"
	else
		echo "JSON file not found under '/tmp'!"
		exit
	fi
}

function TransferToRemoteServer()
{
	local username=$1
	local ip_address=$2
	local password=$3
	
	if ssh admin@$ip_address "ls $file_destination >/dev/null 2>&1" ; then
		ssh admin@$ip_address "echo $password | sudo -S chown -R $username:$username $file_destination"
	else
		echo "Not existing! Creating one..."
		ssh admin@$ip_address "echo $password | sudo -S mkdir $file_destination"
		ssh admin@$ip_address "echo $password | sudo -S chown -R $username:$username /opt/"
	fi
	
	sftp admin@$ip_address << @
		put -R $file_latest $file_destination
		quit
@

	echo "Successfully transferred '$file_latest' to server $username@$ip_address (Server 02)"
}

function RemoveJSONFile()
{
	local file_to_remove=$1
	local file_destination=$2
	
	# Check if a latest filesystem utilization JSON file can be found under /tmp/
	if [ ! -z $file_to_remove ]; then
		rm $file_to_remove
		echo "Removed JSON file '$file_to_remove' under '$file_destination'"
	else
		echo "No JSON file found under directory '$file_destination"
	fi
}

function Main()
{
	CheckServerStatus $username_server02 $ip_server02
	CheckJSONFile
	TransferToRemoteServer $username_server02 $ip_server02 $password_server02
	RemoveJSONFile $file_latest $tmp_directory
}

#==========================================================#
# RUNTIME FUNCTIONS
#==========================================================#

Main

#==========================================================#