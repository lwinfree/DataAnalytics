#next HW use deyo codes for comorbidities 428.x congestive heart failure, 290.x dementia
#use string searched "like"
# C score
sqlStatement<-"select patientid, sum(dem) as demCode,
case when sum(dem) > 0 then 3
else 0 end as comorbidDem
from (select *, case when ICD9Code like '290.%' then 1
else 0 end as dem 
from patient_diagnosis)
group by patientid"
dementia<-dbGetQuery(SQLiteConnection, sqlStatement)
dementia[1:10,]
#FYI, could also do it like:
#make temp table
#ICD9<-c("290.00", "290.20", "290.30", "290.40", "290.43")
#dem<-data.frame(ICD9)
#dbWriteTable(conn = SQLiteConnection, name = "dem", value = dem, append = TRUE)
# don't disconnect bc is only temp table
#sqlStatement<-"select patientid, sum(dem) as demCode,
#case when sum(dem) > 0 then 2
#else 0 end as comorbidDem
#from (select *, case when pd.ICD9Code=dem.ICD9 then 1
#else 0 end as dem
#from patient_diagnosis as pd, dem)
#group by patientid"
dbWriteTable(conn = SQLiteConnection, name = "demScore", value = dementia, append = TRUE)
dbDisconnect(conn = SQLiteConnection)
SQLiteConnection<-dbConnect(drv=SQLite(),dbname="patient1.sqlite")

#do same for congestive heart failure 
sqlStatement<-"select patientid, sum(chf) as chfCode,
case when sum(chf) > 0 then 2
else 0 end as comorbidCHF
from (select *, case when ICD9Code like '428.%' then 1
else 0 end as chf
from patient_diagnosis)
group by patientid"
heart<-dbGetQuery(SQLiteConnection, sqlStatement)
heart[1:10,]
dbWriteTable(conn = SQLiteConnection, name = "CHFscore", value = heart, append = TRUE)
dbDisconnect(conn = SQLiteConnection)
SQLiteConnection<-dbConnect(drv=SQLite(),dbname="patient1.sqlite")

#merge comorbidities scores to my LAE table
sqlStatement<-"select l.*, dem.comorbidDem, chf.comorbidCHF, 
(dem.comorbidDem + chf.comorbidCHF) as CScore
from LAE as l
left join demScore dem on l.patientid=dem.patientid
left join CHFscore chf on l.patientid=chf.patientid"
merged<-dbGetQuery(SQLiteConnection, sqlStatement)
merged[1:10,]
dbWriteTable(conn = SQLiteConnection, name = "total", value = merged, append = TRUE)
dbDisconnect(conn = SQLiteConnection)
SQLiteConnection<-dbConnect(drv=SQLite(),dbname="patient1.sqlite")
#sum
sqlStatement<-"select *, (Lscore + Ascore + CScore + Escore) as LACE from total"
tot<-dbGetQuery(SQLiteConnection, sqlStatement)
tot[1:20,]