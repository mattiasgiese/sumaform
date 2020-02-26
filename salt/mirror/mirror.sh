#!/bin/bash
set -e
set -x

cd /srv/mirror
minima -c /root/minima.yaml sync 2>&1 | tee /var/log/minima.log
/root/refresh_scc_data.py {{ grains.get("cc_username") }}:{{ grains.get("cc_password") }}

apt-mirror
# check for nvidia repo and create links, if necessary
if [ -d suse ]; then
  mkdir -p RPMMD
  for dir in suse/sle* ; do
    d=${dir^^}
    ver=${d#SUSE/SLE}
    if [[ $ver == ${ver%SP*} ]]; then
      target="${ver}-GA"
    else
      target=${ver/SP/-SP}
    fi
    full_path=RPMMD/${target}-Desktop-NVIDIA-Driver
    if [ ! -e ${full_path} ]; then
      ln -s ../suse/$dir ${full_path}
    fi
  done
fi

{% if grains.get('use_mirror_images') %}
wget --mirror --no-host-directories "https://github.com/moio/sumaform-images/releases/download/4.3.0/centos7.qcow2"
wget --mirror --no-host-directories "https://download.opensuse.org/repositories/systemsmanagement:/sumaform:/images:/libvirt/images/opensuse150.x86_64.qcow2"
wget --mirror --no-host-directories "https://download.opensuse.org/repositories/systemsmanagement:/sumaform:/images:/libvirt/images/opensuse151.x86_64.qcow2"
wget --mirror --no-host-directories "http://download.suse.de/ibs/Devel:/Galaxy:/Terraform:/Images/images/sles15.x86_64.qcow2"
wget --mirror --no-host-directories "http://download.suse.de/ibs/Devel:/Galaxy:/Terraform:/Images/images/sles15sp1.x86_64.qcow2"
wget --mirror --no-host-directories "http://download.suse.de/ibs/Devel:/Galaxy:/Terraform:/Images/images/sles11sp4.x86_64.qcow2"
wget --mirror --no-host-directories "http://download.suse.de/ibs/Devel:/Galaxy:/Terraform:/Images/images/sles12.x86_64.qcow2"
wget --mirror --no-host-directories "http://download.suse.de/ibs/Devel:/Galaxy:/Terraform:/Images/images/sles12sp1.x86_64.qcow2"
wget --mirror --no-host-directories "http://download.suse.de/ibs/Devel:/Galaxy:/Terraform:/Images/images/sles12sp2.x86_64.qcow2"
wget --mirror --no-host-directories "http://download.suse.de/ibs/Devel:/Galaxy:/Terraform:/Images/images/sles12sp3.x86_64.qcow2"
wget --mirror --no-host-directories "http://download.suse.de/ibs/Devel:/Galaxy:/Terraform:/Images/images/sles12sp4.x86_64.qcow2"
wget --mirror --no-host-directories "https://github.com/moio/sumaform-images/releases/download/4.4.0/ubuntu1804.qcow2"
{% endif %}

jdupes --linkhard -r -s /srv/mirror/

chmod -R 777 .
