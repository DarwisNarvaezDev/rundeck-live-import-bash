#!/bin/bash

# User provided vars
zip_path=$1
files_per_dir=$2
import_project_name=$3
user_rd_url=$4
user_rd_username=$5
user_rd_password=$6
user_rd_token=$7
user_rdcli_home=$8

# Variables
dest_dir_exists=false
dest_dir="/tmp/partitioned_executions"
filecount=0
dircount=0
filename="project_execs"
temp_dir=""
project_data_dir_preffix="rundeck-"

# Check if the dir in which the partitioned execution will be stored exists,
# if don't, skip all extraction process.
echo "Checking the existence of dir: $dest_dir in /tmp..."
if [ ! -d "$dest_dir" ]; then
    dest_dir_exists=false
    echo "Dir: $dest_dir not found, begining extraction process.."
    echo "Creating $dest_dir dir..."
    mkdir -p "$dest_dir"
else
    echo "Dir found: $dest_dir, skipping extraction process.."
    dest_dir_exists=true
fi

# Report
show_extraction_progress() {
    echo -ne "Files being moved: $filecount from $files_per_dir | Folders created $dircount | Total of files to be copied: $temp_dir_size \r"
}

# Scape plan
trap "rm -rf \"tmp.*\" \"$dest_dir\"; echo -e \"\nInterruption detected. Temp files and dirs removed.\"; exit 1" INT

####################### EXECUTIONS EXTRACTION PROCESS #################################
do_execution_extraction(){
    # ZIP Extract the dir name in which the executions and other components are.
    extract_internal_executions_path(){
        zipfile="$zip_path"
        manifest_path="META-INF/MANIFEST.MF"
        prop="Rundeck-Archive-Project-Name"
        
        echo "Extracting prop: $prop from $zipfile/$manifest_path"
        
        prop_value=$(unzip -p "$zipfile" "$manifest_path" | grep "$prop" | cut -d ' ' -f 2-)
        
        prop_value=$(echo "$prop_value" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
        
        zip_internal_route="rundeck-$prop_value/executions"
    }
    
    make_tmp_import_project_copy(){
        echo "Making a copy of $zip_path in /tmp..."
        temp_dir=$(mktemp -d)
        unzip -qq "$zip_path" -d "$temp_dir"
        temp_dir_size=$(ls -l $temp_dir/$zip_internal_route | grep "^-" | wc -l)
    }
    
    create_new_file() {
        new_folder="$dest_dir/execs_$((++dircount))"
        mkdir -p "$new_folder"
        filecount=0
    }
    
    
    # Extracting execution internal path in zip
    extract_internal_executions_path
    
    # ZIP content to temp file
    make_tmp_import_project_copy
    
    # Crear la primera carpeta
    create_new_file
    
    # Find execution (.xml), output (.rdlog) and state files an then move it to a dir,
    # being aware of the max size of the dir (by user arg).
    find "$temp_dir/$zip_internal_route" -type f -name "execution-*.xml" | while read fileRead; do
        file_name=$(basename "$fileRead")
        exec_number=$(echo "$file_name" | sed -E 's/execution-([0-9]+).xml/\1/')
        
        if [ -n "$exec_number" ]; then
            # Check if we need to create a folder
            if [ $filecount -ge $files_per_dir ]; then
                create_new_file
            fi
            
            output_name="output-$exec_number.rdlog"
            state_name="state-$exec_number.state.json"
            
            # Check if the files exists
            if [ -f "$temp_dir/$zip_internal_route/$output_name" ] && [ -f "$temp_dir/$zip_internal_route/$state_name" ]; then
                mv "$fileRead" "$new_folder"
                mv "$temp_dir/$zip_internal_route/$output_name" "$new_folder"
                mv "$temp_dir/$zip_internal_route/$state_name" "$new_folder"
                
                ((filecount += 3))
                
                show_extraction_progress
            fi
        fi
    done
    
    echo "Extracting process ended."
}
####################### EXECUTIONS EXTRACTION PROCESS #################################

####################### EXECUTIONS IMPORT PROCESS #####################################
do_executions_import(){
    # Check 7z lib
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
        
        job_path="$temp_dir/$internal_path/$jobs_path_preffix"

        echo "Extracting $jobs_path_preffix path from $job_path"
        
        if [ -d "$job_path" ]; then
            echo "Jobs path found: $job_path"
        else
            echo "Jobs path not found: $job_path"
            exit 1
        fi
        
    }
    
    echo "Checking 7z..."
    check7z
    
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
    
    export RD_URL=$user_rd_url
    export RD_USER=$user_rd_username
    export RD_PASSWORD=$user_rd_password
    export RD_TOKEN=$user_rd_token
    
    echo "Checking exported vars:"
    echo "RD_URL: ${RD_URL}"
    echo "RD_USER: ${RD_USER}"
    echo "RD_PASSWORD: ${RD_PASSWORD}"
    echo "RD_TOKEN: ${RD_TOKEN}"
    
    # Loop through the executions folder and, by iteration, copy the folder to the created folder and
    # change its name to "executions", then zip it and upload it as a rd project to server
    loop=0
    total_dirs=$(find "$dest_dir" -maxdepth 1 -type d | wc -l)
    echo "Processing dirs qty: $total_dirs"
    
    sleep 4
    
    for subdir in "$dest_dir"/*; do
        if [ -d "$subdir" ]; then
            echo "Dir found: $subdir"
            
            # Copy the dir to the executions path and change the name for rundeck
            echo "Copying the executions to the zip-to-be file..."
            cp -r $subdir "$filename/$project_data_dir_preffix$prop_value/executions"
            
            # zip the entire created dir as a rd project
            cd "$filename" && echo "from $PWD"
            echo "Zipping file..."
            
            # Properly zip file as a multipart component
            7za -v100m a "/tmp/rundeck-project-$loop.jar" .
            
            # Destroy the exec folder to make a new one in the future
            rm -rf $project_data_dir_preffix$prop_value/executions
            
            # Checkout to /tmp
            cd .. && echo "checking the zipped file in $PWD"
            
            # Upload to server and then destroy the file in temp
            echo "Importing to project: $import_project_name, file: rundeck-project-$loop.jar.001"
            java -jar "$user_rdcli_home" projects archives import -c -f "/tmp/rundeck-project-$loop.jar.001" -p "$import_project_name"
            
            # # Debug purposes
            # if [ "$loop" -eq 5 ]; then
            #     exit 1
            # fi
            
            echo "Removing created zip: /tmp/rundeck-project-$loop.jar.001"
            rm -rf "/tmp/rundeck-project-$loop.jar.001"
            
            show_progress_bar $loop $total_dirs
            
            ((loop += 1))
            
        else
            echo "Directory $subdir not found"
        fi
    done
    
    cd "/tmp"
    show_progress_bar $total_dirs $total_dirs
    echo "All executions uploaded!"
}
####################### EXECUTIONS IMPORT PROCESS #####################################

do_execution_extraction
do_executions_import

# Cleaning files from /tmp
echo "Cleaning /tmp files..."
rm -rf "rundeck-*" "$filename" "tmp.*" "$dest_dir" "$temp_dir"

echo "Process finished, please check rundeck to see the imported executions."