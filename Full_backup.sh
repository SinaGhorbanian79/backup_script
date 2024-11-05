#!/bin/bash

# Function for getting backup from files and directories
file_backup() {
    local source_path=$1
    local dest_file_path=$2
    
    if [ -e "$dest_file_path" ]; then
        echo "File already exist"
        exit 1
    fi
    
    local dirname=$(dirname "$source_path")
    local dest_dirname=$(dirname "$dest_file_path")
    
    if [ -e "$source_path" ] && [ -d "$dest_dirname" ]; then
        local file_or_direcotry_name=$(basename "$source_path")
        local new_file_path="${dest_file_path}"
        if tar zcvf "$new_file_path" -C "$dirname" "$file_or_direcotry_name"; then
            echo "$new_file_path Backup Successful"
        else
            echo "$new_file_path Backup Failed"
        fi
    else
        echo "Source or dest path Doesn't Exist"
    fi
}

# Function for getting backup from databases that are not in a container
database_backup() {
    local database_name=$1
    local database_user=$2
    local database_password=$3
    
    if [ -z "$database_password" ]; then
        read -s -p "Enter database password: " database_password
        echo  # for a new line after the password input
    fi
    
    local dest_file_path=$4
    
    if [ -e "$dest_file_path" ]; then
        echo "File already exist"
        exit 1
    fi
    
    local dirname=$(dirname "$dest_file_path")
    
    if [ -d "$dirname" ]; then
        local database_backup_name="${dest_file_path}"
        if mysqldump -u "$database_user" -p"$database_password" "$database_name" > "$dest_file_path"; then
            echo "$dest_file_path Backup Successful"
        else
            echo "$dest_file_path Backup Failed"
        fi
    else
        echo "Destination path doesn't exist"
    fi
}

# Function for getting backup from databases that are in a container
database_docker_backup() {
    local container_name=$1
    local database_name=$2
    local database_user=$3
    local database_password=$4
    
    if [ -z "$database_password" ]; then
        read -s -p "Enter database password: " database_password
        echo  # for a new line after the password input
    fi
    
    local dest_file_path=$5
    
    if [ -e "$dest_file_path" ]; then
        echo "File already exist"
        exit 1
    fi
    
    local dirname=$(dirname "$dest_file_path")
    
    if [ -d "$dirname" ]; then
        local database_backup_name="${dest_file_path}"
        if docker exec -i "$container_name" mysqldump -u "$database_user" -p"$database_password" "$database_name" > temp_backup && mv temp_backup "$database_backup_name"; then
            echo "$database_backup_name Backup Successful"
        else
            echo "$database_backup_name Backup Failed"
        fi
    else
        echo "Destination path doesn't exist"
    fi

}

backup_type=""
file_or_directory_source_path=""
database_name=""
database_user=""
database_password=""
backup_file_destination_path=""
container_name=""

usage() {
    echo "Usage: $0 [--file --source file_or_directory_path --path path] [--database --container(or not) c_name --dbname dbname --dbuser dbuser --path path]"
    echo "Options:"
    echo "  -f, --file                  Specify that the type of the backup is file or directory"
    echo "  -d, --database              Specify that the type of the backup is database"
    echo "  -c, --container c_name      Specify that the database is in a container and provide containers name or id"
    echo "  -p, --path dest_file_path   Specify the path to save the backup file"
    echo "  -s, --source source_path    Specify the source path to the file or directory you want to get a backup from"
    echo "  -n, --dbname dbname         Specify the database name"
    echo "  -u, --dbuser dbuser         Specify the database username"
    echo "  -w, --dbpass dbpass         Specify the database password"
    echo "  -h, --help                  Shows this message"
    exit 1
}

PARSED_ARGS=$(getopt -o fdc:p:s:n:u:w:h --long file,database,container:,path:,source:,dbname:,dbuser:,dbpass:,help -- "$@")

if [ $? -ne 0 ]; then
    usage
fi

eval set -- "$PARSED_ARGS"

while true; do
    case "$1" in
        -f|--file)
            backup_type="file"
            shift 1
            ;;
        -d|--database)
            backup_type="database"
            shift 1
            ;;
        -c|--container)
            container_name="$2"
            shift 2
            ;;
        -p|--path)
            backup_file_destination_path="$2"
            shift 2
            ;;
        -s|--source)
            file_or_directory_source_path="$2"
            shift 2
            ;;
        -n|--dbname)
            database_name="$2"
            shift 2
            ;;
        -u|--dbuser)
            database_user="$2"
            shift 2
            ;;
        -w|--dbpass)
            database_password="$2"
            shift 2
            ;;
        -h|--help)
            usage
            ;;
        --)
            shift
            break
            ;;
        *)
            usage
            ;;
    esac
done

if [ "$backup_type" == "file" ]; then
    if [ -z "$backup_file_destination_path" ] || [ -z "$file_or_directory_source_path" ]; then
        echo "Error: For file backup, both --path (destination path) and --source (source path) are required."
        usage
    else
        file_backup "$file_or_directory_source_path" "$backup_file_destination_path" 
    fi

elif [ "$backup_type" == "database" ]; then
    if [ -z "$container_name" ]; then
        if [ -z "$database_name" ] || [ -z "$database_user" ] || [ -z "$backup_file_destination_path" ]; then
            echo "Error: For database backup, all --path (destination path) and --dbname (source path) and --dbpass and --dbuser are required."
        else
            database_backup "$database_name" "$database_user" "$database_password" "$backup_file_destination_path"
        fi
    else
        if [ -z "$database_name" ] || [ -z "$database_user" ] || [ -z "$container_name" ] || [ -z "$backup_file_destination_path" ]; then
            echo "Error: For database in container backup, all --path (destination path) and --dbname (source path) and --dbpass and --dbuser and --container are required."
        else
            database_docker_backup "$container_name" "$database_name" "$database_user" "$database_password" "$backup_file_destination_path"
        fi
    fi
else
    echo "Backup type wasn't specified"
fi