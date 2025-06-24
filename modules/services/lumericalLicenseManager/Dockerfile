# 大概这样做：
# cp -r ~/repo/stuff/44/Lumerical_Suite_2023_R1_CentOS/{LicenseManager,Crack,License} .
# sed -i s/xxxxxxxxxxxxx/745d22c7d297/ License/license.txt
# sed -i s/2022.1231/2026.1231/ License/license.txt
# podman build .
# podman image save 7bb3a43bd1ad6103a57f700b13d11d486b6ea117838201e4a29d79b33ac72e3a > image.tar
# nix store add-file ./image.tar --name lumericalLicenseManager.tar
# nix hash file /nix/store/sh4mrjsm40zf88xdr9qywhc0lv7rd4ck-lumericalLicenseManager.tar

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
