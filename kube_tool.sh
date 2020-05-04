#!/bin/bash

function help(){
	cat << HELP
	USAGE:./kube_tool.sh 
	Options:
		-m install kubernetes master node
		-n install kuberentes node node
		-c copy config file
		-s scp config file
		-p install net plugin
		-r create new token and update token/sha256
		-t save token and sha256
		-u kubeadm reset
	NOTE:can not use -c and -m at the same time!
HELP
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
    echo -e "{\n\t\"insecure-registries\": [\"$1\"]\n}" > /etc/docker/daemon.json
    systemctl restart docker
    systemctl enable docker && systemctl start docker
}

function set_env(){
	# root user
	yum install java-1.8.0-openjdk -y
	systemctl disable firewalld
	systemctl stop firewalld
	setenforce 0
	# reboot

	# centos
	if [[ -e /etc/yum.repos.d/kubernetes.repo ]]; then
		rm -f /etc/yum.repos.d/kubernetes.repo
	fi

	install_docker $1

	echo -e "[kubernetes]\nname=Kubernetes Repository\nbaseurl=https://mirrors.aliyun.com/kubernetes/yum/repos/kubernetes-el7-x86_64/\nenbled=1\ngpgcheck=0" >> /etc/yum.repos.d/kubernetes.repo

	# running with swap on is not supported. Please disable swap
	echo "KUBELET_EXTRA_ARGS=--fail-swap-on=false" > /etc/sysconfig/kubelet
}

function download_images_from_private(){
	DOCKER_REPO_USER=$1
	KUBE_VERSION=v1.16.0
	ETCD_VERSION=3.3.15-0
	PAUSE_VERSION=3.1
	COREDNS_VERSION=1.6.2
	WEAVE_VERSION=2.6.2
	mages=(etcd pause kube-proxy kube-scheduler kube-controller-manager kube-apiserver coredns weave-npc weave-kube)
	for imageName in ${images[@]} ; do
        user=k8s.gcr.io
        if [[ ${imageName} = "etcd" ]]; then
                version=${ETCD_VERSION}
        elif [[ ${imageName} = "pause" ]]; then
                version=${PAUSE_VERSION}
        elif [[ ${imageName} = "coredns" ]]; then
                version=${COREDNS_VERSION}
        elif [[ ${imageName} = "weave-npc" || ${imageName} = "weave-kube" ]]; then
                version=${WEAVE_VERSION}
                user=weaveworks
        else
                version=${KUBE_VERSION}
        fi
        docker pull ${DOCKER_REPO_USER}/${imageName}:${version}
        docker tag ${DOCKER_REPO_USER}/${imageName}:${version} ${user}/${imageName}:${version}
        docker rmi ${DOCKER_REPO_USER}/${imageName}:${version}
	done
}

# 无用
# function download_images_from_public(){
# 	set -x
# 	DOCKER_REPO_USER=kubeimage
# 	COREDNS_IMAGE=coredns:1.6.2
# 	SUFFIX=-amd64
# 	KUBE_VERSION=v1.16.0
# 	ETCD_VERSION=3.3.15-0
# 	PAUSE_VERSION=3.1
# 	images=(etcd pause kube-proxy kube-scheduler kube-controller-manager kube-apiserver)
# 	for imageName in ${images[@]} ; do
#         if [[ ${imageName} = "etcd" ]]; then
#                 version=${ETCD_VERSION}
#         elif [[ ${imageName} = "pause" ]]; then
#                 version=${PAUSE_VERSION}
#         else
#                 version=${KUBE_VERSION}
#         fi
#         docker pull ${DOCKER_REPO_USER}/${imageName}${SUFFIX}:${version}
#         docker tag ${DOCKER_REPO_USER}/${imageName}${SUFFIX}:${version} k8s.gcr.io/${imageName}:${version}
#         docker rmi ${DOCKER_REPO_USER}/${imageName}${SUFFIX}:${version}
# 	done
# 	docker pull coredns/${COREDNS_IMAGE}
# 	docker tag coredns/${COREDNS_IMAGE} k8s.gcr.io/${COREDNS_IMAGE}
# 	docker rmi coredns/${COREDNS_IMAGE}
# }

