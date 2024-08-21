#!/bin/bash

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

version="v1.0.0"

# Check root
if [[ $EUID -ne 0 ]]; then
    echo -e "${red}错误: ${plain} 必须使用root用户运行此脚本！\n"
    exit 1
fi

# Check if the OS is Alpine Linux
if [[ -f /etc/alpine-release ]]; then
    release="alpine"
else
    echo -e "${red}未检测到Alpine系统，请联系脚本作者！${plain}\n"
    exit 1
fi

confirm() {
    local prompt default reply
    prompt="$1"
    default="$2"

    echo && read -p "$prompt [默认$default]: " reply
    reply="${reply:-$default}"

    if [[ $reply =~ ^[Yy]$ ]]; then
        return 0
    else
        return 1
    fi
}

install() {
    bash <(curl -Ls https://raw.githubusercontent.com/Arsierl/alpinesoga/main/install.sh)
    if [[ $? -eq 0 ]]; then
        start
    fi
}

update() {
    read -p "输入指定版本(默认最新版): " version
    version="${version:-latest}"

    bash <(curl -Ls https://raw.githubusercontent.com/Arsierl/alpinesoga/main/install.sh) $version

    if [[ $? -eq 0 ]]; then
        echo -e "${green}更新完成，已自动重启 soga，请使用 soga log 查看运行日志${plain}"
        exit
    fi
}

config() {
    soga-tool "$@"
}

uninstall() {
    if confirm "确定要卸载 soga 吗?" "n"; then
        rc-service soga stop
        rc-update del soga
        rm /etc/init.d/soga -f
        rm -rf /etc/soga/ /usr/local/soga/
        echo -e "${green}卸载成功${plain}"
    fi
}

start() {
    rc-service soga start
    if rc-service soga status | grep -q "started"; then
        echo -e "${green}soga 启动成功${plain}"
    else
        echo -e "${red}soga 启动失败${plain}"
    fi
}

stop() {
    rc-service soga stop
    if ! rc-service soga status | grep -q "started"; then
        echo -e "${green}soga 停止成功${plain}"
    else
        echo -e "${red}soga 停止失败${plain}"
    fi
}

restart() {
    rc-service soga restart
    if rc-service soga status | grep -q "started"; then
        echo -e "${green}soga 重启成功${plain}"
    else
        echo -e "${red}soga 重启失败${plain}"
    fi
}

enable() {
    rc-update add soga
    if [[ $? -eq 0 ]]; then
        echo -e "${green}soga 设置开机自启成功${plain}"
    else
        echo -e "${red}soga 设置开机自启失败${plain}"
    fi
}

disable() {
    rc-update del soga
    if [[ $? -eq 0 ]]; then
        echo -e "${green}soga 取消开机自启成功${plain}"
    else
        echo -e "${red}soga 取消开机自启失败${plain}"
    fi
}

show_log() {
    tail -f /var/log/soga.log
}

update_shell() {
    wget -O /usr/bin/soga -N --no-check-certificate https://raw.githubusercontent.com/Arsierl/alpinesoga/main/soga.sh
    if [[ $? -ne 0 ]]; then
        echo -e "${red}下载脚本失败，请检查本机能否连接 Github${plain}"
    else
        chmod +x /usr/bin/soga
        echo -e "${green}升级脚本成功，请重新运行脚本${plain}"
        exit 0
    fi
}

check_status() {
    if ! rc-service soga status | grep -q "started"; then
        return 1
    else
        return 0
    fi
}

show_status() {
    if check_status; then
        echo -e "soga状态: ${green}已运行${plain}"
    else
        echo -e "soga状态: ${red}未运行${plain}"
    fi

    if rc-update | grep -q "soga"; then
        echo -e "是否开机自启: ${green}是${plain}"
    else
        echo -e "是否开机自启: ${red}否${plain}"
    fi
}

show_menu() {
    echo -e "
  ${green}soga 后端管理脚本 (适用于Alpine Linux)${plain}

  ${green}0.${plain} 退出脚本
  ${green}1.${plain} 安装 soga
  ${green}2.${plain} 更新 soga
  ${green}3.${plain} 卸载 soga
  ${green}4.${plain} 启动 soga
  ${green}5.${plain} 停止 soga
  ${green}6.${plain} 重启 soga
  ${green}7.${plain} 查看 soga 日志
  ${green}8.${plain} 设置 soga 开机自启
  ${green}9.${plain} 取消 soga 开机自启
  ${green}10.${plain} 查看 soga 状态
 "
    read -p "请输入选择 [0-10]: " num

    case "$num" in
        0) exit 0 ;;
        1) install ;;
        2) update ;;
        3) uninstall ;;
        4) start ;;
        5) stop ;;
        6) restart ;;
        7) show_log ;;
        8) enable ;;
        9) disable ;;
        10) show_status ;;
        *) echo -e "${red}请输入正确的数字 [0-10]${plain}" ;;
    esac
}

if [[ $# -gt 0 ]]; then
    case "$1" in
        start) start ;;
        stop) stop ;;
        restart) restart ;;
        enable) enable ;;
        disable) disable ;;
        log) show_log ;;
        update) update ;;
        config) config "$@" ;;
        install) install ;;
        uninstall) uninstall ;;
        version) /usr/local/soga/soga -v ;;
        *) show_menu ;;
    esac
else
    show_menu
fi
