#!/bin/bash

echo "Please enter your Gmail account";
read username;

echo "Please enter your Gmail password";
read -s password;

echo "Creating secret"
kubectl create secret generic smtp-account -n monitoring --from-literal=username=${username} --from-literal=password=${password}
