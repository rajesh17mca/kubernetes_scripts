#!/bin/bash

# Update package list
echo "Updating package list..."
apt-get update

# Install tcpdump and net-tools
echo "Installing tcpdump and net-tools..."
apt-get -y install tcpdump net-tools
apt-get install -y curl

# Confirm installation
echo "Installation completed. Verifying versions:"
tcpdump --version
ifconfig --version
