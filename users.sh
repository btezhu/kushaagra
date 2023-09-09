#!/bin/bash

set -e

if [[ $# -lt 1 ]]; then
	echo "No users file provided."
	exit 1
fi
users_file_path="$1"
if [ ! -f $users_file_path ]; then
	echo "The file $users_file_path does not exist."
	exit 1
fi

users_commands_file_path="$2"

if [ -n "$users_commands_file_path" ]; then
	echo "#!/bin/bash" > "$users_commands_file_path"
	echo >> "$users_commands_file_path"
fi

# read users from provided file
users_in_file=()
declare -A users_encountered
while IFS= read -r line; do
	users_in_file+=("$line")
	users_encountered["$line"]=""
done < <(grep . "${users_file_path}")

# read users from /etc/passwd
users_in_passwd=()
while IFS= read -r line; do
	if [[ "$line" != "#"* ]]; then # if the line doesn't start with a comment
		users_in_passwd+=("$line")
	fi
done < /etc/passwd

echo_command() {
	if [ -n "$users_commands_file_path" ]; then
		echo $1 >> "$users_commands_file_path"
	else
		echo $1
	fi
}

echo_todo() {
	if [ -n "$users_commands_file_path" ]; then
		echo "TODO:" $1
		echo "# TODO:" $1 >> "$users_commands_file_path"
	else
		echo "# TODO:" $1
	fi
}

echo_command "passwd -l root"
echo_command

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
			echo_todo "Set user_id for user $username to nonzero value"
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
	if [ "$is_in_file" -eq 0 ]; then
		echo_command "deluser --remove-all-files $username"
	fi
	users_encountered["$username"]="$user_id"
done

echo_command

for user in "${users_in_file[@]}"; do
	if [ -z "${users_encountered[$user]}" ]; then
		echo_command "adduser $user"
	else
		if [ "${users_encountered[$user]}" -lt 1000 ]; then
			echo_todo "Set user_id for user $user to value >= 1000"
		fi
	fi
done