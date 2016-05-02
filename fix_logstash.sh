#/bin/bash

#usage info
show_help() {
cat << EOF
Usage: ${0##*/} [-h] [ -H ] [-r AWS_REGION ] [-l LOAD_BALANCER_NAME ] ...
-h display this help and exit
-r AWS region default: us-west-1
-H hard reboot instances
-l load balancer name default: prod-logstash
EOF
}

#set defaults
region="us-west-1"
hard_reboot='no'
load_balancer="prod-logstash"

#while getopts ':h:l:r:b:' opt; do
while getopts "hHr:l:" opt; do
    case "$opt" in
        h)
            show_help
            exit 1
            ;;
        H)
            hard_reboot='yes'
            ;;
        r)
            region=${OPTARG}
            region=${region}
            ;;
        l)
            load_balancer=${OPTARG}
            ;;
       \?)
            show_help
            exit 1
            ;;
    esac
done

unhealthy_instances=$(aws elb describe-instance-health --load-balancer-name $load_balancer --region $region | jq '.InstanceStates[]|select (.State == "OutOfService") | .InstanceId'|tr -d '"'|tr '\n' ' ');

#bail if all is good
if [ -z "$unhealthy_instances" ]; then
    echo "No unhealthy instances found" 
    exit 0
fi

unhealthy_instance_ips=$(aws ec2 describe-instances --instance-ids $unhealthy_instances --region $region | jq '.Reservations[]|.Instances[] | .PrivateIpAddress'| tr -d '"' | tr '\n' ',');

if [ $hard_reboot == 'yes' ]; then
  echo "Rebooting unhealthy instances"
  aws ec2 reboot-instances --region $region --instance-ids $unhealthy_instances
  exit 0
else
 echo "Restarting logstash on unhealthy instances."
 ansible -i "$unhealthy_instance_ips" all -m shell -a "sudo sync && sudo bash -cl \"echo 1 > /proc/sys/vm/drop_caches\" && sudo service logstash restart" 
 exit 0
fi
