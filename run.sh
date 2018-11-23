#!/usr/bin/env bash
docker build -t chinthaka316/k8-jvisualvm-poc:latest .
docker login --username=chinthaka316
docker push chinthaka316/k8-jvisualvm-poc:latest
kubectl apply -f ./Deployment.yaml
sleep 10
kubectl port-forward $(kubectl get pods -n default|grep k8-jvisualvm-poc|awk '{print $1}') 9999:9999