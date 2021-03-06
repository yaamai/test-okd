## Setup NW
```
sudo iptables -P FORWARD ACCEPT
sudo iptables -t nat -I POSTROUTING -s 10.101.101.0/24 -j MASQUERADE
sudo ip link add br0 type bridge
sudo ip link set dev br0 up
```

## build infra container image
```
docker build vm/ -t localhost/yaamai/container-vm:latest
docker build pxe/ -t localhost/yaamai/container-vm-pxe:latest
```

## Launch PXE/LB infra containers
```
docker run --privileged --net host --rm -it -v $PWD/inst:/pxe/http/gen -v $PWD/pxeconf:/pxe/tftpboot/pxelinux.cfg -v $PWD/dnsmasq:/dnsmasq localhost/yaamai/container-vm-pxe:latest
docker run --name lb --rm --net host -it -v $PWD/lb:/usr/local/etc/haproxy:ro haproxy:2.5
```

## Launch workstation VM
```
$ docker run --rm --net host --name ws --hostname ws --privileged -it -v /dev/kvm:/dev/kvm -v $PWD:/work -w /work -e DATA_DIR_BASE=/work/vmdata -e VM_ASSIGN_PORTS=1 -e VM_BRIDGE=br0 -e BRIDGE_PXE=1 -e VM_MEMORY=1024 -e USERNET=0 localhost/yaamai/container-vm:latest bin/debian-11-generic-amd64.qcow2
```

## Start bootstrap OKD
###
```
sudo rm -r vmdata/{bootstrap,master0,master1,master2}
```

### prepare install-config.yaml
```
ws login: debian
Password:
Linux ws 5.10.0-13-amd64 #1 SMP Debian 5.10.106-1 (2022-03-17) x86_64
debian@ws:~$ ssh-keygen
Generating public/private rsa key pair.
Enter file in which to save the key (/home/debian/.ssh/id_rsa):
Enter passphrase (empty for no passphrase):
Enter same passphrase again:
Your identification has been saved in /home/debian/.ssh/id_rsa
Your public key has been saved in /home/debian/.ssh/id_rsa.pub
The key fingerprint is:
SHA256:YKhYR/OLJSxWO559PqIHtfTCLejLdr3UTpX3hbKrcao debian@ws
The key's randomart image is:
+---[RSA 3072]----+
|    +            |
|   + =           |
|  + B =          |
| + = Ooo     . . |
|. . +=o+S   + o .|
|    o =oo. . + ..|
|   . ..++ + o   .|
|   .o.oo.+ + .   |
|   .++  Eo+..    |
+----[SHA256]-----+
debian@ws:~$ vim /mnt/install-config.yaml
debian@ws:~$ cp /mnt/install-config.yaml /mnt/inst/
```

### generate manifests and ignition configs
```
debian@ws:~$ tar xf /mnt/bin/openshift-install-linux-4.10.0-0.okd-2022-03-07-131213.tar.gz
debian@ws:~$ ./openshift-install --dir /mnt/inst create manifests
INFO Consuming Install Config from target directory
WARNING Making control-plane schedulable by setting MastersSchedulable to true for Scheduler cluster settings
INFO Manifests created in: /mnt/inst/manifests and /mnt/inst/openshift
debian@ws:~$ ./openshift-install --dir /mnt/inst create ignition-configs
INFO Consuming Common Manifests from target directory
INFO Consuming Openshift Manifests from target directory
INFO Consuming Master Machines from target directory
INFO Consuming OpenShift Install (Manifests) from target directory
INFO Consuming Worker Machines from target directory
INFO Ignition-Configs created in: /mnt/inst and /mnt/inst/auth
```

### wait
```
debian@ws:~$ ./openshift-install --dir /mnt/inst wait-for bootstrap-complete
INFO Waiting up to 20m0s (until 1:37AM) for the Kubernetes API at https://api.test.example.com:6443...
```

