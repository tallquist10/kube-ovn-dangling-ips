# Kube OVN Dangling IPs Sample

This repo sets up a small environment using kube-ovn, multus, and kubevirt to simulate an issue we're seeing in kube-ovn. This issue involves IPs not being deleted when the surrounding resources for it, namely its subnet, are removed. 

## Steps for Reproduction
1. Run `install.sh`. Note that there is a 3 minute sleep period between installing the dependencies/CRDs and applying the manifest.
1. Ensure that the controllers for kube-ovn and kubevirt are running, and ensure that the VM has all three replicas running.
1. Run `kubectl get ip` and `kubectl get subnet`. You should find the `kube-ovn-dangling-ips-control-net` subnet and the `test-vm-1.kube-ovn-dangling-ips.kube-ovn-dangling-ips-control-net.kube-ovn-dangling-ips.ovn` subnet.
1. In a separate window, run `kubectl logs -l app=kube-ovn-controller -f -n kube-system`, assuming that the kube-ovn controllers are running in the `kube-system` namespace.
1. Once all three replicas are running, run `kubectl delete -f manifest.yaml`.
1. By running `kubectl get ip` and `kubectl get subnet`, you should see the subnet is now gone, but the IP is still there.
1. With the kube-ovn-controller logs still tailing, run `kubectl delete ip test-vm-1.kube-ovn-dangling-ips.kube-ovn-dangling-ips-control-net.kube-ovn-dangling-ips.ovn`. You'll notice that there are a bunch of failures in kube-ovn-controller because it can't find the subnet.

## Theory of the Root Cause

In the [`handleDeleteSubnet`](https://github.com/kubeovn/kube-ovn/blob/b31418851ec95e89d1e39f2b37c960ec23be75aa/pkg/controller/subnet.go#L973-L1053) function, the only check related to IPs is seeing if an IP exists that fits the u2oInterconn pattern (`u2o-interconnection.{vpc}.{subnet}`). So long as an IP matching that specific format doesn't exist, and all other criteria are met, the subnet will be deleted. That said, when handling deletion of an IP in the [`handleUpdateIP`](https://github.com/kubeovn/kube-ovn/blob/v1.14.15/pkg/controller/ip.go#L235-L276) function, if the subnet does not exist, the function will fail and not delete the IP. From my understanding, this is because it needs to ensure that the other resources (LSP, IPAM pod key, etc.) also need to be correctly updated, and many of these things rely on the subnet.

The problem with this is that since the it is very easy to delete subnets, we are consistently finding that IP resources are being left dangling (sometimes referred to as orphaned) and unable to be deleted, since the subnet is gone before the IP undergoes the deletion process.