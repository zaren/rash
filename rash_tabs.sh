#!/bin/bash

# Path to your SSH private key
private_key="$HOME/.ssh/id_rsa"

# Path to the file with machine groups
machine_groups_file="machine_groups.txt"

# Function to execute command on a group of machines
execute_command() {
    group_name="$1"
    command_to_execute="$2"
    shift 2
    machines=("$@")

    echo "Executing command '$command_to_execute' on group $group_name..."
    for machine in "${machines[@]}"; do
        # AppleScript to open a new Terminal tab, run the SSH command, and set the tab title
        osascript <<EOF
tell application "Terminal"
    if not (exists window 1) then
        do script "ssh -i \"$private_key\" -o ConnectTimeout=15 -o StrictHostKeyChecking=no -o PasswordAuthentication=no -o LogLevel=ERROR -q -T \"$username@$machine\" \"sudo $command_to_execute\""
        set currentTab to tab 1 of window 1
        set currentTab's custom title to "$machine"
    else
        tell application "System Events" to tell process "Terminal" to keystroke "t" using command down
        set currentTab to tab -1 of window 1
        do script "ssh -i \"$private_key\" -o ConnectTimeout=15 -o StrictHostKeyChecking=no -o PasswordAuthentication=no -o LogLevel=ERROR -q -T \"$username@$machine\" \"sudo $command_to_execute\"" in currentTab
        set currentTab's custom title to "$machine"
    end if
end tell
EOF
    done

    echo "Done with group $group_name."
}

# Read username from external file
username_file="admin_account.txt"
if [ -f "$username_file" ]; then
    username=$(<"$username_file")
else
    echo "Error: Username file not found."
    exit 1
fi

# Initialize index counter for groups
index=0

# Initialize arrays to hold group names and corresponding machine lists
declare -a group_names
declare -a machine_lists

# Read machine groups from the specified file
while IFS= read -r line; do
    # Extract the group name which is the first word on the line
    group_name="${line%% *}"
    group_names[index]="$group_name"

    # Extract the machines list from the line, removing the group name
    machines="${line#* }"
    machine_lists[index]="$machines"

    index=$((index+1))
done < "$machine_groups_file"

# Prompt user to select a group
echo "Available groups:"
for i in "${!group_names[@]}"; do
    echo "$((i+1)). ${group_names[i]}"
done
read -p "Enter the number of the group you want to manage: " group_choice

# Validate the user selection and convert selection to zero-based index
group_index=$((group_choice-1))

# Check if the selection is valid
if [[ "$group_choice" =~ ^[0-9]+$ ]] && [ "$group_choice" -ge 1 ] && [ "$group_choice" -le "${#group_names[@]}" ]; then
    group_name="${group_names[$group_index]}"
    machines=(${machine_lists[$group_index]})
else
    echo "Invalid choice. Exiting."
    exit 1
fi

# Prompt user to input a command
read -p "Enter the command you want to execute: " user_command

# Execute the user-inputted command on the selected group of machines
execute_command "$group_name" "$user_command" "${machines[@]}"
