#!/bin/sh

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

cur_dir=$(pwd)

# Check root
if [ "$EUID" -ne 0 ]; then
    echo -e "${red}错误：${plain} 必须使用root用户运行此脚本！\n"
    exit 1
fi

# Check OS
if grep -Eqi "alpine" /etc/issue || grep -Eqi "alpine" /proc/version; then
    release="alpine"
else
    echo -e "${red}未检测到Alpine系统，请联系脚本作者！${plain}\n"
    exit 1
fi

arch=$(arch)

if [ "$arch" = "x86_64" ] || [ "$arch" = "x64" ] || [ "$arch" = "amd64" ]; then
    arch="amd64"
elif [ "$arch" = "aarch64" ] || [ "$arch" = "arm64" ]; then
    arch="arm64"
else
    arch="amd64"
    echo -e "${red}检测架构失败，使用默认架构: ${arch}${plain}"
fi

echo "架构: ${arch}"

if [ "$(getconf WORD_BIT)" != '32' ] && [ "$(getconf LONG_BIT)" != '64' ] ; then
    echo "本软件不支持 32 位系统(x86)，请使用 64 位系统(x86_64)，如果检测有误，请联系作者"
    exit 2
fi

install_base() {
    apk update
    apk add wget curl tar openrc socat tzdata
}

check_status() {
    if ! rc-service soga status > /dev/null 2>&1; then
        return 2
    fi
    if rc-service soga status | grep -q "running"; then
        return 0
    else
        return 1
    fi
}

install_acme() {
    curl https://get.acme.sh | sh
    /root/.acme.sh/acme.sh --set-default-ca --server letsencrypt
}

install_soga() {
    cd /usr/local/
    if [ -e /usr/local/soga/ ]; then
        rm /usr/local/soga/ -rf
    fi

    if [ $# -eq 0 ]; then
        echo -e "开始安装 soga 最新版"
        wget -N --no-check-certificate -O /usr/local/soga.tar.gz https://github.com/vaxilu/soga/releases/latest/download/soga-linux-${arch}.tar.gz
        if [ $? -ne 0 ]; then
            echo -e "${red}下载 soga 失败，请确保你的服务器能够下载 Github 的文件${plain}"
            exit 1
        fi
    else
        last_version=$1
        url="https://github.com/vaxilu/soga/releases/download/${last_version}/soga-linux-${arch}.tar.gz"
        echo -e "开始安装 soga v$1"
        wget -N --no-check-certificate -O /usr/local/soga.tar.gz ${url}
        if [ $? -ne 0 ]; then
            echo -e "${red}下载 soga v$1 失败，请确保此版本存在${plain}"
            exit 1
        fi
    fi

    tar zxvf soga.tar.gz
    rm soga.tar.gz -f
    cd soga
    chmod +x soga
    last_version="$(./soga -v)"
    mkdir -p /etc/soga/
    rm /etc/init.d/soga -f
    cp -f soga.init /etc/init.d/soga
    chmod +x /etc/init.d/soga
    rc-update add soga default
    echo -e "${green}soga v${last_version}${plain} 安装完成，已设置开机自启"
    if [ ! -f /etc/soga/soga.conf ]; then
        cp soga.conf /etc/soga/
        echo -e ""
        echo -e "全新安装，请先配置必要的内容"
    else
        rc-service soga start
        sleep 2
        check_status
        echo -e ""
        if [ $? -eq 0 ]; then
            echo -e "${green}soga 重启成功${plain}"
        else
            echo -e "${red}soga 可能启动失败，请稍后使用 soga log 查看日志信息${plain}"
        fi
    fi

    if [ ! -f /etc/soga/blockList ]; then
        cp blockList /etc/soga/
    fi
    if [ ! -f /etc/soga/dns.yml ]; then
        cp dns.yml /etc/soga/
    fi
    if [ ! -f /etc/soga/routes.toml ]; then
        cp routes.toml /etc/soga/
    fi
    curl -o /usr/bin/soga -Ls https://raw.githubusercontent.com/vaxilu/soga/master/soga.sh
    chmod +x /usr/bin/soga
    curl -o /usr/bin/soga-tool -Ls https://raw.githubusercontent.com/vaxilu/soga/master/soga-tool-${arch}
    chmod +x /usr/bin/soga-tool
    echo -e ""
    echo "soga 管理脚本使用方法: "
    echo "------------------------------------------"
    echo "soga                    - 显示管理菜单 (功能更多)"
    echo "soga start              - 启动 soga"
    echo "soga stop               - 停止 soga"
    echo "soga restart            - 重启 soga"
    echo "soga status             - 查看 soga 状态"
    echo "soga enable             - 设置 soga 开机自启"
    echo "soga disable            - 取消 soga 开机自启"
    echo "soga log                - 查看 soga 日志"
    echo "soga update             - 更新 soga"
    echo "soga update
