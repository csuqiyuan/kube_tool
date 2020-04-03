#!/bin/bash

source kube_tool.sh

install_kubernetes

kubeadm join 192.168.159.12:6443 --token uib20o.ggdi24n8k9gym1wc \
    --discovery-token-ca-cert-hash sha256:7c2a02da74110dd7b7c068d53da2c716723d2d2bc02e20eaea8580abefb456d7