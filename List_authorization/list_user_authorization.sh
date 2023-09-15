#!/bin/bash

# README.MD this script use format as
# $ ./list_user_authorization.sh <user_name>

user=$1
if [ -z $1 ]
then
  echo "Please fill the format as $ ./list_user_authorization.sh <user_name>"
  exit 0
elif [ ! -z $2 ]
then
  echo "Please fill the format as $ ./list_user_authorization.sh <user_name>"
  exit 0
fi

echo -e "Warning: If there is empty spcae at namespace. It mean that namespace is default.\n"

# List clusterrole that user grant authorization
echo "************************** List ClusterRolebinding authorization ****************************"

clusterrolebinding_user_list=$(for i in $(kubectl get clusterrolebinding -A -o=jsonpath='{range .items[*]},{.subjects[*].kind},{.subjects[*].name},{.metadata.name},{.roleRef.name},{.roleRef.kind},{.subjects[*].namespace}{"\n"}{end}'); do
    echo $i ; done)
echo $clusterrolebinding_user_list | sed -e "s/ /\n/g" | grep ,$user, | awk 'BEGIN {print "User type,Subject Name,Rolebinding Name,Role/ClusterRole Name,Kind,User Namespace"} {print $0}' | column -t -s ","


echo $clusterrolebinding_user_list | sed -e "s/ /\n/g" | grep ,$user, | awk 'BEGIN {print "User type,Subject Name,Rolebinding Name,Role/ClusterRole Name,Kind,User Namespace"} {print $0}'  > clusterrole_user_list_for_script.txt

# List role that user grant authorization
echo ""
echo "************************** List Rolebinding authorization ***********************************"

rolebinding_user_list=$(for i in $(kubectl get rolebinding -A -o=jsonpath='{range .items[*]},{.subjects[*].kind},{.subjects[*].name},{.metadata.name},{.roleRef.name},{.roleRef.kind},{.subjects[*].namespace}{"\n"}{end}'); do
    echo $i ; done)
echo $rolebinding_user_list | sed -e "s/ /\n/g" | grep ,$user, | awk 'BEGIN {print "User type,Subject Name,Rolebinding Name,Role/ClusterRole Name,Kind,User Namespace"} {print $0}' | column -t -s ","

echo $rolebinding_user_list | sed -e "s/ /\n/g" | grep ,$user, | awk 'BEGIN {print "User type,Subject Name,Rolebinding Name,Role/ClusterRole Name,Kind,User Namespace"} {print $0}'  > role_user_list_for_script.txt

# Map Clusterrolebing with user
echo ""
echo "************************** ClusterRolebinding ***********************************************"

for i in $( cat clusterrole_user_list_for_script.txt | sed 1,1d); do
    # echo $i | column -t -s "," | awk '{ print $5 ,$6 }';
    kind=$(echo $i | column -t -s "," | awk '{ print $5}');
    role_name=$(echo $i | column -t -s "," | awk '{ print $4}');
    if [ -z $kind ]
    then
      kind="empty"
    fi
    if [ $kind ==  Role ]
    then
      echo kind is $kind
    elif [ $kind == ClusterRole ]
    then
      echo $i | column -t -s "," | awk '{ print $5 ,$6 }';
      kubectl describe clusterrole $role_name  | sed -n -e '/Labels/,/PolicyRule/d; p' | sed '/Name:/a PolicyRule:'
      echo =============================================================================================
    else
      echo $kind
    fi
done

# Map Rolebinding with user
echo ""
echo "*************************** Rolebinding *****************************************************"

for i in $( cat role_user_list_for_script.txt | sed 1,1d); do
    # echo $i | column -t -s "," | awk '{ print $4 , $5, default }'  | awk 'BEGIN {print "Role/ClusterRole_Name Kind Namespace"} {print $0}' | column -t -s " "
    kind=$(echo $i | column -t -s "," | awk '{ print $5}');
    role_name=$(echo $i | column -t -s "," | awk '{ print $4}');
    if [ -z $kind ]
    then
       kind="empty"
    fi
    if [ $kind ==  Role ]
    then
      role_namespace=$(echo $i | column -t -s "," | awk '{ print $6}')
      if [ -z $role_namespace ]
      then
        echo the empty spcae at namespace is default
        role_namespace=default
        echo $i | column -t -s "," | awk '{ print $4 , $5, "default"}'  | awk 'BEGIN {print "Role/ClusterRole_Name Kind Namespace"} {print $0}' | column -t -s " "
      else
        echo $i | column -t -s "," | awk '{ print $4 , $5, $6 }'  | awk 'BEGIN {print "Role/ClusterRole_Name Kind Namespace"} {print $0}' | column -t -s " "
      fi
      kubectl describe role $role_name -n $role_namespace  | sed -n -e '/Labels/,/PolicyRule/d; p' | sed '/Name:/a PolicyRule:'
      echo =============================================================================================
    elif [ $kind == ClusterRole ]
    then
      echo $i | column -t -s "," | awk '{ print $4 , $5, $6 }'  | awk 'BEGIN {print "Role/ClusterRole_Name Kind Namespace"} {print $0}' | column -t -s " "
      kubectl describe clusterrole $role_name  | sed -n -e '/Labels/,/PolicyRule/d; p' | sed '/Name:/a PolicyRule:'
      echo =============================================================================================
    else
      echo $kind
    fi
done

# remove file
rm clusterrole_user_list_for_script.txt
rm role_user_list_for_script.txt
