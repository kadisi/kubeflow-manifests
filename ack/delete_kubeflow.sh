#!/bin/bash

function delete() {
    cat kubeflow.yaml | kubectl delete -f -
    kubectl delete ns kubeflow-user-example-com

    kubectl get ns |grep "Terminating"

    while kubectl get ns |grep "Terminating"; do
        echo "Retrying to wait Terminating namespace deleted"
        sleep 5 
    done

}

delete

