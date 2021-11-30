# gcp-deployment-memcached-lite
**Deployment automation** of <a href="https://github.com/amolsangar/memcached-lite">memcached-lite</a> service on Google cloud VMs

## Requirement
- Make sure GCP SDK is installed along with GCP Beta SDK (for linking projects with billing account)

## Config File (config.yml)
- Contains initial values for network, firewall, server name, client name, zone and scripts path.
  
  Modify the config file as you require.

## Operations performed in order
  1.	gcloud web authentication
  
  2.	Project creation/selection and then setting the current project to default configuration
  
  3.	API enabling – cloudresourcemanager and compute
  
  4.	VPC/Network creation 
  
  5.	Firewall opening for tcp,udp,icmp and tcp:22,tcp:3389 ports
  
  6.	Two VM creation along with startup script (metadata.sh) for library installation 
  
  7.	Waiting for startup scripts to finish on each VM

  8.	Server code Installation/Copying from local machine

  9.	Client code Installation/Copying from local machine
  
  10.	SSH into client and server VMs and unzipping code
  
  11.	Server startup 
  
  12.	Client testing – performs 4 client tests
  
  13.	Copying server and client logs from VM to local machine
  
  14.	VM Shutdown/Stopping

## Run Script
-	create.sh
-	cleanup.sh
    
    Resource cleanup – Deletes VM, Firewalls, and Network in that order

## Cost
- Virtual Machines
  -	n1-standard-1 (1 vCPU, 3.75 GB memory) => $0.04749975 per hour * 2
  
- Network
  -	Ingress	traffic	=> No charge for ingress traffic
  
  -	Egress to the same Google Cloud zone when using the internal IP addresses of the resources1	=> No charge

- Firewall 
  -	500 or fewer attributes in the policy (standard) => $1 per VM covered by the policy 
  
  There are two VMs which uses the firewall and hence it will cost $2 per month.

## VM Cost Estimator for the selected VMs
<img src="https://github.com/amolsangar/gcp-deployment-memcached-lite/blob/master/images/img1.jpg" alt='VM Cost'>
 
## Performance of key-value store when deployed to cloud VMs

All results can be found in the **output-logs folder** along with server logs after script execution

1.	100 simultaneous connections to server and closing them afterwards (CONNECTION TEST)
    
    Test 1 Execution Time: 61743.148051 milliseconds
    
    ----

2.	100 connections to server and each perform 1 write and then 1 read
    
    Test 2 Execution Time: 61758.51037199999 milliseconds
    
    ----

3.	1 client writes to 1 key every 0ms and another client reads from the same key every 0ms for 100 times (Performance + Concurrency test)
    
    Test 3 Execution Time: 2175.790368999995 milliseconds
    
    ----

4.	2 clients write to same key at the same time for 500 times (Concurrency test for DB and multiple requests from a single client test)
    
    Test 4 Execution Time: 4209.0177080000285 milliseconds
