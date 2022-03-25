#!/bin/bash

kubectl create job sas-stop-now-`date +%s` --from cronjob/sas-stop-all -n viya4a

