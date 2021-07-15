


kubectl apply -f nginx.yaml

kubectl describe deployment sensus-nginx-deployment

kubectl expose deployment sensus-nginx-deployment --port=80 --type=LoadBalancer

# undo the above