echo "Configuring Systemctl ModProbe Overlay and Netfilter"
sudo modprobe overlay
sudo modprobe br_netfilter
echo "Enabling IP forwarding so that our pods can communicate with each other"
sudo tee /etc/sysctl.d/kubernetes.conf<<EOF
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF
sudo sysctl --system

echo "Installing Docker..."
sudo yum install -y yum-utils device-mapper-persistent-data lvm2
sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
sudo yum install -y docker-ce docker-ce-cli containerd.io
sudo mkdir /etc/docker
sudo mkdir -p /etc/systemd/system/docker.service.d

sudo tee /etc/docker/daemon.json <<EOF
{
"exec-opts": ["native.cgroupdriver=systemd"],
"log-driver": "json-file",
"log-opts": {
"max-size": "100m"
},
"storage-driver": "overlay2",
"storage-opts": [
"overlay2.override_kernel_check=true"
]
}
EOF

sudo systemctl daemon-reload
sudo systemctl restart docker
sudo systemctl enable docker

echo "Your Docker Version is :"
sudo docker --version

echo "Disabling Firewall if enabled"
sudo systemctl disable --now firewalld

echo "Checking Netfilter Availability"
lsmod | grep br_netfilter

echo "Enabling Kubelet"
sudo systemctl enable kubelet
sudo kubeadm config images pull

echo "WHICH CNI YOU WANT TO CHOOSE CALICO OR FLANNEL ENTER BELOW IN SMALL CAPS"
read cni
if [ $cni == flannel ]
then
echo "Enter the control plane"
read ip
echo "Kubeadm Intialzing Advertising the Public IP on This Master Node"
sudo kubeadm init --pod-network-cidr=10.244.0.0/16 --upload-certs --control-plane-endpoint=$1p
echo "Installing Flanner Network"
kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml
fi

if [ $cni == calico ]
then
echo "Enter the control plane"
read ip1
echo "Kubeadm Intialzing Advertising the Public IP on This Master Node"
sudo kubeadm init --pod-network-cidr=192.168.0.0/16 --upload-certs --control-plane-endpoint=$ip1
echo "Installing Calico Network"
kubectl create -f https://docs.projectcalico.org/manifests/tigera-operator.yaml 
kubectl create -f https://docs.projectcalico.org/manifests/custom-resources.yaml
fi


# if [ $cni == flannel ]
# then
# echo "Installing Calico Network"
# kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml
# fi

# if [ $cni == calico ]
# then
# echo "Installing Calico Network"
# kubectl create -f https://docs.projectcalico.org/manifests/tigera-operator.yaml 
# kubectl create -f https://docs.projectcalico.org/manifests/custom-resources.yaml
# fi

#Fix the Error – The connection to the server localhost:8080 was refused
export KUBECONFIG=/etc/kubernetes/admin.conf
sudo cp /etc/kubernetes/admin.conf $HOME/
sudo chown $(id -u):$(id -g) $HOME/admin.conf
export KUBECONFIG=$HOME/admin.conf

echo "Checking Status of Nodes"
sudo kubectl get nodes

echo "Checking Status of Nodes After Applying Calico Network"
sudo kubectl get nodes
