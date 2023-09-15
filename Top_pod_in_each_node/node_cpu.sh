#!/bin/bash

node_list=$(kubectl get node -o=jsonpath={.items[*].metadata.name})
echo $node_list
for i in $node_list; do
    echo "################# $i #################"
    pod_name=$(kubectl get pod -A -o=jsonpath='{.items[?(@.spec.nodeName=="'$i'")].metadata.name}' | sed 's/ /\\|/g')
    kubectl top pod -A --sort-by=cpu | grep $pod_name
    echo ""
done