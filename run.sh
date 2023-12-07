#!/bin/bash
kubectl create ns assignment && kubectl apply -k ./ #&& minikube tunnel
