# ku() {
#   kubectl $@
# }

alias ku=kubectl

if [[ -d $HOME/.krew/bin ]]; then
  export PATH="${KREW_ROOT:-$HOME/.krew}/bin:$PATH"
fi
# install jq, yq.  Depends on `autoconf` and `libtool`
[[ $(command -v yq) ]] || pip install --user -U jq yq pygments==2.3.1
# https://github.com/sharkdp/bat - bat for colorization
# alias kf='kubefed'
# alias kufu='kubefed'

get_current_namespace() {
  if [[ ! -z ${KUBE_CURRENT_CLUSTER} ]]  ; then
    KUBE_CURRENT_NAMESPACE=$(kubectl config view --minify --output 'jsonpath={..namespace}')
    echo ${KUBE_CURRENT_NAMESPACE}
  fi
}

kubectl() {
  [[ -z ${AWS_PROJECT} ]] && [[ ${CLIENT_CONTEXT} == 'amfam' ]] && echo "ERROR: set AWS_PROJECT with 'awo project YOUR_PROJECT'"
  if [[ ${CLIENT_CONTEXT} == 'amfam' ]]; then
    export KUBE_COMMAND="aws-okta exec ${AWS_PROJECT} -- kubectl"
  else
    export KUBE_COMMAND="command kubectl"
  fi
  case $1 in
    namespace|ns)
      if [[ $2 ]] ; then
        [[ -z $(${KUBE_COMMAND} get namespaces | grep ${2}) ]] && echo "ERROR: invalid namespace ${2}" && return
        kubectl config set-context $(kubectl config current-context) --namespace=${2} 2>&1 >>/dev/null
        export KUBE_CURRENT_NAMESPACE=$2
      else
        get_current_namespace
      fi
      ;;
    get)
      shift
      # action=$(echo ${@} | awk '{$1=$2=$3="";$0=$0;$1=$1}1')
      # ${KUBE_COMMAND} ${1} ${2} --no-headers ${action}
      ${KUBE_COMMAND} get --no-headers ${@}
      ;;
    l)
      sub_container=''
      if [[ $3 ]] ; then
        echo "sub_container is ${3}"
        sub_container=" -c ${3}"
      fi
      # grab the first matching pod's logs.
      podname=$(${KUBE_COMMAND} get pods --all-namespaces | grep ${2} | head -n 1 | awk '{ print $1, $2 }')
      [[ -z ${podname} ]] && return
      podnamespace=$(echo ${podname} | awk '{ print $1 }' )
      podname=$(echo ${podname} | awk '{ print $2 }' )
      # container='' && [[ ${3} == '-c' ]] && [[ ${4} ]] && container="-c ${4} "
      echo "kubectl logs --namespace ${podnamespace} -f ${container} ${podname}${sub_container}"
      ${KUBE_COMMAND} logs --namespace ${podnamespace} -f ${container} ${podname}${sub_container}
      ;;
    delete-context)
      [[ -z $2 ]] && echo "No context given, exiting" && return
      CONTEXT_INFO=$(kubectl config get-contexts --no-headers $2 | tr -d '*' )
      kubectl config unset users.$(echo ${CONTEXT_INFO} | awk '{ print $3 }')
      [[ $(kubectl config get-clusters | egrep "^${2}$") ]] && kubectl config delete-cluster $(kubectl config get-clusters | egrep "^${2}$")
      kubectl config delete-context $(echo ${CONTEXT_INFO} | awk '{ print $1 }')
      ;;
    kill)
      if [[ -z $2 ]] ; then
        echo "No pod provided, nothing to do."
      else
        set ${@:2}
        ${KUBE_COMMAND} delete pod "$@" --grace-period=0 --force
      fi
      ;;
    gkill)
      if [[ -z $2 ]] ; then
        echo "No pod provided, nothing to do."
        echo "Usage: $1 podname [podname] [podname] [-y]"
      else
        set ${@:2}
        unset pod_list
        unset final_list
        pod_list=$(${KUBE_COMMAND} get pods -n ${KUBE_CURRENT_NAMESPACE} | awk '{ print $1 }')
        for i in $@ ; do
          if [[ $i != '-y' ]]; then
            final_list+=$(echo $pod_list | tr ' ' '\n' | grep $i)
          fi
        done
        echo "Pod List is:"
        echo "${final_list}"
        if [[ ${@: -1} == "-y" ]]; then
          ${KUBE_COMMAND} delete pod ${final_list} --grace-period=0 --force
        else
          printf "\nAppend '-y' to this command, to actually kill the pods.\n"
        fi
      fi
      ;;
    wipe)
      command read -r -a physical_volume <<< "$(ku get pvc | grep ${2})"
      echo "deleting pv ${physical_volume[2]} and pvc ${physical_volume[0]}"
      kubectl delete pv ${physical_volume[2]}
      kubectl delete pvc ${physical_volume[0]}
      kubectl delete pod $2 --grace-period=0 --force
      ;;
    gp)
      shift
      if [[ $1 ]] ; then
        ${KUBE_COMMAND} get pod --all-namespaces | grep $1
      else
        ${KUBE_COMMAND} get pod | tail -n +2
      fi
      ;;

    decrypt)
      shift
      command kubesecret.py -j "$@"
      ;;
    desc|de)
      shift
      ${KUBE_COMMAND} describe "$@"
      ;;
    rm|del)
      shift
      ${KUBE_COMMAND} delete "$@"
      ;;
    ingresslogs|il)
      namespace="ingress-nginx"
      pod_name="nginx-ingress-controller"
      if [[ $2 == "kill" ]] ; then
        ${KUBE_COMMAND} delete pod --grace-period=0 --force --wait=false --namespace=${namespace} $(${KUBE_COMMAND} get pods --namespace=${namespace} | grep ${pod_name} | awk '{ print $1 }')
      else
        ${KUBE_COMMAND} logs -f --namespace=${namespace} --tail=100 $(${KUBE_COMMAND} get pods --namespace=${namespace} | grep ${pod_name} | awk '{ print $1 }')  | grep -v --line-buffered 'change in configuration'
      fi
      ;;
    ubuntu)
      ${KUBE_COMMAND} run -it --rm --image=ubuntu ${2:-test-ubuntu} /bin/bash
      ;;
    image)
      ${KUBE_COMMAND} run -it --rm --image=${2} test-image-$(whoami) /bin/sh
      ;;
    clobber)
      ${KUBE_COMMAND} delete -f $2 ; kubectl create -f $2
      ;;
    db)
      if [[ $2 == "redis" ]] ; then
        pf_pod=$(${KUBE_COMMAND} get po -lapp=proxy-mysql-client | tn2 | head -n 1 | awk '{ print $1 }' )
        if [[ ${pf_pod} ]] ; then
          ${KUBE_COMMAND} port-forward $(${KUBE_COMMAND} get pods | grep proxy-mysql | awk '{ print $1 }') 6379:6379
        else
          echo "ERROR: no proxy-mysql pod found, aborting..." && return
        fi
      elif [[ $2 ]] ; then
        vault kv get secret/${2}-mysql | grep root | awk '{ print $NF }'
      fi
      ${KUBE_COMMAND} port-forward $(${KUBE_COMMAND} get pods | grep proxy-mysql | awk '{ print $1 }') 3306:3306
      ;;
    cord)
      ${KUBE_COMMAND} drain  --ignore-daemonsets  --force --delete-local-data $2
      ;;
    health)
      ${KUBE_COMMAND} get pods --all-namespaces | egrep -v '1/1|2/2|3/3|4/4|5/5|6/6|7/7|Completed'
      for i in $(${KUBE_COMMAND} get pods -n kube-system -lname=weave-net | awk '{ print $1 }' | tail -n +2) ; do
        res=$(${KUBE_COMMAND} exec -i -t ${i} -c weave -n kube-system -- ping -c1 icanhazip.com)
        if [[ $? -ne 0 ]] ; then
          printf "FAILED"
          res="FAILED"
        else
          res="OK"
        fi
        echo "${i} : ${res}"
      done
      ;;
    token)
      if [[ -z ${2} ]] ; then
        echo "using ${KUBE_CURRENT_CLUSTER}"
      fi
      token_location="/var/run/shm/$(whoami)/${CLIENT_CONTEXT}/${KUBE_CURRENT_CLUSTER}.token"
      kubeconfig_location=/var/run/shm/$(whoami)/${CLIENT_CONTEXT}/${KUBE_CURRENT_CLUSTER}-kubeconfig.yaml
      export KUBECONFIG=${kubeconfig_location}
      aws eks update-kubeconfig --name ${KUBE_CURRENT_CLUSTER}
      aws eks get-token --cluster-name ${KUBE_CURRENT_CLUSTER} | jq .status.token | tr -d '"' > $token_location
      kubectl config set-credentials $(whoami) --token=$(<$token_location)
      kubectl config set-context --current --user=$(whoami)
      ;;
    dump)
      shift
      resource=${@: -2:1}
      item=${@: -1:1}
      set -- "${@:1:$(($#-2))}"
      echo ${resource}-${item}.yaml
      kubectl export ${@} ${resource} ${item} > ${resource}-${item}.yaml
      ;;

    export)
    shift
      # "Yeah, the docs are a bit weak on this point. .foo is just shorthand for .["foo"], like in JS (or lua)." - https://github.com/stedolan/jq/issues/207

      # del(.[][] | select(. == null)) - deletes all null/empty keys - https://github.com/stedolan/jq/issues/104#issuecomment-17818922

      # del(.. | .terminationMessagePath?, .terminationMessagePolicy? ) - deletes objects that matc these values.  Needed as there may be multple container entries. - https://stackoverflow.com/questions/47371280/delete-objects-and-arrays-with-jq-which-match-a-key

      ${KUBE_COMMAND} get -ojson $@ | jq '
        del(
          .metadata.annotations."deployment.kubernetes.io/revision",
          .metadata.annotations."pv.kubernetes.io/bind-completed",
          .metadata.annotations."pv.kubernetes.io/bound-by-controller",
          .metadata.annotations."kubectl.kubernetes.io/last-applied-configuration",
          .metadata.creationTimestamp,
          .metadata.generation,
          .metadata.resourceVersion,
          .metadata.selfLink,
          .metadata.uid,
          .spec.claimRef,
          .spec.progressDeadlineSeconds,
          .spec.revisionHistoryLimit,
          .spec.strategy,
          .spec.template.metadata.creationTimestamp,
          .status
        ) | del(.. |
          .terminationMessagePath?,
          .terminationMessagePolicy?,
          .dnsPolicy?,
          .restartPolicy?,
          .schedulerName?,
          .terminationGracePeriodSeconds?
        ) | walk(
       if type == "array" then
         map(select(. != null))
       elif type == "object" then
         with_entries(
           select(
             .value != null and
             .value != "" and
             .value != [] and
             .value != {}
           )
         )
       else
         .
       end
    )' | yq e -P -
      ;;
    *)
      ${KUBE_COMMAND} "$@"
      ;;
  esac
}

