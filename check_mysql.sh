 #!/bin/bash
podId=$(kubectl get pod -n assignment | grep mysql | awk '{printf $1}')

kubectl exec -it $podId -n assignment -- mysql -u root -p
