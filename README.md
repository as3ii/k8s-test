# Kube-cluster

### Create the VM template in proxmox (based on debian 13)
```bash
curl -LO https://cloud.debian.org/images/cloud/trixie/latest/debian-13-genericcloud-amd64.qcow2
qm create 9100 --cores 2 --memory 2048 --balloon 256 --name debian13 --net0 virtio,bridge=vmbr0
qm importdisk 9100 debian-13-genericcloud-amd64.qcow2 local-lvm
qm set 9100 --scsihw virtio-scsi-single --scsi0 local-lvm:vm-9100-disk-0,iothread=on,ssd=on,discard=on
qm set 9100 --ide0 local-lvm:cloudinit
qm set 9100 --boot order=scsi0
qm set 9100 --serial0 socket --vga serial0
qm set 9100 --agent enabled=1
# Here configure the cloud-init image via CLI or web UI
# Next regenerate the cloud-init image and check that everything is fine
qm template 9100
```

### Deploy VMs and basic DNS records
```bash
cd terraform
just deploy
cd ..
```

### VMs setup and deploy k3s
This will setup kube-vip via static charts
```bash
cd ansible
cp inventory.yaml.template inventory.yaml
# edit inventory.yaml
just deploy
cd ..
```
