#! /bin/sh

solutionId="amshelpr"
securitydom=$(/bin/secpolicytools -D ${solutionId}Dom)
if [ $? -ne 0 ]; then
 /bin/logger daemon.info "could not find vmkaccess domain ${solutionId}Dom"
fi
CMD=$1
shift
$CMD ++group=host/vim/vmvisor/${solutionId},securitydom=${securitydom} "$@"
