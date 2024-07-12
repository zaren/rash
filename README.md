# RASH

RASH ("Remote Apple Shell Helper") is a Bash script written to assist in the management of macOS computers. It is designed to execute a shell command on a specified group of machines.

## Why?

I do a lot of Mac management via shell commands or scripts. I've always used Apple's ARD (Apple Remote Desktop) software to send commands to groups of machines, but it's... not always reliable these days. It won't see machines that are clearly on the network, and which I can SSH into manually. This script allows me to do my shell-based work while bypassing ARD's problem of not seeing the machines.

## Installation

This script is dependant on SSH private keys to function. See https://www.ssh.com/academy/ssh/keygen for the full explanation of the process of creating and installing private keys, but in short, do the following:

> 1) ssh-keygen
> 2) ssh-copy-id -i ~/.ssh/your_key.pub user@host

repeating step 2 for each machine you are managing.

After SSH private keys are installed, copy the rash.sh script, put it somewhere convenient on your machine, and `chmod +x` it to make sure it's executable. You can either download the machine_groups.txt file and edit it, or create your own based on the displayed formatting. By default, this file will reside in the same directory as the script. 

```
North_Lab 192.168.1.2 192.168.1.3
SouthLab 192.168.1.5 192.168.1.6 19.168.1.7
```

The script reads the first entry in each line as the name of that machine group (presented as "Available groups" when the script runs), and processes the rest of the line as the IP adresses for that group.

## Usage

Execute the script, and follow the prompts as shown in the example below:

```
bash-3.2$ ./rash.sh 
Available groups:
1. North_Lab
2. SouthLab
Enter the number of the group you want to manage: 1
Enter the command you want to execute: pwd
Executing command 'pwd' on group North_Lab...
Command executed successfully on machine 192.168.1.2.
/Users/admin

Command executed successfully on machine 192.168.1.3.
/Users/admin

Done with group North_Lab.
```

### Fiddly bits

Failure to enable private keys will result in the script failing as follows:

```
Executing command 'pwd' on group Studios...
(admin@192.168.1.246) Password:
An error occurred for machine 192.168.1.246.
sudo: a terminal is required to read the password; either use the -S option to read from standard input or configure an askpass helper
sudo: a password is required
```

This will ALSO occur if you have not made a change to the `sudoers` file granting permission to execute commands. To fix this, issue the `sudo visuo` command and change the following entry:

```
# root and users in group wheel can run anything on any machine as any user
root            ALL = (ALL) ALL
%admin          ALL = (ALL) ALL
```

to read:

```
# root and users in group wheel can run anything on any machine as any user
root            ALL = (ALL) ALL
%admin          ALL = (ALL) NOPASSWD: ALL
```


A variation of this script, rash_tabs.sh, will create a separate window for each machine it connects to, setting those up as tabs in a single window. It will also label each window with the IP address of the machine it connects to, to make it easier to manage the processes.
