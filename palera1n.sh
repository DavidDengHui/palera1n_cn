#!/bin/bash

mkdir -p logs
set -e
bl="\033[1;30m" bu="\033[1;34m" re="\033[1;31m" ge="\033[1;32m" cd="\033[1;36m" ye="\033[1;33m" pk="\033[1;35m" ed="\033[0m"
log="$(date +%T)"-"$(date +%F)"-"$(uname)"-"$(uname -r)".log
cd logs
touch "$log"
cd ..

{

echo -e "[*]$ye 当前运行命令:`if [ $EUID = 0 ]; then echo " sudo"; fi` ./palera1n.sh $@ $ed"

# =========
# Variables
# =========
os=$(uname)
dir="$(pwd)/binaries/$os"
ver="2.0.0"
commit="DavidDengHui"
Datee="2023.02.08"
max_args=1
arg_count=0

# =========
# Functions
# =========
remote_cmd() {
    "$dir"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p6413 root@localhost "$@"
}

remote_cp() {
    "$dir"/sshpass -p 'alpine' scp -o StrictHostKeyChecking=no -P6413 $@
}

step() {
    for i in $(seq "$1" -1 0); do
        if [ "$(get_device_mode)" = "dfu" ]; then
            break
        fi
        printf '\r\e[K\e[1;36m%s (%d)' "$2" "$i"
        sleep 1
    done
    printf '\e[0m\n'
}

print_help() {
    cat << EOF
Usage: $0 [Options] [ subcommand | iOS version ]
iOS 15.0-16.2 支持checkm8设备的越狱工具

Options:
    --help              打印帮助
    --dfuhelper         dfu进入助手
    --no-baseband       没基带
    --debug             调试模式
    --serial            开启串口输出
    --rootfull          启用rootfull模式

Subcommands:
    dfuhelper           启用 --dfuhelper 参数
    clean               清理创建的文件

iOS版本应该输入当前设备的OS版本号
需要DFU模式才能运行.
EOF
}

parse_opt() {
    case "$1" in
        --)
            no_more_opts=1
            ;;
        --dfuhelper)
            dfuhelper=1
            ;;
        --no-baseband)
            no_baseband=1
            ;;
        --serial)
            serial=1
            ;;
        --debug)
            debug=1
            ;;
        --rootfull)
            rootfull=1
            ;;
        --help)
            print_help
            exit 0
            ;;
        *)
            echo "[-] Unknown option $1. Use $0 --help for help."
            exit 1;
    esac
}

parse_arg() {
    arg_count=$((arg_count + 1))
    case "$1" in
        dfuhelper)
            dfuhelper=1
            ;;
        clean)
            clean=1
            ;;
        *)
            version="$1"
            ;;
    esac
}

parse_cmdline() {
    for arg in $@; do
        if [[ "$arg" == --* ]] && [ -z "$no_more_opts" ]; then
            parse_opt "$arg";
        elif [ "$arg_count" -lt "$max_args" ]; then
            parse_arg "$arg";
        else
            echo "[-] 太多参数. 使用 $0 --help 获取帮助信息.";
            exit 1;
        fi
    done
}

recovery_fix_auto_boot() {
    "$dir"/irecovery -c "setenv auto-boot true"
    "$dir"/irecovery -c "saveenv"
}

_info() {
    if [ "$1" = 'recovery' ]; then
        echo $("$dir"/irecovery -q | grep "$2" | sed "s/$2: //")
    elif [ "$1" = 'normal' ]; then
        echo $("$dir"/ideviceinfo | grep "$2: " | sed "s/$2: //")
    fi
}

_reset() {
    echo "[*] Resetting DFU state"
    "$dir"/gaster reset
}

