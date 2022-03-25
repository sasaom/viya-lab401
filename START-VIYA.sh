#!/bin/bash

kubectl create job sas-start-now-`date +%s` --from cronjob/sas-start-all -n viya4a