# delete user entries: https://github.com/kubernetes/kubectl/issues/396
#   Get users: kubectl config view -o jsonpath='{range .users[*]}{.name}{"\n"}{end}'
#   Delete them: kubectl config unset users.${name of user to delete}

containsElement () {
  local e match="$1"
  shift
  for e; do [[ "$e" == "$match" ]] && return 0; done
  return 1
}

kuby() {
  if [[ -z $(cat ${KUBECONFIG}) ]]  ; then
    export KUBE_CURRENT_CLUSTER=''
    return
  fi

  if [ -z ${1} ]; then
    export KUBE_CURRENT_CLUSTER=$(kubectl config view | grep current-context | awk '{ print $NF }' | awk -F '.' '{ print $1 }')
    return
  fi

  clustername=${1}
  kubecfg_clusters=$(kubectl config get-clusters | tail -n +2 | awk -F '.' '{ print $1 }')
  in_cluster=False
  for i in ${kubecfg_clusters} ; do
    if [[ ${clustername} == "${i}" ]] ; then
      in_cluster=True
    fi
  done
  if [[ ${in_cluster} != "True" ]] ; then
    echo "WARNING: ${clustername} not in kubecfg!"
    export KUBE_CURRENT_CLUSTER=${clustername}
    return
  fi

  kubectl ns ${default_namespace}
  export KUBE_CURRENT_CLUSTER=$(kubectl config view | grep current-context | awk '{ print $NF }' | awk -F '.' '{ print $1 }')
}

