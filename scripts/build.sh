#!/bin/bash -e
# https://github.com/2ndsightlabresearch/2sl-jobs
# scripts/build.sh
# author: @tradichel @2ndsightlab
# description: Build a docker container for a job
##############################################################

image="$1"
echo "Building docker image: $image"
PROFILE="$2"
test="$3"

aws ecr-public get-login-password --region us-east-1 --profile $PROFILE  \
	| docker login --username AWS --password-stdin public.ecr.aws

jobexec=$test'2sl-job-exec'
jobresources=$test'2sl-job-resources'
job=$test'2sl-jobs/jobs/'$image'/'
dockerfile=$job'Dockerfile'

echo "Dockerfile: $dockerfile"

if [ ! -f $dockerfile ]; then 
  echo "Dockerfile: $dockerfile does not exist"
  exit 1
fi

docker buildx build --tag $image -f $dockerfile \
	--build-context jobexec=$jobexec \
	--build-context jobresources=$jobresources \
  --build-context job=$job .

#################################################################################
# Copyright Notice
# All Rights Reserved.
# All materials (the “Materials”) in this repository are protected by copyright 
# under U.S. Copyright laws and are the property of 2nd Sight Lab. They are provided 
# pursuant to a royalty free, perpetual license the person to whom they were presented 
# by 2nd Sight Lab and are solely for the training and education by 2nd Sight Lab.
#
# The Materials may not be copied, reproduced, distributed, offered for sale, published, 
# displayed, performed, modified, used to create derivative works, transmitted to 
# others, or used or exploited in any way, including, in whole or in part, as training 
# materials by or for any third party.
#
# The above copyright notice and this permission notice shall be included in all 
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, 
# INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A 
# PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT 
# HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION 
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE 
# SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
################################################################################
