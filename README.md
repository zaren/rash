# RASH

RASH ("Remote Apple Shell Helper") is a script written to assist in the management of macOS computers. It is designed to execute a shell command on a specified group of machines.

## Why?

I do a lot of Mac management via shell commands or scripts. I've always used Apple's ARD (Apple Remote Desktop) software to send commands to groups of machines, but it's... not always reliable these days. It won't see machines that are clearly on the network, and which I can SSH into manually. This script allows me to do my shell-based work while bypassing ARD's problem of not seeing the machines.

This script is dependant on SSH private keys to function. See https://www.ssh.com/academy/ssh/keygen for the full explanation of the process in creating and installing private keys, but in short, do the following:

```
1) ssh-keygen
2) ssh-copy-id -i ~/.ssh/your_key.pub user@host
```

repeating step 2 for each machine you are managing.

This script also relies on an external file ("machine_groups.txt" by default), formatted with each line containing a label for each group of machines you wish to manage, and IP numbers of those machines. The label must be a single string of text with no spaces, and the IP number will follow that, separated by spaces. For example:

```
North_Lab 192.168.1.2 192.168.1.3
SouthLab 192.168.1.5 192.168.1.6 19.168.1.7
```
By default, this file will reside in the same directory as the script.
