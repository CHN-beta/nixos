# 大概这样做：
# cp ~/repo/stuff/44/xxxx/{LicenseManager,Crack,License} .
# sed -i s/xxxx/000123456789/ License/license.txt
# docker build . -t lumericallicensemanager:2023r1
# docker image save > image.tar
# nix store add-file ./image.tar --name lumericalLicenseManager.tar
# nix hash file /nix/store/g9f9xjfkvp1kbarz19i6qw7i9fg9pagx-lumericalLicenseManager.tar

FROM centos:7

USER root

COPY ./LicenseManager /tmp/LicenseManager
RUN chmod +x /tmp/LicenseManager/INSTALL && \
  /tmp/LicenseManager/INSTALL -silent -install_dir /home/ansys_inc -lm && \
  rm -rf /tmp/LicenseManager
COPY ./Crack/ansys_inc/ /home/ansys_inc
RUN sed -i "s|127.0.0.1|0.0.0.0|g" /home/ansys_inc/shared_files/licensing/tools/tomcat/conf/server.xml
RUN chmod -R 777 /home/ansys_inc
RUN ln -s ld-linux-x86-64.so.2 /lib64/ld-lsb-x86-64.so.3
COPY ./License/license.txt /home/ansys_inc/shared_files/licensing/license_files/ansyslmd.lic

WORKDIR /home/ansys_inc/shared_files/licensing
CMD ["/bin/sh", "-c", "(./start_ansysli &); (./start_lmcenter &); tail -f /dev/null"]
