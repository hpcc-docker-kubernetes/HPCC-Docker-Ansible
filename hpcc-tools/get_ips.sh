#!/bin/bash

KUBE_TOKEN=$(</var/run/secrets/kubernetes.io/serviceaccount/token)
wget --no-check-certificate --header="Authorization: Bearer $KUBE_TOKEN"  \
 https://$KUBERNETES_SERVICE_HOST:$KUBERNETES_PORT_443_TCP_PORT/api/v1/pods  -O /tmp/pods.json

KUBE_TOKEN=$(</var/run/secrets/kubernetes.io/serviceaccount/token)
wget --no-check-certificate --header="Authorization: Bearer $KUBE_TOKEN"  \
 https://$KUBERNETES_SERVICE_HOST:$KUBERNETES_PORT_443_TCP_PORT/api/v1/services  -O /tmp/services.json

[ ! -d /tmp/ips ] && mkdir -p /tmp/ips
[ ! -d /tmp/lb-ips ] && mkdir -p /tmp/lb-ips
