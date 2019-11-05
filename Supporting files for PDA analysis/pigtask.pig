nycbusiness = LOAD 'hdfs://localhost:9000/nycbusiness.csv' USING PigStorage(',') AS (DCA:chararray,Type:chararray,City:chararray,Status:chararray,CreationDate:chararray,Industry:chararray,Expiration:chararray,Business:chararray,Address:chararray,Address_Street:chararray,Address_City:chararray,Address_State:chararray,ZIP:INT,Borough:chararray,

District:INT,Detail:chararray,Longitude:chararray,Latitude:chararray);
grp = GROUP nycbusiness BY Type;
out  = FOREACH grp GENERATE group, COUNT(nycbusiness.Type);
DUMP out;
STORE out INTO 'hdfs://localhost:9000/pig_out1' USING PigStorage('\t');
