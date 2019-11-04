echo "Starting all the services"
cd

start-all.sh

echo " MySQL data loaded"
: '
echo "Sqoop done"
hadoop dfs -cp /nycbusiness/part-m-00000 /nycbusiness/nycbusiness.csv 
echo " Files are in HDFS "
'
echo "Running Hadoop jar files"

echo " running industry nyc"
hadoop jar industrynyc.jar /nycbusiness /nycindustry
hadoop fs -ls /nycindustry

echo " running city nyc"
hadoop jar city.nyc /nycbusiness /nycbusinesscity

hadoop fs -ls /nycbusinesscity

echo "hive table creation"
hive -e "CREATE TABLE nycbusiness ( DCANumber STRING,LicenseType STRING,City STRING,Status STRING,LicenseCreationDate STRING,Industry STRING,ExpDate STRING,
BusinessName STRING,Building STRING,
Street STRING,AddressCity STRING,
State STRING,Zip INT,AddressBorough STRING,CouncilDistrict INT,Detail STRING,Longitude STRING,Lattitude STRING)
ROW FORMAT DELIMITED
FIELDS TERMINATED BY ','"

echo "Loading data into Hive from HDFs location"
hive -e "load data inpath '/nycbusiness/nycbusiness.csv' into TABLE nycbusiness"


echo "Hive queries"


select zip,count(*) as noofbusiness from nycbusiness group by zip having noofbusiness>500"

echo "License Type"

hive -e "INSERT OVERWRITE DIRECTORY '/licensestate' ROW FORMAT DELIMITED FIELDS TERMINATED BY '\t' select licenseType,count(*) from nycbusiness group by licenseType"

hive -e "INSERT OVERWRITE DIRECTORY '/licensestate' ROW FORMAT DELIMITED FIELDS TERMINATED BY '\t'
select 'No of Expired License', count(*)  from nycbusiness where split(expdate,'/')[2]<2019 union
select 'No of Active License', count(*) from nycbusiness where split(expdate,'/')[2]>=2019"


echo " Pig task"

pig -x local pigtask.pig

echo " all output files are in HDFS"

echo "Moving data from HDFS to HBase"

cho "Creating HBase table"
cd /usr/local/hbase/bin

echo "create ‘pig’, ‘cf1’ “ |  ./hbase shell
echo "create ‘hive1’, ‘cf1’ “ |  ./hbase shell
echo "create ‘hive2’, ‘cf1’ “ |  ./hbase shell
echo "create ‘MapReduce1’, ‘cf1’ “ |  ./hbase shell
echo "create ‘MapReduce2’, ‘cf1’ “ |  ./hbase shell
cd

cd /usr/local/hbase

#Moving output data from HDFS to HBase
#MapReduce Task 1 to HBase
bin/hbase org.apache.hadoop.hbase.mapreduce.ImportTsv  -Dimporttsv.columns=HBASE_ROW_KEY,cf1:count MapReduce1 /nycbusinesscity/part-r-00000

#MapReduce Task 2 to HBase
bin/hbase org.apache.hadoop.hbase.mapreduce.ImportTsv  -Dimporttsv.columns=HBASE_ROW_KEY,cf1:count MapReduce2 /nycindustry/part-r-00000

#Hive task 1 output to HBase
bin/hbase org.apache.hadoop.hbase.mapreduce.ImportTsv  -Dimporttsv.columns=HBASE_ROW_KEY,cf1:count hive1 /zipcodewise/000000_0

#Hive task 2 output to HBase
bin/hbase org.apache.hadoop.hbase.mapreduce.ImportTsv  -Dimporttsv.columns=HBASE_ROW_KEY,cf1:count hive2 /licensestate/000000_0

#Pig data HBase

bin/hbase org.apache.hadoop.hbase.mapreduce.ImportTsv  -Dimporttsv.columns=HBASE_ROW_KEY,cf1:count pig /pig_out/part-r-00000

echo "Moving data to HBase is done"

echo "Exporting data from HBase to HDFS and then moving it to local."
cd /usr/local/hbase/

echo "In hanse directory"

echo " Starting hbase services"
bin/start-hbase.sh


bin/hbase org.apache.hadoop.hbase.mapreduce.Export pig hbase_pig
bin/hbase org.apache.hadoop.hbase.mapreduce.Export hive1 hbase_hive1
bin/hbase org.apache.hadoop.hbase.mapreduce.Export hive2 hbase_hive2
bin/hbase org.apache.hadoop.hbase.mapreduce.Export  MapReduce1 hbase_MR1
bin/hbase org.apache.hadoop.hbase.mapreduce.Export  MapReduce2 hbase_MR2

cd

hadoop fs -ls hbase_pig
hadoop fs -ls hbase_hive1
hadoop fs -ls hbase_hive2
hadoop fs -ls hbase_MR1
hadoop fs -ls hbase_MR2


echo "Moving data to local file system for future analysis
hadoop fs -copyToLocal hbase_pig hbasePigOutput
hadoop fs -copyToLocal hbase_hive1 hbase_hive1out
hadoop fs -copyToLocal hbase_hive2 hbase_hive2out
hadoop fs -copyToLocal hbase_MR1 hbase_MR1out
hadoop fs -copyToLocal hbase_MR2 hbase_MR2out