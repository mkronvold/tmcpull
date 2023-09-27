#!/bin/bash

tempkey=9492       # set this to something unique to your scripts
tmps=1             # number of tmp files needed
DEBUG=

############ don't mess with these ###########
#
program=${0##*/}   # similar to using basename
confdir=$(dirname "$0")
[ $workdir ] || workdir=$confdir
[ -d $workdir ] || workdir=$confdir
#[ -f $confdir/bab.conf ] && source $confdir/bab.conf || die "No config file found in default location $confdir/bab.conf" 10
[ -f $confdir/babfunc.sh ] && source $confdir/babfunc.sh || die "$confdir/babfunc.sh not found" 11
mktmps
#
###############################################

# get config
#[ $listdir ] || warn "No listdir found in config" 10
#[ -d $listdir ] || listdir=$(pwd)

CSVLOOK=cat

while [[ $# -gt 0 ]] && [[ "$1" == "--"* ]] ;
do
  opt=${1}
  case "${opt}" in
    "--" )
      break 2;;
    "--dry" ) DRYRUN=1;;
    "--dryrun" ) DRYRUN=1;;
    "--reqs"|"--requirements" ) [ $(which csvlook) ] && echo "csvkit found." || die "csvkit not found.  Install with: sudo pip install csvkit";;
    "--csv" ) MKCSV=1;;
    "--look"|"--csvlook" ) CSVLOOK=$(which csvlook || echo cat);;
    "--save="* )
      SAVE=1
      SAVEFILE="${opt#*=}";;
    "--test" ) DRYRUN=1;;
    "--debug" ) DEBUG=1 ;;
    "--break" ) BREAKPOINT=1;;
    "--tkr" ) work=listtkr ;;
    "--tkrcount" ) work=counttkr ;;
    "--tns" ) work=listtns ;;
    "--clusterdetails"|"--clusters"|"--tkc" ) work=listtkc ;;
    "--tkg"|"--mgmt"|"--management" ) work=listmgmt ;;
    "--workspaces"|"--wks" ) work=listworkspaces ;;
    "--ls="* )
      work=ls
      ls="${opt#*=}";;
    *)
    #   erm.  nothing here.
    ;;
  esac
  shift
done


#main
debug "tmps=$tmps"
debug "tmp()=${tmp[@]}"
debug "tmp[0]=${tmp[0]}"
debug "tmp[1]=${tmp[1]}"
[ $BREAKPOINT ] && die "DEBUG BREAKPOINT" 99

