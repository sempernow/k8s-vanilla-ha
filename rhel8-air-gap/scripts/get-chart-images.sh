#!/usr/bin/env bash
######################################
# Get all images of a Helm chart
#
# ARGs: /path/to/chart
######################################
##################################################################
#·The·"helm·template"·method·of·getting·the·image·dependencies•
#·reveals·only·those·images·that·would·run·as·containers·under•
#·the·current·settings·at·values.yaml
##################################################################

# YAML images (Helm charts and others)
[[ -d $1 ]] || exit 1

chart_root=$1

# To capture all chart images in form required by container tools (repo/name:tag), 
# values across many fields must be collected and assembled:
list=chart.images.log

find $chart_root -type f -iname '*.yaml' -exec cat {} \; |grep -A1 repository: \
    |cut -d':' -f2 \
    |sed 's,",,g' \
    |grep -v -- -- \
    |grep -v -- { \
    |xargs -n 2 printf "%s:%s\n" \
    |sort -u \
    |tee $list
# AND 
find $chart_root -type f -iname '*.yaml' -exec cat {} \; |grep image: \
    |grep -v -- { \
    |cut -d':' -f2,3,4,5 \
    |sed '/^$/d' \
    |sort -u \
    |sed 's, ,,g' \
    |sed 's,",,g' \
    |tee -a $list 

exit 0
######

