#!/bin/sh

#we went to add the project to /etc/hosts and check if it already exists

# insert/update hosts entry
ip_address="127.0.0.1"
host_name=$1
BASEDIR=$(dirname "$0")

# find existing instances in the host file and save the line numbers
matches_in_hosts="$(grep -n $host_name /etc/hosts | cut -f1 -d:)"
host_entry="${ip_address} ${host_name}"

echo "Writing '$host_entry' to /etc/hosts file"

if [ ! -z "$matches_in_hosts" ]
then
    echo "Updating existing hosts entry."
    # iterate over the line numbers on which matches were found
    while read -r line_number; do
        # replace the text of each line with the desired host entry
        sudo sed -i '' "${line_number}s/.*/${host_entry} /" /etc/hosts
    done <<< "$matches_in_hosts"
else
    echo "Adding new hosts entry."
    echo "\n$host_entry" | sudo tee -a /etc/hosts > /dev/null
fi

echo "\nAdding nginx configuration file"
 
cp $BASEDIR/../stubs/nginx.stub $BASEDIR/../nginx/conf.d/$1.conf
sed -i '' "s/{project}/$1/g" $BASEDIR/../nginx/conf.d/$1.conf
STUB=$BASEDIR/../stubs/service.stub

echo "\nAdding service to docker-compose file"
sed -i '' "/PHP Services/ r $STUB" ./docker-compose.yml
sed -i '' "s/{project}/$1/g" ./docker-compose.yml

docker-compose up -d

