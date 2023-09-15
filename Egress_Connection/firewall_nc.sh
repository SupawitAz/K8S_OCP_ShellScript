#/bin/bash
# usage ./firewall_nc.sh <egress_ip> <namespace>
# don't forget to fill in destination ip & port into "ipadress_destination.txt" file

# namespace="tcrb-infra-utility"
deployment_name="nc"
egress_ip=$1
namespace=$2

echo patch egress ip $egress_ip to namespace $namespace
if [ -z "$1" ] || [ -z "$2" ]
then
  echo "usage ./firewall_nc.sh <egress_ip> <namespace>"
  echo "do not forget to fill in destination ip & port into 'ipadress_destination.txt' file"
  exit 0
fi

eval pod_name=$(oc get pod -l app=nc-egress -n $namespace -o=jsonpath='{.items[*].metadata.name}')

if [ -z "$pod_name" ]
then
cat << EOF | kubectl apply -f -
  apiVersion: apps/v1
  kind: Deployment
  metadata:
    name: nc-test-egress
    namespace: $namespace
  spec:
    replicas: 1
    selector:
      matchLabels:
        app: nc-egress
    template:
      metadata:
        labels:
          app: nc-egress
      spec:
        containers:
        - name: c1
          image: 'mir.npd.ocp.tcbank.local:8443/library/alpine:latest'
          args:
          - sleep
          - "3600"
EOF
  oc wait deploy --for=condition=Available=True nc-test-egress -n $namespace
fi

eval namespace_own_egress=$(oc get netnamespace -o=jsonpath='{.items[?(@.egressIPs[*]=="'${egress_ip}'")].metadata.name}')
if [ -z "$namespace_own_egress" ]
then
  echo There are not any project use egressIP: $egress_ip
else
  echo There is $namespace_own_egress use egressIP: $egress_ip
  oc get netnamespace -o=jsonpath='{range .items[?(@.egressIPs[*]=="'${egress_ip}'")]}{.metadata.name},{.egressIPs[*]}{end}' | column -t -s "," -N NAME,EGRESS_IP
  oc patch netnamespace $namespace_own_egress --type=merge -p '{"egressIPs": null}'
fi

oc patch netnamespace $namespace --type=merge -p '{"egressIPs": ["'${egress_ip}'"]}'

echo After patch egress netnamespace to $namespace
oc get netnamespace -o=jsonpath='{range .items[?(@.egressIPs[*]=="'${egress_ip}'")]}{.metadata.name},{.egressIPs[*]}{end}' | column -t -s "," -N NAME,EGRESS_IP
echo =====================================================
ip_address=$(awk '{print $1}' ipadress_destination.txt)
port=$(awk '{print $2}' ipadress_destination.txt)
line_number=$(awk '$1!="" {print NR,$0}' ipadress_destination.txt | wc -l)
line_number=$(( $line_number-1 ))
ipaddress_arr=($ip_address)
port_arr=($port)
eval pod_name=$(oc get pod -l app=nc-egress -n $namespace -o=jsonpath='{.items[*].metadata.name}')
#pod_name="nc-b95c5d7f4-4rsvx"
echo $pod_name
for i in $(seq 0 $line_number);do
   if [ ${ipaddress_arr[$i]:0:1} != \# ]
   then
     echo connect to ${ipaddress_arr[$i]}:${port_arr[$i]}
     oc exec -it $pod_name -n $namespace -- timeout 10 nc -vvvz ${ipaddress_arr[$i]} ${port_arr[$i]}
     echo =====================================================
   fi
done

sleep 5

oc delete deployment -n $namespace nc-test-egress
oc delete pod -n $namespace $pod_name --force
echo =====================================================
oc patch netnamespace $namespace --type=merge -p '{"egressIPs": null}'
if [ -z "$namespace_own_egress" ]
then
  echo Test completed
else
  echo Patch egressIP: $egress_ip to namespace: $namespace_own_egress
  oc patch netnamespace $namespace_own_egress --type=merge -p '{"egressIPs": ["'${egress_ip}'"]}'
  oc get netnamespace -o=jsonpath='{range .items[?(@.egressIPs[*]=="'${egress_ip}'")]}{.metadata.name},{.egressIPs[*]}{end}' | column -t -s "," -N NAME,EGRESS_IP
  echo Test completed
fi
