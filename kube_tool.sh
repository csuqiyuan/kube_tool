#!/bin/bash

set -x

function set_env(){
	# root user
	systemctl disable firewalld
	systemctl stop firewalld
	setenforce 0
	# reboot

	# centos
	if [[ -e /etc/yum.repos.d/kubernetes.repo ]]; then
		rm -f /etc/yum.repos.d/kubernetes.repo
	fi

	install_docker

	echo -e "[kubernetes]\nname=Kubernetes Repository\nbaseurl=https://mirrors.aliyun.com/kubernetes/yum/repos/kubernetes-el7-x86_64/\nenbled=1\ngpgcheck=0" >> /etc/yum.repos.d/kubernetes.repo

	# running with swap on is not supported. Please disable swap
	echo "KUBELET_EXTRA_ARGS=--fail-swap-on=false" > /etc/sysconfig/kubelet
}

function install_docker(){
	yum remove -y docker docker-client docker-client-latest docker-common docker-latest docker-latest-logrotate docker-logrotate docker-engine
    yum install -y yum-utils device-mapper-persistent-data lvm2
    yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
    yum update -y
    yum install -y docker-ce
    # 更改 docker 镜像仓库
    if [[ -e /etc/docker/daemon.json ]]; then
    	rm -f /etc/docker/daemon.json
	fi
	touch /etc/docker/daemon.json
    # echo -e "{\n\t\"registry-mirrors\": [\"https://registry.docker-cn.com\"]\n}" >> /etc/docker/daemon.json
    echo -e "{\n\t\"insecure-registries\": [\"192.168.159.12:5000\"]\n}" > /etc/docker/daemon.json
    systemctl restart docker
    systemctl enable docker && systemctl start docker

}

function install_kubeadm(){
	# version 1.16.0
	yum install -y kubelet-1.16.0 kubeadm-1.16.0 kubectl-1.16.0 --disableexcludes=kubernetes
	systemctl enable kubelet && systemctl start kubelet
	./download_images_from_private.sh
	swapoff -a
	# /proc/sys/net/bridge/bridge-nf-call-iptables contents are not set to 1
	echo 1 > /proc/sys/net/bridge/bridge-nf-call-iptables
	echo 1 > /proc/sys/net/bridge/bridge-nf-call-ip6tables
	# kubeadm init --ignore-preflight-errors=Swap
}

function install_kubernetes(){
	set_env
	install_kubeadm
}
