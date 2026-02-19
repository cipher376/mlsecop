Building an MLSecOps pipeline on Kubernetes is an ambitious and highly relevant project. You aren't just deploying a model; you are building a "fortress" around it that can scale automatically and defend against vulnerabilities.
Here is a step-by-step architectural guide to building this production-ready pipeline.

🏗️ Phase 1: Infrastructure & Cluster Foundation
Before the ML logic, you need a stable, secure "ground."
Provision the Cluster: Use a managed service like GKE, EKS, or AKS. For high availability, ensure your node pools are spread across at least three Availability Zones (AZs).

Network Isolation: Implement Kubernetes Network Policies (using Calico or Cilium). By default, K8s allows all pods to talk to each other; you must restrict your ML API so it only communicates with the ingress and your database.
Namespacing: Separate your concerns. Create namespaces like ml-development, ml-staging, and ml-production to enforce RBAC (Role-Based Access Control).

🛠️ Phase 2: The Secure CI/CD Pipeline
This is where "Sec" meets "Ops." Your code and images must be vetted before they touch the cluster.
Source Control (Git): Use GitFlow or GitHub Actions.
Static Analysis (SAST): Integrate tools like Bandit or Snyk in your pipeline to scan your Python/ML code for hardcoded secrets or insecure libraries.
Container Security (SCA/Linting):
Trivy or Grype: Scan your Docker images for known vulnerabilities (CVEs).
Hadolint: Ensure your Dockerfiles follow security best practices (e.g., not running as root).
Model Signing: Use Cosign (from the Sigstore project) to digitally sign your model artifacts and container images. This ensures the model running in production is exactly the one you trained.

🚀 Phase 3: High-Availability Deployment
Standard kubectl apply isn't enough for production.
Deployment Strategy: Use Helm Charts to package your application. Implement Rolling Updates to ensure zero downtime.
Self-Healing: Define Liveness and Readiness probes. If a model container hangs due to memory leakage (common in ML), Kubernetes will automatically kill and restart it.
Horizontal Pod Autoscaler (HPA): Set up HPA to scale your replicas based on CPU/GPU utilization or custom metrics like "Inference Latency."

