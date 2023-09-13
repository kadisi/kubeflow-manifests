#!/bin/bash

function apply_manifest() {
    while ! cat kubeflow.yaml | kubectl apply -f -; do 
        echo "Retrying to apply resources"
        sleep 10
    done
}

function get_istio_ingressgateway_lb_address() {
    local ipaddress
    ipaddress=$(kubectl get svc -n istio-system istio-ingressgateway -ojsonpath='{.status.loadBalancer.ingress[0].ip}')
    if [[ $ipaddress == *.*.*.* ]]; then
        echo $ipaddress
    else
        echo ""
    fi
}

function create_cert_manager_certificate() {

    local lbaddress 
    
    while true
    do
        lbaddress=$(kubectl get svc -n istio-system istio-ingressgateway -ojsonpath='{.status.loadBalancer.ingress[0].ip}')
        if [[ $lbaddress == *.*.*.* ]]; then
            echo "get istio-ingressgateway lb address $lbaddress"
            break
        fi

        echo "wait istio ingressgateway lb created..."
        sleep 2
    done

kubectl apply -f - <<EOF

apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: istio-ingressgateway-certs
  namespace: istio-system
spec:
  commonName: istio-ingressgateway.istio-system.svc
  # Use ipAddresses if your LoadBalancer issues an IP
  ipAddresses:
  - ${lbaddress} 
  isCA: true
  issuerRef:
    kind: ClusterIssuer
    name: kubeflow-self-signing-issuer
  secretName: istio-ingressgateway-certs

EOF
}

function re_scale_istio-ingressgateway(){

    kubectl scale deploy -n istio-system istio-ingressgateway --replicas 0
    kubectl scale deploy -n istio-system istio-ingressgateway --replicas 1 
    sleep 5
}

function wait_pods_ready() {
    while true
    do
        notrunningpods=$(kubectl get pod -A |grep -E 'kubeflow|kubeflow-user-example-com|knative-serving|istio-system|auth|cert-manager' |grep -v 'Running')
        if [ -z $notrunningpods ]; then
            break
        fi
        echo "======== waiting pod ready ========"
        echo $notrunningpods
        sleep 2
    done
}

apply_manifest

create_cert_manager_certificate

re_scale_istio-ingressgateway

wait_pods_ready

echo "create kubeflow success ... ..."
