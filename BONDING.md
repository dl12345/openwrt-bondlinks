# Introduction to bonding two internet links

This code was used to run two internet links bonded together into a single fast pipe for over a year. When originally investigating this scenario, it became apparent that there were no freely available solutions that worked out of the box. I found a number of commercial services that offered a bonded link, however they all kept their technique a secret. As a result, I decide to roll my own solution using OpenWrt. It took considerable effort to get a working solution and I always meant to document it and package it up. Here it is.

# Background and Prerequisites

This howto requires an advanced level of skill. You will need to compile your own image as it requires a kernel modification to the bonding driver in order to allow the bonding of a point-to-point link, something which is normally impossible as the kernel driver will reject an interface with no MAC address. This is also not a hotwo in which every step you need to take is outlined in detail here: some things you will need to know how to do yourself, such as generate x509 certificates and keys for openvpn and manage Linux services. You will also need more than a passing familiarity with firewalls and NAT.

You will need a hardware platform for OpenWrt that is capable of the necessary AES throughput that can support wire speed encryption. For this project, I built my own router as most commercial consumer routers tend to top out at about 15Mbps of throughput. I used a platform based on the Intel C2558 SoC, using a Supermicro A1SRi-2558F motherboard. This is a 64 bit 4 core Atom processor with AES-NI hardware acceleration capable of sustaining 3 - 4Gbps of AES throughput. It's important to note that if you don't use a powerful enough platform, you simply won't get the performance you're expecting. 

You will also need to get a VM in a datacentre to serve as the endpoint for your bonded connection. The most important thing (apart from the pricing of your host) is the latency between you and the datacentre, as this will impact your maximum achievable speed. The latency between my router and the datacentre is 5ms. You also need to have a sufficiently powerful instance that can support your wirespeed encryption. Depending on the OS you use, you may also need to make a kernel modification (Centos 6 requires no kernel mod, whereas Centos 7 does). Your VM provider will need to be able to allocate you two static IP addresses on your VM.

In addition, you will need two internet links. I bonded two ADSL links from BT, opting for one of their business class connections with a higher quality of service than the consumer connections (priority over all consumer traffic). For each connection, you will require a static IP address. It's important to get two links that are as symmetrical as possible in terms of latency and sync speed, as the maximum performance is approximately 90% of 2x the slowest link.

In a nutshell, this is an expensive solution. It's cheaper to get a faster line than to bond two lines together. I only did this because my road was bypassed by fibre. Total cost for the lines and the VM amounts to about £110 pounds sterling per month. The ADSL business class lines are expensive and you could definitely get a cheaper solution by opting for a consumer class connection if your provider can offer static IP addresses (normally only the province of a business class line), but the business class connections offer substantially less latency and so contribute significantly to an improved throughput.

Performance-wise, it's actually pretty good. I bonded together two annex M ADSL connections that sync at about 12Mbps each. The resulting throughput of the bonded connection is 22Mbps download and a similar combined performance on the upload. Practically speaking, you achieve about a 90% efficiency. However, I would expect this to drop significantly as you add more links. 

Graphically, the setup looks as follows

