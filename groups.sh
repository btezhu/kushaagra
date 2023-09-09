#!/bin/bash

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
source "$SCRIPT_DIR/utils.sh"

set -e
if [[ $# -lt 1 ]]; then
	echo "No groups file provided."
	exit 1
fi
groups_file_path="$1"
if [ ! -f $groups_file_path ]; then
	echo "The file $groups_file_path does not exist."
	exit 1
fi

groups_command_file_path="$2"

if [ -n "$groups_command_file_path" ]; then
	echo "#!/bin/bash" > "$groups_command_file_path"
	echo >> "$groups_command_file_path"
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

echo_command() {
	if [ -n "$groups_command_file_path" ]; then
		echo $1 >> "$groups_command_file_path"
	else
		echo $1
	fi
}

echo_todo() {
	if [ -n "$groups_command_file_path" ]; then
		echo "TODO:" $1
		echo "# TODO:" $1 >> "$groups_command_file_path"
	else
		echo "# TODO:" $1
	fi
}

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
				users_found="$users"
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
			fi
		done
	fi

	if [ "$is_in_file" -eq 0 ]; then
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