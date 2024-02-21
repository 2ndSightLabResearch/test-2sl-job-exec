#!/bin/bash -e
# https://github.com/tradichel/2sl-jobs
# jobs/awsdeploy/run.sh
# author: @teriradichel @2ndsightlab
# Description: Run a job to deploy resource on AWS
##############################################################

######################## 
#upgrade buildx if it's still at version 0
#hopefully this will not be neccessary in the future
#if AWS Linux 2023 gets updated, including CloudShell
########################
buildxversion=$(docker buildx version | cut -d " " -f2 | cut -d "+" -f1)
echo "Buildx Version: $buildxversion"

if [ "$buildxversion" == "v0.0.0" ]; then
  git clone https://github.com/docker/buildx.git
  cd buildx
  sudo make install
  mkdir -p ~/.docker/cli-plugins #no sudo
  sudo install bin/build/buildx ~/.docker/cli-plugins/docker-buildx
  cd ..
  rm -rf buildx
  buildxversion=$(docker buildx version)
  echo "Buildx updated to version: $buildxversion"
  echo "If using CloudShell, restart to free up space and run this script again"
fi

d=`basename "$PWD"`
base=$(echo $d | sed 's|-exec||')

if [[ $base == test* ]]; then test="test-"; fi

########################
# warn if in wrong directory and offer
# to move to correct directory
########################
thisfile="run_local.sh"

if [ "$d" == $base'-exec' ] || [ -f "README.md" ]; then
  echo "You are in this directory:"
  echo $d
  echo -e "\nIt appears you may be executing this file from the repository"
  echo "directory. You need to execute it from the folder one level up"
  echo "that contains all four 2SL Job Exec Framework repositories."
  echo "Would you like to copy the file one level? (y)"
  read y
  if [ "$y" == "y" ]; then
    cp $thisfile ../
    echo "File successfully copied. Changing to directory one level up."
    cd ..
    sh -c "./$thisfile"
  fi
  exit
fi

# Check for CloudShell credentials
# Otherwise ask for CLI Profile

creds=$(curl -H "Authorization: $AWS_CONTAINER_AUTHORIZATION_TOKEN" $AWS_CONTAINER_CREDENTIALS_FULL_URI 2>/dev/null || true)
 
y=""
if [ "$creds" != "" ]; then 
	echo "Do you want to use CloudShell credentials?"
	read "y"
fi

if [ "$y" == "y" ]; then 

	PROFILE=""

  creds=$(curl -H "Authorization: $AWS_CONTAINER_AUTHORIZATION_TOKEN" $AWS_CONTAINER_CREDENTIALS_FULL_URI 2>/dev/null)

  if [ "$creds" == "" ]; then echo "No CloudShell credentials found"; exit; fi
  region=$AWS_REGION
  sudo yum install jq -y

  accesskeyid="$(echo $creds | jq -r ".AccessKeyId")"
  secretaccesskey="$(echo $creds | jq -r ".SecretAccessKey")"
  sessiontoken="$(echo $creds | jq -r ".Token")"
else
 
  echo "Enter AWS CLI profile that can read the SSM Job Parameter and credential secret." 
  
    read PROFILE

    while [ "$PROFILE" == "" ]; do
      echo "An AWS CLI profile is required."
      read PROFILE
    done
fi

echo "********************************************"
echo "Define repositories"
echo "********************************************"
repo_exec=$test'2sl-job-exec'
repo_resources=$test'2sl-job-resources'
repo_config=$test'2sl-job-config'
repo_job=$test'2sl-jobs'

echo "Repositories:"
echo $repo_exec
echo $repo_resources
echo $repo_job

if [ ! -d $repo_exec ]; then echo "$repo_exec does not exist. Are you in the correct directory?"; exit; fi
if [ ! -d $repo_resources ]; then echo "$repo_resources does not exist. Are you in the correct directory?"; exit; fi
if [ ! -d $repo_job ]; then echo "$repo_job does not exist. Are you in the correct directory?"; exit; fi

echo "Do you want to delete existing repositories and re-clone?"
read y


if [ "$y" == "y" ]; then
  echo "ARE YOU SURE??? (y)"
  read y
