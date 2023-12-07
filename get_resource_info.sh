#!/bin/bash
kubectl get all -n assignment -o wide && kubectl get ing -n assignment -o wide