kshell() {
  [[ "${1}" == "" ]] && echo "Usage: ${FUNCNAME[0]} [-c container_name] <pod>" && return
  if [[ ${1} == '-c' ]] ; then
    shift
    CONTAINER=" -c ${1}"
    shift
  else
    CONTAINER=
  fi
  POD=${1}
  shift
  if [[ ${1} ]] ; then
    COMMAND=${@}
  else
    COMMAND="bash"
  fi
  POD=$(${KUBE_COMMAND} get pods | grep ${POD} | head -n 1 | awk '{ print $1 }')
  if [[ ${POD} == ${1} ]] ; then
    echo "Found exact match ${POD}"
  else
    echo "Using first match, ${POD}"
  fi
  COLUMNS=$(tput cols)
  LINES=$(tput lines)
  TERM=xterm
  echo "kubectl exec -i -t ${POD}${CONTAINER} env COLUMNS=${COLUMNS} LINES=${LINES} TERM=${TERM} -- ${COMMAND}"
  kubectl exec -i -t ${POD}${CONTAINER} env COLUMNS=${COLUMNS} LINES=${LINES} TERM=${TERM} -- ${COMMAND}
}

dshell() {
  [[ "${1}" == "" ]] && echo "Usage: ${FUNCNAME[0]} <pod>" && return
  POD=${1}
  shift
  if [[ ${1} ]] ; then
    COMMAND=${@}
  else
    COMMAND="bash"
  fi
  COLUMNS=$(tput cols)
  LINES=$(tput lines)
  TERM=xterm
  docker exec -i -t --env COLUMNS=$COLUMNS --env LINES=$LINES --env TERM=$TERM ${POD} ${COMMAND}
}

