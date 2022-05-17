#! /bin/bash

###################################################################
#Script Name	:   Birthday
#Description	:   Update the README.md file
#Args           :   None
#Author       	:   Antonio Pantaleo
#Email         	:   antonio_pantaleo@icloud.com
###################################################################

YEAR=$(date +'%Y')
AGE=$(($YEAR - 1996))

yq -i ".age = $AGE" data/homepage.yaml