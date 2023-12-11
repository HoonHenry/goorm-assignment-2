#!/bin/bash
#nodes=$(kubectl get node -o name | head -n 2)
#
#i=1
#for node in $nodes; do
#    if [ "$i" -eq 1 ]; then
#        kubectl label $node app=db
#    else
#        kubectl label $node app=was
#    fi
#    i=$((i + 1))
#done

sed -i.bak -e "s|your-ingress-group-name|$CLUSTER_NAME|" ./wordpress-deployment.yaml && \
kubectl create ns assignment && \
kubectl apply -k ./