![Bonding Image](https://raw.githubusercontent.com/dl12345/openwrt-packages/for-15.05/images/bonding.jpg)

The solution I crafted uses a modified kernel bonding driver, some source routing wizardry and a couple of scripts. It's configured with a standard OpenWrt UCI script. I would strongly recommend that you read the scripts carefully in order to understand what they do as otherwise trouble shooting becomes a stab in the dark.

Your custom image requires a number of command line programs in order to work. In no specific order, these are 


* /usr/sbin/ip
* /sbin/route
* /usr/sbin/openvpn
* /usr/bin/socat
* /sbin/ifconfig


You will also require a number of packages


* openvpn
* socat
* logger
* python and python-expat for the speedtest

The kernel patch, the necessary packages and the scripts are all installed by the bonding package in this repository. **Before** launching a top level make, be sure to run the prepare method of the bonding package to install the kernel patch, otherwise it won't be installed and your bonding won't work. The rest of the steps below are automatically performed on openwrt but the server machine needs to be setup manually. 

```
openwrt@openwrt-host.git]$ make package/bondlink/prepare V=s
```

We will deal first with the OpenWrt configuration and then with the configuration of the VM in the data centre.

# Kernel

The critical element to this solution is the patch to the kernel bonding driver that allows a point-to-point interface to be made a slave to a bonding master. Normally, the driver will refuse to bond a point-to-point interface in kernels above 2.x. It's a simple patch that just involves commenting out a section of code. This patch will almost certainly break the bonding driver for other applications. Of course, you must also make sure that the bonding driver is activated in the OpenWrt configuration.

If you're using a kernel on your datacentre VM that is > 2.x, then you will also need to apply this patch to your datacentre VM kernel. Centos 6 works out of the box with no kernel changes needed.

```
--- a/drivers/net/bonding/bond_main.c
+++ b/drivers/net/bonding/bond_main.c
@@ -1303,11 +1303,11 @@ int bond_enslave(struct net_device *bond
             if (!bond_has_slaves(bond)) {
                 bond->params.fail_over_mac = BOND_FOM_ACTIVE;
                 netdev_warn(bond_dev, "Setting fail_over_mac to active for active-backup mode\n");
-            } else {
+            } /*else {
                 netdev_err(bond_dev, "The slave device specified does not support setting the MAC address, but fail_over_mac is not set to active\n");
                 res = -EOPNOTSUPP;
                 goto err_undo_flags;
-            }
+            } */
         }
     }
 
@@ -1355,7 +1355,7 @@ int bond_enslave(struct net_device *bond
         memcpy(addr.sa_data, bond_dev->dev_addr, bond_dev->addr_len);
         addr.sa_family = slave_dev->type;
         res = dev_set_mac_address(slave_dev, &addr);
-        if (res) {
+        if (res && res != -EOPNOTSUPP) {
             netdev_dbg(bond_dev, "Error %d calling set_mac_address\n", res);
             goto err_restore_mtu;
         }
```

# /etc/config/bonding

The software configuration is through /etc/config/bonding using standard UCI format. This file will be read by the /etc/init.d/bonding script. You will also need to configure the interfaces and firewall zones as well as setup appropriate openvpn key and certificate stores. Most of the configuration items are self-explanatory. All of these files are installed by the bondlink package and you will only need to edit the config files.

/etc/config/bonding:

```

config link 'link0'
        option interface 'wan0'
        option tunnel 'tun0'
        option local_port '1194' # Your separate tunnels need to run on different ports
        option remote_port '1194'
        option server '<secondary IP address of data centre server>'
        option routing_table 'link0'
        option active '1'

config link 'link1'
        option interface 'wan1'
        option tunnel 'tun1'
        option local_port '1195'
        option remote_port '1195'
        option server '<secondary IP address of data centre server>'
        option routing_table 'link1'

config interface 'bond'
        option ifname 'bond0'
        option ipaddr '10.0.0.2'  # private ip address of openwrt bonding interface
        option netmask '255.255.255.0'
        option remote_ipaddr '10.0.0.1' # private ip address of VM bonding interface
        option watchdog '1' # watchdog enabled
        option watchdog_ip '8.8.8.8' # ping this address to confirm link is up
        option watchdog_period '5' # how often to ping in seconds
        option watchdog_timeout '30' # restart after not receiving a reply for N seconds
        option watchdog_action '/etc/scripts/restartbonding.sh' # restart action

config openvpn 
        option client '1'
        option dev_type 'tun'
        option proto 'udp'
        option fragment '1400'
        option mssfix '1' 
        option persist_key '1'
        option persist_tun '1'
        option replay_window '512'
        option mute_replay_warnings '1'
        option verb '2'
        option cipher 'AES-256-CBC'
        option ca '/etc/openvpn/ca.crt'
        option cert '/etc/openvpn/router.crt'
        option key '/etc/openvpn/router.key'
        option dh '/etc/openvpn/dh2048.pem'
        option tls_auth '/etc/openvpn/ta.key 1'
        option ns_cert_type 'server'
        option tls_client '1'
        option txqueuelen '1000'
        option keepalive '5 30'
        option nice '-20'
        option fast_io '1'
        option replay_window '256 60'
        option key_method '2'
        option reneg_sec '3600'
        option tran_window '900'
        option comp_lzo '1'
        option script_security '2'
        option up_delay '1'

config openvpn-server
        option server '1'
        option dev_type 'tun'
        option proto 'udp'
        option fragment '1400'
        option mssfix '1'
        option persist_key '1'
        option persist_tun '1'
        option replay_window '512'
        option mute_replay_warnings '1'
        option verb '2'
        option cipher 'AES-256-CBC'
        option ca '/etc/openvpn/ca.crt'
        option cert '/etc/openvpn/server.crt'
        option key '/etc/openvpn/server.key'
        option dh '/etc/openvpn/dh2048.pem'
        option tls_auth '/etc/openvpn/ta.key 0'
        option ns_cert_type 'server'
        option tls_server '1'
        option txqueuelen '1000'
        option keepalive '5 15'
        option nice '-20'
        option fast_io '1'
        option replay_window '256 60'
        option key_method '2'
        option reneg_sec '3600'
        option tran_window '900'
        option comp_lzo '1'
        option script_security '2'
        option up_delay '1'
```

You will need to use openssl to generate the necessary keys and certificates for the router and the server in your data centre.


# /etc/init.d/bonding

```
#!/bin/sh /etc/rc.common
# Copyright (C) 2006-2011 OpenWrt.org

. /lib/functions.sh
. /lib/functions/network.sh

START=99
USE_PROCD=1
PROG=bonding
DELAY=5

LIST_SEP="
"

IPBINARY="/usr/sbin/ip"
ROUTEBINARY="/sbin/route"
IFCONFIGBINARY="/sbin/ifconfig"
OPENVPNBINARY="/usr/sbin/openvpn"
SYSFSROOT="/sys/class/net"
BONDING_MASTERS="bonding_masters"
RUNDIR="/var/run"
CONFDIR="/var/etc"
PREUPSCRIPT="/etc/bonding/bonding-preup.sh"
UPSCRIPT="/etc/bonding/bonding-up.sh"
PREDOWNSCRIPT="/etc/bonding/bonding-predown.sh"
DOWNSCRIPT="/etc/bonding/bonding-down.sh"
WATCHBOND="/etc/bonding/watchbond.sh"
WATCHDOGACTION="/etc/init.d/bonding restart"
MANAGEMENT_INTERFACE="1"

EXTRA_COMMANDS="d_start d_stop status test"
EXTRA_HELP="    d_start    Start in debug mode (no action taken)    
    d_stop    Stop in debug mode (no action taken)
    status    Show bonding status
    test    Run speedtest (requires python and python-expat)"

LOGGER="logger -t ${PROG}"
#LOGGER="echo"

logmessage ()
{
    ${LOGGER} "$@"
}

shell_command() 
{
    if [ -z "${DEBUG}" ]; then
        logmessage "${2}"
        eval "${2}"
    else
        debug "${1}: ${2}"
    fi

}

# add_source_route(routing table, wanip)
del_source_route() 
{
    
    local function_name="del_source_route"
    local routecmd

    debug "${function_name}: routing_table=${1} wanip=${2}"

    routecmd="${IPBINARY} rule del from ${2} 2> /dev/null"
    shell_command "${function_name}" "${routecmd}"

    routecmd="${IPBINARY} route del default table ${1} 2> /dev/null"
    shell_command "${function_name}" "${routecmd}"

}

# add_source_route(routing table, wan_interface, wanip, gateway)
add_source_route() 
{

    local function_name="add_source_route"
    local routecmd
    local device

    debug "${function_name}: routing_table=${1} wan_interface=${2} wanip=${3} gateway=${4}"

    network_get_device device ${2}
    if [ -z "${device}" ]; then
        logmessage "Unable to locate physical device name for logical interface ${2}"
        return 1
    fi
    debug "${function_name}: ${2} has device ${device}"

    routecmd="$IPBINARY rule add from ${3} lookup ${1}"
    shell_command "${function_name}" "${routecmd}"

    routecmd="${IPBINARY} route add default via ${4} table ${1} dev ${device}"
    shell_command "${function_name}" "${routecmd}"
}




# setup_default_route $bond_remoteip
setup_default_route() 
{

    local function_name="setup_default_route"
    local routecmd
    local bond_remoteip

    config_get bond_remoteip "bond" remote_ipaddr
    if [ -z "${bond_remoteip}" ]; then
        logmessage "No bond remote ip specified for ${1}"
        return 1
    fi

    routecmd="${ROUTEBINARY} delete default"
    shell_command "${function_name}" "${routecmd}"

    routecmd="${ROUTEBINARY} add default gw ${bond_remoteip}"
    shell_command "${function_name}" "${routecmd}"
}

setup_bonding_interface() 
{
    local tunnel_devices_list; eval tunnel_devices_list=\$${1}
    local function_name="setup_bonding_interface"
    local bondcmd
    local bond_interface
    local bond_localip
    local bond_netmask
    local expr

    config_get bond_interface "bond" ifname
    if [ -z "${bond_interface}" ]; then
        logmessage "No bond interface specified for ${1}"
        return 1
    fi
    config_get bond_localip "bond" ipaddr
    if [ -z "${bond_localip}" ]; then
        logmessage "No bond ip specified for ${1}"
        return 1
    fi

    config_get bond_netmask "bond" netmask
    if [ -z "${bond_netmask}" ]; then
        logmessage "No bond netmask specified for ${1}"
        return 1
    fi

    debug "${function_name}: interface=${bond_interface} ip=${bond_localip} netmask=${bond_netmask} slaves=${tunnel_devices_list}"

    # reset the bonding by first removing the bond interface if it's already present in bonding_masters

    expr="$(cat ${SYSFSROOT}/${BONDING_MASTERS} | sed  -n "s/.*\(${bond_interface}\).*/\1/p")"
    if [ -n "${expr}" ]; then
        bondcmd="echo -${expr} > ${SYSFSROOT}/${BONDING_MASTERS}"
        shell_command "${function_name}" "${bondcmd}"
    fi

    bondcmd="echo +${bond_interface} > ${SYSFSROOT}/${BONDING_MASTERS}"
    shell_command "${function_name}" "${bondcmd}"

    # add the previously parsed tunnel devices as slaves

    if [ -n "${tunnel_devices_list}" ]; then
        for i in ${tunnel_devices_list} ; do 
            bondcmd="echo \"${i}\" > ${SYSFSROOT}/${bond_interface}/bonding/slaves"
            shell_command "${function_name}" "${bondcmd}"
        done
    fi
    
    # ifconfig and up the bonding device

    bondcmd="${IFCONFIGBINARY} ${bond_interface} ${bond_localip} netmask ${bond_netmask}"
    shell_command "${function_name}" "${bondcmd}"

}

delete_bonding_interface() 
{
    local function_name="del_bonding_interface"
    local bondcmd
    local bond_interface
    local expr

    config_get bond_interface "bond" ifname
    if [ -z "${bond_interface}" ]; then
        logmessage "No bond interface specified for ${1}"
        return 1
    fi

    debug "${function_name}: interface=${bond_interface} ip=${bond_localip} netmask=${bond_netmask} slaves=${tunnel_devices_list}"

    # reset the bonding by removing the bond interface from bonding_masters

    expr="$(cat ${SYSFSROOT}/${BONDING_MASTERS} | sed  -n "s/.*\(${bond_interface}\).*/\1/p")"
    if [ -n "${expr}" ]; then
        bondcmd="echo -${expr} > ${SYSFSROOT}/${BONDING_MASTERS}"
        shell_command "${function_name}" "${bondcmd}"
    fi

}

append_bools() 
{
    local p; local v; local s="${1}"; shift
    for p in $*; do
        config_get v "${s}" "${p}"
        IFS="${LIST_SEP}"
        for v in ${v}; do
            [ -n "${v}" ] && (
                echo ""${p}"" | sed -e 's|_|-|g' >> ${config_file}
            )
        done
        unset IFS
    done
}

append_params() 
{
    local p; local v; local s="${1}"; shift
    for p in $*; do
        config_get v "${s}" "${p}"
        IFS="${LIST_SEP}"
        for v in ${v}; do
            [ -n "${v}" ] && (
                echo ""${p}" "${v}"" | sed -e 's|_|-|g' >> ${config_file}
            )
        done
        unset IFS
    done
}

append_params_quotes() 
{
    local p; local v; local s="${1}"; shift
    for p in $*; do
        config_get v "${s}" "${p}"
        IFS="${LIST_SEP}"
        for v in ${v}; do
            [ -n "${v}" ] && (
                echo -n "\""${p} | sed -e 's|/|\\/|g;s|_|-|g' >> ${config_file}; \
                echo "\": \""${v}"\"," >> ${config_file}
            )
        done
        unset IFS
    done
}

openvpn_add_instance() 
{
    local function_name="openvpn_add_instance"
    local syslog="${1}"
    local dir="${2}"
    local conf="${3}"
    local cmd

    cmd="${OPENVPNBINARY} --syslog \"${syslog}\" --cd ${dir} --config ${conf}"
    logmessage "${cmd}"

    procd_open_instance 
    procd_set_param command "${OPENVPNBINARY}" 
    procd_append_param command --syslog "${syslog}" --cd "${dir}" --config "${conf}"
    #procd_set_param file "${dir}/${conf}"
    procd_close_instance
}

start_openvpn() 
{
    local function_name="start_openvpn"
    local z; eval z=\$${1}
    local syslog


    for i in ${z}; do
        syslog="$(echo ${i} | awk -F '\/' '{print $NF}' | sed  "s/\([A-Za-z0-9_].*\)\.conf/\1/")"
        debug "start_openvpn:  ${OPENVPNBINARY} --cd ${CONFDIR} --syslog openvpn(${syslog}) --config ${i}"
        if [ -z "${DEBUG}" ]; then
            openvpn_add_instance "openvpn(${syslog})" "${CONFDIR}" "${i}"
        else
            echo "DEBUG is set"
        fi
    done

}

configure_link() 
{
    local s="${1}"; local v;
    local function_name="configure_link"
    local expr
    local openvpncmd

    local interface
    local tunnel
    local local_port
    local remote_port
    local server
    local local_ipaddr
    local routing_table
    local gateway

    [ ! -d "${RUNDIR}" ] && mkdir -p "${RUNDIR}"
    [ ! -d "${CONFDIR}" ] && mkdir -p "${CONFDIR}"

    config_file="${CONFDIR}/${1}.conf"
    [ -f "${config_file}" ] && rm "${config_file}"

    debug "${function_name}: writing config file ${config_file}"

    config_get interface "${1}" interface
    if [ -z "${interface}" ]; then
        logmessage "No wan interface specified for ${1}"
        return 1
    fi

    network_get_ipaddr local_ipaddr ${interface}
    if [ -z "${local_ipaddr}" ]; then
        logmessage "No ip address specified for interface ${interface}"
        return 1
    fi

    # wait until the wan link is up

    while  ! network_is_up ${interface} ; do
        debug "${function_name}" "waiting for interface ${interface} to come up"
        sleep $DELAY
    done

    config_get tunnel "${1}" tunnel
    if [ -z "${tunnel}" ]; then
        logmessage "No tunnel device name specified for ${1}"
        return 1
    fi
    config_get local_port "${1}" local_port
    if [ -z "${local_port}" ]; then
        logmessage "No local port specified for ${1}"
        return 1
    fi
    config_get remote_port "${1}" remote_port
    if [ -z "${remote_port}" ]; then
        logmessage "No remote port specified for ${1}"
        return 1
    fi

    config_get server "${1}" server
    if [ -z "${server}" ]; then
        logmessage "No server ip specified for ${1}"
        return 1
    fi

    config_get routing_table "${1}" routing_table
    if [ -z "${routing_table}" ]; then
        logmessage "No routing table specified for ${1}"
        return 1
    fi

    network_get_gateway gateway ${interface} 1
    if [ -z "${gateway}" ]; then
        logmessage "No gateway specified for ${1}"
        return 1
    fi

    echo "dev ${tunnel}" >> ${config_file}
    echo "remote ${server} ${remote_port}" >> ${config_file}
    echo "port ${local_port}" >> ${config_file}
    echo "local ${local_ipaddr}" >> ${config_file}

    if [ "${MANAGEMENT_INTERFACE}" == "1" ]; then
        echo "management ${RUNDIR}/openvpn-${1}.sockd unix" >> ${config_file}
    fi

    # the tunnel devices list is iteratively built up through successive calls

    bond_tunnel_devices="$bond_tunnel_devices +${tunnel}"

    # create the tunnel devices

    openvpncmd="$OPENVPNBINARY --mktun --dev-type tun --dev ${tunnel} > /dev/null 2>&1"
    shell_command "${function_name}" "$openvpncmd"
    
    # Remove any prior source routes before adding them

    del_source_route ${routing_table} ${local_ipaddr} 
    add_source_route ${routing_table} ${interface} ${local_ipaddr} ${gateway}

    config_foreach read_openvpn_config 'openvpn' ${config_file}
    openvpn_instances="${openvpn_instances} ${config_file}"

}

disable_link() 
{
    local s="${1}"; local v;
    local function_name="disable_link"
    local cmd

    local interface
    local routing_table
    local local_ipaddr
    local active
    local gateway

    config_get interface "${1}" interface
    if [ -z "${interface}" ]; then
        logmessage "No wan interface specified for ${1}"
        return 1
    fi

    config_get routing_table "${1}" routing_table
    if [ -z "${routing_table}" ]; then
        logmessage "No routing table specified for ${1}"
        return 1
    fi

    network_get_ipaddr local_ipaddr ${interface}
    if [ -z "${local_ipaddr}" ]; then
        logmessage "No ip address specified for interface ${interface}"
        return 1
    fi

    # determine if this is the link that would normally hold the default route

    config_get active "${1}" active

    network_get_gateway gateway ${interface}  1
    if [ -z "${gateway}" ]; then
        logmessage "No gateway specified for ${1}"
        return 1
    fi

    # Remove any prior source routes before adding them
    del_source_route ${routing_table} ${local_ipaddr} 


    if [ "$active" == "1" ]; then
        cmd="${ROUTEBINARY} add default gw ${gateway}"
        shell_command "${function_name}" "${cmd}"
    fi

}

read_openvpn_config() 
{
    local s="${1}"
    
    config_file=${2}

    
    [ ! -d "${RUNDIR}" ] && mkdir -p "${RUNDIR}"
    [ ! -d "${CONFDIR}" ] && mkdir -p "${CONFDIR}"


    # append flags
    append_bools "$s" \
        auth_nocache auth_retry auth_user_pass_optional bind ccd_exclusive client client_cert_not_required \
        client_to_client comp_lzo comp_noadapt disable \
        disable_occ down_pre duplicate_cn fast_io float http_proxy_retry \
        ifconfig_noexec ifconfig_nowarn ifconfig_pool_linear management_forget_disconnect management_hold \
        management_query_passwords management_signal mktun mlock mtu_test mssfix multihome mute_replay_warnings \
        nobind no_iv no_name_remapping no_replay opt_verify passtos persist_key persist_local_ip \
        persist_remote_ip persist_tun ping_timer_rem pull push_reset \
        remote_random rmtun route_noexec route_nopull single_session socks_proxy_retry \
        suppress_timestamps tcp_nodelay test_crypto tls_client tls_exit tls_server \
        tun_ipv6 up_restart username_as_common_name

    # append params
    append_params "$s" \
        askpass auth auth_user_pass auth_user_pass_verify bcast_buffers ca cert \
        chroot cipher client_config_dir client_connect client_disconnect connect_freq \
        connect_retry connect_timeout connect_retry_max crl_verify dev dev_node dev_type dh \
        engine explicit_exit_notify fragment group hand_window hash_size \
        http_proxy http_proxy_option http_proxy_timeout ifconfig ifconfig_pool \
        ifconfig_pool_persist ifconfig_push inactive ipchange iroute keepalive \
        key key_method keysize learn_address link_mtu lladdr local log log_append \
        lport management management_log_cache max_clients \
        max_routes_per_client mode mtu_disc mute nice ns_cert_type ping \
        ping_exit ping_restart pkcs12 plugin port port_share prng proto rcvbuf \
        redirect_gateway remap_usr1 remote remote_cert_eku remote_cert_ku remote_cert_tls \
        reneg_bytes reneg_pkts reneg_sec \
        replay_persist replay_window resolv_retry route route_delay route_gateway \
        route_metric route_up rport script_security secret server server_bridge setenv shaper sndbuf \
        socks_proxy status status_version syslog tcp_queue_limit tls_auth \
        tls_cipher tls_remote tls_timeout tls_verify tmp_dir topology tran_window \
        tun_mtu tun_mtu_extra txqueuelen up_delay user verb down push up

}

link_status() 
{
    local function_name="link_status"
    local domain_socket
    local routing_table
    local tunnel
    local socatbin

    if [ "${MANAGEMENT_INTERFACE}" != "1" ]; then
        return 1
    fi
    socatbin="$(which socat)"
    if [ -z "${socatbin}" ]; then
        logmessage "Cannot locate socat binary"
    fi

    domain_socket="$RUNDIR/openvpn-${1}.sockd"
    if [ -f "${domain_socket}" ]; then
        logmessage "No domain socket found for ${1}"
    fi

    config_get tunnel "${1}" tunnel
    if [ -z "${tunnel}" ]; then
        logmessage "Cannot find tunnel device for ${1}"
        return 1
    fi

    echo
    echo -n "${1} connection state: "
    echo -e "state" | ${socatbin} - UNIX-CONNECT:\"${domain_socket}\"  | sed "3,$ d" | sed "1,1 d" 
    echo
    ifconfig ${tunnel}
    echo -e "status" | ${socatbin} - UNIX-CONNECT:\"${domain_socket}\" | sed "1,3 d" | sed "10,$ d" | sed "s/\(^.*\)/\\t  \1/"

    config_get bond_interface "bond" ifname
    if [ -z "${bond_interface}" ]; then
        logmessage "No bond interface specified for ${1}"
        return 1
    fi

    echo

}

start_watchdog()
{
    local s=""
    local bond_gateway
    local watchdog
    local watchdog_ip
    local watchdog_period='10'
    local watchdog_timeout='60'
    local watchdog_action="${WATCHDOGACTION}"

    if [ -n "${DEBUG}" ]; then
        return 0
    fi

    config_get watchdog "bond" watchdog
    if [ -z ${watchdog} ]; then
        return 0
    fi

    config_get bond_gateway "bond" remote_ipaddr
    config_get watchdog_ip "bond" watchdog_ip ${bond_gateway}
    config_get watchdog_period "bond" watchdog_period '10'
    config_get watchdog_timeout "bond" watchdog_timeout '60'
    config_get watchdog_action "bond" watchdog_action "/etc/init.d/bonding restart"

    procd_open_instance 
    procd_set_param command "${WATCHBOND}" 
    procd_append_param command "${watchdog_timeout}" "${watchdog_ip}" "${watchdog_period}" "${watchdog_action}"
    procd_close_instance
}


boot()
{
    QUIET=1
    /usr/sbin/modprobe ${PROG} > /dev/null 2>&1
    start
}

d_start()
{
    DEBUG="echo"
    start
}

d_stop()
{
    DEBUG="echo"
    stop
}

restart_service()
{
    return 0
}

start_service() 
{
    local function_name="start"
    local expr

    if [ -f "${PREUPSCRIPT}" ]; then
        shell_command "start_service" "${PREUPSCRIPT}"
    fi

    expr="$(lsmod | grep ${PROG})"
    if [ -z "${expr}" ]; then
        logmessage "Bonding module not loaded"
        return 1
    fi

    config_load 'bonding'


    # this is a little ugly, but we can't pass parameters in to the callback by reference
    # and we need to parse the config sections completely before setting up the bond device.
    # append the tunnel devices and config files onto a local variable that we can use later

    local bond_tunnel_devices=""
    local openvpn_instances=""
    config_foreach configure_link 'link'

    setup_bonding_interface bond_tunnel_devices

    start_openvpn openvpn_instances

    setup_default_route 

    start_watchdog

    if [ -f "${UPSCRIPT}" ]; then
        shell_command "start_service" "${UPSCRIPT}"
    fi
}

stop_service() 
{
    local function_name="stop"
    local expr

    if [ -f "${PREDOWNSCRIPT}" ]; then
        shell_command "start_service" "${PREDOWNSCRIPT}"
    fi

    config_load 'bonding'

    local bond_tunnel_devices=""
    local openvpn_instances=""
    config_foreach disable_link 'link'

    delete_bonding_interface 

    if [ -f "${DOWNSCRIPT}" ]; then
        shell_command "start_service" "${DOWNSCRIPT}"
    fi
}


status()
{
    local function_name="status"

    config_load 'bonding'

    config_foreach link_status 'link'

    config_get bond_interface "bond" ifname
    if [ -z "${bond_interface}" ]; then
        logmessage "No bond interface specified for ${1}"
        return 1
    fi

    echo
    echo "Bonding device ${bond_interface} status:"
    echo
    ifconfig ${bond_interface}
}

test()
{
    local function_name="status"
    local pythonbin="$(which python)"
    local pythonexpat="$(opkg find python-expat)"
    local speedtest="$(which speedtest_cli)"

    if [ -z "${pythonbin}" ]; then
        logmessage "Python is not installed"
        return 1
    fi

    if [ -z "${pythonexpat}" ]; then
        logmessage "Python expat module is not installed"
        return 1
    fi

    if [ -z "${speedtest}" ]; then
        wget -O /usr/bin/speedtest_cli --no-check-certificate \
            https://raw.githubusercontent.com/sivel/speedtest-cli/master/speedtest_cli.py
        chmod 755 /usr/bin/speedtest_cli
    fi

    local bond_interface
    local bond_ipaddr

    config_load 'bonding'

    config_get bond_interface "bond" ifname
    if [ -z "${bond_interface}" ]; then
        logmessage "No bond interface specified"
        return 1
    fi

    if  !  network_is_up "${bond_interface}" ; then
        logmessage "Bond interface ${bond_interface} is not up"
        return 1
    fi

    config_get bond_ipaddr "bond" ipaddr
    if  [ -z "${bond_ipaddr}" ]; then
        logmessage "Cannot retrieve ip address for ${bond_interface}"
        return 1
    fi

    echo "Testing speed from source ip ${bond_ipaddr}..."

    speedtest_cli --source ${bond_ipaddr} ${@}
}

```

# /etc/bonding/watchbond.sh

```

#!/bin/sh 
# Adapted from /usr/bin/watchcat.sh

watchbond() 
{
    local period="$1"; local pinghosts="$2"; local pingperiod="$3"; local command="${4}"

    time_now="$(cat /proc/uptime)"
    time_now="${time_now%%.*}"
    time_lastcheck="$time_now"
    time_lastcheck_withinternet="$time_now"

    logger -p daemon.info -t "watchbond[$$]" "Monitoring bond link every ${pingperiod} seconds. Restart enabled after ${period} seconds"

    # sleep for 10 seconds to give the tunnels time to initialize 

    sleep 10

    while true
    do
        # account for the time ping took to return. With a ping time of 5s, ping might take more 
        # than that, so it is important to avoid even more delay.

        time_now="$(cat /proc/uptime)"
        time_now="${time_now%%.*}"
        time_diff="$((time_now-time_lastcheck))"

        [ "$time_diff" -lt "$pingperiod" ] && {
            sleep_time="$((pingperiod-time_diff))"
            sleep "$sleep_time"
        }

        time_now="$(cat /proc/uptime)"
        time_now="${time_now%%.*}"
        time_lastcheck="$time_now"

        for host in "$pinghosts"
        do
            if ping -c 1 "$host" &> /dev/null 
            then 
                time_lastcheck_withinternet="$time_now"
            else
                time_diff="$((time_now-time_lastcheck_withinternet))"
                logger -p daemon.info -t "watchbond[$$]" "no internet connectivity for $time_diff seconds. Resetting bond when reaching $period"       
            fi
        done

        time_diff="$((time_now-time_lastcheck_withinternet))"
        if [ "$time_diff" -ge "$period" ]; then
            logger -p daemon.info -t "watchbond[$$]" "Resetting with ${4}"
            eval "${4}"
        fi

    done
}

watchbond "$1" "$2" "$3" "$4"

```

The scripts in /etc/bonding are run pre-up, post-up and pre-down, post-down of the bonding links if these scripts exits. 

# /etc/bonding/restartbonding.sh

```

#!/bin/sh

ifdown wan0
ifdown wan1
sleep 3
ifup wan0
ipup wan1
/etc/init.d/bonding restart

```

# /etc/config/network

```
config interface 'bond0'
    option ifname 'bond0'
    option _orig_ifname 'bond0'
    option _orig_bridge 'false'
    option proto 'none'

config interface 'ov0'
    option proto 'none'
    option ifname 'tun0'

config interface 'ov1'
    option proto 'none'
    option ifname 'tun1'
```

# /etc/config/openvpn

```

config openvpn tun0
	option enabled 1
	option config /etc/openvpn/tun0.conf

config openvpn tun1
	option enabled 1
	option config /etc/openvpn/tun1.conf


```

# /etc/config/firewall

```

# Modify your wan zone

option name 'wan'
    option conntrack '1'
    option log '1'
    option masq '1'
    option mtu_fix '1'
    option input 'DROP'
    option output 'ACCEPT'
    option forward 'DROP'
    option log_limit '100/minute'
    option network 'wan0 wan1 bond0'

# Add the following to your /etc/config/firewall
    
config rule
    option name 'openvpn-udp-link0'
    option src 'wan'
    option dest_port '1194'
    option proto 'udp'
    option src_ip '<datacentre server ip>'

config rule
    option name 'openvpn-udp-link1'
    option src 'wan'
    option dest_port '1195'
    option proto 'udp'
    option src_ip '<datacentre server ip>'
    option target 'ACCEPT'
    
config zone
    option name 'bondnet'
    option output 'ACCEPT'
    option mtu_fix '1'
    option forward 'DROP'
    option input 'DROP'
    option masq '1'
    option conntrack '1'
    option log '1'
    option network 'ov0 ov1'
    
config forwarding
    option dest 'bondnet'
    option src 'wan'
    
config forwarding
    option dest 'wan'
    option src 'bondnet'
    
```

# Datacentre VM configuration

This configuration is for Centos. I'm still using Centos 6, however Centos 7 can be used if you apply the same kernel patch.

# /etc/sysconfig/network-scripts/ifcfg-bond0

```
DEVICE=bond0
IPADDR=10.0.0.1
NETMASK=255.255.255.0
ONBOOT=yes
BOOTPROTO=none
USERCTL=no
BONDING_OPTS="mode=0"
```

# /etc/sysconfig/network-scripts/ifcfg-tun0

```
DEVICE=tun0
ONBOOT=yes
BOOTPROTO=none
USERCTL=no
MASTER=bond0
SLAVE=yes
```

# /etc/sysconfig/network-scripts/ifcfg-tun1

```
DEVICE=tun1
ONBOOT=yes
BOOTPROTO=none
USERCTL=no
MASTER=bond0
SLAVE=yes
```

# /etc/sysconfig/network-scripts/ifcfg-eth0

```
DEVICE=eth0
BOOTPROTO=static
HWADDR=00:16:3e:2e:d2:d7
IPADDR=<main ip address of data centre server>
NETMASK=255.255.255.0
ONBOOT=yes
```

# /etc/sysconfig/network-scripts/ifcfg-eth0:1

```
DEVICE=eth0:1
BOOTPROTO=static
# This IP address will be the one which appears to be your ip address to the internet
IPADDR=<virtual static ip address of datacentre server>
NETMASK=255.255.255.0
ONBOOT=yes
```

# /etc/openvpn/tun0.conf

```
local <server ip>
port 1194
proto udp
dev-type tun
dev tun0

ca /etc/openvpn/ca.crt
cert /etc/openvpn/server.crt
key /etc/openvpn/server.key
dh /etc/openvpn/dh2048.pem
tls-auth /etc/openvpn/ta.key 0 
tls-server
cipher AES-256-CBC

fragment 1400 
mssfix

keepalive 5 15
max-clients 1
user nobody
group nobody
persist-key
persist-tun
status /var/run/openvpn-status-tun0.log
verb 4
;mute 20



txqueuelen 1000
script-security 2
nice -20
fast-io
replay-window 256 60
reneg-sec 3600
tran-window 900
comp-lzo
log /var/log/openvpn-tun0.log
```

# /etc/openvpn/tun1.conf

```
local <server ip>
port 1195
proto udp
dev-type tun
dev tun1

ca /etc/openvpn/ca.crt
cert /etc/openvpn/server.crt
key /etc/openvpn/server.key
dh /etc/openvpn/dh2048.pem
tls-auth /etc/openvpn/ta.key 0 
tls-server
cipher AES-256-CBC

fragment 1400 
mssfix

keepalive 5 30

max-clients 1
user nobody
group nobody
persist-key
persist-tun
status /var/run/openvpn-status-tun1.log
verb 4
;mute 20

txqueuelen 1000
script-security 2
nice -20
fast-io
replay-window 256 60
reneg-sec 3600
tran-window 900
comp-lzo
log /var/log/openvpn-tun1.log

```

Make sure to enable the openvpn service using chkconfig.

# Server firewall configuration

A firewall builder configuration for the datacentre server is available in this repository in the bonding-server folder. You simply need to change the ip addresses to the relevant ones for your configuration. Should you be using Centos 6 which uses iptables for firewalling, you can use this file to generate an appropriate configuration and install it on your server. Should you be using another distribution which uses firewalld, you will need to look at the rules in this file and duplicate them appropriately. I suggest you install firewall builder and read the rules to see what you need.


