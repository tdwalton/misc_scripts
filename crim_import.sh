#!/bin/bash

OPTIND=1

# Usage info
show_help() {
cat << EOF
Usage: ${0##*/} [-h] [-l LOCAL_DIR] [-r REMOTE_DIR] ...
-h display this help and exit
-r Copy files from REMOTEDIR in s3 defaults to root of s3 bucket
-l Copy files to LOCALDIR defaults to current directory
-b S3 bucket to copy files from. defaults to crim-prod-import-data
EOF
}

#if no arguments print help and exit
NUMARGS=$#
if [ $NUMARGS -eq 0 ]; then
  show_help
  exit 1
fi

#set defaults
s3_db_dir="/"
local_db_dir="./"
s3_bucket="crim-prod-import-data"

#while getopts ':h:l:r:b:' opt; do
while getopts "hl:r:b:" opt; do
    case "$opt" in
        h)
            show_help
            exit 1
            ;;
        l)
            local_db_dir=${OPTARG}
            ;;
        r)
            s3_db_dir=${OPTARG}
            s3_db_dir=${s3_db_dir}
            ;;
        b)
            s3_bucket=${OPTARG##*\/}
            ;;
       \?)
            show_help
            exit 1
            ;;
    esac
done

shift "$((OPTIND-1))"

#echo $local_db_dir
#echo $s3_db_dir
#echo $s3_bucket

copy s3 files to destination dir
aws s3 cp s3://$s3_bucket/$s3_db_dir/ $local_db_dir --exclude "*" --include "*.rar" --recursive 

#unrar s3 files in db dir
sudo find $local_db_dir -name "*.part01.rar" -exec rar x -o+ {} $local_db_dir  \;

#restart mysql
sudo service mysqld restart

#back up existing csvs - don't need this right now. we're going to run import on a clean instance from an AMI.
#sudo mkdir -p $local_db_dir/backup
#sudo mv -f $local_db_dir/*.csv $local_db_dir/backup/

#create dumpfile 
sudo mysql -e "SELECT IDCaseNumber, Category, LastName, FirstName, MiddleName , Generation , DOB, BirthState , AKA1, AKA2, DOBAKA, Address1, Address2, City, State, Zip , Age, Hair, Eye, Height , Weight, Race, ScarsMarks , Sex, SkinTone , MilitaryService , ChargesFiledDate , OffenseDate, OffenseCode, NCICCode , OffenseDesc1, OffenseDesc2, Counts , Plea, ConvictionDate, ConvictionPlace , SentenceYYYMMDDD , ProbationYYYMMDDD , PhotoName , Court, Source, Disposition, DispositionDate , CourtCosts , ArrestingAgency , caseType , Fines , sourceState , sourceName, caseno , fullname , ArrestDate , ParoleDate , ReleaseDate , AdmittedDate INTO OUTFILE '$local_db_dir/crim.csv' FIELDS TERMINATED BY '|' LINES TERMINATED BY '\n' FROM criminal;" -u root crim_data 

#split dumpfile into parts for map reduce job
sudo split -n l/512 --additional-suffix=.csv $local_db_dir/crim.csv /crim_data/raw/crim


