# goorm-assignment-2
This bransh is for Google Kubernete Engine.

## Prerequisites
```
# install ingress-nginx-controller
# ref: https://kubernetes.github.io/ingress-nginx/deploy/#gce-gke

kubectl create clusterrolebinding cluster-admin-binding \
   --clusterrole cluster-admin \
   --user $(gcloud config get-value account)

kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.2/deploy/static/provider/cloud/deploy.yaml
```

## set up a cluster
```
./run.sh
```
