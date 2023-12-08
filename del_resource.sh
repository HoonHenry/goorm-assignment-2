 #!/bin/bash                                                                                                                                      
#nodes=$(kubectl get node -o name | head -n 2)
#
#kubectl delete ns assignment && \
#for node in $nodes; do
#    kubectl label $node app-
#done

kubectl delete ns assignment