case "$work" in
  "listtkr" )
    debug "attempting to list tkrs of all tkcs"
    if [ $MKCSV ]; then
      if [ $SAVE ]; then
        echo "clustername,distribution" > $SAVEFILE-$(date +'%Y-%m-%d_%H-%M-%S').csv
        tanzu mission-control cluster list -o json | jq -r '.clusters[] | "\(.fullName.name) \(.spec.tkgServiceVsphere.distribution.version)"' | awk -F+ '{print $1}' | csvsort -c 2 | sed -e 's/\ /,/g' >> $SAVEFILE-$(date +'%Y-%m-%d_%H-%M-%S').csv
      else
        ( echo "clustername,distribution" ;
        tanzu mission-control cluster list -o json | jq -r '.clusters[] | "\(.fullName.name) \(.spec.tkgServiceVsphere.distribution.version)"' | awk -F+ '{print $1}' | sed -e 's/\ /,/g' ) | csvsort -c 2 | $CSVLOOK
      fi
    else
      tanzu mission-control cluster list -o json | jq -r '.clusters[] | "\(.fullName.name) \(.spec.tkgServiceVsphere.distribution.version)"' | awk -F+ '{print $1}'
    fi
    ;;
  "counttkr" )
    debug "attempting to count tkrs of all tkcs"
    tanzu mission-control cluster list -o json | jq -r '.clusters[] | "\(.fullName.name) \(.spec.tkgServiceVsphere.distribution.version)"' | awk -F+ '{print $1}' | sed -e 's/\ /,/g' | csvstat -c 2 --freq --freq-count 25 | jq | sort | grep :
    ;;
  "listtkc" )
    debug "attempting to list tkc details"
    if [ $MKCSV ]; then
      if [ $SAVE ]; then
        echo "clustername,memorytotal,memorypercent,cputotal,cpupercent,nodecount,health,message" > $SAVEFILE-$(date +'%Y-%m-%d_%H-%M-%S').csv
        tanzu mission-control cluster list -o json | jq -r '.clusters[] | "\(.fullName.name),\(.status.allocatedMemory.allocatable),\(.status.allocatedMemory.allocatedPercentage),\(.status.allocatedCpu.allocatable),\(.status.allocatedCpu.allocatedPercentage),\(.status.nodeCount),\(.status.health),\(.status.healthDetails.message)"' >> $SAVEFILE-$(date +'%Y-%m-%d_%H-%M-%S').csv
      else
        ( echo "clustername,memorytotal,memorypercent,cputotal,cpupercent,nodecount,health,message" ;
        tanzu mission-control cluster list -o json | jq -r '.clusters[] | "\(.fullName.name),\(.status.allocatedMemory.allocatable),\(.status.allocatedMemory.allocatedPercentage),\(.status.allocatedCpu.allocatable),\(.status.allocatedCpu.allocatedPercentage),\(.status.nodeCount),\(.status.health),\(.status.healthDetails.message)"' ) | $CSVLOOK 2> /dev/null
      fi
    else
      tanzu mission-control cluster list -o json | jq -r '.clusters[] | "\(.fullName.name) \(.status.allocatedMemory.allocatable) \(.status.allocatedMemory.allocatedPercentage) \(.status.allocatedCpu.allocatable) \(.status.allocatedCpu.allocatedPercentage) \(.status.nodeCount) \(.status.health) \(.status.healthDetails.message)"'
    fi
    ;;
  "listtns" )
    debug "attempting to list all tns by tkc"
    if [ $MKCSV ]; then
      if [ $SAVE ]; then
        ( echo "namespace,clustername,workspace,mgmtcluster" ;
        tanzu mission-control cluster namespace list -o json | jq -r '.namespaces[] | "\(.fullName.name),\(.fullName.clusterName),\(.spec.workspaceName),\(.fullName.managementClusterName)"' ) | csvsort -c 4,2,3,1 > $SAVEFILE-$(date +'%Y-%m-%d_%H-%M-%S').csv
      else
        ( echo "namespace,clustername,workspace,mgmtcluster" ;
        tanzu mission-control cluster namespace list -o json | jq -r '.namespaces[] | "\(.fullName.name),\(.fullName.clusterName),\(.spec.workspaceName),\(.fullName.managementClusterName)"' ) | csvsort -c 4,2,3,1 | $CSVLOOK 2> /dev/null
      fi
    else
      ( echo "namespace,clustername,workspace,mgmtcluster" ;
      tanzu mission-control cluster namespace list -o json | jq -r '.namespaces[] | "\(.fullName.name),\(.fullName.clusterName),\(.spec.workspaceName),\(.fullName.managementClusterName)"' ) | csvsort -c 4,2,3,1
    fi
    ;;
  "listmgmt" )
    debug "attempting to list all mgmt-clusters"
    debug "attempting to list all tkcs by tns"
    if [ $MKCSV ]; then
      if [ $SAVE ]; then
        echo "fullName,ClusterGroup,health,READYmessage" > $SAVEFILE-$(date +'%Y-%m-%d_%H-%M-%S').csv
        tanzu mission-control management-cluster list -o json | jq -r '.managementClusters[] | "\(.fullName.name),\(.spec.defaultClusterGroup),\(.status.health),\(.status.conditions.READY.message)"' | grep connected >> $SAVEFILE-$(date +'%Y-%m-%d_%H-%M-%S').csv
      else
        ( echo "fullName,ClusterGroup,health,READYmessage" ;
        tanzu mission-control management-cluster list -o json | jq -r '.managementClusters[] | "\(.fullName.name),\(.spec.defaultClusterGroup),\(.status.health),\(.status.conditions.READY.message)"' | grep connected ) | $CSVLOOK 2> /dev/null
      fi
    else
      tanzu mission-control management-cluster list
    fi
    ;;
  "listworkspaces" )
    debug "attempting to list all workspaces"
    [ $DRYRUN ] && echo "tanzu mission-control workspace list -o json | jq '.workspaces[].fullName.name'" || tanzu mission-control workspace list -o json | jq '.workspaces[].fullName.name'
    ;;
  *)
    die "nothing else to do" 100
    ;;
esac

cleanup
