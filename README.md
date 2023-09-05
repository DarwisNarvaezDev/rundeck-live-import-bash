# Shell Script to Import Big Quantities of Executions in Rundeck Project
Given a exported project (.jar file) the script can take all the executions and import it to a fresh rundeck project asynchronously and with visible progres throug shell console.

# Script Usage
One-liner preview:
```bash
sudo bash import-executions-to-project.sh /home/user/path/exported-job.jar 1000 my-fresh-project http://127.0.0.1:4440 admin admin my-long-rundeck-auth-token /home/user/path/to/rundeckcli/jar/rdcli.jar
```

**Args explanation:**
- $1: The job inside your rundeck server in which the executions and jobs will be imported.
- $2: Since there are many executions, the script divides them into small portions of data before sending them to the server, this argument specifies the divisor number of the total files to upload, for example, if there are 1000 files and the number is 100, they will be sent executions in groups of 100.
- $3: The fresh project in which the executions and jobs will be imported.
- $4: The rundeck server URL
- $5: Qualified role username
- $6: Qualified role password
- $7: Auth token
- $8: Rundeck CLI executable jar path
