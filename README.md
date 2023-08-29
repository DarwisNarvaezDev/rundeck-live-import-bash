# Bash Scripts for Rundeck
Given a exported project (.jar file) the scripts can a) make a dir in wich there will be different directories with parts of executions and b) import each folder with executions, asynchronously to rd server via CLI.

# "Extract Executions" script
Args: $1: exported project path, $2: quantity of files per dir
Output: the dirctory "partitioned_executions" with isolated executions

Basically what the script does is to copy the given project, to a temp file in /tmp, then from that copy, extract the executions and its corresponding files to a folder, the max quantity of files per directory is by users choice via argument in script run.

The main intension is to break the executions in smaller chunks of data, so rundeck dont get too busy.

# "Import Executions" script
Args: $1: project name
Output: Imported executions in the given project

This script takes the content of "partitioned_executions" and import each dir (with executions) to rundeck