get_device_mode() {
    if [ "$os" = "Darwin" ]; then
        apples="$(system_profiler SPUSBDataType 2> /dev/null | grep -B1 'Vendor ID: 0x05ac' | grep 'Product ID:' | cut -dx -f2 | cut -d' ' -f1 | tail -r)"
    elif [ "$os" = "Linux" ]; then
        apples="$(lsusb | cut -d' ' -f6 | grep '05ac:' | cut -d: -f2)"
    fi
    local device_count=0
    local usbserials=""
    for apple in $apples; do
        case "$apple" in
            12a8|12aa|12ab)
            device_mode=normal
            device_count=$((device_count+1))
            ;;
            1281)
            device_mode=recovery
            device_count=$((device_count+1))
            ;;
            1227)
            device_mode=dfu
            device_count=$((device_count+1))
            ;;
            1222)
            device_mode=diag
            device_count=$((device_count+1))
            ;;
            1338)
            device_mode=checkra1n_stage2
            device_count=$((device_count+1))
            ;;
            4141)
            device_mode=pongo
            device_count=$((device_count+1))
            ;;
        esac
    done
    if [ "$device_count" = "0" ]; then
        device_mode=none
    elif [ "$device_count" -ge "2" ]; then
        echo "[-] 只连接一台设备" > /dev/tty
        kill -30 0
        exit 1;
    fi
    if [ "$os" = "Linux" ]; then
        usbserials=$(cat /sys/bus/usb/devices/*/serial)
    elif [ "$os" = "Darwin" ]; then
        usbserials=$(system_profiler SPUSBDataType 2> /dev/null | grep 'Serial Number' | cut -d: -f2- | sed 's/ //')
    fi
    if grep -qE '(ramdisk tool|SSHRD_Script) (Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec) [0-9]{1,2} [0-9]{4} [0-9]{2}:[0-9]{2}:[0-9]{2}' <<< "$usbserials"; then
        device_mode=ramdisk
    fi
    echo "$device_mode"
}

_wait() {
    if [ "$(get_device_mode)" != "$1" ]; then
        echo -e "[*]$bu 等待设备进入 $1 模式$ed"
    fi

    while [ "$(get_device_mode)" != "$1" ]; do
        sleep 1
    done

    if [ "$1" = 'recovery' ]; then
        recovery_fix_auto_boot;
    fi
}

_dfuhelper() {
    local step_one;
    deviceid=$( [ -z "$deviceid" ] && _info normal ProductType || echo $deviceid )
    if [[ "$1" = 0x801* && "$deviceid" != *"iPad"* ]]; then
        step_one="按住音量减 + 电源键"
    else
        step_one="按住返回键 + 电源键"
    fi
    echo -e "[*]$bu 按任意键开始进入DFU模式$ed"
    read -n 1 -s
    step 3 "请准备"
    step 4 "$step_one" &
    sleep 3
    "$dir"/irecovery -c "reset" &
    wait
    if [[ "$1" = 0x801* && "$deviceid" != *"iPad"* ]]; then
        step 10 '松开 电源键, 继续按住 音量减'
    else
        step 10 '松开 电源键, 继续按住 返回键'
    fi
    sleep 1

    if [ "$(get_device_mode)" = "dfu" ]; then
        echo -e "[*]$bu 成功进入DFU模式!$ed"
    else
        echo -e "[*]$bu 进入DFU模式失败,请重新运行程序!$ed"
        return -1
    fi
}

_kill_if_running() {
    if (pgrep -u root -xf "$1" &> /dev/null > /dev/null); then
        # yes, it's running as root. kill it
        sudo killall $1
    else
        if (pgrep -x "$1" &> /dev/null > /dev/null); then
            killall $1
        fi
    fi
}

_exit_handler() {
    [ $? -eq 0 ] && exit
    echo "[-] 当前代码报错"

    if [ -d "logs" ]; then
        cd logs
        mv "$log" FAIL_${log}
        cd ..
    fi

    echo "[*] 已制作失败日志."
}
trap _exit_handler EXIT

# ===========
# Fixes
# ===========

# ============
# Dependencies
# ============

# Check for required commands
if [ "$os" = 'Linux' ]; then
    linux_cmds='lsusb'
fi

for cmd in curl unzip python3 git ssh scp killall sudo grep pgrep ${linux_cmds}; do
    if ! command -v "${cmd}" > /dev/null; then
        echo "[-] Command '${cmd}' not installed, please install it!";
        cmd_not_found=1
    fi
done
if [ "$cmd_not_found" = "1" ]; then
    exit 1
fi

# Download gaster


# Download checkra1n


# ============
# Prep
# ============

# Update submodules

# Re-create work dir if it exists, else, make it
if [ -e work ]; then
    rm -rf work
    mkdir work
else
    mkdir work
fi

chmod +x "$dir"/*
#if [ "$os" = 'Darwin' ]; then
#    xattr -d com.apple.quarantine "$dir"/*
#fi

# ============
# Start
# ============

echo -e "[*] $bu palera1n $ed | $pk 版本号:$ed $pk $ver -$bu $commit  $pk 更新日期: $Datee $ed"
sleep 1
echo -e "$bu Nebula和Mineek原创编写 | 部分代码来自Nathan的ramdisk. $ed"
echo -e "$bu 特别感谢 checkra1n 团队的辛勤工作,开源代码和启发. $ed"
echo -e "$bu 即使我们使用 checkra1n,我们也不以任何方式,形式或形式隶属于他们. $ed"
echo -e "$bu 这个工具是独立项目,没有得到 checkra1n 的认可,也不被他们支持. $ed"
echo -e "$bu palera1n按原样提供，不提供任何明示或暗示的保证. $ed"
echo -e "$bu palera1n对您的设备可能发生的任何损坏、数据丢失或任何其他问题概不负责. $ed"
echo ""

version=""
parse_cmdline "$@"

if [ "$debug" = "1" ]; then
    set -o xtrace
fi

if [ "$rootfull" = "1" ]; then
    echo -e "$ye[*] 警告：将使用rootfull模式越狱,这是半限制,需要引导越狱!$ed"
    echo -e "$ye[*] 您是否 100% 确定要继续? (y/n)$ed"
    read -n 1 -s
    if [ "$REPLY" != "y" ]; then
        echo "[-] 退出"
        exit 1
    fi
fi

if [ "$rootfull" = "1" ]; then
    echo -e "$re[!] 越狱完成后的必须步骤:$ed"
    echo -e "$re[!] 终端输入:$bu'bootstrap'$re 安装越狱环境.$ed"
    echo "[!] 耐心等待5分钟,Sileo 和 Substitute 将被安装到iOS设备."
fi

if [ "$clean" = "1" ]; then
    rm -rf boot* work .tweaksinstalled
    echo "[*] 移除创建的文件"
    exit
fi

# Get device's iOS version from ideviceinfo if in normal mode
echo -e "[*]$bu 等待设备连接 $ed"
while [ "$(get_device_mode)" = "none" ]; do
    sleep 1;
done
echo $(echo -e "[*]$bu 当前设备是: $(get_device_mode) 模式 $ed" | sed 's/dfu/DFU/')

if grep -E 'pongo|checkra1n_stage2|diag' <<< "$(get_device_mode)"; then
    echo -e "[*]$bu 检测到的设备处于不受支持的模式 '$(get_device_mode)' $ed"
    exit 1;
fi

if [ "$(get_device_mode)" != "normal" ] && [ -z "$version" ] && [ "$dfuhelper" != "1" ]; then
    echo -e "[*]$bu 没有从正常模式启动时，您必须输入设备的iOS版本 $ed"
    exit
fi

if [ "$(get_device_mode)" = "ramdisk" ]; then
    # If a device is in ramdisk mode, perhaps iproxy is still running?
    _kill_if_running iproxy
    echo -e "[*]$bu 重启设备连接SSH Ramdisk $ed"
    if [ "$os" = 'Linux' ]; then
        sudo "$dir"/iproxy 6413 22 &
    else
        "$dir"/iproxy 6413 22 &
    fi
    sleep 2
    remote_cmd "/usr/sbin/nvram auto-boot=false"
    remote_cmd "/sbin/reboot"
    _kill_if_running iproxy
    _wait recovery
fi

if [ "$(get_device_mode)" = "normal" ]; then
    version=${version:-$(_info normal ProductVersion)}
    arch=$(_info normal CPUArchitecture)
    if [ "$arch" = "arm64e" ]; then
        echo -e "[-]$bu palera1n不支持非check8设备,也永远不会支持$ed"
        exit
    fi
    echo "Hello, $(_info normal ProductType) on $version!"

    echo -e "[*]$bu 切换到恢复模式...稍等10秒钟 $ed"
    "$dir"/ideviceenterrecovery $(_info normal UniqueDeviceID)
    _wait recovery
fi

# Grab more info
echo -e "[*]$bu 读取设备信息中...$ed"
cpid=$(_info recovery CPID)
model=$(_info recovery MODEL)
deviceid=$(_info recovery PRODUCT)

if [ "$dfuhelper" = "1" ]; then
    echo -e "[*]$bu 运行 DFU 模式助手$ed"
    _dfuhelper "$cpid"
    exit
fi

# Have the user put the device into DFU
if [ "$(get_device_mode)" != "dfu" ]; then
    recovery_fix_auto_boot;
    _dfuhelper "$cpid" || {
        echo "[-] 进入DFU模式失败,请重新运行工具"
        exit -1
    }
fi
sleep 2

# ============
# Boot device
# ============

sleep 2
_reset
echo -e "[*]$bu 启动设备中 ...$ed"

echo -e "[!]$bu  越狱完成后，您需要手动引导bootstrap. $ed"
echo -e "[!]$bu  您可以通过运行"iproxy 1337 1337"开启SSH通道 $ed"
echo -e "[!]$bu  运行命令 'nc 127.1 1337'连接通道,输入'bootstrap' 安装越狱. $ed"
echo -e "[!]$bu  几秒钟后,Sileo 和 Substitute 将被安装. $ed"

# if rootfull, use "$dir"/checkra1n -r other/rootedramdisk.dmg -k other/pongo.bin -K other/checkra1n-kpf-pongo
if [ "$rootfull" = "1" ]; then
    "$dir"/checkra1n -r other/rootedramdisk.dmg -k other/pongo.bin -K other/checkra1n-kpf-pongo
elif [ "$version" = "15"* ]; then
    "$dir"/checkra1n -r other/rootless/rd15.dmg -k other/pongo.bin -K other/checkra1n-kpf-pongo
else
    "$dir"/checkra1n -r other/rootless/rd16.dmg -k other/pongo.bin -K other/checkra1n-kpf-pongo
fi

if [ -d "logs" ]; then
    cd logs
     mv "$log" SUCCESS_${log}
    cd ..
fi

echo -e "[!]$bu  越狱完成后，您需要手动引导bootstrap. $ed"
echo -e "[!]$bu  您可以通过运行"iproxy 1337 1337"开启SSH通道 $ed"
echo -e "[!]$bu  运行命令 'nc 127.1 1337'连接通道,输入'bootstrap' 安装越狱. $ed"
echo -e "[!]$bu  几秒钟后,Sileo 和 Substitute 将被安装. $ed"

} 2>&1 | tee logs/${log}
