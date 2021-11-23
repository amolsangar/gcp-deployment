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

# ===========================================================
# Clean up script
#project="fa21-engr-e516-asangar"
project=$project_id
$(gcloud config set project $project)
network=$network_name
firewall1=$firewall_1_name
firewall2=$firewall_2_name
server=$server_name
client=$client_name
clop=$(gcloud compute instances delete $server --zone=us-central1-a --quiet)
echo $clop
echo "VM deleted - $server"

clop=$(gcloud compute instances delete $client --zone=us-central1-a --quiet)
echo $clop
echo "VM deleted - $client"

clop=$(gcloud compute firewall-rules delete $firewall1 $firewall2 --quiet)
echo $clop
echo "Firewalls deleted - $firewall1 $firewall2"

clop=$(gcloud compute networks delete $network --quiet)
echo $clop
echo "Network deleted - $network"

del=$(gcloud projects delete $project --quiet)
echo $del