## Launch Bootstrap and Master VMs
```
docker run --rm --net host --name bootstrap --hostname bootstrap --privileged -it -v /dev/kvm:/dev/kvm -v $PWD:/work -w /work -e DATA_DIR_BASE=/work/vmdata -e VM_ASSIGN_PORTS=1 -e VM_BRIDGE=br0 -e BRIDGE_PXE=1 -e VM_CPU=8 -e VM_MEMORY=8192 -e VM_USERNET=0 localhost/yaamai/container-vm:latest
docker run --rm --net host --name master0 --hostname master0 --privileged -it -v /dev/kvm:/dev/kvm -v $PWD:/work -w /work -e DATA_DIR_BASE=/work/vmdata -e VM_ASSIGN_PORTS=1 -e VM_BRIDGE=br0 -e BRIDGE_PXE=1 -e VM_CPU=8 -e VM_MEMORY=16384 -e VM_USERNET=0 localhost/yaamai/container-vm:latest
docker run --rm --net host --name master1 --hostname master1 --privileged -it -v /dev/kvm:/dev/kvm -v $PWD:/work -w /work -e DATA_DIR_BASE=/work/vmdata -e VM_ASSIGN_PORTS=1 -e VM_BRIDGE=br0 -e BRIDGE_PXE=1 -e VM_CPU=8 -e VM_MEMORY=16384 -e VM_USERNET=0 localhost/yaamai/container-vm:latest
docker run --rm --net host --name master2 --hostname master2 --privileged -it -v /dev/kvm:/dev/kvm -v $PWD:/work -w /work -e DATA_DIR_BASE=/work/vmdata -e VM_ASSIGN_PORTS=1 -e VM_BRIDGE=br0 -e BRIDGE_PXE=1 -e VM_CPU=8 -e VM_MEMORY=16384 -e VM_USERNET=0 localhost/yaamai/container-vm:latest
```

## check bootstrapping status
```
# prepare oc command
export KUBECONFIG=/mnt/inst/auth/kubeconfig
tar xf /mnt/bin/openshift-client-linux-4.10.0-0.okd-2022-03-07-131213.tar.gz

# check log
./oc adm node-logs --role=master -u kubelet
tail -f /mnt/inst/.openshift_install.log
ssh-keygen -R bootstrap
ssh core@bootstrap journalctl -b -f -u bootkube.service

./oc get nodes
./oc get nodes -o wide
# about 100 pods became Running status
./oc get pods -A | grep Runn | wc -l
```

## wait
```
debian@ws:~$ ./openshift-install --dir /mnt/inst wait-for bootstrap-complete --log-level debug
DEBUG OpenShift Installer 4.10.0-0.okd-2022-03-07-131213
DEBUG Built from commit 3b701903d96b6375f6c3852a02b4b70fea01d694
INFO Waiting up to 20m0s (until 9:02AM) for the Kubernetes API at https://api.test.example.com:6443...
DEBUG Still waiting for the Kubernetes API: Get "https://api.test.example.com:6443/version": net/http: TLS handshake timeout
INFO API v1.23.3-2003+e419edff267ffa-dirty up
INFO Waiting up to 30m0s (until 9:12AM) for bootstrapping to complete...
DEBUG Bootstrap status: complete
INFO It is now safe to remove the bootstrap resources
DEBUG Time elapsed per stage:
DEBUG Bootstrap Complete: 3m15s
DEBUG                API: 27s
INFO Time elapsed: 3m15s
```

## remove bootstrap node
```
$ sudo rm -r vmdata/bootstrap/                                                                                                                               
```

