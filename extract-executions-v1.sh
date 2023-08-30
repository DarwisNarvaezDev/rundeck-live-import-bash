#!/bin/bash

# Variables
filecount=0
dircount=0
zip_path=$1
dest_dir="/tmp/partitioned_executions"
files_per_dir=$2

# Exporting envs
sh ./export_envs.sh

# ZIP internal route
extract_internal_executions_path(){
    
    zipfile="$zip_path"
    manifest_path="META-INF/MANIFEST.MF"
    prop="Rundeck-Archive-Project-Name"
    
    echo "Extracting prop: $prop from $zipfile/$manifest_path"
    
    prop_value=$(unzip -p "$zipfile" "$manifest_path" | grep "$prop" | cut -d ' ' -f 2-)
    
    prop_value=$(echo "$prop_value" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
    
    echo "$prop value: $prop_value"
    zip_internal_route="rundeck-$prop_value/executions"
    
}

# Extracting execution internal path in zip
extract_internal_executions_path

# ZIP content to temp file
temp_dir=$(mktemp -d)
unzip -qq "$zip_path" -d "$temp_dir"
temp_dir_size=$(ls -l $temp_dir/$zip_internal_route | grep "^-" | wc -l)

show_progress() {
    echo -ne "Files being moved: $filecount from $files_per_dir | Folders created $dircount | Total of files to be copied: $temp_dir_size \r"
}

# If an exit signal is detected, temp files and dirs will be deleted
trap "rm -rf \"$temp_dir\" \"$dest_dir\"; echo -e \"\nInterruption detected. Temp files and dirs removed.\"; exit 1" INT

# Check if the destination folder exists, create it if not
if [ ! -d "$dest_dir" ]; then
    mkdir -p "$dest_dir"
fi

create_new_file() {
    new_folder="$dest_dir/execs_$((++dircount))"
    mkdir -p "$new_folder"
    filecount=0
}

# Crear la primera carpeta
create_new_file

# Buscar y mover los archivos
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
            
            show_progress
        fi
    fi
done

rm -rf "$temp_dir" tmp.* partitioned_executions

echo -e "\nProcess completed."
