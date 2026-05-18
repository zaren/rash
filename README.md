# RASH

RASH ("Remote Apple Shell Helper") is a script and application written to assist in the management of macOS computers. It is designed to execute a shell command as a local admin user on a specified group of machines. It is available as both scripts to run from the command line, as well as a point-and-click GUI app, to run as you prefer.

## Why?

I do a lot of Mac management via shell commands or scripts. I've always used Apple's ARD (Apple Remote Desktop) software to send commands to groups of machines, but it's... not always reliable these days. It won't see machines that are clearly on the network, and which I can SSH into manually. This script allows me to do my shell-based work while bypassing ARD's problem of not seeing the machines.

## Application setup

### SSH keys

RASH is dependant on SSH private keys to function. See https://www.ssh.com/academy/ssh/keygen for the full explanation of the process of creating and installing private keys, but in short, issue the following commands on your local / managing machine:

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

Failure to enable private keys will result in the script failing as follows:

```
Executing command 'pwd' on group Studios...
(admin@192.168.1.246) Password:
An error occurred for machine 192.168.1.246.
sudo: a terminal is required to read the password; either use the -S option to read from standard input or configure an askpass helper
sudo: a password is required
```

### machine_groups.txt file

RASH operates on a list of IP addresses contained in a file called `machine_groups.txt`. It is formatted to have a group name as the first word in a line, following by IP addresses after it, with single spaces separating all content. Multiple lines are used for multiple groups. 

```
North_Lab 192.168.1.2 192.168.1.3
SouthLab 192.168.1.5 192.168.1.6 19.168.1.7
```

A sample machine_groups.txt file is included with the download that you can edit, or you can create your own based on the displayed formatting. This file is intended to live in the same directory as the command line script by default, but it can be located anywhere you like with the GUI app, as you will have to locate it within the app during setup.

## Usage - command line (RASH_CLI)

When you run the script, you will be prompted to receive your output in either a single window, or in multiple tabs. The single window option has a built-in 15 second failover before moving to the next machine on the list, while the multiple tabs option executes each command simultanously.

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

## Usage - graphical interface (RASH_GUI)

The first time you launch the app, you should see the following interface. The message in the upper left indicates that it cannot find the groups file.

<img width="820" height="612" alt="image" src="https://github.com/user-attachments/assets/37e4a713-7450-4b72-ac3d-b8f1f2ffcaba"  />

Click the gear icon in that space, and you will find your preferences to configure in two tabs. 

In the Connections tab, you will confirm the location of the public SSH key you generated, along with the name of the local admin account that will be executing the commands you are sending.

<img width="996" height="612" alt="image" src="https://github.com/user-attachments/assets/89b38362-5f0c-4f14-87b3-41df6201acfe"  />

In the Group Files tab, you will find a default path to confirm for the groups file location, and a blank space that can be used to edit the file.

<img width="996" height="612" alt="image" src="https://github.com/user-attachments/assets/67260436-9b76-4df4-aa54-49670340736c"  />

You can copy and paste a `machine_groups.txt` file into this space or type it in manually in this space. Once the data is entered, click "Save", and then the X in the upper right to close the window.

<img width="932" height="612" alt="image" src="https://github.com/user-attachments/assets/7d7e4d81-58ce-47a8-94ea-510a77ca9775"  />

(The "Browse..." button is there to locate and load a groups file from another location, and the "Reload" button is to be used if further changes are made to the file.)

Once the groups file is loaded, the app will populate the groups on the left side of the window. You will also see an "+ Add Group" button on the lower left, which can be used to make additions to the groups list.

<img width="932" height="612" alt="image" src="https://github.com/user-attachments/assets/d51e3a2e-ca1b-452e-907c-5b2c591f1e16" />

<img width="932" height="612" alt="image" src="https://github.com/user-attachments/assets/705ac480-47f8-4d12-bf01-dbcb28b9768e" />

Once you select a group, you will see the command entry field appear.

<img width="996" height="612" alt="image" src="https://github.com/user-attachments/assets/7a83552e-9a4f-4d9a-87dc-03cd12cfda6b" />

From here, you can type in a command (no "sudo" needed) and then either hit "Return" on your keyboard or click the "Run" button.

<img width="996" height="612" alt="image" src="https://github.com/user-attachments/assets/f210d2c2-9b64-4057-82fb-fd5fae97e2a7" />

### Fiddly bits

If you prefer to always have your output in either a single window or multiple tabs, I broke those features out in two additional scripts, `rash_single.sh` and `rash_tabs.sh`. Use them as you see fit.
