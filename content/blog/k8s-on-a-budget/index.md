---
title: "Kubernetes on a Budget"
date: 2021-04-14
draft: true
tags: ["infra", "devops", "microsoft"]
---
# Prologue
PaaS webapps are cool and all, but sometimes ya boi needs to deploy something *legacy* (🤮).
Time to build some infra over the midsem break.

Zoomer gotta zoom so I obviously want to use containers. And overengineering for high availability sounds fun.
All the cool kids are using this thing called kubernetes, surely that's perfect for little old me, right?
*googles hosted kubernetes pricing* oh shit go back
[meme bullying k8s]

# Part 1: Pretty Drawings
Don't get me wrong, I love containers and cloud PaaS. But together? My uni student wallet can't cope.
So I spent my midsem break trying to get the best of both worlds.
[reject monke (cloud), embrace hybrid (busted PC)]
Self-hosting was an obvious choice to save $, so I'll spare you the details (ie my dodgy closet server is embarrassing).


I found a mate with some more resilient infra, but neither of us can compete with the uptime of an actual company. And my "baby's first todo list" webapps obviously need five 9s. So time to search for a cloud provider...

First off, what's the criteria? Tl:dr;
*cost*
locality
integration (CI/CD)
scaling

Everyone and their mother provides hosted 

https://docs.microsoft.com/en-us/azure/aks/ingress-tls


bruteforcing vm types lmao - most failed, either preprovisioning or during deployment of VM set with 
standard_a2 3.5gb mem but still works

https://staffordwilliams.com/blog/2020/05/13/optimising-for-cost-in-aks/#the-cheapest-cluster not really tho

CD compatible
https://docs.github.com/en/actions/guides/publishing-docker-images#publishing-images-to-github-packages
https://docs.microsoft.com/en-us/azure/aks/kubernetes-action

IoT workloads
https://k3s.io/

Automatic failover
https://docs.microsoft.com/en-us/azure/traffic-manager/traffic-manager-metrics-alerts#alerts-on-traffic-manager-metrics
https://docs.microsoft.com/en-us/azure/azure-monitor/alerts/alerts-metric
https://docs.microsoft.com/en-us/azure/azure-monitor/alerts/action-groups#automation-runbook
https://docs.microsoft.com/en-us/azure/aks/start-stop-cluster
functions require effort and logic apps don't have an aks connector, `az aks stop --name aks-failover1 -g personal-kube-clusters` is so much easier