#!/bin/bash
function parse_yaml {
   local prefix=$2
   local s='[[:space:]]*' w='[a-zA-Z0-9_]*' fs=$(echo @|tr @ '\034')
   sed -ne "s|^\($s\):|\1|" \
        -e "s|^\($s\)\($w\)$s:$s[\"']\(.*\)[\"']$s\$|\1$fs\2$fs\3|p" \
        -e "s|^\($s\)\($w\)$s:$s\(.*\)$s\$|\1$fs\2$fs\3|p"  $1 |
   awk -F$fs '{
      indent = length($1)/2;
      vname[indent] = $2;
      for (i in vname) {if (i > indent) {delete vname[i]}}
      if (length($3) > 0) {
         vn=""; for (i=0; i<indent; i++) {vn=(vn)(vname[i])("_")}
         printf("%s%s%s=\"%s\"\n", "'$prefix'",vn, $2, $3);
      }
   }'
}

config_file="./config.yml"
eval $(parse_yaml $config_file)

function isFirewallPresent() {
    command=$1
    value=$2
    for c in $($command)
    do
        return 1
    done
}

function checkResource() {
    command=$1
    value=$2
    for res in $($command)
    do
        temp=`echo $res | sed -e 's/^[[:space:]]*//'`
        if [[ $temp == $value ]]
        then
            echo "Resource: $res"
            return 1
        fi
    done
}

function createResource() {
    command=$1
    value=$2
    resource=$($command)
    if [[ $resource == *"Created" ]]
    then
        return 1
    fi
}

wait_startup_script_to_finish() {
    vm_name=$1
    vm_zone=$2
    echo -n "Wait for \"$vm_name\" startup script to exit."
    status=""
    while [[ -z "$status" ]]
    do
        sleep 3;
        echo -n "."
        status=$(gcloud compute ssh $vm_name --zone=$vm_zone --command 'grep -m 1 "startup-script exit status" /var/log/syslog' 2>&-)
    done
    echo $status
}

echo "Please authenticate yourself by logging into GCP"

sleep 1
$(gcloud auth login)

read -p "Enter project name (New/Old): " projectName
echo "Project Name - $projectName"

# project="FA21-ENGR-E516-asangar"
checkResource "gcloud projects list --filter=NAME=$projectName --format=value(NAME)" "$projectName"
isProject=$?
echo "p$isProject"
if [[ $isProject == 0 ]]
then
    createResource "gcloud projects create ${projectName,,} --name=$projectName --folder=946064600477 --set-as-default"
    link=$(gcloud beta billing projects link ${projectName,,} --billing-account=$billing_account)
    echo $link
    #echo "Project not available. Please create and map billing account before proceeding! "
    #exit
fi

sleep 2

project=$( gcloud projects list --filter=NAME=$projectName --format="value(project_id)" )

echo "Setting project configuration -"
res1=$(gcloud config set project $project)
res2=$(gcloud services enable cloudresourcemanager.googleapis.com)
res3=$(gcloud services enable compute.googleapis.com)
res4=$(gcloud config list)
echo $res4

# Store project name in config file 
new_config_1=$(awk -v new="" 'prev=="project:"{sub(/\047.*/,""); $0="\tid: " new} {prev=$1} 1' $config_file)
echo "$new_config_1" > "$config_file"
new_config=$(awk -v new="\"$project\"" 'prev=="project:"{sub(/\047.*/,""); $0=$0 new} {prev=$1} 1' $config_file)
echo "$new_config" > "$config_file"

network=$network_name
checkResource 'gcloud compute networks list --format=value(NAME) --quiet' "$network"
isNetwork=$?
echo "n$isNetwork"
if [[ $isNetwork == 0 ]]
then
    createResource "gcloud compute networks create $network"
    if [[ $? == 1 ]]
    then
        echo "Network Created"
    fi
fi

sleep 1

firewall1=$firewall_1_name
firewall2=$firewall_2_name
isFirewallPresent "gcloud compute firewall-rules list --filter=network:($network) --format=value(NAME) --quiet"
isFirewall=$?
echo "f$isFirewall"
if [[ $isFirewall == 0 ]]
then
    createResource "gcloud compute firewall-rules create $firewall1 --network $network --allow tcp,udp,icmp --quiet"
    if [[ $? == 1 ]]
    then
        echo "Firewall-1 Created"
    fi
    createResource "gcloud compute firewall-rules create $firewall2 --network $network --allow tcp:22,tcp:3389,icmp --quiet"
    if [[ $? == 1 ]]
    then
        echo "Firewall-2 Created"
    fi
fi

sleep 1

# Create VM
server=$server_name
client=$client_name
zone="us-central1-a"
startup_script_filepath='./metadata.sh'
checkResource "gcloud compute instances list --format=value(NAME)" "$server"
isServerVMPresent=$?
checkResource "gcloud compute instances list --format=value(NAME)" "$client"
isClientVMPresent=$?
echo "vm1"$isServerVMPresent
echo "vm2"$isClientVMPresent