🔒 Phase 4: Secure API Access & Serving
The "front door" of your model needs to be locked.
Ingress Controller: Use NGINX or Istio with TLS termination (Let's Encrypt). No traffic should enter via unencrypted HTTP.
Authentication (OIDC/JWT): Don't let your API be public. Integrate an identity provider (like Okta, Auth0, or Keycloak) using OpenID Connect (OIDC). Your ML API should validate a JSON Web Token (JWT) for every request.
API Gateway/Rate Limiting: Protect against DDoS or "Model Scraping" (adversaries trying to steal your model by querying it thousands of times) by implementing rate limits.

📈 Phase 5: Monitoring & Governance
Once it's live, you need to watch it.
Observability Stack: Deploy Prometheus and Grafana. Track system metrics (CPU/RAM) alongside ML metrics (Prediction Drift, Latency).
Runtime Security: Use Falco to monitor for suspicious activity inside your containers (e.g., a process unexpectedly trying to write to /etc).
Centralized Logging: Use the ELK Stack (Elasticsearch, Logstash, Kibana) or Loki to aggregate logs. In an MLSecOps context, log every inference request (anonymized) for audit trails.

💡 Pro-Tip for Your Portfolio:
To make this truly "Production-Ready," try implementing KServe or Seldon Core on top of your cluster. These are specialized K8s operators that handle model versioning, A/B testing, and "Canary" deployments out of the box.



Air-Gap Deployment Stack

Create the offYou will need three Linux VMs (Ubuntu server 24.04 is recommended):
1. The Master Node (Control Plane)
Why 4GB RAM? While K3s can run on 512MB, a production simulation involves constant API calls from your CI/CD pipeline and security scanners (like Trivy). If the Master node runs out of memory, the whole cluster "locks up."
Tip: Set the CPU Reservation in VMware to ensure the Master always has priority.
2. Worker 1: The "ML Engine"
Why 8GB RAM? Loading a medium-sized model (like a BERT variant or a large Scikit-learn ensemble) often spikes memory usage to 2–4GB just for the Python process. If you add a "Sidecar" container for logging or security, 4GB will cause Out Of Memory (OOM) kills.
Disk Space: 80GB seems high, but Docker images for ML are massive. A single PyTorch base image can be 4GB+.
3. Worker 2: The "Security Fortress"
Role: This node will run your observability tools.
Resource Tip: If you decide to add HashiCorp Vault or Elasticsearch later, you may need to bump this to 8GB. For a basic setup (Prometheus/Grafana), 4GB is sufficient.


Why not an Ubuntu desktop? 
Ubuntu Desktop comes with pre-installed software like LibreOffice, Firefox, and games. Each of these is a potential vulnerability and also very heavy.
Why not an Ubuntu core?
While Ubuntu Core is exceptionally secure due to its immutable, snap-only architecture, I recommend sticking with Ubuntu Server for this project because it provides the standard library support and flexibility required for complex ML dependencies and custom Kubernetes configurations that can be difficult to manage in Core's strictly confined environment.

Remember to verify the check sum of the downloaded image since security is our utmost objective.

echo "c3514bf0056180d09376462a7a1b4f213c1d6e8ea67fae5c25099c6fd3d8274b *ubuntu-24.04.3-live-server-amd64.iso" | shasum -a 256 --check

Kubernetes Installation (K3s)
Configure this on the master-node.
# Install K3s without Flannel and without the default Network Policy controller
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--flannel-backend=none --disable-network-policy --write-kubeconfig-mode 644" sh -
# 1. Back up the old, broken config (just in case)
mv ~/.kube/config ~/.kube/config.bak
# 2. Copy the new config from the system location
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
# 3. Fix the permissions so your user can read it
sudo chown $(id -u):$(id -g) ~/.kube/config

# Check status 
sudo systemctl status k3s 
sudo k3s kubectl get nodes


# Get the JOIN TOKEN (You will need this for the workers)
K3S_TOKEN=$(sudo cat /var/lib/rancher/k3s/server/node-token)
MASTER_IP=$(hostname -I | awk '{print $1}')

echo "Your Master IP: $MASTER_IP"
echo "Your Join Token: $K3S_TOKEN"

Configure this on the Worker-nodes 
#This will join the worker nodes to the cluster
# Install K3s Agent and join the cluster 
#Enter on the master node to get a connection string
echo “curl -sfL https://get.k3s.io | K3S_URL=https://${MASTER_IP}:6443 K3S_TOKEN=${K3S_TOKEN} sh -”

*** Optional *****
If you want to automate this even faster from your laptop, use the k3sup (pronounced "ketchup") tool. It uses SSH to install K3s on your VMware VMs automatically:
k3sup install --ip $MASTER_IP --user ubuntu
k3sup join --ip $WORKER_IP --server-ip $MASTER_IP --user ubuntu

**********************

Separation of concerns 

We’ll use Node Labels to identify your servers and Node Affinity in your YAML to ensure GitLab, the Runners, and the Models land exactly where you want them.

#label-nodes.sh
# Assign roles to the hardware
kubectl label nodes worker-node-ml workload=ml-production
kubectl label nodes worker-node-opssec workload=security-tools
kubectl label nodes worker-node-build workload=build-jobs


Network Security
In a professional MLSecOps pipeline, you cannot trust the "default" behavior of Kubernetes, which allows every Pod to talk to every other Pod. To implement Network Isolation, you must adopt a Zero-Trust posture. By using VMware, you can now implement these "Production-Level" security layers:
Virtual Network Isolation: In VMware, put your VMs on a private "LAN Segment." This simulates a private data center where your model is not exposed to the public internet.
Snapshotting the "Safe State": Once the cluster is up, take a VM Snapshot. If you accidentally delete a critical K8s component while testing security policies, you can "Time Travel" back to a working state in 5 seconds.
Resource Pinning: You can manually limit exactly how much RAM/CPU the ML worker gets. This prevents a "DDoS" attack on your ML API from crashing the entire VMware host.
Since you are using K3s on VMware, the default CNI (Flannel) does not support network policies. You first need to ensure you have a policy-capable CNI like Calico or Cilium installed, remember the default Flannel was disabled. To proceed, I recommend Cilium. It uses eBPF (instead of old-school iptables), which provides deeper security visibility (L7/HTTP-aware policies) and better performance for heavy ML data traffic. Let’s remove Flannel and its default network policy controller from K3s.
Install the Cilium CLI
#-----------
CILIUM_CLI_VERSION=$(curl -s https://raw.githubusercontent.com/cilium/cilium-cli/main/stable.txt)
CLI_ARCH=amd64
if [ "$(uname -m)" = "aarch64" ]; then CLI_ARCH=arm64; fi
curl -L --fail --remote-name-all https://github.com/cilium/cilium-cli/releases/download/${CILIUM_CLI_VERSION}/cilium-linux-${CLI_ARCH}.tar.gz{,.sha256sum}
sha256sum --check cilium-linux-${CLI_ARCH}.tar.gz.sha256sum
sudo tar xzvfC cilium-linux-${CLI_ARCH}.tar.gz /usr/local/bin
rm cilium-linux-${CLI_ARCH}.tar.gz{,.sha256sum}
#------------
#Inject CRD into kubernetes
kubectl apply --server-side -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.4.1/standard-install.yaml
helm upgrade --install cilium cilium/cilium \
--version 1.16.0 \
--namespace kube-system \
--set hubble.enabled=true \
--set hubble.ui.enabled=true \
--set hubble.relay.enabled=true
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
Verify cilium installation
# Check cilium status
cilium status –wait
# Run connectivity test
cilium connectivity test

By choosing Cilium over the default Flannel:
L7 Visibility: You can write a policy that says: "The ML Model can only talk to api.huggingface.co, but ONLY via GET requests." Standard K8s networking can't do that.
Hubble UI: You can open a browser and visually see blocked attacks. If a "Rogue Pod" tries to scan your ML node, you'll see a red line on the map.
Performance: eBPF processes packets at the kernel level, ensuring your large ML datasets don't get slowed down by thousands of legacy firewall rules.
Note: Since you are in a VM environment, ensure your MTU settings match. If you notice network lag, you may need to adjust the Cilium MTU to 1450 (common for virtualized networks) using the --set mtu=1450 flag during install.
Create a gateway to connect to external world
Cilium needs to know which IPs it’s "allowed" to give to your services which are required by the gateway. Choose a small range of free IPs from your VMware network.
#cilium-Ip-pool.yaml
apiVersion: "cilium.io/v2alpha1"
kind: CiliumLoadBalancerIPPool
metadata:
 name: "ingress-pool"
spec:
 blocks:
   - cidr: "192.168.32.200/31"
---
apiVersion: "cilium.io/v2alpha1"
kind: CiliumL2AnnouncementPolicy
metadata:
 name: "l2-policy"
spec:
 loadBalancerIPs: true
 interfaces:
   - ^ens33
 nodeSelector:
   matchExpressions:
     - key: "kubernetes.io/hostname"
       operator: Exists


#prod-gateway.yaml
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
 name: prod-gateway
 namespace: ml-ingress-gateway
 labels:
   app.kubernetes.io/component: ingress
   app.kubernetes.io/managed-by: cilium
   network/type: external
 annotations:
   # THIS STATICALLY ASSIGNS THE IP:
   io.cilium/lb-ipam-ips: "192.168.32.201"
spec:
 gatewayClassName: cilium
 listeners:
 - name: http
   port: 80
   protocol: HTTP
   allowedRoutes:
     namespaces:
       from: Same # CRITICAL: This allows routes from any namespace to attach
This gateway will be used by all routes that need to access the external services.

Accessing Hubble UI by forwarding to the VMware host.
Since you are running Cilium on a K3s VM via VMware NAT, you can't access the Hubble UI directly by typing localhost into your browser on the Host PC—the port is only open inside the VM. 

helm upgrade cilium cilium/cilium \
  --namespace kube-system \
  --reuse-values \
  --set hubble.enabled=true \
  --set hubble.relay.enabled=true \
  --set hubble.ui.enabled=true
Enable route by portforwarding
The easiest way to bridge the gap between your Guest VM and Host PC is to use port-forwarding.
kubectl port-forward -n kube-system svc/hubble-ui --address 0.0.0.0 12000:80
--address 0.0.0.0 tells Kubernetes to listen on the VM's network interface, not just its internal loopback.
12000 is the port you'll use in your browser
Optional: Adjust your firewall if they are enabled.
sudo ufw allow 12000/tcp comment 'Hubble UI Access'

Enable persistent route by L2Announcements

You can add a persistent route that will survive reboot.
Add these route to cilium-httpRoute.yaml and apply 

apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
 name: hubble-ui-route
 namespace: ml-ingress-gateway
spec:
 parentRefs:
   - name: prod-gateway
     namespace: ml-ingress-gateway
     sectionName: http
 hostnames:
   - "hubble.local"
 rules:
   - matches:
       - path:
           type: PathPrefix
           value: /
     backendRefs:
       - name: hubble-ui # Fixed the service name
         namespace: kube-system # Hubble lives in kube-system by default
         port: 80
---
# Allow traffic to Hubble
apiVersion: gateway.networking.k8s.io/v1beta1
kind: ReferenceGrant
metadata:
 name: allow-ingress-to-hubble
 namespace: kube-system
spec:
 from:
   - group: gateway.networking.k8s.io
     kind: HTTPRoute
     namespace: ml-ingress-gateway
 to:
   - group: ""
     kind: Service


After applying this configuration, run the following command to upgrade cilium

helm upgrade cilium cilium/cilium --namespace kube-system --reuse-values \
  	--set ingressController.enabled=true \
--set k8sServiceHost=192.168.32.128 \ #IP of master node
--set k8sServicePort=6443 \
--set gatewayAPI.enabled=true \
--set loadBalancer.l2announcements.enabled=true \
--set l2announcements.enabled=true \
--set loadBalancer.l2announcements.enabled=true \
--set standaloneDnsProxy.enabled=false \
--set gatewayAPI.createDefaultGatewayClass=true \
--set kubeProxyReplacement=true \
--set externalIPs.enabled=true \
  	--set devices=ens33  # Replace ens33 with your VM's main interface name

Why this is the "SecOps" Choice
Using Hubble from  Cilium's Gateway API allows you to see exactly which IP addresses that are attempting to log into your instances at the kernel level

Workload Isolation
To implement the logical and physical isolation we discussed, you should use a single YAML file to define your namespaces. This will also ensure that Pod Security Admission (PSA)  labels are applied consistently from the start when deploying pods.
Namespaces:
ml-production: Host your model pods here with the Restricted security profile and node pinning to protect your workload from attacks.
ml-monitoring: Separating metrics ensures that if your ML model is under a DDoS attack, your monitoring tools stay online so you can see what is happening.
ml-security: Placing your "trust" tools (like Vault for API keys or Harbor for images) in a separate namespace allows you to apply even stricter RBAC policies, ensuring only cluster admins can access them.

Namespace
Pod Security Level
Responsibility
ml-build
Baseline
GitLab application and its database components. (soft-lock)
ml-security
Restricted
Security scanning jobs, Trivy, and Cilium Hubble. (soft-lock)
ml-monitoring
Baseline
Prometheus, Grafana, and Kube-state-metrics. (Soft lock)
ml-production
Restricted
Your AI model inference pods


# namespaces.yaml
---
apiVersion: v1
kind: Namespace
metadata:
  name: ml-production
  labels:
    # PHYSICAL ISOLATION: Used for Node Affinity to target secure worker nodes
    tier: ml-secure
    # LOGICAL SECURITY: Enforce the strictest Pod Security Standard (PSA)
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/warn: restricted
    pod-security.kubernetes.io/audit: restricted
---
apiVersion: v1
kind: Namespace
metadata:
  name: ml-monitoring
  labels:
    # BASELINE: Monitoring tools often need some host-level access (e.g., node-exporter)
    pod-security.kubernetes.io/enforce: baseline
    pod-security.kubernetes.io/warn: baseline
---
apiVersion: v1
kind: Namespace
metadata:
  name: ml-security
  labels:
    # RESTRICTED: Tools like Vault or Harbor must be extremely locked down
    pod-security.kubernetes.io/enforce: restricted

Why these labels matter
pod-security.kubernetes.io/enforce: restricted: This is your primary defense. If a container image tries to run as the root user, or tries to access the host's network/filesystem, Kubernetes will reject the deployment immediately. The Restricted profile will immediately block your models if they try to run as the root user (UID 0). You must update your Deployment YAML to include a securityContext. 
tier: ml-secure: This custom label is your "hook" for the Node Pinning we discussed. When you deploy your model, you will use a nodeSelector that looks for this specific label on your VMware worker nodes.
baseline vs restricted: You'll notice ml-monitoring uses baseline. This is because tools like Prometheus Node Exporter actually need to read host metrics to be useful. If you set it to restricted, your monitoring might break.
#deployment.yaml (EXAMPLE – DO NOT APPLY)
…
spec: 
securityContext: 
# Prevents the container from ever gaining root privileges 
runAsNonRoot: true 
# Forces the container to run as a specific unprivileged user 
runAsUser: 1000 
# Ensures all files created are owned by this group 
fsGroup: 2000 
# Modern standard for process isolation 
seccompProfile: 
type: RuntimeDefault
Containers:
…
securityContext: 
# Disallows any dynamic privilege escalation (e.g. sudo) allowPrivilegeEscalation: false 
# Removes dangerous Linux capabilities (like raw network access) 
capabilities: 
drop: 
- ALL 
# Makes the root filesystem of the container read-only readOnlyRootFilesystem: true	
Handling the "Read-Only" Filesystem
ML models often need to write temporary files (like cache or logs). Since we set readOnlyRootFilesystem: true (a core MLSecOps best practice), you must provide a safe place for these files using an emptyDir volume.
#deployment.yaml (EXAMPLE - DO NOT APPLY)
…
volumeMounts:
        - name: tmp-volume
          mountPath: /tmp
      volumes:
      - name: tmp-volume
        emptyDir: {}

Testing the Lock
To verify this works for your project demo:
Try to deploy a standard nginx pod into the ml-production namespace and you should receive an error.
$kubectl run test-pod --image=nginx -n ml-production
Error from server (Forbidden): pods "test-pod" is forbidden: violates PodSecurity "restricted:latest": allowPrivilegeEscalation !=
false (container "test-pod" must set securityContext.allowPrivilegeEscalation=false), unrestricted capabilities (container "test-po
d" must set securityContext.capabilities.drop=["ALL"]), runAsNonRoot != true (pod or container "test-pod" must set securityContext.
runAsNonRoot=true), seccompProfile (pod or container "test-pod" must set securityContext.seccompProfile.type to "RuntimeDefault" or
"Localhost")
It will fail because the default nginx image tries to run as root.
This proves that your "Security Fortress" is successfully blocking unauthorized or insecure software from entering your ML environment.
Configuring Security for  Namespaces and Nodes
Both creating dedicated namespaces and pinning them to specific nodes is highly recommended. Think of Namespaces as logical fences and Node Pinning as physical walls. In a high-security ML environment, you need both to prevent a "noisy neighbor" (a heavy training job) or a "malicious actor" (a compromised API) from taking down your entire VMware cluster.
By combining Namespaces with Taints and Tolerations, you create a "Sanitarium" architecture:
Logical Isolation (Namespaces): Separates secrets, RBAC permissions, and network policies (e.g., the ml-development team cannot see the ml-production model weights).
Physical Isolation (Node Pinning): Ensures that if your ML model suffers a memory leak or a "ReDoS" (Regular Expression Denial of Service) attack, it only crashes its dedicated worker node, leaving your Master node and other system services (like logging/monitoring) untouched.
First, by using taints, let's tell a worker-node-ml: "You are only for production ML. Do not let anyone    else in.
# Run this on your master node
$kubectl taint nodes worker-node-ml dedicated=ml-production:NoSchedule
$kubectl label nodes worker-node-ml tier=ml-secure

# Reserve workers for Infrastructure (Monitoring & Security)
$kubectl taint nodes worker-node-opssec dedicated=infra:NoSchedule
$kubectl label node worker-node-opssec dedicated=infra

Now, you tell your ML Model: "You are the only one with the key to that node, and I prefer you go there."
Add this to your ml production deployment spec any pod you want to deploy to work-node-ml:
….
spec:
  template:
    spec:
      # THE KEY: Allows the pod to ignore the "Stain" (Taint)
      tolerations:
      - key: "dedicated"
        operator: "Equal"
        value: "ml-production"
        effect: "NoSchedule"
      
      # THE COMPASS: Forces the pod to choose the specific node
      nodeSelector:
        tier: ml-secure


Add this to your Grafana or Prometheus deployment spec any pod you want to deploy to work-node-opssec:
…
spec:
  template:
    spec:
      tolerations:
      - key: "dedicated"
        operator: "Equal"
        value: "infra"
        effect: "NoSchedule"
      # Best Practice: Use Node Affinity to force it here
      nodeSelector:
        dedicated: infra


The Trade-off: Security vs. Cost
Feature
No Node Pinning (Shared)
With Node Pinning (Isolated)
Resource Efficiency
High (Pods fill every gap)
Lower (Nodes may sit idle)
Security Risk
High (Container escapes affect host)
Low (Blast radius is limited to 1 node)
Troubleshooting
Hard (Many logs mixed together)
Easy (1 Node = 1 Environment)


For a true MLSecOps pipeline, you don't want to manually add these lines to every file. You should use a PodNodeSelector Admission Controller.
This is a setting in the Kubernetes API server that says: "Any pod created in the ml-production namespace must automatically be moved to nodes labeled tier=ml-secure."
Let’s enable the admission controller

Only for K3s:
Create or edit the k3s config file
$sudo nano /etc/rancher/k3s/config.yaml

#add to file
 kube-apiserver-arg:
  - "enable-admission-plugins=NodeRestriction,PodNodeSelector"

#verify
$sudo systemctl restart k3s
# Check k3s is running 
$sudo systemctl status k3s 
# Verify admission plugins are active 
$kubectl get --raw /metrics | grep admission


Resource Quotas and Limit Ranges for Namespaces
In a production MLSecOps environment, we use a "Belt and Suspenders" approach:
ResourceQuota: Sets a hard ceiling for the entire namespace (the "Total Budget").
LimitRange: Sets the guardrails for individual containers (the "Apartment Rules").
1. The "Total Budget" (ResourceQuota)
Apply this to your ml-production namespace. It ensures that even if you have 50 models, they can never collectively exceed what your VMware Worker nodes can handle.
#ml-namespace-quota.yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: ml-namespace-quota
  namespace: ml-production
spec:
  hard:
    requests.cpu: "4"           # Total CPU reserved by all models
    requests.memory: "8Gi"      # Total RAM reserved by all models
    limits.cpu: "6"             # Absolute max CPU burst for namespace
    limits.memory: "12Gi"       # Absolute max RAM burst for namespace
    pods: "10"                  # Maximum 10 model pods allowed
2. The "Guardrails" for namespace  (LimitRange) 
This is the "Secret Sauce" of MLSecOps. If a developer forgets to define resource limits in their deployment, the LimitRange automatically injects them. This prevents a "rogue" container from requesting 0 RAM and then expanding until it kills the node.
#ml-production-limits.yaml

apiVersion: v1
kind: LimitRange
metadata:
  name: ml-container-limits
  namespace: ml-production
spec:
  limits:
  - type: Container
    default:             # Default LIMIT if not specified
      cpu: "1000m"
      memory: "6Gi"
    defaultRequest:      # Default REQUEST (guaranteed) if not specified
      cpu: "500m"
      memory: "4Gi"
    max:                 # Absolute maximum any single container can ask for
      cpu: "2000m"
      memory: "8Gi"
    min:                 # Absolute minimum (prevents "tiny" unstable pods)
      cpu: "100m"
      memory: "128Mi"


# monitoring-limits.yaml
apiVersion: v1
kind: LimitRange
metadata:
  name: monitoring-limits
  namespace: ml-monitoring
spec:
  limits:
  - type: Container
    default:
      cpu: "1000m"      # 1 Full Core
      memory: "3Gi"     # Prometheus standard for ~200k series
    defaultRequest:
      cpu: "500m"
      memory: "2Gi"
    max:
      cpu: "2000m"
      memory: "4Gi"
    min:                 # Absolute minimum (prevents "tiny" unstable pods)
      cpu: "100m"
      memory: "128Mi"


# security-limits.yaml
apiVersion: v1
kind: LimitRange
metadata:
  name: security-limits
  namespace: ml-security
spec:
  limits:
  - type: Container
    default:
      cpu: "500m"
      memory: "1Gi"
    defaultRequest:
      cpu: "250m"
      memory: "512Mi"
    max:
      cpu: "1500m"      # Higher max for Trivy scanning spikes
      memory: "2Gi"
    min:                 # Absolute minimum (prevents "tiny" unstable pods)
      cpu: "100m"
      memory: "128Mi"


Namespace
Guaranteed RAM (Requests)
Max RAM (Limits)
Strategy
ml-production
4.0 GiB
8.0 GiB
Priority: High (Guaranteed)
ml-monitoring
2.0 GiB
3.0 GiB
Priority: Medium
ml-security
0.5 GiB
1.0 GiB
Priority: Critical
TOTAL
6.5 GiB
12.0 GiB
Fits in 16GB Node (with some swap)


Why this matters for MLSecOps
Security against DoS: An attacker who gains access to your API might try to run a "Memory Bomb" (a process that allocates infinite RAM). With these quotas, the container will be OOM Killed (Out of Memory) by the kernel before it can destabilize your VMware host.
Deterministic Performance: By setting requests equal to limits for ML workloads (known as Guaranteed QoS), you ensure the Linux kernel never "throttles" your model's CPU, keeping your inference latency stable.
How to apply and test
Create the namespace: kubectl create namespace ml-production
Save the YAMLs above and apply them: kubectl apply -f system-quota.yaml -f ml-production-limits.yaml -f security-limits.yaml -f monitoring-limits.yaml
Try to deploy a pod without resource limits. Run kubectl describe pod <name> and you will see Kubernetes has automatically "injected" the 2Gi limit for you!


Chapter 2 

Building secure CI/CD Pipeline. 

In Chapter 1, we built the "Fortress" (the kubernetes infrastructure); now, we are building the "Armored Convoy" that safely transports your code and models into that fortress.
A secure ML pipeline isn't just about code—it's about the Supply Chain. We need to ensure that the data, the model weights, and the Python dependencies haven't been tampered with

What we want to achieve:
1. Developer pushes code to GitLab
2. CI: docker build → image.tar artifact
3. CI: trivy image scan → SARIF uploaded to GitLab Security Dashboard
4. CI: trivy config scan → K8s manifests checked for misconfigs
5. CI: if no CRITICALs → docker push to GitLab Registry
6. CI: update image tag in k8s/values.yaml → git push [skip ci]
7. ArgoCD detects Git change → syncs Deployment to K3s
8. Cilium enforces NetworkPolicies on all pods (eBPF-level)
9. Trivy Operator continuously scans running pods → VulnerabilityReports
10. Hubble provides real-time network flow visibility


ArgoCD 
Argo CD is a declarative, GitOps continuous delivery tool for Kubernetes. It acts as a bridge between your Git repository (where your code and configuration live) and your Kubernetes cluster (where your application runs).

How it works
Git as the "Source of Truth": You define your desired application state (YAML files, Helm charts, or Kustomize) in a Git repo (like GitLab or GitHub).  
Continuous Monitoring: Argo CD watches that repository.
Automated Syncing: If you change something in Git, Argo CD detects that the "Live State" in the cluster doesn't match the "Target State" in Git. It then automatically (or manually) applies those changes to the cluster.

While Kubernetes technically allows you to install resources anywhere, installing ArgoCD in its own dedicated namespace (usually argocd) is the industry standard and a core security requirement. In your "Fortress" architecture, the argocd namespace acts as the Control Plane for your deployments.

# 1. Create the dedicated management namespace
kubectl create namespace argocd

# 2. Label it for security (PSA)
# ArgoCD needs 'privileged' to manage cluster-wide resources
kubectl label namespace argocd pod-security.kubernetes.io/enforce=privileged

# 3. Install the stable manifests into that namespace
kubectl create -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

kubectl replace -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

Lock down deployment channels to ArgoCD (postpone lockdown to later)

We will use an ArgoCD AppProject to tell ArgoCD: "You are allowed to deploy models into the ml-production namespace, but you are FORBIDDEN from deploying anything back into the argocd namespace." This prevents a "Loop Attack" where a compromised model tries to overwrite the GitOps controller.

#ml-project.yaml

apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: ml-production-project
  namespace: argocd
spec:
  description: "Secure project for Production ML Workloads"
  
  # GATE 1: Restrict where the code comes from
  sourceRepos:
    - 'https://gitlab.build.server/ml-security/production-models.git'

  # GATE 2: Restrict where the models can land
  destinations:
    - namespace: ml-production
      server: https://kubernetes.default.svc

  # GATE 3: Resource Whitelist (Security Lockdown)
  # We allow Deployments and Services, but FORBID powerful cluster-wide resources
  namespaceResourceWhitelist:
    - group: 'apps'
      kind: Deployment
    - group: ''
      kind: Service
    - group: ''
      kind: ConfigMap
    - group: 'networking.k8s.io'
      kind: NetworkPolicy

  # GATE 4: Deny Cluster-Scoped Resources
  # This prevents the ML team from accidentally deleting namespaces or changing RBAC
  clusterResourceBlacklist:
    - group: '*'
      kind: '*'

Note: this script is not applied now because we will test our configuration with dummy pods in which we deploy locally not through the source control like Gitlab. 

What’s included in the yaml
Repository Locking (sourceRepos): By specifying your GitLab URL, you ensure that even if an attacker creates a malicious Git repo on GitHub, ArgoCD will refuse to pull from it for this project.
Destination Isolation (destinations): This prevents "Namespace Hopping." If a developer tries to deploy an ML model into kube-system or argocd, the sync will fail.
Resource Whitelisting (namespaceResourceWhitelist): We explicitly allow NetworkPolicy. This is critical for Phase 1/Phase 2 integration—it means ArgoCD can automate the "Micro-segmentation" of your ML models while still blocking them from creating dangerous resources like Privileged pods (if you add PodSecurityPolicies later).
Cluster Blacklist: This is the "Hard Shell." It ensures that the ml-production project can never affect the global state of your VMware cluster (like nodes, storage classes, or cluster roles).

We will configure ArgoCD-UI for cilium. Cilium is moving away from traditional Ingress toward the Gateway API. This provides more granular security control. 
Let’s configure cillium as our Load Balancer and Gateway. 
helm upgrade cilium cilium/cilium --namespace kube-system --reuse-values \
  --set gatewayAPI.enabled=true \
  --set ingressController.enabled=true \
  --set l2announcements.enabled=true \
  --set loadBalancer.l2announcements.enabled=true \
  --set devices=ens33  # Replace ens33 with your VM's main interface name


After creating the pool, tell Cilium to create a "Front Door" (Gateway) and a "Path" (HTTPRoute) to the ArgoCD UI. Since we already have a gateway, we will add a route that references the gateway (prod-gateway.yaml). The route is part of the file cilium-httpRoute.yaml

apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
 name: argocd-ui-route
 namespace: ml-ingress-gateway
spec:
 parentRefs:
   - name: prod-gateway
     namespace: ml-ingress-gateway
     sectionName: http
 hostnames:
   - "argocd.local"
 rules:
   - matches:
       - path:
           type: PathPrefix
           value: /
     backendRefs:
       - name: argocd-server
         namespace: argocd # MUST specify where the service lives
         port: 80
---
# Allow traffic to ArgoCD
apiVersion: gateway.networking.k8s.io/v1beta1
kind: ReferenceGrant
metadata:
 name: allow-ingress-to-argocd
 namespace: argocd
spec:
 from:
   - group: gateway.networking.k8s.io
     kind: HTTPRoute
     namespace: ml-ingress-gateway
 to:
   - group: ""
     kind: Service


After adding the route, activate the cilium’s gateway api 

#Tell cilium to use the gateway Api.
helm upgrade cilium cilium/cilium -n kube-system --reuse-values \
--set kubeProxyReplacement=true \
--set k8sServiceHost=$(kubectl get nodes -o  jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}') \
--set k8sServicePort=6443 \
--set gatewayAPI.enabled=true \
--set loadBalancer.l2announcements.enabled=true \
--set l2announcements.enabled=true \
--set loadBalancer.l2announcements.enabled=true \
--set standaloneDnsProxy.enabled=false \
--set gatewayAPI.enabled=true \
--set gatewayAPI.createDefaultGatewayClass=true \
--set ingressController.enabled=true \
--set kubeProxyReplacement=true \
--set devices=<VM main interface e.g eth0, ens+> \
--set externalIPs.enabled=true

Verify for L2 announcements:
kubectl get cm cilium-config -n kube-system -o yaml | grep -E "l2-announcements|kube-proxy-replacement"

For a smooth "handshake" between the Gateway and the UI, we let the Gateway handle the traffic and tell ArgoCD to stop trying to force its own internal HTTPS.

kubectl patch cm argocd-cmd-params-cm -n argocd --type merge -p '{"data": {"server.insecure": "true"}}'
kubectl rollout restart deployment argocd-server -n argocd

Check the Gateway status to see which IP was assigned from your pool:

kubectl get gateway -n argocd

#Verify: Programmed should return ‘true’ and Address shows the assigned IP

Visit: http://gateway-ip-from-pool to access ArgoUI



Signing into ArgoCD

By default, the initial username is admin, but the password is automatically generated during the installation and stored as a Kubernetes secret. Use the command below to retrieve the password.
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d; echo
Note: It is highly recommended to change the autogenerated password immediately and delete the secret that holds the password. You can change your password from the UI or from the command line. Use this command if you prefer the command line.
argocd account update-password 



The Build Server (GitLab)

A separate GitLab server acts as the Command Center for your MLSecOps pipeline. It centralizes four critical security functions:

Feature
MLSecOps Contribution
Isolated Runners
You can have a "GPU Runner" for model testing and a "CPU Runner" for linting. If a malicious model tries to escape the container, it only affects the Runner server, not your K8s Master.
Registry Isolation
GitLab has a built-in Container Registry. Keeping your ML images on a separate server means you can back them up independently of your VMware cluster.
Audit Logging
By keeping Git on its own server, you have a separate "paper trail" of who accessed the model weights or modified the training parameters.
Webhook Security
You can configure your VMware firewall to only allow traffic from the GitLab IP to your K3s Master, closing off the rest of the world.


Note: Since you are using VMware, I recommend creating a new VM with at least 4 vCPUs and 8GB of RAM (GitLab is resource-heavy).

# Update and install dependencies
sudo apt-get update
sudo apt-get install -y curl openssh-server ca-certificates tzdata perl

# Add the GitLab Repo and Install
curl https://packages.gitlab.com/install/repositories/gitlab/gitlab-ee/script.deb.sh | sudo bash
sudo EXTERNAL_URL="http://gitlab.build.server" apt-get install gitlab-ee

Build-server Firewall 
Implementing a separate GitLab server creates a Security Air Gap between your code development and your production environment. In a VMware setup, this is usually done by placing the GitLab VM and the K3s VM on different virtual networks or by using strict firewall rules.
The "Zero Trust" Firewall Configuration
You need to open specific "ports" so that GitLab can scan your code and deploy it to K3s without exposing the cluster to the public internet. If you are using your vmware host PC as a developer PC then set the IP address accordingly.
Traffic Type
Source
Destination
Port/Protocol
Purpose
Inbound
Developer PC / Vmare host pc
GitLab VM
443/TCP
Access the GitLab UI
Inbound
Developer PC / Vmware host pc
GitLab VM
22/TCP
Push code via SSH
Outbound
GitLab VM
K3s Master
6443/TCP
Deploying models (K8s API)
Bi-directional
K3s Cluster
GitLab VM
8150/TCP
GitLab Agent (KAS) tunnel
Inbound
K3s Nodes
GitLab VM
5050/TCP
Pulling ML images (Registry)


By using a separate GitLab server, your pipeline gains "The Three Pillars of MLSecOps":
1. The Secure Image Registry (Gate 2 & 3)
Instead of using Docker Hub, your GitLab server hosts its own Private Container Registry.
When your pipeline builds an ML image, it stays on your hardware. You can use Trivy to scan the image on the GitLab server before it is even "visible" to the K3s cluster.
2. The gRPC Tunnel (No Open API Ports)
We avoid opening port 6443 to the world. Instead, we use the GitLab Agent for Kubernetes.
How it works: A small pod on your K3s master initiates an outbound connection to GitLab.
Your K3s cluster stays invisible behind the firewall. GitLab "talks" to K3s through this secret tunnel.
3. Isolated Build Runners
You can set up a "GitLab Runner" on a third VM. This runner is the "Worker" that actually runs Gitleaks and Bandit.
 If a malicious Python dependency tries to steal data during a build, it only has access to the temporary Runner VM—it can't "see" your production ML models or your K3s Master.

Initial Setup (Safety First)
#Before applying rules, ensure you don't lock yourself out of the VM.
# Reset to defaults (Deny all incoming, Allow all outgoing)
sudo ufw default deny incoming
sudo ufw default allow outgoing

# CRITICAL: Allow your own SSH access so you don't get kicked out
sudo ufw allow ssh

 Inbound Rules (Traffic to GitLab VM)
# Allow Developer PC to access UI (443) and SSH (22)
sudo ufw allow from <Developer_PC_IP> to any port 443 proto tcp comment 'GitLab UI'
sudo ufw allow from <Developer_PC_IP> to any port 22 proto tcp comment 'GitLab SSH Push'

# Allow K3s Nodes to pull images from GitLab Registry (5050)
sudo ufw allow from <K3s_Nodes_Subnet> to any port 5050 proto tcp comment 'Container Registry'

# Allow K3s Cluster to connect to GitLab Agent (KAS)
sudo ufw allow from <K3s_Nodes_Subnet> to any port 8150 proto tcp comment 'GitLab Agent KAS'

Outbound Rules (Traffic from GitLab VM)

# Change default to deny outgoing (Warning: This blocks everything not explicitly allowed!)
sudo ufw default deny outgoing

# Allow GitLab to talk to K3s API
sudo ufw allow out to <K3s_Master_IP> port 6443 proto tcp comment 'K8s API'

# Allow GitLab to talk to its own Agent Tunnel (KAS)
sudo ufw allow out to <K3s_Nodes_Subnet> port 8150 proto tcp comment 'KAS Outbound'

# Essential: Allow DNS and Updates (Don't forget these!)
sudo ufw allow out 53/udp
sudo ufw allow out 80,443/tcp


Verify your firewall configuration

# Check the numbered list of rules
sudo ufw status numbered

# Enable the firewall
sudo ufw enable

NOTE: Since you are using Cilium on your K3s cluster, remember that Cilium manages its own NetworkPolicies inside the cluster. The rules above protect the VMs themselves, but you may still need a CiliumNetworkPolicy to allow the pods inside K3s to reach the GitLab VM's IP.

#global-allow-gitlab-vm.yaml

apiVersion: "cilium.io/v2"
kind: CiliumClusterwideNetworkPolicy
metadata:
 name: "global-allow-gitlab-vm"
spec:
 description: "Allow GitLab Egress AND Host PC Ingress for ArgoCD"
 endpointSelector: {}  
 ingress:
   - fromCIDR:
       - "192.168.32.0/24" # Replace with your VMware NAT Subnet
     toPorts:
       - ports:
           - port: "443"
             protocol: TCP
           - port: "80"
             protocol: TCP
# Rule 2: Allow internal cluster communication (Essential!)
   - fromEntities:
       - cluster
       - host
 egress:
# 1. GLOBAL DNS ALLOW
   # This fixes the "dial udp 10.43.0.10:53: connect: operation not permitted"
   - toEndpoints:
       - matchLabels:
           "k8s:io.kubernetes.pod.namespace": kube-system
           "k8s:k8s-app": kube-dns
     toPorts:
       - ports:
           - port: "53"
             protocol: UDP
           - port: "53"
             protocol: TCP
         rules:
           dns:
             - matchPattern: "*"
#----------------------------------------------------------------------
# 2. GLOBAL GITLAB ACCESS
   # This allows the tunnel to reach your GitLab server via IP or Hostname
   - toEntities:
       - world
     toPorts:
       - ports:
           - port: "80"
             protocol: TCP
           - port: "443"
             protocol: TCP
# -----------------------------------------------------------------------
# 3. ALLOW HUBBLE TO COMMUNICATE WITH VMWARE HOST
   - toCIDR:
       - "192.168.32.126/32"
     toPorts:
       - ports:
           - port: "5050"
             protocol: TCP
           - port: "8150"
             protocol: TCP
           - port: "12000" # <--- ADD THIS for Hubble
             protocol: TCP
#------------------------------------------------------------------------
# Rule 4: Allow pods to talk to each other and DNS (Essential!)
   - toEntities:
       - cluster
       - host
   - toEndpoints:
       - matchLabels:
           "k8s:io.kubernetes.pod.namespace": kube-system
           "k8s-app": kube-dns
     toPorts:
       - ports:
           - port: "53"
             protocol: UDP
         rules:
           dns:
             - matchPattern: "*"

#------------------------------------------------------------------------
   - toCIDR:
       - 10.43.0.10/32 # The K3s Cluster DNS Service IP
     toPorts:
       - ports:
           - port: "53"
             protocol: ANY
#-------------------------------------------------------------------------

   # Allow HTTPS to GitLab server
   - toFQDNs:
       - matchName: "gitlab.build.server"
     toPorts:
       - ports:
           - port: "443"
             protocol: TCP
           - port: "80"
             protocol: TCP



Applying this inside your K3s cluster tells Cilium to "Allow pods in the ml-production namespace to talk to the GitLab VM's IP on the specific ports we opened in the firewall." We also allow internal entities to communicate to each other like pod-to-pod or pod-to-node. Finally, we allow the vmware host to communicate to the pods.
Verify the Connection

#the following command should return ‘true’
kubectl get ccnp
Once you have applied the UFW rules on the VM and the CNP in the cluster, run a network test from inside a K3s pod:
# Test the Registry Port
kubectl run -i --tty --rm debug --image=busybox --restart=Never -- \
  nc -zv <GITLAB_VM_IP> 5050
If this test failed, it is because of the guard rail we created earlier to prevent deployment into the default name space. This is a production server and we only want to get a workload deployed through ArgoCD. We will test it later when we complete our pipeline.

Creating a New Gitlab Project
Sign In: Log into your self-hosted GitLab instance (the URL you set up earlier, e.g., http://gitlab.build.server.com).
Navigate to Projects:
In the top navigation bar, select Create new (+) and then New project/repository.  
Alternatively, click the New project button on your dashboard.  
Select "Create blank project":
This is the best choice for your MLSecOps project because it allows you to build your specific folder structure from scratch.
Configure Project Details:
Project name: Something descriptive like MLSecOps-Classifier.
Project slug: This auto-fills (e.g., mlsecops-classifier). This will be part of your Git URL.
Visibility Level: Choose Private. In MLSecOps, you never want your model weights or training data exposed to the public.
Initialize repository with a README: Check this box. It creates a default branch (main) immediately, which makes it easier to connect your GitLab Runner later.
Click "Create project".
Create the Two Projects
Create two projects named Mlsecops-tunnel and Mlsecops-production-pipeline.
The Mlsecops-tunnel project will be your Management Project (holding the Agent's identity and connection), and Mlsecops-production-pipeline will be your Application Project (holding the models and deployment logic).
Create Mlsecops-tunnel: This is a blank project. Its only job is to provide a home for the Agent configuration.
Create Mlsecops-production-pipeline: This is another blank project where you will push your ML code, Dockerfile, and K8s manifests.

Agent Creation & Configuration
Visit: https://docs.gitlab.com/user/clusters/agent/install/ for tutorials on how to create an agent.
You must define the Agent's "brain" inside the Tunnel project before registering it.
In Mlsecops-tunnel, create a file at exactly this path: .gitlab/agents/mlsecops-agent/config.yaml
Configure Access: Add the following content to the file. This tells the agent: "Allow the Production project to use your secure tunnel."
#config.yaml

ci_access:
  projects:
    - id: <YOUR-GROUP>/Mlsecops-production-pipeline # Use your actual path

      3. Register in UI:
Go to Operate > Kubernetes clusters in the Mlsecops-tunnel project.
Click Connect a cluster (agent).
Select mlsecops-agent from the dropdown (GitLab will recognize the config file you just pushed).
Copy the Token and the helm command provided.

Agent Deployment (K3s Master)
Log into your K3s Master node and run the command you copied. It will look like this:
helm upgrade --install mlsecops-agent gitlab/gitlab-agent \
  --namespace gitlab-agent-mlsecops-agent \
  --create-namespace \
  --set config.token=<YOUR_TOKEN> \
  --set config.kasAddress=wss://gitlab.yourdomain.com/-/kubernetes-agent/

Verify the connection: In the GitLab UI (Mlsecops-tunnel project), the status should now show Connected.

Sometimes, this will fail and according to my setup it was an error with the coreDNS. The agent cannot resolve gitlab.build.server the url of gitlab build server. I patched the coreDNS configuration and added the host manually.

kubectl edit cm coredns -n kube-system

Add this to patch: 

apiVersion: v1
kind: ConfigMap
metadata:
  name: coredns
data:
  Corefile: |
    .:53 {
        errors
        health
        ready
        # ADD THIS BLOCK START
        hosts {
          192.168.32.126 gitlab.build.server
          fallthrough
        }
        # ADD THIS BLOCK END
        kubernetes cluster.local in-addr.arpa ip6.arpa {
           pods insecure
           fallthrough in-addr.arpa ip6.arpa
        }
        forward . /etc/resolv.conf
        cache 30
        loop
        reload
        loadbalance
    }

Whitelist DNS for the Agent
After patching you need to allow the agent to send a dns packet through the network. Achieve this by creating and applying a cilium network policy that allows dns communication for the agent.

#gitlab-agent-cilium-dns-policy.yaml

apiVersion: "cilium.io/v2"
kind: CiliumNetworkPolicy
metadata:
  name: allow-agent-dns
  namespace: gitlab-agent-mlsecops-agent
spec:
  endpointSelector:
    matchLabels:
      app.kubernetes.io/name: gitlab-agent
  egress:
    # 1. Allow DNS queries to CoreDNS
    - toEndpoints:
        - matchLabels:
            "k8s:io.kubernetes.pod.namespace": kube-system
            "k8s:k8s-app": kube-dns
      toPorts:
        - ports:
            - port: "53"
              protocol: UDP
          rules:
            dns:
              - matchPattern: "*"
    # 2. Allow the actual tunnel traffic to your GitLab Server
    - toEntities:
        - world
      toPorts:
        - ports:
            - port: "443"
              protocol: TCP
            - port: "80"
              protocol: TCP


Verify: 

kubectl exec -it -n gitlab-agent-mlsecops-agent deployment/mlsecops-agent -- nslookup gitlab.build.server

If it says command not found, that's okay (the agent image is minimal).
If it says connection refused, the policy above isn't applied correctly.
If it says NXDOMAIN, you need to add the hostAlias or Corefile edit we discussed previously.




Roadmap: The 4 Gates

Gate
Focus
Tooling
Gate 1: Pre-Build
Static Analysis & Secrets
Gitleaks, Bandit
Gate 2: The Build
Vulnerability Scanning
Trivy, Docker
Gate 3: Supply Chain
Model Provenance (AIBOM)
Syft, Cosign
Gate 4: Deployment
Secure Secrets Injection
HashiCorp Vault




Now, we move into the "Sec" part of MLSecOps. We are going to create a pipeline in your Mlsecops-production-pipeline project that builds a model, scans it for vulnerabilities, and then uses the agent to tell ArgoCD to deploy it.

📂 Phase 1: Create the Application Files
On your local machine, inside your cloned Mlsecops-production-pipeline folder, create these three essential files:
1. app/main.py (The ML Logic)
A simple FastAPI app that simulates a model inference endpoint.

from fastapi import FastAPI
import os

app = FastAPI()

@app.get("/")
def home():
    return {"status": "ML Model Online", "version": os.getenv("VERSION", "1.0")}

@app.get("/predict")
def predict(data: str):
    # This is where your model logic would go
    return {"prediction": "safe", "input": data}

2. Dockerfile (The Package)
We use a distroless or slim image to reduce the attack surface—a key SecOps practice.
FROM python:3.11-slim
WORKDIR /app
COPY app/main.py .
RUN pip install fastapi uvicorn
EXPOSE 8000
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]

3. k8s/deployment.yaml (The Infrastructure)
This is what ArgoCD will watch.
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ml-model-deployment
  namespace: ml-production
spec:
  replicas: 1
  selector:
    matchLabels:
      app: ml-classifier
  template:
    metadata:
      labels:
        app: ml-classifier
    spec:
      containers:
      - name: model
        image: gitlab.build.server:5050/your-user/mlsecops-production-pipeline:latest
        ports:
        - containerPort: 8000


Phase 2: Create the .gitlab-ci.yml
This is the "brain" of your pipeline. It has three stages: Build, Scan (Security), and Deploy.
stages:
  - build
  - test
  - deploy

variables:
  IMAGE_TAG: $CI_REGISTRY_IMAGE:$CI_COMMIT_SHORT_SHA

build_image:
  stage: build
  image: docker:24.0.5
  services:
    - docker:24.0.5-dind
  script:
    - docker login -u $CI_REGISTRY_USER -p $CI_REGISTRY_PASSWORD $CI_REGISTRY
    - docker build -t $IMAGE_TAG .
    - docker push $IMAGE_TAG

security_scan:
  stage: test
  image: 
    name: aquasec/trivy:latest
    entrypoint: [""]
  script:
    # Scan the image and fail the pipeline if CRITICAL vulnerabilities are found
    - trivy image --exit-code 1 --severity CRITICAL $IMAGE_TAG

deploy_to_k3s:
  stage: deploy
  image:
    name: bitnami/kubectl:latest
    entrypoint: [""]
  script:
    # 1. Access the cluster via the Tunnel Project's agent
    - kubectl config use-context your-user/mlsecops-tunnel:mlsecops-agent
    # 2. Update the image in the manifest (GitOps update)
    - sed -i "s|image:.*|image: $IMAGE_TAG|g" k8s/deployment.yaml
    # 3. Apply the change (ArgoCD will pick up the rest)
    - kubectl apply -f k8s/deployment.yaml

Phase 3: Connect ArgoCD
Now, log into your ArgoCD UI (the one we exposed via Cilium Gateway earlier) and create the link:
New App -> Name: ml-model.
Project: default.
Sync Policy: Automatic.
Source:
Repository URL: http://gitlab.build.server/your-user/mlsecops-production-pipeline.git
Path: k8s
Destination:
Cluster: https://kubernetes.default.svc
Namespace: ml-production (ArgoCD will create this if it's missing).

🧪 Step 5: The Test
Push your code: git add . && git commit -m "First MLSecOps push" && git push origin main.
Watch GitLab: You will see the Docker image build, then Trivy will scan it. If you used a very old, "vulnerable" base image in your Dockerfile, Trivy would stop the deployment right here!
Watch ArgoCD: Once the deploy stage in GitLab finishes, go to your ArgoCD dashboard. You should see the ml-model-deployment turning green.