## check deploy result
```
debian@ws:~$ ./oc version
Client Version: 4.10.0-0.okd-2022-03-07-131213
Server Version: 4.10.0-0.okd-2022-03-07-131213
Kubernetes Version: v1.23.3-2003+e419edff267ffa-dirty

debian@ws:~$ ./oc get pods -A  -o wide
NAMESPACE                                          NAME                                                        READY   STATUS             RESTARTS        AGE     IP              NODE      NOMINATED NODE   READINESS GATES
openshift-apiserver-operator                       openshift-apiserver-operator-fbbcfffdb-qgdng                1/1     Running            2               25m     10.128.0.20     master1   <none>           <none>
openshift-apiserver                                apiserver-6b7bdd787f-2hdkd                                  2/2     Running            0               5m35s   10.130.0.43     master2   <none>           <none>
openshift-apiserver                                apiserver-6b7bdd787f-4lbmx                                  2/2     Running            0               12m     10.129.0.41     master0   <none>           <none>
openshift-apiserver                                apiserver-6b7bdd787f-mskb4                                  2/2     Running            0               9m7s    10.128.0.5      master1   <none>           <none>
openshift-authentication-operator                  authentication-operator-56585c6d7f-vbjjq                    1/1     Running            2               25m     10.128.0.15     master1   <none>           <none>
openshift-authentication                           oauth-openshift-67d7bdcc5c-l6dwr                            1/1     Running            0               3m5s    10.128.0.49     master1   <none>           <none>
openshift-authentication                           oauth-openshift-67d7bdcc5c-tjqtb                            0/1     Pending            0               26s     <none>          <none>    <none>           <none>
openshift-authentication                           oauth-openshift-6fc7c96dd4-lf5jx                            1/1     Terminating        0               12m     10.129.0.40     master0   <none>           <none>
openshift-authentication                           oauth-openshift-6fc7c96dd4-qkvzg                            1/1     Running            0               12m     10.130.0.36     master2   <none>           <none>
openshift-cloud-controller-manager-operator        cluster-cloud-controller-manager-operator-b6ccd5ff4-lw68n   2/2     Running            2               25m     10.101.101.49   master1   <none>           <none>
openshift-cloud-credential-operator                cloud-credential-operator-66699d5d4c-sqcll                  2/2     Running            2               25m     10.128.0.4      master1   <none>           <none>
openshift-cluster-machine-approver                 machine-approver-7f6ff596f8-q8z8l                           2/2     Running            2               25m     10.101.101.49   master1   <none>           <none>
openshift-cluster-node-tuning-operator             cluster-node-tuning-operator-6764cd7b84-js962               1/1     Running            1               25m     10.128.0.29     master1   <none>           <none>
openshift-cluster-node-tuning-operator             tuned-j2ps5                                                 1/1     Running            1               20m     10.101.101.49   master1   <none>           <none>
openshift-cluster-node-tuning-operator             tuned-qrjzw                                                 1/1     Running            0               20m     10.101.101.50   master2   <none>           <none>
openshift-cluster-node-tuning-operator             tuned-wgw6k                                                 1/1     Running            0               20m     10.101.101.48   master0   <none>           <none>
openshift-cluster-samples-operator                 cluster-samples-operator-5dbddd7dfc-r77p6                   2/2     Running            0               16m     10.130.0.24     master2   <none>           <none>
openshift-cluster-storage-operator                 cluster-storage-operator-75d44d7bcf-w858s                   1/1     Running            2               25m     10.128.0.23     master1   <none>           <none>
openshift-cluster-storage-operator                 csi-snapshot-controller-6b56df796f-6mj9x                    1/1     Running            1 (9m46s ago)   21m     10.129.0.3      master0   <none>           <none>
openshift-cluster-storage-operator                 csi-snapshot-controller-6b56df796f-vgq6s                    1/1     Running            0               21m     10.130.0.3      master2   <none>           <none>
openshift-cluster-storage-operator                 csi-snapshot-controller-operator-6b5776c58f-njltk           1/1     Running            1               25m     10.128.0.24     master1   <none>           <none>
openshift-cluster-storage-operator                 csi-snapshot-webhook-556df58965-lx4gg                       1/1     Running            0               21m     10.129.0.5      master0   <none>           <none>
openshift-cluster-storage-operator                 csi-snapshot-webhook-556df58965-pftdc                       1/1     Running            0               21m     10.130.0.5      master2   <none>           <none>
openshift-cluster-version                          cluster-version-operator-6f57fcb854-bvn92                   1/1     Running            1               25m     10.101.101.49   master1   <none>           <none>
openshift-config-operator                          openshift-config-operator-95d566bb9-s9x65                   1/1     Running            2               25m     10.128.0.35     master1   <none>           <none>
openshift-controller-manager-operator              openshift-controller-manager-operator-d9c574d99-d2q6r       1/1     Running            2               25m     10.128.0.41     master1   <none>           <none>
openshift-controller-manager                       controller-manager-7qjm6                                    1/1     Running            0               20m     10.129.0.14     master0   <none>           <none>
openshift-controller-manager                       controller-manager-tvmzg                                    1/1     Running            1               20m     10.128.0.18     master1   <none>           <none>
openshift-controller-manager                       controller-manager-vq2f7                                    1/1     Running            1 (9m36s ago)   20m     10.130.0.14     master2   <none>           <none>
openshift-dns-operator                             dns-operator-f57cc4d6f-59d96                                2/2     Running            2               25m     10.128.0.21     master1   <none>           <none>
openshift-dns                                      dns-default-c45nn                                           2/2     Running            0               20m     10.130.0.8      master2   <none>           <none>
openshift-dns                                      dns-default-rn8fj                                           2/2     Running            2               20m     10.128.0.16     master1   <none>           <none>
openshift-dns                                      dns-default-xv7nl                                           2/2     Running            0               20m     10.129.0.10     master0   <none>           <none>
openshift-dns                                      node-resolver-lm5pd                                         1/1     Running            0               20m     10.101.101.50   master2   <none>           <none>
openshift-dns                                      node-resolver-lv6d6                                         1/1     Running            0               20m     10.101.101.48   master0   <none>           <none>
openshift-dns                                      node-resolver-nhp28                                         1/1     Running            1               20m     10.101.101.49   master1   <none>           <none>
openshift-etcd-operator                            etcd-operator-7cdf659f76-j5m4x                              1/1     Running            2               25m     10.128.0.30     master1   <none>           <none>
openshift-etcd                                     etcd-master0                                                4/4     Running            0               14m     10.101.101.48   master0   <none>           <none>
openshift-etcd                                     etcd-master1                                                4/4     Running            0               2m4s    10.101.101.49   master1   <none>           <none>
openshift-etcd                                     etcd-master2                                                4/4     Running            0               8m38s   10.101.101.50   master2   <none>           <none>
openshift-etcd                                     etcd-quorum-guard-55c858456b-9bc2l                          1/1     Running            1               21m     10.101.101.49   master1   <none>           <none>
openshift-etcd                                     etcd-quorum-guard-55c858456b-wm4zt                          1/1     Running            0               21m     10.101.101.50   master2   <none>           <none>
openshift-etcd                                     etcd-quorum-guard-55c858456b-x5lxz                          1/1     Running            1               21m     10.101.101.49   master1   <none>           <none>
openshift-etcd                                     installer-2-master2                                         0/1     Completed          0               20m     10.130.0.9      master2   <none>           <none>
openshift-etcd                                     installer-4-master1                                         0/1     Completed          0               17m     10.128.0.48     master1   <none>           <none>
openshift-etcd                                     installer-6-master0                                         0/1     Completed          0               15m     10.129.0.33     master0   <none>           <none>
openshift-etcd                                     installer-7-master0                                         0/1     Completed          0               92s     10.129.0.46     master0   <none>           <none>
openshift-etcd                                     installer-7-master1                                         0/1     Completed          0               4m22s   10.128.0.46     master1   <none>           <none>
openshift-etcd                                     installer-7-master2                                         0/1     Completed          0               12m     10.130.0.35     master2   <none>           <none>
openshift-etcd                                     revision-pruner-7-master0                                   0/1     Completed          0               101s    10.129.0.47     master0   <none>           <none>
openshift-etcd                                     revision-pruner-7-master1                                   0/1     Completed          0               103s    10.128.0.48     master1   <none>           <none>
openshift-etcd                                     revision-pruner-7-master2                                   0/1     Completed          0               105s    10.130.0.46     master2   <none>           <none>
openshift-image-registry                           cluster-image-registry-operator-ddd96d697-4bbrb             1/1     Running            1               25m     10.128.0.40     master1   <none>           <none>
openshift-image-registry                           node-ca-4kv6g                                               1/1     Running            0               3m31s   10.101.101.48   master0   <none>           <none>
openshift-image-registry                           node-ca-g6pfm                                               1/1     Running            0               3m31s   10.101.101.50   master2   <none>           <none>
openshift-image-registry                           node-ca-z24m4                                               1/1     Running            0               3m31s   10.101.101.49   master1   <none>           <none>
openshift-ingress-canary                           ingress-canary-25npw                                        1/1     Running            0               11m     10.128.0.11     master1   <none>           <none>
openshift-ingress-canary                           ingress-canary-4zzbd                                        1/1     Running            0               11m     10.129.0.42     master0   <none>           <none>
openshift-ingress-canary                           ingress-canary-tssx6                                        1/1     Running            0               11m     10.130.0.37     master2   <none>           <none>
openshift-ingress-operator                         ingress-operator-848cb57596-khd8n                           2/2     Running            4               25m     10.128.0.28     master1   <none>           <none>
openshift-ingress                                  router-default-56df547f75-gsrxh                             1/1     Running            2 (14m ago)     20m     10.101.101.50   master2   <none>           <none>
openshift-ingress                                  router-default-56df547f75-n7b6s                             1/1     Running            2 (14m ago)     20m     10.101.101.48   master0   <none>           <none>
openshift-insights                                 insights-operator-6c98b65bd-k5d44                           1/1     Running            2               25m     10.128.0.10     master1   <none>           <none>
openshift-kube-apiserver-operator                  kube-apiserver-operator-c5b54866c-fn2mj                     1/1     Running            2               25m     10.128.0.7      master1   <none>           <none>
openshift-kube-apiserver                           installer-4-master0                                         0/1     Completed          0               19m     10.129.0.18     master0   <none>           <none>
openshift-kube-apiserver                           installer-5-master0                                         0/1     Completed          0               17m     10.129.0.24     master0   <none>           <none>
openshift-kube-apiserver                           installer-6-master0                                         0/1     Completed          0               15m     10.129.0.36     master0   <none>           <none>
openshift-kube-apiserver                           installer-7-master0                                         0/1     Completed          0               12m     10.129.0.39     master0   <none>           <none>
openshift-kube-apiserver                           installer-8-master2                                         1/1     Running            0               2m22s   10.130.0.45     master2   <none>           <none>
openshift-kube-apiserver                           kube-apiserver-guard-master0                                1/1     Running            0               18m     10.129.0.22     master0   <none>           <none>
openshift-kube-apiserver                           kube-apiserver-master0                                      5/5     Running            0               9m37s   10.101.101.48   master0   <none>           <none>
openshift-kube-apiserver                           revision-pruner-6-master0                                   0/1     Completed          0               15m     10.129.0.35     master0   <none>           <none>
openshift-kube-apiserver                           revision-pruner-6-master1                                   0/1     Completed          0               15m     10.128.0.53     master1   <none>           <none>
openshift-kube-apiserver                           revision-pruner-6-master2                                   0/1     Completed          0               15m     10.130.0.27     master2   <none>           <none>
openshift-kube-apiserver                           revision-pruner-7-master0                                   0/1     Completed          0               14m     10.129.0.38     master0   <none>           <none>
openshift-kube-apiserver                           revision-pruner-7-master1                                   0/1     Completed          0               14m     10.128.0.55     master1   <none>           <none>
openshift-kube-apiserver                           revision-pruner-7-master2                                   0/1     Completed          0               14m     10.130.0.31     master2   <none>           <none>
openshift-kube-apiserver                           revision-pruner-8-master0                                   0/1     Completed          0               2m43s   10.129.0.45     master0   <none>           <none>
openshift-kube-apiserver                           revision-pruner-8-master1                                   0/1     Completed          0               2m35s   10.128.0.47     master1   <none>           <none>
openshift-kube-apiserver                           revision-pruner-8-master2                                   0/1     Completed          0               2m39s   10.130.0.44     master2   <none>           <none>
openshift-kube-controller-manager-operator         kube-controller-manager-operator-57bc446b77-qp7fr           1/1     Running            2               25m     10.128.0.31     master1   <none>           <none>
openshift-kube-controller-manager                  installer-4-master2                                         0/1     Completed          0               19m     10.130.0.16     master2   <none>           <none>
openshift-kube-controller-manager                  installer-5-master0                                         0/1     Completed          0               15m     10.129.0.31     master0   <none>           <none>
openshift-kube-controller-manager                  installer-5-master1                                         0/1     Completed          0               17m     10.128.0.49     master1   <none>           <none>
openshift-kube-controller-manager                  installer-5-master2                                         0/1     Completed          0               14m     10.130.0.30     master2   <none>           <none>
openshift-kube-controller-manager                  installer-6-master1                                         1/1     Running            0               79s     10.128.0.50     master1   <none>           <none>
openshift-kube-controller-manager                  installer-6-master2                                         0/1     Completed          0               3m25s   10.130.0.42     master2   <none>           <none>
openshift-kube-controller-manager                  kube-controller-manager-guard-master0                       1/1     Running            0               15m     10.129.0.37     master0   <none>           <none>
openshift-kube-controller-manager                  kube-controller-manager-guard-master1                       1/1     Running            1               16m     10.128.0.8      master1   <none>           <none>
openshift-kube-controller-manager                  kube-controller-manager-guard-master2                       1/1     Running            0               18m     10.130.0.20     master2   <none>           <none>
openshift-kube-controller-manager                  kube-controller-manager-master0                             4/4     Running            6 (74s ago)     15m     10.101.101.48   master0   <none>           <none>
openshift-kube-controller-manager                  kube-controller-manager-master1                             4/4     Running            6 (37s ago)     16m     10.101.101.49   master1   <none>           <none>
openshift-kube-controller-manager                  kube-controller-manager-master2                             4/4     Running            1 (98s ago)     2m34s   10.101.101.50   master2   <none>           <none>
openshift-kube-scheduler-operator                  openshift-kube-scheduler-operator-67cbb8d86f-hrgjk          1/1     Running            2               25m     10.128.0.6      master1   <none>           <none>
openshift-kube-scheduler                           installer-6-master1                                         0/1     Completed          0               20m     10.128.0.36     master1   <none>           <none>
openshift-kube-scheduler                           installer-7-master0                                         0/1     Completed          0               17m     10.129.0.26     master0   <none>           <none>
openshift-kube-scheduler                           installer-7-master1                                         0/1     Completed          1               12m     10.128.0.13     master1   <none>           <none>
openshift-kube-scheduler                           installer-7-master2                                         0/1     Completed          0               15m     10.130.0.26     master2   <none>           <none>
openshift-kube-scheduler                           openshift-kube-scheduler-guard-master0                      1/1     Running            0               16m     10.129.0.28     master0   <none>           <none>
openshift-kube-scheduler                           openshift-kube-scheduler-guard-master1                      1/1     Running            1               19m     10.128.0.12     master1   <none>           <none>
openshift-kube-scheduler                           openshift-kube-scheduler-guard-master2                      1/1     Running            0               14m     10.130.0.29     master2   <none>           <none>
openshift-kube-scheduler                           openshift-kube-scheduler-master0                            3/3     Running            1 (9m35s ago)   16m     10.101.101.48   master0   <none>           <none>
openshift-kube-scheduler                           openshift-kube-scheduler-master1                            3/3     Running            0               4m47s   10.101.101.49   master1   <none>           <none>
openshift-kube-scheduler                           openshift-kube-scheduler-master2                            3/3     Running            1 (4m55s ago)   14m     10.101.101.50   master2   <none>           <none>
openshift-kube-scheduler                           revision-pruner-6-master0                                   0/1     Completed          0               20m     10.129.0.15     master0   <none>           <none>
openshift-kube-scheduler                           revision-pruner-6-master1                                   0/1     Completed          0               20m     10.128.0.34     master1   <none>           <none>
openshift-kube-scheduler                           revision-pruner-6-master2                                   0/1     Completed          0               19m     10.130.0.15     master2   <none>           <none>
openshift-kube-scheduler                           revision-pruner-7-master0                                   0/1     Completed          0               17m     10.129.0.25     master0   <none>           <none>
openshift-kube-scheduler                           revision-pruner-7-master1                                   0/1     Completed          0               17m     10.128.0.47     master1   <none>           <none>
openshift-kube-scheduler                           revision-pruner-7-master2                                   0/1     Completed          0               17m     10.130.0.22     master2   <none>           <none>
openshift-kube-storage-version-migrator-operator   kube-storage-version-migrator-operator-85c88fcbcd-qjmg8     1/1     Running            2               25m     10.128.0.34     master1   <none>           <none>
openshift-kube-storage-version-migrator            migrator-85976b4574-4fjm9                                   1/1     Running            0               21m     10.129.0.4      master0   <none>           <none>
openshift-machine-api                              cluster-autoscaler-operator-6c6ffd9948-2nv59                2/2     Running            2               25m     10.128.0.17     master1   <none>           <none>
openshift-machine-api                              cluster-baremetal-operator-76fd6798b6-pz256                 2/2     Running            2               25m     10.128.0.26     master1   <none>           <none>
openshift-machine-api                              machine-api-operator-74f4fbdcc9-zp5s9                       2/2     Running            2               24m     10.128.0.27     master1   <none>           <none>
openshift-machine-config-operator                  machine-config-controller-bbc954c9c-xfwnv                   1/1     Running            1 (9m46s ago)   20m     10.129.0.8      master0   <none>           <none>
openshift-machine-config-operator                  machine-config-daemon-ksc8v                                 2/2     Running            0               23m     10.101.101.50   master2   <none>           <none>
openshift-machine-config-operator                  machine-config-daemon-kttb8                                 2/2     Running            0               23m     10.101.101.48   master0   <none>           <none>
openshift-machine-config-operator                  machine-config-daemon-rtjkq                                 2/2     Running            2               23m     10.101.101.49   master1   <none>           <none>
openshift-machine-config-operator                  machine-config-operator-9c6d9dd78-jxdz6                     1/1     Running            1               25m     10.128.0.33     master1   <none>           <none>
openshift-machine-config-operator                  machine-config-server-57zfg                                 1/1     Running            1               20m     10.101.101.49   master1   <none>           <none>
openshift-machine-config-operator                  machine-config-server-hlr69                                 1/1     Running            0               20m     10.101.101.50   master2   <none>           <none>
openshift-machine-config-operator                  machine-config-server-xtlgb                                 1/1     Running            0               20m     10.101.101.48   master0   <none>           <none>
openshift-marketplace                              community-operators-6dt7c                                   1/1     Running            0               18m     10.129.0.20     master0   <none>           <none>
openshift-marketplace                              marketplace-operator-7d44654db-gnph2                        1/1     Running            3               25m     10.128.0.25     master1   <none>           <none>
openshift-monitoring                               alertmanager-main-0                                         5/6     CrashLoopBackOff   5 (73s ago)     5m44s   10.130.0.39     master2   <none>           <none>
openshift-monitoring                               alertmanager-main-1                                         5/6     CrashLoopBackOff   4 (53s ago)     5m44s   10.128.0.43     master1   <none>           <none>
openshift-monitoring                               cluster-monitoring-operator-7f57cd7fb-jmvrx                 2/2     Running            2               25m     10.128.0.9      master1   <none>           <none>
openshift-monitoring                               grafana-6cd855f567-5qbff                                    3/3     Running            0               5m43s   10.130.0.40     master2   <none>           <none>
openshift-monitoring                               kube-state-metrics-7dd5fcf48b-7dfvx                         3/3     Running            0               20m     10.129.0.13     master0   <none>           <none>
openshift-monitoring                               node-exporter-2dznl                                         2/2     Running            0               20m     10.101.101.50   master2   <none>           <none>
openshift-monitoring                               node-exporter-rl89r                                         2/2     Running            0               20m     10.101.101.48   master0   <none>           <none>
openshift-monitoring                               node-exporter-wcfc8                                         2/2     Running            2               20m     10.101.101.49   master1   <none>           <none>
openshift-monitoring                               openshift-state-metrics-57c84995c9-p5cxv                    3/3     Running            0               20m     10.129.0.12     master0   <none>           <none>
openshift-monitoring                               prometheus-adapter-fb86f49f4-67b4l                          1/1     Running            0               5m50s   10.129.0.44     master0   <none>           <none>
openshift-monitoring                               prometheus-adapter-fb86f49f4-ftk6p                          1/1     Running            0               5m50s   10.128.0.42     master1   <none>           <none>
openshift-monitoring                               prometheus-k8s-0                                            6/6     Running            0               5m39s   10.130.0.41     master2   <none>           <none>
openshift-monitoring                               prometheus-k8s-1                                            6/6     Running            0               5m39s   10.128.0.45     master1   <none>           <none>
openshift-monitoring                               prometheus-operator-674f47f9f6-qbdxf                        2/2     Running            0               20m     10.129.0.7      master0   <none>           <none>
openshift-monitoring                               thanos-querier-7d5bc97b4b-8p8qg                             6/6     Running            0               5m47s   10.130.0.38     master2   <none>           <none>
openshift-monitoring                               thanos-querier-7d5bc97b4b-rt7pp                             6/6     Running            0               5m47s   10.128.0.44     master1   <none>           <none>
openshift-multus                                   multus-4sf5b                                                1/1     Running            1               24m     10.101.101.49   master1   <none>           <none>
openshift-multus                                   multus-additional-cni-plugins-f6t5r                         1/1     Running            0               24m     10.101.101.48   master0   <none>           <none>
openshift-multus                                   multus-additional-cni-plugins-w76bt                         1/1     Running            0               23m     10.101.101.50   master2   <none>           <none>
openshift-multus                                   multus-additional-cni-plugins-x8sbx                         1/1     Running            1               24m     10.101.101.49   master1   <none>           <none>
openshift-multus                                   multus-admission-controller-6kz8h                           2/2     Running            0               22m     10.130.0.11     master2   <none>           <none>
openshift-multus                                   multus-admission-controller-f2jd4                           2/2     Running            0               23m     10.129.0.6      master0   <none>           <none>
openshift-multus                                   multus-admission-controller-l5w4h                           2/2     Running            2               23m     10.128.0.36     master1   <none>           <none>
openshift-multus                                   multus-c49zf                                                1/1     Running            0               24m     10.101.101.48   master0   <none>           <none>
openshift-multus                                   multus-mkdtr                                                1/1     Running            0               23m     10.101.101.50   master2   <none>           <none>
openshift-multus                                   network-metrics-daemon-7xv4p                                2/2     Running            0               24m     10.129.0.16     master0   <none>           <none>
openshift-multus                                   network-metrics-daemon-866gn                                2/2     Running            2               24m     10.128.0.38     master1   <none>           <none>
openshift-multus                                   network-metrics-daemon-m92r4                                2/2     Running            0               23m     10.130.0.17     master2   <none>           <none>
openshift-network-diagnostics                      network-check-source-74645d55dd-k5b2d                       1/1     Running            0               23m     10.130.0.18     master2   <none>           <none>
openshift-network-diagnostics                      network-check-target-dscv4                                  1/1     Running            1               23m     10.128.0.3      master1   <none>           <none>
openshift-network-diagnostics                      network-check-target-q98bk                                  1/1     Running            0               23m     10.129.0.2      master0   <none>           <none>
openshift-network-diagnostics                      network-check-target-z427j                                  1/1     Running            0               23m     10.130.0.2      master2   <none>           <none>
openshift-network-operator                         network-operator-686ffb9ff7-bhg58                           1/1     Running            0               25m     10.101.101.48   master0   <none>           <none>
openshift-oauth-apiserver                          apiserver-d647585fd-6c82z                                   1/1     Running            0               12m     10.128.0.2      master1   <none>           <none>
openshift-oauth-apiserver                          apiserver-d647585fd-p6lww                                   1/1     Running            3 (9m47s ago)   14m     10.130.0.32     master2   <none>           <none>
openshift-oauth-apiserver                          apiserver-d647585fd-xcnmg                                   1/1     Running            0               5m30s   10.129.0.48     master0   <none>           <none>
openshift-operator-lifecycle-manager               catalog-operator-8567dd948-bkfrt                            1/1     Running            1               25m     10.128.0.14     master1   <none>           <none>
openshift-operator-lifecycle-manager               collect-profiles-27488685-bnxsm                             0/1     Completed          0               14m     10.130.0.33     master2   <none>           <none>
openshift-operator-lifecycle-manager               collect-profiles-27488700-nxvjv                             1/1     Running            0               5s      10.130.0.47     master2   <none>           <none>
openshift-operator-lifecycle-manager               olm-operator-5664cc68b5-zvptf                               1/1     Running            1               25m     10.128.0.39     master1   <none>           <none>
openshift-operator-lifecycle-manager               package-server-manager-54bf5b8858-84psl                     1/1     Running            3               25m     10.128.0.19     master1   <none>           <none>
openshift-operator-lifecycle-manager               packageserver-6f7dd5999c-bxhqs                              1/1     Running            0               20m     10.130.0.6      master2   <none>           <none>
openshift-operator-lifecycle-manager               packageserver-6f7dd5999c-kf4kg                              1/1     Running            1               20m     10.128.0.37     master1   <none>           <none>
openshift-sdn                                      sdn-controller-d6wpx                                        2/2     Running            0               23m     10.101.101.50   master2   <none>           <none>
openshift-sdn                                      sdn-controller-grcpp                                        2/2     Running            2               23m     10.101.101.49   master1   <none>           <none>
openshift-sdn                                      sdn-controller-whpv5                                        2/2     Running            0               23m     10.101.101.48   master0   <none>           <none>
openshift-sdn                                      sdn-fjskv                                                   2/2     Running            0               23m     10.101.101.50   master2   <none>           <none>
openshift-sdn                                      sdn-hwpzj                                                   2/2     Running            0               23m     10.101.101.48   master0   <none>           <none>
openshift-sdn                                      sdn-lvbnn                                                   2/2     Running            2               23m     10.101.101.49   master1   <none>           <none>
openshift-service-ca-operator                      service-ca-operator-786d5f85ff-kghr8                        1/1     Running            2               25m     10.128.0.32     master1   <none>           <none>
openshift-service-ca                               service-ca-54b4cf6549-p7bw8                                 1/1     Running            1 (9m46s ago)   21m     10.130.0.4      master2   <none>           <none>
```

```
Apr 07 17:47:28 server kernel: Out of memory: Killed process 9925 (qemu-system-x86) total-vm:17625176kB, anon-rss:8433680kB, file-rss:0kB, shmem-rss:0kB, UID:0 pgtables:2585>
```
