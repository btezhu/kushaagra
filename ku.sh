#!/bin/bash

# created 

set -e

commands_file_path=""

echo_todo() {
	if [ -n "$commands_file_path" ]; then
		echo "TODO: $1"
		echo "# TODO: $1" >> "$commands_file_path"
	else
		echo "# TODO: $1"
	fi
}

echo_command() {
	if [ -n "$commands_file_path" ]; then
		echo $1 >> "$commands_file_path"
	else
		echo $1
	fi
}

do_users() {
	users_file_path="$1"
	commands_file_path="$2"
	if [ -n "$commands_file_path" ]; then
		echo "#!/bin/bash" > "$commands_file_path"
		echo >> "$commands_file_path"
	fi

	users_in_file=()
	declare -A users_encountered
	while IFS= read -r line; do
		users_in_file+=("$line")
		users_encountered["$line"]=""
	done < <(grep . "${users_file_path}")

	users_in_passwd=()
	while IFS= read -r line; do
		if [[ "$line" != "#"* ]]; then # if the line doesn't start with a comment
			users_in_passwd+=("$line")
		fi
	done < <(sort -t: -k3 -n /etc/passwd)

	echo_command "passwd -l root"
	echo_command

	done_sys=0
	for user in "${users_in_passwd[@]}"; do
		IFS=":"
		read username encrypted_password user_id group_id user_id_info home_directory shell <<< "$user"
		if [[ "$user_id" -lt "1000" ]]; then # system user
			if [[ ! ("$shell" == "/bin/false" || "$shell" == "/usr/sbin/nologin" || "$shell" == "/usr/bin/false")]]; then
				echo_todo "Set shell for user $username from $shell to /bin/false"
			fi
			if [ "$user_id" == "0" ] && [ "$username" != "root" ]; then
				echo_todo "Set user_id for user $username to nonzero value"
			fi
			if [ "$group_id" == "0" ] && [ "$username" != "root" ]; then
				echo_todo "Set group_id for user $username to nonzero value"
			fi
		else
			if [ "$done_sys" -eq 0 ]; then
				done_sys=1
				echo_command
				echo_command "# User accounts"
			fi
		fi
		if [ "$encrypted_password" != "x" ]; then
			echo_todo "Ensure user $username has an 'x' in /etc/passwd"
		fi
		is_in_file=0
		if [ "$username" == "root" ]; then
			is_in_file=1
		else
			for user in "${users_in_file[@]}"; do
				if [[ "$username" == "$user" ]]; then
					is_in_file=1
				fi
			done
		fi
		if [ "$is_in_file" -eq 0  ] && [[ "$user_id" -gt "999" ]]; then
			echo_command "deluser --remove-all-files $username"
		fi
		users_encountered["$username"]="$user_id"
	done

	echo_command

	for user in "${users_in_file[@]}"; do
		if [ -z "${users_encountered[$user]}" ]; then
			echo_command "adduser -m $user"
		else
			if [ "${users_encountered[$user]}" -lt 1000 ]; then
				echo_todo "Set user_id for user $user to value >= 1000"
			fi
		fi
	done
}

do_groups() {
	groups_file_path="$1"
	commands_file_path="$2"
	if [ -n "$commands_file_path" ]; then
		echo "#!/bin/bash" > "$commands_file_path"
		echo >> "$commands_file_path"
	fi

	# read groups from provided file
	groups_in_file=()
	declare -A groups_encountered
	declare -A users_in_group
	while IFS= read -r line; do
		read groupname users <<< "$line"
		groups_in_file+=("$groupname")
		groups_encountered["$groupname"]=""
		users_in_group["$groupname"]="$users"
	done < <(grep . "${groups_file_path}")

	# read groups from /etc/group
	groups_in_group=()
	while IFS= read -r line; do
		if [[ "$line" != "#"* ]]; then # if the line doesn't start with a comment
			groups_in_group+=("$line")
		fi
	done < /etc/group

	for group in "${groups_in_group[@]}"; do
		IFS=":"
		read groupname encrypted_password group_id users <<< "$group"
		if [ "$group_id" == "0" ] && [ "$groupname" != "root" ]; then
			echo_todo "Set group_id for group $groupname to nonzero value"
		fi
		if [ "$encrypted_password" != "x" ]; then
			echo_todo "Ensure group $groupname has an 'x' in /etc/group"
		fi
		if [ "$groupname" == "shadow" ]; then
			if [ -n "$users" ]; then
				echo_command
				IFS=","
				for user in "${users[@]}"; do
					echo_command "gpasswd -d $user shadow"
				done 
				echo_command
			fi
		fi
		IFS=$' \t\n'

		is_in_file=0
		if [ "$groupname" == "sudo" ]; then
			is_in_file=1
		else
			for group in "${groups_in_file[@]}"; do
				if [[ "$groupname" == "$group" ]]; then
					is_in_file=1
					IFS=','
					read -a users_found <<< "$users"
					read -ra users <<< "${users_in_group[$group]}"
					declare -A users_encountered
					echo_command
					echo_command "# Group $group"

					for user in "${users[@]}"; do
						users_encountered["$user"]=""
					done

					for user_found in "${users_found[@]}"; do
						is_in_group=0
						for user in "${users[@]}"; do
							if [[ "$user_found" == "$user" ]]; then
								is_in_group=1
							fi
						done
						if [ "$is_in_group" -eq 0 ]; then
							echo_command "gpasswd -d $user_found $group"
						fi
						users_encountered["$user_found"]="encountered"
					done
					for user in "${users[@]}"; do
						if [ -z "${users_encountered[$user]}" ]; then
							echo_command "usermod -aG $group $user"
						fi
					done
					echo_command
					IFS=$' \t\n'
				fi
			done
		fi

		if [ "$is_in_file" -eq 0 ] && [ "$group_id" -gt "999" ]; then
			echo_command "groupdel $groupname"
		fi
		groups_encountered["$groupname"]="encountered" # any nonempty string
	done

	echo_command

	# add non-encountered groups
	for group in "${groups_in_file[@]}"; do
		if [ -z "${groups_encountered[$group]}" ]; then
			echo_command "addgroup $group"
			IFS=" "
			read -ra users <<< "${users_in_group[$group]}"
			for user in "${users[@]}"; do
				echo_command "usermod -aG $group $user"
			done
			IFS=$' \t\n'
		fi
	done
}

usage() {
	echo "Usage: ku.sh <COMMAND> [OPTIONS]"
	echo
	echo "Commands:"
	echo "    users <users-file> [<output-file>]"
	echo "    groups <groups-file> [<output-file>]"
	echo "    media"
	echo "    permissions"
}

if [[ $# -lt 1 ]]; then
	usage
	echo
	echo "ERROR: No command provided"
	exit 1
fi

command="$1"

if [[ "$command" == "users" ]]; then
	if [[ $# -lt 2 ]]; then
		echo "No users file provided."
		exit 1
	elif [[ $# -gt 3 ]]; then
		echo "Too many arguments provided"
		exit 1
	fi
	if [ ! -f $2 ]; then
		echo "The file $2 does not exist."
		exit 1
	fi
	do_users $2 $3
elif [[ "$command" == "groups" ]]; then
	if [[ $# -lt 2 ]]; then
		echo "No groups file provided."
		exit 1
	elif [[ $# -gt 3 ]]; then
		echo "Too many arguments provided"
		exit 1
	fi
	if [ ! -f $2 ]; then
		echo "The file $2 does not exist."
		exit 1
	fi
	do_groups $2 $3
else 
	echo "Unknown command"
fi