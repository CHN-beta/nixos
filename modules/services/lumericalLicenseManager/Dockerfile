# 大概这样做：
# cp -r ~/repo/stuff/44/Lumerical_Suite_2023_R1_CentOS/{LicenseManager,Crack,License} .
# sed -i s/xxxxxxxxxxxxx/745d22c7d297/ License/license.txt
# docker build . -t lumericallicensemanager:2023r1
# docker image save aae2c2c839a4761d7291f84cdcfe9a7598e7a273dc76ad4587f924a8bb87ad8f > image.tar
# nix store add-file ./image.tar --name lumericalLicenseManager.tar
# nix hash file /nix/store/cbyspr2q52l691xydc6r4r6v4qkdf9p8-lumericalLicenseManager.tar

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
