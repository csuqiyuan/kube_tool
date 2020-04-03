#!/bin/bash

set -x
DOCKER_REPO_USER=192.168.159.12:5000
KUBE_VERSION=v1.16.0
ETCD_VERSION=3.3.15-0
PAUSE_VERSION=3.1
COREDNS_VERSION=1.6.2
WEAVE_VERSION=2.6.0
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