fi

if [ "$y" == "y" ]; then
  echo "********************************************"
  echo "Delete and clone the repositories"
  echo "********************************************"

  if [ -d $repo_exec ]; then rm -rf $repo_exec; fi
  if [ -d $repo_resources ]; then rm -rf $repo_resources; fi
  if [ -d $repo_job ]; then rm -rf $repo_job; fi
 
  echo "********************************************"
  echo "Clone the repositories"
  echo "********************************************"
  owner="2ndsightlabresearch"

  git clone https://github.com/$owner/$repo_exec
  git clone https://github.com/$owner/$repo_resources 
  git clone https://github.com/$owner/$repo_job

fi

echo "********************************************"
echo "List available job configurations in Parameter Store"
echo "********************************************"
echo "Available Jobs:"

if [ "$PROFILE" == "" ]; then p=""; else p="--profile $PROFILE"; fi

aws ssm describe-parameters --query "Parameters[*].Name" $p \
 | grep "/job" | sed 's|"||g' | sed 's|,||'

echo "Copy and paste the paramter name for the job you want to run:"
read ssm_param_name


echo "********************************************"
echo "Build the container"
echo "********************************************"

#pass in test prefix if using test repositories
./$repo_exec/scripts/build.sh awsdeploy $PROFILE $test

echo "Push to and pull to validate correct image is in ECR? (y)"; read push
if [ "$push" == "y" ]; then 
	echo "********************************************"
	echo "********** Push container to ECR ***********"
	echo "********************************************"
	./container/push.sh; 
	
	image="awsdeploy"
	echo "********************************************"
	echo " Pull image back down (testing push worked correctly)"
	echo "********************************************"
	source container/pull.sh
fi

echo "********************************************"
echo "Get the credentials for the current user"
echo "From SSM Parameter Store"
echo "********************************************"
username=$(aws sts get-caller-identity --profile $PROFILE \
        | grep user | cut -d "/" -f2 | sed 's|"||g')

#account=current account for now
account=$(aws sts get-caller-identity --query Account --output text --profile $PROFILE)

#region=current region for now
region=$(aws configure list --profile $PROFILE | grep region | awk '{print $2}')

echo "********************************************"
echo "Retreiving secret: 'arn:aws:secretsmanager:'$region':'$account':secret:'$username"
echo "********************************************"

echo "NOT TESTED YET AFTER THIS POINT. Enter to continue. Ctrl-C to exit"
read ok

secret=$(aws secretsmanager get-secret-value \
  --secret-id 'arn:aws:secretsmanager:'$region':'$account':secret:'$username \
  --query SecretString --output text --profile $PROFILE)

validate_set $s "Access key and secret key in secret $username" $secret
access_key_id=$(echo $secret | jq -r ".aws_access_key_id")
secret_key=$(echo $secret | jq -r ".aws_secret_key")
validate_set $s "access_key_id in secret $username." $access_key_id
validate_set $s "secret_key in secret $username." $secret_key

echo "********************************************"
echo "Get job profile"
echo "********************************************"

#the job profile and job role name are one and the same 
#and come from the SSM Parameter Name
jobprofile=$(echo $ssm_param_name | cut -d "/" -f5)
echo $jobprofile

echo "********************************************"
echo "Get the secret for the current user"
echo "********************************************"

echo "NOT DONE. NEED TO PARSE JOB PROFILE OUT OF SSM PARAM AND OBTAIN CREDS"
read ok

echo "********************************************"
echo "Pass credentials to container"
echo "********************************************"
parameters="\
  profile=$jobprofile,\
  accesskey=$accesskeyid,\
  secretaccesskey=$secretaccesskey,\
  sessiontoken=$sessiontoken,\
  region=$AWS_REGION,\
  jobconfig=$ssm_parameter_name"

#remove any spaces so the parameter list is treated as a single argument passed to the container
parameters=$(echo $parameters | sed 's/ //g')

echo "********************************************"
echo "Run the container $image and execute the job $job_parameter"
echo "********************************************"
echo "docker run $image $parameters"
docker run $image $parameters

