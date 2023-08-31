#!/bin/sh
kubectl create secret generic --namespace first-application --from-literal=url=redis://redis-master:6379 redis-secret 
