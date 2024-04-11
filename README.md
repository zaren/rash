# RASH

RASH ("Remote Apple Shell Helper") is a script written to assist in the management of macOS computers. It is designed to execute a shell command on a specified group of machines.

This script is dependant on SSH private keys to function. See https://www.ssh.com/academy/ssh/keygen for the full explanation of the process in creating and installing private keys, but in short:

1) ssh-keygen
2) ssh-copy-id -i ~/.ssh/your_key.pub user@host