kri() {
  TEST_POD="test-ubuntu"
  if [[ ${1} == "" ]] ; then
    command kubectl run -it --rm --image=ubuntu ${2:-${TEST_POD}} /bin/bash && return
  elif [[ ${1} == "kill" ]]; then
    if [[ -z ${2} ]]; then
      POD=$(${KUBE_COMMAND} get pods | awk '{ print $1 }' | grep ${TEST_POD})
      echo POD is $POD
      if [[ ${POD} ]] ; then
        echo "killing pod ${POD}"
        command kubectl delete deployment ${TEST_POD} --grace-period=0 --force
      fi
    fi
  fi

}

# ky() {
#   if [ -z ${1} ]; then
#     export KUBE_CURRENT_CLUSTER=$(kubectl config current-context | awk -F '.' '{ print $1 }')
#     return
#   fi


#   kubecfg_contexts=$(kubectl config get-contexts | tail -n +2 | tr -d '*' | awk '{ print $1 }')
#   in_contexts=False

#   # -f flag, force usage of a kube context regardless of the client context
#   if [[ ${1} == "-f" ]] ; then
#     clustername=${2}
#     for i in ${kubecfg_contexts} ; do
#       if [[ ${i} == ${2} ]] ; then  # KUBE_CLUSTER_DOMAIN set by client_context.sh
#         echo kubectl config use-context ${clustername}
#         kubectl config use-context ${clustername}
#         if [[ $? -eq 0 ]] ; then
#           export KUBE_CURRENT_CLUSTER=$(kubectl config current-context | awk -F '.' '{ print $1 }')
#           export KUBE_CURRENT_NAMESPACE=$(kubectl config view --minify --output 'jsonpath={..namespace}')
#         fi
#       fi
#     done
#     return
#   fi

#     # KUBE_CURRENT_CLUSTER=$(kubectl config current-context | awk -F '.' '{ print $1 }')


#   clustername=${1}.${KUBE_CLUSTER_DOMAIN}

#   for i in ${kubecfg_contexts} ; do
#     if [[ ${clustername} == ${i} ]] ; then  # KUBE_CLUSTER_DOMAIN set by client_context.sh
#       in_contexts=True
#     fi
#   done

#   if [[ ${in_contexts} != "True" ]] ; then
#     echo "ERROR: ${clustername} not found in KUBE_CLUSTER_DOMAIN ${KUBE_CLUSTER_DOMAIN}!"
#     return
#   fi

#   # echo kubectl config use-context ${clustername}
#   export KUBE_CURRENT_CLUSTER=${1}
#   kubectl config use-context ${clustername}
#   export KUBE_CURRENT_NAMESPACE=$(kubectl config view --minify --output 'jsonpath={..namespace}')

# }
