#!/bin/bash
kubectl get all -n assignment -o wide && kubectl get ing -n assignment -o wide && kubectl get secret -n assignment && kubectl get pvc,pv -n assignment
