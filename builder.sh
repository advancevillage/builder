#!/usr/bin/env bash

##
#INFO: deb|rpm 制作器
##

export root=`dirname $0`
. $root/job/deb.sh

os=${1:-"ubuntu"}
project=${2:-"letaotao"}


case "$os" in
ubuntu)
    deb_config_dir $project
    ;;
clean)
    rm -rf $root/build
    ;;
*)
   echo "$0 support [ubuntu]"
   exit 1
   ;;
esac
