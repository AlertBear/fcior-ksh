#!/usr/bin/ksh -p

. ${CTI_SUITE}/config/test_config

typeset source=${SOURCE_DOMAIN}
typeset nprd1=${NPRD_A}
typeset nprd2=${NPRD_B}
typeset iod=${IOD}
typeset pf1=${PF_A}
typeset pf2=${PF_B}

function get_bus_of_pf
{
    pf=$1
    pcie_1=${pf%/IOVFC.PF[0123]}
    bus=""
    bus_equation=$(ldm list-io -p|grep PCIE|grep ${pcie_1} | \
        awk -F'|' '{print $7}')
    eval ${bus_equation}
    echo ${bus}
}

function has_value
{
    element=$1
    array=$2
    for item in ${array};do
        if [[ ${element} == ${item} ]];then
            return 0
        fi
    done            
    return 1
}

function check_domain_exists
{
	domain=$1
	ldm list ${domain} > /dev/null 2>&1
	return $?
}

function destroy_domain
{
    domain=$1
    ldm stop -f ${domain} > /dev/null
    [ $? -ne 0 ] && return 1
    ldm unbind ${domain} 
    [ $? -ne 0 ] && return 1
    ldm rm-vcpu 8 ${domain} > /dev/null
    [ $? -ne 0 ] && return 1
    ldm rm-memory 16G ${domain} > /dev/null
    [ $? -ne 0 ] && return 1
    ldm rm-vnet vnet_${domain} ${domain}
    [ $? -ne 0 ] && return 1
    ldm rm-vdisk vdisk_${domain} ${domain}
    [ $? -ne 0 ] && return 1

    vds=$(ldm list-services -p|grep VDS|gawk -F'[|=]' '{print $3}')
    ldm rm-vdsdev ${domain}@${vds}
    [ $? -ne 0 ] && return 1
    ldm destroy ${domain}
    [ $? -ne 0 ] && return 1
    zfs destroy rpool/${domain}
    [ $? -ne 0 ] && return 1
    return 0
}

function get_volume_of_domain
{
    i=0
    vdisk_num=$(ldm list-bindings $1|grep VDISK|wc -l)    
    vdsdev_array=$(ldm list-bindings -p fc | \
        grep VDISK|gawk -F'[|=@]' '{print $5}')
    for vdsdev in ${vdsdev_array};do
        volume=$(ldm list-services -p|grep ${vdsdev}|awk -F'|' '{print $4}' | \
            awk -F'=' '{print $2}') 
        volume_array[$i]=${volume#'/dev/zvol/dsk/'}
        (( i++ ))
    done
    echo ${volume_array}
}

print "-----------------------------------------"
typeset bus_1=$(get_bus_of_pf ${pf1})
typeset bus_2=$(get_bus_of_pf ${pf2})

typeset tempfile=$(mktemp)
for bus in ${bus_1} ${bus_2};do
    typeset i=0
    ldm list-io -p|grep type=VF|grep bus=${bus_1} > ${tempfile}
    while read ndev ualias nstatus udomain ntype nbus;do
        alias=""
        domain=""
        eval ${udomain}
        eval ualias
        if [[ ${domain} != "" ]];then
            ldm rm-io ${alias} ${domain}
        fi
        pf=${alias%'\.VF[0-9]\+'}
        if !$(has_value ${pf} ${pf_array});then
            pf_array[$i]=${pf}
            (( i++ ))
        fi
    done < ${tempfile}
done

for destroy_pf in ${pf_array};do
    ldm destroy-vf -n max ${destroy_pf}
done

for domain_to_destroy in ${nprd1} ${nprd2} ${iod};do
	if $(check_domain_exists ${domain_to_destroy});then
    	print "Destroying ${domain_to_destroy}..."
    	destroy_domain ${domain_to_destroy}
		if [ $? -ne 0 ];then
			print "Failed"
		else
			print "Done"
		fi
	fi		
done

typeset source_volume_array=$(get_volume_of_domain ${source})
typeset i=0
for source_volume in ${source_volume_array};do
    try_get_snapshot_array=($(zfs list -t snapshot|grep ${source_volume} | \
        awk '{print $1}'))
    if [ -n ${try_snapshot} ];then
		for try_get_snapshot in ${try_get_snapshot_array[*]};do
       		snapshot_array[$i]=${try_get_snapshot} 
       		(( i++ ))
		done
    fi
done

once_destroy_flag=false
while true
do
    if ${once_destroy_flag};then
        print "Do you want to continue?y/n" 
        yes_array=("y" "Y" "")
        no_array=("n" "N")
        read continue_flag
        if $(has_value ${continue_flag} ${yes_array});then
            print "" 
        elif $(has_value ${continue_flag} ${no_array});then
            break    
        else
            print "Please input the y or n"
            continue
        fi
    fi
	count=$((${#snapshot_array[*]}-1))
	if (( ${count} == 0 ));then
		input=0
	else
		print "--------------------------"
    	for j in {0..${count}};do
        	print "[$j] ${snapshot_array[$j]}"
    	done
		print "--------------------------"
    	print "Which snapshot do you want to destroy?"
    	read input
	fi		

    if (( ${input} <= ${count} )) && (( ${input} >= 0 ));then
        destroy_snapshot_num=${input}
		print "Destroying ${snapshot_array[${destroy_snapshot_num}]}..."
		sleep 3
        zfs destroy ${snapshot_array[${destroy_snapshot_num}]}
		print "Done"
        once_destroy_flag=true
        unset snapshot_array[${destroy_snapshot_num}]    
        if (( ${#snapshot_array[*]} == 0 ));then
            break
        fi
    else
        print "Please input the number below" 
    fi            
done

