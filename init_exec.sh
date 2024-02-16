#!/bin/bash -e
# https://github.com/2ndSightLabResearch/2sl-job-exec
# /init-exec.sh
# author: @tradichel @2ndsightlab
# Description: Download the code required to run jobs
# using the 2nd Sight Lab Job Execution Framework
# Prerequisite: Run the init script in the config
# repo to and deploy an SSM Parameter with the 
# configuration of the job you want to run
#####################################################

d=`basename "$PWD"`
base=$(echo $d | sed 's|-exec||')

########################
# warn if in wrong directory and offer
# to move to correct directory
########################

if [ "$d" == $base'-exec' ] || [ -f "README.md" ]; then
  echo "You are in this directory:"
  echo $d
  echo -e "\nIt appears you may be executing this file from the repository"
  echo "directory. You need to execute it from the folder one level up"
  echo "that contains all four 2SL Job Exec Framework repositories."
  echo "Would you like to copy the file one level? (y)"
  read y
  if [ "$y" == "y" ]; then
    cp init.sh ../
    echo "File successfully copied. Changing to directory one level up."
    cd ..
    sh -c "./init.sh"
  fi
  exit
fi

echo "Before you can execute jobs you need to deploy a configuration"
echo "to SSM Parameter store. If you have not already done that,"
echo "run init-config.sh in the the 2sl-job-config repository first."
echo "(Enter to proceed, ctrl-c to exit.)"
read ok

echo -e "\nDo you want to use the test version of the repos?"
echo "The test repos start with test- in front of the names above."
echo "Type 'test' (no quotes) to use the test version otherwise type enter."
read test

if [ "$test" == "test" ]; then test="test-"; else test=""; fi

PARENT_FOLDER=$test'2sl-job'
if [ "$base" != $PARENT_FOLDER ]; then
  echo "You need to clone the repositories into a folder named"
  echo "$PARENT_FOLDER. Do you want to create that directory? (y)"
  read create
  if [ "$create" == "y" ]; then
		if [ -d $PARENT_FOLDER ]; then
			echo "Parent folder $PARENT_FOLDER already exists."
			echo "Do you want to delete it and everything in it it to proceed? (y for yes or enter to continue)"
			read delete
			if [ "$delete" == "y" ]; then
				echo "Deleteing $PARENT_FOLDER ok? (Crtl-c to exit)"
				read ok
				rm -rf $PARENT_FOLDER
			else
				create="n"
			fi 
		fi
		if [ "$create" == "y" ]; then
    	mkdir $PARENT_FOLDER
		fi
  fi
fi 

cd $PARENT_FOLDER

REPO_EXEC=$test'2sl-job-exec'
REPO_RESOURCES=$test'2sl-job-resources'
REPO_JOBS=$test'2sl-jobs'

echo "Repositories to be cloned. Enter to continue, ctrl-c to exit."
echo $REPO_EXEC
echo $REPO_RESOURCES
echo $REPO_JOBS
read ok

if [ -d $REPO_EXEC ]; then echo "$REPO_EXEC already exists"; else
	git clone 'https://github.com/2ndSightLabResearch/'$REPO_EXEC'.git'
fi

if [ -d $REPO_RESOURCES ]; then echo "$REPO_RESOURCES already exists"; else
  git clone 'https://github.com/2ndSightLabResearch/'$REPO_RESOURCES'.git'
fi

if [ -d $REPO_JOBS ]; then echo "$REPO_JOBS already exists"; else
  git clone 'https://github.com/2ndSightLabResearch/'$REPO_JOBS'.git'
fi

echo -e "\nYou now have the required code to run jobs"
echo 'To run one now you can execute this script: '$REPO_EXEC'/run_local.sh'
