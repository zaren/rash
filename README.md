# RASH

RASH ("Remote Apple Shell Helper") is a Bash script written to assist in the management of macOS computers. It is designed to execute a shell command on a specified group of machines.

## Why?

I do a lot of Mac management via shell commands or scripts. I've always used Apple's ARD (Apple Remote Desktop) software to send commands to groups of machines, but it's... not always reliable these days. It won't see machines that are clearly on the network, and which I can SSH into manually. This script allows me to do my shell-based work while bypassing ARD's problem of not seeing the machines.

## Installation

### SSH keys

(DISCLAIMER: This first part is a bit time and labor intensive, but you should only have to do it once.)

This script is dependant on SSH private keys to function. See https://www.ssh.com/academy/ssh/keygen for the full explanation of the process of creating and installing private keys, but in short, issue the following commands on your local / managing machine:

> 1) ssh-keygen
> 2) ssh-copy-id -i ~/.ssh/your_key.pub user@host

repeating step 2 with the public key that was generated in step 1 ("your_key.pub"), along with a local admin account ("user") and machine address ("host") of each machine you wish to manage.

You will also need to make a change to the `sudoers` file on each remote machine granting permission to execute commands. This must be done locally on each machine you wish to manage - it is not a file change you can copy to the machine.

To do this, ssh to each machine you wish to manage, issue the `sudo visudo` command, and change the following entry:

```
# root and users in group wheel can run anything on any machine as any user
root            ALL = (ALL) ALL
%admin          ALL = (ALL) ALL
```

to read as follows:

```
# root and users in group wheel can run anything on any machine as any user
root            ALL = (ALL) ALL
%admin          ALL = (ALL) NOPASSWD: ALL
```

You will not need to reboot any machines after applying these changes.

### Script

After SSH private keys are installed, copy the rash.sh script, put it somewhere convenient on your machine, and `chmod +x` it to make sure it's executable. You can either download the machine_groups.txt file and edit it, or create your own based on the displayed formatting. By default, this file will reside in the same directory as the script. 

```
North_Lab 192.168.1.2 192.168.1.3
SouthLab 192.168.1.5 192.168.1.6 19.168.1.7
```

The script reads the first entry in each line as the name of that machine group (presented as "Available groups" when the script runs), and processes the rest of the line as the IP adresses for that group.

When you run the script, you will be prompted to receive your output in either a single window, or in multiple tabs. The single window option has a built-in 15 second failover before moving to the next machine on the list, while the multiple tabs option executes each command simultanously.

## Usage

Execute the script, and follow the prompts as shown in the example below:

```
bash-3.2$ ./rash.sh

---===### ###===---

Display command output in 1) A single window or 2) Separate tabs? 

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

Done with group North_Lab. Exiting script.
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

Also, if you prefer to always have your output in either a single window or multiple tabs, I broke those features out in two additional scripts, `rash_single.sh` and `rash_tabs.sh`. Use then as you see fit.