if [[ $isServerVMPresent == 0 ]]
then
    createResource "gcloud compute instances create $server --quiet --network=$network --zone=$zone --metadata-from-file=startup-script=$startup_script_filepath"
    if [[ $? == 1 ]]
    then
        echo "Server VM Created"
    fi
fi

if [[ $isClientVMPresent == 0 ]]
then
    createResource "gcloud compute instances create $client --quiet --network=$network --zone=$zone --metadata-from-file=startup-script=$startup_script_filepath"
    if [[ $? == 1 ]]
    then
        echo "Client VM Created"
    fi
fi

# Wait for Startup scripts to finish
wait_startup_script_to_finish $server $zone
wait_startup_script_to_finish $client $zone

# ===========================================================
# Server Installation
op=$(gcloud compute scp $servercode_filepath $server:./memcached-lite-asangar-server --quiet --zone=$zone)
echo $op
echo "Server code copy completed"

# Client Installation
op=$(gcloud compute scp $clientcode_filepath $client:./memcached-lite-asangar-client --quiet --zone=$zone)
echo $op
echo "Client code copy completed"

# ===========================================================
# SSH into Server VM -> Run memcached-server
server_int_ip=$(gcloud compute instances describe $server --zone=$zone --format='value(networkInterfaces.networkIP)')
echo "Memcached Server IP "$server_int_ip

server_user=$(gcloud compute ssh $server --zone=$zone --command 'whoami' 2>&-)
echo "Memcached Server Setup Start"
extract=$(gcloud compute ssh $server --zone=$zone --command "unzip /home/$server_user/memcached-lite-asangar-server -d server" 2>&1)

server_run=$(gcloud compute ssh $server --zone=$zone --command "nohup node /home/$server_user/server/memcached-lite-asangar/server.js > server_output.log 2>&1 &" 2>&1)
echo $server_run
op=$(gcloud compute scp $server:./server_output.log ./output-logs/server_output.log --zone=$zone)
echo $op
echo "Server log copied to output-logs folder"

# ===========================================================
# SSH into Client VM -> Run memcached-client and perform tests
client_user=$(gcloud compute ssh $client --zone=$zone --command 'whoami' 2>&-)
echo "Memcached Client Setup Start"
client_extract=$(gcloud compute ssh $client --zone=$zone --command "unzip /home/$client_user/memcached-lite-asangar-client -d client" 2>&-)

# --------------
echo "Performing Client Tests - Wait until test finishes"
echo "Memcached Client Test #1"
client_run_1=$(gcloud compute ssh $client --zone=$zone --command "node /home/$client_user/client/memcached-lite-asangar/test1.js $server_int_ip > client_output_1.log 2>&1" 2>&1)
op=$(gcloud compute scp $client:./client_output_1.log ./output-logs/client_output_1.log --zone=$zone)
echo $op
echo "Test 1 results copied to the output-logs folder"

# --------------
echo "Memcached Client Test #2"
client_run_2=$(gcloud compute ssh $client --zone=$zone --command "node /home/$client_user/client/memcached-lite-asangar/test2.js $server_int_ip > client_output_2.log 2>&1" 2>&1)
op=$(gcloud compute scp $client:./client_output_2.log ./output-logs/client_output_2.log --zone=$zone)
echo $op
echo "Test 2 results copied to the output-logs folder"

# --------------
echo "Memcached Client Test #3"
client_run_3=$(gcloud compute ssh $client --zone=$zone --command "node /home/$client_user/client/memcached-lite-asangar/test3.js $server_int_ip > client_output_3.log 2>&1" 2>&1)
op=$(gcloud compute scp $client:./client_output_3.log ./output-logs/client_output_3.log --zone=$zone)
echo $op
echo "Test 3 results copied to the output-logs folder"

# --------------
echo "Memcached Client Test #4"
client_run_4=$(gcloud compute ssh $client --zone=$zone --command "node /home/$client_user/client/memcached-lite-asangar/test4.js $server_int_ip > client_output_4.log 2>&1" 2>&1)
op=$(gcloud compute scp $client:./client_output_4.log ./output-logs/client_output_4.log --zone=$zone)
echo $op
echo "Test 4 results copied to the output-logs folder"
# --------------

echo "Client Tests Finished"
echo ""

# Copy server log again after execution
op=$(gcloud compute scp $server:./server_output.log ./output-logs/server_output.log --zone=$zone)
echo $op
echo "Server log copied to output-logs folder"

sleep 1

# Stopping VMs
shutdown1=$(gcloud compute instances stop $server --zone=$zone --quiet)
echo $shutdown1

shutdown2=$(gcloud compute instances stop $client --zone=$zone --quiet)
echo $shutdown2