# 
function remove_images(){
	KUBE_VERSION=v1.16.0
	ETCD_VERSION=3.3.15-0
	PAUSE_VERSION=3.1
	COREDNS_VERSION=1.6.2
	WEAVE_VERSION=2.6.2
	images=(etcd pause kube-proxy kube-scheduler kube-controller-manager kube-apiserver coredns weave-npc weave-kube)
	for imageName in ${images[@]} ; do
		user=k8s.gcr.io
		if [[ ${imageName} = "etcd" ]]; then
			version=${ETCD_VERSION}
		elif [[ ${imageName} = "pause" ]]; then
			version=${PAUSE_VERSION}
		elif [[ ${imageName} = "coredns" ]]; then
			version=${COREDNS_VERSION}
		elif [[ ${imageName} = "weave-npc" || ${imageName} = "weave-kube" ]]; then
			version=${WEAVE_VERSION}
			user=weaveworks
		else
			version=${KUBE_VERSION}
		fi
		docker rmi ${user}/${imageName}:${version}
	done
}

function install_kubeadm(){
	# version 1.16.0
	yum install -y kubelet-1.16.0 kubeadm-1.16.0 kubectl-1.16.0 --disableexcludes=kubernetes
	systemctl enable kubelet && systemctl start kubelet
	download_images_from_private $1
	swapoff -a
	# /proc/sys/net/bridge/bridge-nf-call-iptables contents are not set to 1
	echo 1 > /proc/sys/net/bridge/bridge-nf-call-iptables
	echo 1 > /proc/sys/net/bridge/bridge-nf-call-ip6tables
	# kubeadm init --ignore-preflight-errors=Swap
}

function install_kubernetes(){
	set_env $1
	install_kubeadm $1
}

# -m 
function master(){
	PRIVATE_REPO_PATH=$1
	install_kubernetes ${PRIVATE_REPO_PATH}
	# 初始化
	kubeadm init --ignore-preflight-errors=Swap
}

# -n
function node(){
	OLD_IFS="$IFS" 
	IFS="," 
	arr=($1) 
	IFS="$OLD_IFS" 
	PRIVATE_REPO_PATH=${arr[0]}
	# 写数据库缓存
	MASTER_IP=${arr[1]}
	# 写数据库缓存，24h
	TOKEN=${arr[2]}
	# 写数据库缓存，24h
	SHA256=${arr[3]}
	install_kubernetes ${PRIVATE_REPO_PATH}


	kubeadm join ${MASTER_IP} --token ${TOKEN} \
    	--discovery-token-ca-cert-hash sha256:${SHA256} \
    	--ignore-preflight-errors=Swap
}
# -u
function uninstall(){
	echo y | kubeadm reset
}

# -c
function cp_config(){
	rm -rf ~/.kube
	# 复制配置文件
	mkdir -p ~/.kube
	echo $1 | sudo -S cp -i /etc/kubernetes/admin.conf ~/.kube/config
	echo $1 | sudo -S chown $(id -u):$(id -g) ~/.kube/config

	kubectl create clusterrolebinding test:anonymous --clusterrole=cluster-admin --user=system:anonymous
}
# -s
function scp_config(){
	OLD_IFS="$IFS" 
	IFS="," 
	arr=($1) 
	IFS="$OLD_IFS" 
	NODE_IP=${arr[0]}
	PORT=${arr[1]}
	NODE_USERNAME=${arr[2]}
	NODE_PASSWORD=${arr[3]}
	java -jar ./connect.jar ${NODE_IP} ${PORT} ${NODE_USERNAME} ${NODE_PASSWORD}
}
# -p
function net_plugin(){
	# 安装网络插件
	kubectl apply -f ./net.yaml
}
# -r
function create_and_post_token(){
	kubeadm token create
	token_and_sha $1
}
# -t
function token_and_sha(){
	set -x
	token=$(kubeadm token list | awk -F" " '{print $1}' |tail -n 1)
	sha256=$(openssl x509 -pubkey -in /etc/kubernetes/pki/ca.crt | openssl rsa -pubin -outform der 2>/dev/null | openssl dgst -sha256 -hex | sed 's/^.* //')
	curl $1/apis/callback/token -X POST --data-urlencode token=${token} --data-urlencode sha=${sha256}
}

while getopts "m:n:c:s:pr:t:u" opt; do
	case $opt in
		m)
		echo "this is -m the arg is ! $OPTARG" 
		master $OPTARG
		;;
		n)
		echo "this is -n the arg is ! $OPTARG" 
		node $OPTARG
		;;
		c)
		echo "this is -c the arg is ! $OPTARG" 
		cp_config $OPTARG
		;;
		s)
		echo "this is -s the arg is ! $OPTARG" 
		scp_config $OPTARG
		;;
		p)
		echo "this is -p" 
		net_plugin
		;;
		r)
		echo "this is -r the arg is ! $OPTARG" 
		create_and_post_token $OPTARG
		;;
		t)
		echo "this is -t the arg is ! $OPTARG" 
		token_and_sha $OPTARG
		;;
		u)
		echo "this is -u" 
		uninstall
		;;
		\?)
		help
		;;
	esac
done
