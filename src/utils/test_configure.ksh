#!/usr/bin/ksh -p
. ${CTI_SUITE}/config/test_config

typeset source_name=${SOURCE_DOMAIN}
typeset nprd1_name=${NPRD_A}
typeset nprd2_name=${NPRD_B}
typeset iod_name=${IOD}
typeset pf1=${PF_A}
typeset pf2=${PF_B}
typeset password=${SOURCE_DOMAIN_PASSWORD}
typeset iod_ip=${IOD_IP}

function check_domain_exists
{
    ldm list $1 > /dev/null
    if [[ $? != 0 ]];then
        return 1
    else
        return 0
    fi
}

function get_volume_of_domain
{
    i=0
    vdisk_num=$(ldm list-bindings $1|grep VDISK|wc -l)    
    vdsdev_array=$(ldm list-bindings -p fc|grep VDISK|gawk -F'[|=@]' \
        '{print $5}')
    for vdsdev in ${vdsdev_array};do
        volume=$(ldm list-services -p|grep ${vdsdev}|awk -F'|' '{print $4}'| \
            awk -F'=' '{print $2}') 
        volume_array[$i]=${volume#'/dev/zvol/dsk/'}
        (( i++ ))
    done
    echo ${volume_array[@]}
}

function create_snapshot
{
    now=$(date +%y%m%d)
    zfs snapshot ${1}@ior-${now}
    if [ $? != 0 ];then
        return 1
    else
		volume_snapshot="$1@ior-$now"
        echo ${volume_snapshot}
    fi     
}

function create_domain_by_clone
{
    source_snapshot=$1
    ldgname=$2
   
    zfs clone ${source_snapshot} rpool/${ldgname}
    [ $? -ne 0 ] && return 1

    ldm add-domain ${ldgname}
    [ $? -ne 0 ] && return 1

    ldm add-vcpu 8 ${ldgname}
    [ $? -ne 0 ] && return 1

    ldm add-memory 16G ${ldgname}
    [ $? -ne 0 ] && return 1

    typeset name=""
    vsw_equation=$(ldm list-services -p|grep VSW|awk -F'|' '{print $2}')
    eval ${vsw_equation}
    ldm add-vnet vnet_${ldgname} ${name} ${ldgname}

    vds_equation=$(ldm list-services -p|grep VDS|awk -F'|' '{print $2}')
    eval ${vds_equation}
    ldm add-vdsdev /dev/zvol/dsk/rpool/${ldgname} ${ldgname}@${name}
    [ $? -ne 0 ] && return 1

    ldm add-vdisk vdisk_${ldgname} ${ldgname}@${name} ${ldgname}
    [ $? -ne 0 ] && return 1

    ldm set-var auto-boot\?=true ${ldgname}
    
    ldm bind ${ldgname}
    [ $? -ne 0 ] && return 1

    return 0
}

function get_bus_of_pf
{
    pf=$1
    pcie_1=${pf%/IOVFC.PF[0123]}
    typeset bus=""
    bus_equation=$(ldm list-io -p|grep PCIE|grep ${pcie_1} | \
        awk -F'|' '{print $7}')
    eval ${bus_equation}
    echo ${bus}
}

function get_domain_port
{
    port=$(ldm list $1|tail -1|awk '{print $4}')
    echo ${port}
}
volume_array=($(get_volume_of_domain ${source_name}))

if (( ${#volume_array[@]} > 1 ));then
    typeset i=0
    while true
    do
		print "-------------------------------------"
        for volume in ${volume_array[@]};do
           print "[$i]${volume}"
           (( i++ ))
        done
		print "-------------------------------------"
        print "Which volume do you want to snapshot?"
        read num
        max_num=$(( ${#volume_array[@]} - 1 ))
        if [ ${num} -gt ${max_num} ] || [ ${num} -gt 0 ];then
            print "Please input the number above"            
        else
            source_volume=${volume_array[$num]}
            break
        fi 
    done
else
	print "-------------------------------------"
    source_volume=${volume_array[0]}
fi

volume_snapshot=$(create_snapshot ${source_volume})
[ $? -ne 0 ] && print "Failed to create snapshot of ${source_name}" && exit 1

domain_array=(${nprd1_name} ${nprd2_name} ${iod_name})
for create_domain in ${domain_array[@]};
do
    print "Creating ${create_domain}..."   
    create_domain_by_clone ${volume_snapshot} ${create_domain} 
    if [ $? -ne 0 ];then
        print "Failed to create ${create_domain}"
        exit 1       
    else
        print "Done"     
    fi        
done

bus_1=$(get_bus_of_pf ${pf1})
bus_2=$(get_bus_of_pf ${pf2})

print "Allocating ${bus_1} to ${nprd1_name}"
ldm add-io iov=on ${bus_1} ${nprd1_name}
[ $? -ne 0 ] && print "Failed" && exit 1

print "Allocating ${bus_2} to ${nprd2_name}"
ldm add-io iov=on ${bus_2} ${nprd2_name}
[ $? -ne 0 ] && print "Failed" && exit 1

print "Start ${nprd1_name} ${nprd2_name} ${iod_name}..."
ldm start ${nprd1_name}
ldm start ${nprd2_name}
ldm start ${iod_name}

print "Waitting all domains boot up..."
sleep 150
 
# Checking domains whether boot up 

tempfile=$(mktemp)
cat > ${tempfile} << "EOF"
#!/usr/bin/expect

set port [ lindex $argv 0 ]
set password [ lindex $argv 1 ]

spawn telnet 0 $port

expect {
	"Press ~? for control options" {
		send "\r"
	}       
	timeout {
	    exit 1
	}          
}

set timeout 600
expect {
    "console login:" { send "root\r" }
    timeout  { return 1 }
}

set timeout 15
expect {
    "Password:" { send "$password\r" }
    timeout { return 1 }
}

expect {
	"~#" { return 0 }
	timeout { return 1 }
}

send "\x1d\r"
expect {
        "telnet>" { send "q\r" }
}

EOF

chmod +x ${tempfile}

nprd1_port=$(get_domain_port ${nprd1_name})
nprd2_port=$(get_domain_port ${nprd2_name})
iod_port=$(get_domain_port ${iod})

${tempfile} ${nprd1_port} ${password}
if [ $? -ne 0 ];then
	print "${nprd1_name} is not up"
else
	print "${nprd1_name} is up"
fi

${tempfile} ${nprd2_port} ${password}
if [ $? -ne 0 ];then
	print "${nprd2_name} is not up"
else
	print "${nprd2_name} is up"
fi

${tempfile} ${iod_port} ${password}
if [ $? -ne 0 ];then
	print "${iod_name} is not up"
	exit 1
else
	print "${iod_name} is up"
fi

# Configure IP of io domain
print "Configure IP of IO domain and enable rsh..."

tempfile1=$(mktemp)
cat > ${tempfile1} << "EOF"
#!/usr/bin/expect
    
set port [ lindex $argv 0 ]
set password [ lindex $argv 1 ]
set ip [ lindex $argvgv 2 ]
set subnet [ lindex $argvgv 3 ]

set timeout 30
spawn telnet 0 $port

expect {
	"Press ~? for control options" {
		send "\r"
	}
	timeout {
	    return 1
    }
}

expect {
    "console login:" { 
		send "root\r"
	}
    timeout {
		return 1
	}
}

expect {
    "Password:" { 
		send "$password\r" 
	}
    timeout {
		return 1
	}
}

expect {
    "~#" { 
		send "ipadm delete-ip net0\r"
        send "\r"
        send "ipadm create-ip net0\r"
        send "\r"
        send "ipadm create-addr -T static -a $ip/24 net0\r"
        send "\r"
        send "route add default $subnet\r"
        send "\r"
		sleep 3
	}
    timeout {
		return 1
	}
}

expect {
    "~#" { 
		send "sed '/^CONSOLE/s/\\\(CONSOLE\\\)/\#\\\1/' /etc/default/login > \
            /etc/default/login.new\r"
        send "\r"
        send "mv -f /etc/default/login.new /etc/default/login\r"
        send "\r"
        send "sed '/^PermitRootLogin/s/no/yes/' /etc/ssh/sshd_config > \
            /etc/ssh/sshd_config.new\r"
        send "\r"
        send "mv -f /etc/ssh/sshd_config.new /etc/ssh/sshd_config\r"
        send "\r"
        send "svcadm restart ssh\r"
        send "\r"
		sleep 5
	}          
    timeout {
		return 1
	}
}

expect {
    "~#" { 
		send "svcadm enable -r -s svc:/network/login:rlogin\r" 
        send "\r"
        send "svcadm enable -r -s svc:/network/shell:default\r" 
        send "\r"
		sleep 5
    }
    timeout {
		return 1
	}
}


expect {
    "~#" {
		send "touch /root/.rhosts\r" 
        send "\r"
        send "echo '+ +' > /root/.rhosts" 
        send "\r"
		return 0
    }
    timeout {
		return 1
	}		
}

send "\x1d\r"
expect {
        "telnet>" { send "q\r" }
}
EOF

# Enable IO domain rsh
chmod +x ${tempfile1}
subnet=${ip%\.[0-9]*}
${tempfile1} ${iod_port} ${password} ${iod_ip}
if [ $? -ne 0 ];then
    print "Failed"
else
    print "Success"
fi
