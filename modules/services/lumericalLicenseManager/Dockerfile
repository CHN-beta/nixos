# 大概这样做：
# cp -r ~/repo/stuff/44/Lumerical_Suite_2023_R1_CentOS/{LicenseManager,Crack,License} .
# podman build .
# podman image save --format oci-archive 6803f9562b941c23db81a2eae5914561f96fa748536199a010fe6f24922b2878 -o image.tar
# singularity build image.sif oci-archive://image.tar
# nix store add-file ./image.tar --name lumericalLicenseManager.tar
# nix hash file /nix/store/v626n153vdr8sib52623gx1ych8zfsa6-lumericalLicenseManager.tar
# nix store add-file ./image.sif --name lumericalLicenseManager.sif
# nix hash file /nix/store/wr4i09smarzwyn1g2jhxlpkxghcwa01l-lumericalLicenseManager.sif

FROM centos:7

USER root

COPY ./LicenseManager /tmp/LicenseManager
RUN chmod +x /tmp/LicenseManager/INSTALL && \
  /tmp/LicenseManager/INSTALL -silent -install_dir /home/ansys_inc -lm && \
  rm -rf /tmp/LicenseManager
COPY ./Crack/ansys_inc/ /home/ansys_inc
# RUN sed -i "s|127.0.0.1|0.0.0.0|g" /home/ansys_inc/shared_files/licensing/tools/tomcat/conf/server.xml
RUN chmod -R 777 /home/ansys_inc
RUN ln -s ld-linux-x86-64.so.2 /lib64/ld-lsb-x86-64.so.3
COPY ./License/license.txt /home/ansys_inc/shared_files/licensing/license_files/ansyslmd.lic

WORKDIR /home/ansys_inc/shared_files/licensing
CMD ["/bin/sh", "-c", "(./start_ansysli &); (./start_lmcenter &); tail -f /dev/null"]
