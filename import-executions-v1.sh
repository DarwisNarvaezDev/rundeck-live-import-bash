#!/bin/bash

# User inputs
import_project_name=$1

# Variables
execs_path="/tmp/partitioned_executions"
filename="project_execs"
temp_dir=$(mktemp -d)
zip_path="/home/darwis/Downloads/project1-20230803-145653.rdproject.jar"
project_data_dir_preffix="rundeck-"

# Check 7z
check7z(){
    if command -v 7z &>/dev/null; then
        echo "p7zip-full is installed."
    else
        echo "p7zip-full is not installed..."
        apt-get update
        apt-get install p7zip-full
        if [ $? -eq 0 ]; then
            echo "p7zip-full is installed."
        else
            echo "There was an error installing p7zip-full."
        fi
    fi
}

# Progress bar
show_progress_bar() {
    local current_iteration=$1
    local total_iterations=$2
    local bar_width=50
    
    percentage=$((current_iteration * 100 / total_iterations))
    completed=$((percentage * bar_width / 100))
    remaining=$((bar_width - completed))
    
    # Mover el cursor a la siguiente línea y actualizar el progreso
    tput cuu1  # Mover el cursor hacia arriba una línea
    tput el    # Limpiar la línea actual
    printf "[%-${bar_width}s] %d%%\n" "$(printf '#%.0s' $(seq 1 $completed))" "$percentage"
}

# Extract project name
extract_internal_executions_path(){
    
    zipfile="$zip_path"
    manifest_path="META-INF/MANIFEST.MF"
    prop="Rundeck-Archive-Project-Name"
    
    echo "Extracting prop: $prop from $zipfile/$manifest_path"
    
    prop_value=$(unzip -p "$zipfile" "$manifest_path" | grep "$prop" | cut -d ' ' -f 2-)
    
    prop_value=$(echo "$prop_value" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
    
    echo "$prop value: $prop_value"
    zip_internal_route="$project_data_dir_preffix$prop_value/executions"
    
}

# Extract META-INF path
extract_meta_path(){
    
    manifest_path="META-INF"
    
    echo "Extracting $manifest_path path..."
    
    meta_path="$temp_dir/$manifest_path"
    
    if [ -d "$meta_path" ]; then
        echo "Meta path found: $meta_path"
    else
        echo "Meta path not found: $meta_path"
        exit 1
    fi
    
}

# Extract jobs path
extract_jobs_path(){
    
    internal_path="$project_data_dir_preffix$prop_value"
    jobs_path_preffix="jobs"
    
    echo "Extracting $jobs_path_preffix path..."
    
    job_path="$temp_dir/$internal_path/$jobs_path_preffix"
    
    if [ -d "$job_path" ]; then
        echo "Jobs path found: $job_path"
    else
        echo "Jobs path not found: $job_path"
        exit 1
    fi
    
}

# BEGIN
echo "Checking 7z..."
check7z

echo "Navigating to /tmp..."
cd "/tmp"

# Create a unzipped copy of the rd project in /tmp
echo "Creating tmp file from zip..."
unzip -qq "$zip_path" -d "$temp_dir"

extract_internal_executions_path
extract_meta_path
extract_jobs_path

# Create a model dir to the jobs and executions
echo "Creating zip-to-be dir in /tmp... "
mkdir -p "$filename"

# Make a copy of meta-inf and jobs, then move it to the created dir
echo "Creating a copy of meta to zip..."
cp -r $meta_path "$filename"

echo "Creating a copy of jobs from zip..."
mkdir -p "$filename/$project_data_dir_preffix$prop_value"
cp -r $job_path "$filename/$project_data_dir_preffix$prop_value"

# Loop through the executions folder and, by iteration, copy the folder to the created folder and
# change its name to "executions", then zip it and upload it as a rd project to server
loop=0
total_dirs=total_dirs=$(find "$execs_path" -maxdepth 1 -type d | wc -l)
for subdir in "$execs_path"/*; do
    if [ -d "$subdir" ]; then
        echo "Dir found: $subdir"
        
        # Copy the dir to the executions path and change the name for rundeck
        echo "Copying the executions to the zip-to-be file..."
        cp -r $subdir "$filename/$project_data_dir_preffix$prop_value/executions"
        
        # zip the entire created dir as a rd project
        cd "$filename" && echo "from $PWD"
        echo "Zipping file..."
        
        # Properly zip file as a multipart component
        7za -v100m a "../rundeck-project-$loop.jar" .

        # Destroy the exec folder to make a new one in the future
        rm -rf $project_data_dir_preffix$prop_value/executions
        
        # Checkout to /tmp
        cd .. && echo "checking the zipped file in $PWD"

        # Upload to server and then destroy the file in temp
        echo "Importing to project: , file: rundeck-project-$loop.jar.001"
        java -jar /home/darwis/rdcli/rd.jar projects archives import -c -f "/tmp/rundeck-project-$loop.jar.001" -p "$import_project_name"

        # Debug purposes
        # if [ "$loop" -eq 5 ]; then
        #     exit 1
        # fi

        ((loop += 1))

        rm -rf $subdir

        show_progress_bar $loop $total_dirs
        
    else
        echo "Directory $subdir not found"
    fi
done

cd "/tmp"

rm -rf rundeck-* "$filename" "tmp.*"

show_progress_bar $total_dirs $total_dirs

echo "All executions uploaded!"
