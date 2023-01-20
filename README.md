# Flussonic Loadbalancing Tests

### Run Terraform

``` sh
terraform plan
terraform apply
```

### Run Ansible

```sh
ansible-playbook -i hosts -e "ansible_ssh_user=ubuntu" --private-key=~/.ssh/flussonic_test.pem playbooks/ingest_proxy.yml
ansible-playbook -i hosts -e "ansible_ssh_user=ubuntu" --private-key=~/.ssh/flussonic_test.pem playbooks/ingest_cluster.yml
ansible-playbook -i hosts -e "ansible_ssh_user=ubuntu" --private-key=~/.ssh/flussonic_test.pem playbooks/edge_cluster.yml
```
