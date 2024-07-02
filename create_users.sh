#!/bin/bash

# Ensure the script is run as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 
   exit 1
fi

# Check if the input file is provided
if [ $# -ne 1 ]; then
  echo "Usage: $0 <name-of-text-file>"
  exit 1
fi

input_file=$1

# Log file and password file paths
log_file="/var/log/user_management.log"
password_file="/var/secure/user_passwords.csv"

# Create necessary directories and set permissions
mkdir -p /var/secure
touch $log_file
touch $password_file
chmod 600 $password_file

# Function to generate a random password
generate_password() {
  echo "$(tr -dc A-Za-z0-9 </dev/urandom | head -c 12)"
}

# Read input file line by line
while IFS=";" read -r username groups; do
  # Remove whitespace
  username=$(echo $username | xargs)
  groups=$(echo $groups | xargs)

  if id "$username" &>/dev/null; then
    echo "User $username already exists. Skipping." | tee -a $log_file
    continue
  fi

  # Create user and primary group
  useradd -m -s /bin/bash $username
  echo "Created user $username" | tee -a $log_file

  # Set up the user's home directory permissions
  chmod 700 /home/$username
  chown $username:$username /home/$username
  echo "Set permissions for /home/$username" | tee -a $log_file

  # Create additional groups and add the user to these groups
  IFS=',' read -ra ADDR <<< "$groups"
  for group in "${ADDR[@]}"; do
    group=$(echo $group | xargs)
    if ! getent group "$group" > /dev/null; then
      groupadd $group
      echo "Created group $group" | tee -a $log_file
    fi
    usermod -aG $group $username
    echo "Added $username to group $group" | tee -a $log_file
  done

  # Generate a random password for the user
  password=$(generate_password)
  echo "$username:$password" | chpasswd
  echo "Generated password for $username" | tee -a $log_file

  # Store the password securely
  echo "$username,$password" >> $password_file
done < "$input_file"

echo "User creation process completed." | tee -a $log_file

