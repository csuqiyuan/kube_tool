#!/bin/bash

set -x
DOCKER_REPO_USER=kubeimage
COREDNS_IMAGE=coredns:1.6.2
SUFFIX=-amd64
KUBE_VERSION=v1.16.0
ETCD_VERSION=3.3.15-0
PAUSE_VERSION=3.1
images=(etcd pause kube-proxy kube-scheduler kube-controller-manager kube-apiserver)
for imageName in ${images[@]} ; do
        if [[ ${imageName} = "etcd" ]]; then
                version=${ETCD_VERSION}
        elif [[ ${imageName} = "pause" ]]; then
                version=${PAUSE_VERSION}
        else
                version=${KUBE_VERSION}
        fi
        docker pull ${DOCKER_REPO_USER}/${imageName}${SUFFIX}:${version}
        docker tag ${DOCKER_REPO_USER}/${imageName}${SUFFIX}:${version} k8s.gcr.io/${imageName}:${version}
        docker rmi ${DOCKER_REPO_USER}/${imageName}${SUFFIX}:${version}
done
docker pull coredns/${COREDNS_IMAGE}
docker tag coredns/${COREDNS_IMAGE} k8s.gcr.io/${COREDNS_IMAGE}
docker rmi coredns/${COREDNS_IMAGE}