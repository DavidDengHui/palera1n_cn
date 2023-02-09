#!/bin/bash
bl="\033[1;30m" bu="\033[1;34m" re="\033[1;31m" ge="\033[1;32m" cd="\033[1;36m" ye="\033[1;33m" pk="\033[1;35m" ed="\033[0m"
if ! iproxy -v >/dev/null 2>&1; then
echo -e "$bu[*]iproxy 没有安装$ed"
exit
fi

echo -e "$bu[*]越狱前准备...$ed"
IPROXY=$(iproxy 28605 44 >/dev/null 2>&1 & echo $!)

unzstd bootstrap-ssh-iphoneos-arm64.tar.zst

echo -e "$bu[*]拷贝文件到设备... $ed"
echo -e "$bu[*]默认密码password是: alpine $ed"
if scp -O /dev/null /dev/zero 2>/dev/null; then
    scp -O -qP28605 -o "StrictHostKeyChecking no" -o "UserKnownHostsFile=/dev/null" bootstrap-ssh-iphoneos-arm64.tar \
    org.coolstar.sileonightly_2.4_iphoneos-arm64.deb \
    ellekit_rootless.deb \
    preferenceloader_2.2.6-1debug_iphoneos-arm64.deb \
    src/iphoneos-arm64/install.sh \
    root@127.0.0.1:/var/root/
else
    scp -qP28605 -o "StrictHostKeyChecking no" -o "UserKnownHostsFile=/dev/null" bootstrap-ssh-iphoneos-arm64.tar \
    org.coolstar.sileonightly_2.4_iphoneos-arm64.deb \
    ellekit_rootless.deb \
    preferenceloader_2.2.6-1debug_iphoneos-arm64.deb \
    src/iphoneos-arm64/install.sh \
    root@127.0.0.1:/var/root/
fi

echo -e "$bu[*]安装越狱环境到设备...$ed"
ssh -qp28605 -o "StrictHostKeyChecking no" -o "UserKnownHostsFile=/dev/null" root@127.0.0.1 "/var/pkg/bin/bash /var/root/install.sh"

rm -rf bootstrap-ssh-iphoneos-arm64.tar

kill "$IPROXY"
