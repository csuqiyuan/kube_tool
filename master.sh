#!/bin/bash
source kube_tool.sh

install_kubernetes

kubeadm init --ignore-preflight-errors=Swap

# 需要使用普通用户运行
mkdir -p /home/qiyuanfeng/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config