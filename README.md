# goorm-assignment-2
This branch is just for a local machine with minikube

# Settings for Mac OS(Sonoma 14.1.2, Intel x86_64)
```
brew install minikube
minikube start --nodes=3
minikube addons enalbe ingress
chmod 744 ./run.sh
./run.sh
minikube tunnel
```

Check the following link for the installation: https://minikube.sigs.k8s.io/docs/start/
