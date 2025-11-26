#!/bin/bash
install-kube-ovn() {
    # Install kube-ovn with Helm
    kubectl label node -lbeta.kubernetes.io/os=linux kubernetes.io/os=linux --overwrite
    kubectl label node -lnode-role.kubernetes.io/control-plane kube-ovn/role=master --overwrite

    helm upgrade --install kube-ovn oci://ghcr.io/kubeovn/charts/kube-ovn-v2 \
    --version v1.14.15 \
    --timeout 15m \
    --set ovsOvn.disableModulesManagement=true \
    --set networking.services.cidr.v4="10.100.0.0/16" \
    --set pinger.targets.externalAddresses.v4="8.8.8.8" \
    --set pinger.targets.externalDomain.v4="google.com." \
    --install
    -n kube-system 
}

install-kubevirt() {
    export VERSION=$(curl -s https://storage.googleapis.com/kubevirt-prow/release/kubevirt/kubevirt/stable.txt)
    echo $VERSION

    # Install operator
    kubectl create -f "https://github.com/kubevirt/kubevirt/releases/download/${VERSION}/kubevirt-operator.yaml"
    # Install CRDs
    kubectl create -f "https://github.com/kubevirt/kubevirt/releases/download/${VERSION}/kubevirt-cr.yaml"
    # Install CDI
    export VERSION=$(basename $(curl -s -w %{redirect_url} https://github.com/kubevirt/containerized-data-importer/releases/latest))
    kubectl create -f https://github.com/kubevirt/containerized-data-importer/releases/download/$VERSION/cdi-operator.yaml
    kubectl create -f https://github.com/kubevirt/containerized-data-importer/releases/download/$VERSION/cdi-cr.yaml
}


# Install multus
kubectl apply -f https://raw.githubusercontent.com/k8snetworkplumbingwg/multus-cni/master/deployments/multus-daemonset-thick.yml

install-kube-ovn
install-kubevirt
sleep 180
kubectl apply -f ./manifest.yaml