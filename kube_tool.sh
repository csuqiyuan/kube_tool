#!/bin/bash

# 临时参数，最终是由外部传入，通过平台配置中心
private_repo_path=172.18.37.12:5000

function help(){
	cat << HELP
	NAME：dis - display the gived className or methodName  
	USAGE:dis [-c className] [-c] [-m methodName] [-m] [-n num] [-h ]
	Options:
		-f 
		-m
		-n
		-r
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
	DOCKER_REPO_USER=172.17.172.226:5000
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
	download_images_from_private
	swapoff -a
	# /proc/sys/net/bridge/bridge-nf-call-iptables contents are not set to 1
	echo 1 > /proc/sys/net/bridge/bridge-nf-call-iptables
	echo 1 > /proc/sys/net/bridge/bridge-nf-call-ip6tables
	# kubeadm init --ignore-preflight-errors=Swap
}

function install_kubernetes(){
	set_env $1
	install_kubeadm
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
# -c
function cp_config(){
	# 复制配置文件
	mkdir -p ${HOME}/.kube
	sudo cp -i /etc/kubernetes/admin.conf ${HOME}/.kube/config
	sudo chown $(id -u):$(id -g) ${HOME}/.kube/config
}
# -s 未完，要调用对应java包
function scp_config(){
	OLD_IFS="$IFS" 
	IFS="," 
	arr=($1) 
	IFS="$OLD_IFS" 
	NODE_IP=${arr[0]}
	NODE_USERNAME=${arr[1]}
	NODE_PASSWORD=${arr[2]}
	java -jar ./connect.jar ${NODE_IP} ${NODE_USERNAME} ${NODE_PASSWORD}
}
# -p
function net_plugin(){
	# 安装网络插件
	kubectl apply -f ./net.yaml
}
# -r
function create_and_post_token(){
	callback=$1
	kubeadm token create
	token_and_sha ${callback}
}
# -t
function token_and_sha(){
	callback=$1
	token=$(kubeadm token list | awk -F" " '{print $1}' |tail -n 1)
	sha256=$(openssl x509 -pubkey -in /etc/kubernetes/pki/ca.crt | openssl rsa -pubin -outform der 2>/dev/null | openssl dgst -sha256 -hex | sed 's/^.* //')
	curl ${callback}/apis/callback/token -X POST --data-urlencode token=${token} --data-urlencode sha=${sha256}
}

function test(){
	OLD_IFS="$IFS" 
	IFS="," 
	arr=($1) 
	IFS="$OLD_IFS" 
	echo ${arr[0]}
	echo ${arr[1]}
	echo ${arr[2]}
}
while getopts "a:bcs:" opt; do
	case $opt in
		a)
		echo "this is -a the arg is ! $OPTARG" 
		test $OPTARG
		;;
		b)
		echo "this is -b the arg is ! $OPTARG" 
		test $OPTARG
		;;
		c)
		echo "this is -c the arg is ! $OPTARG" 
		test $OPTARG
		;;
		s)
		echo "this is -c the arg is ! $OPTARG" 
		scp_config $OPTARG
		;;
		\?)
		help
		;;
	esac
done
