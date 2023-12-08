#!/bin/bash
#kubectl get node -l app=db --show-labels=true && \
#kubectl get node -l app=was --show-labels=true && \
kubectl get all -n assignment -o wide && \
kubectl describe ing -n assignment