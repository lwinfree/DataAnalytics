#start HW2 LACE
#calculate length of stay using julianday
sqlStatement<-"select Admit.*, julianday(Discharge_date) - julianday(Admit_date) 
as LengthOfStay from Admit where index_admit = 1"
len<-dbGetQuery(SQLiteConnection, sqlStatement)
len[1:10,]
#save table
dbWriteTable(conn = SQLiteConnection, name = "LenAdmit", value = len, append = TRUE)
dbDisconnect(conn = SQLiteConnection)
SQLiteConnection<-dbConnect(drv=SQLite(),dbname="patient1.sqlite")
#recode dates for LACE score
sqlStatement<-"select LenAdmit.*, case
when LengthOfStay = 1 then 1
when LengthOfStay = 2 then 2
when LengthOfStay = 3 then 3
when LengthOfStay > 3 and LengthOfStay < 7 then 4
when LengthOfStay > 6 and LengthOfStay < 14 then 5
when LengthOfStay > 13 then 7
else 0 end as Lscore
from LenAdmit"
lQuery<-dbGetQuery(SQLiteConnection,sqlStatement)
lQuery[1:10,]
#save table
dbWriteTable(conn = SQLiteConnection, name = "L_Admit", value = lQuery, append = TRUE)
dbDisconnect(conn = SQLiteConnection)
SQLiteConnection<-dbConnect(drv=SQLite(),dbname="patient1.sqlite")
#get A score
sqlStatement<-"select L_Admit.*, case
when Admit_source = 'Emergency Room' then 3
else 0 end as Ascore
from L_Admit"
aQuery<-dbGetQuery(SQLiteConnection, sqlStatement)
aQuery[1:10,]
#save table
dbWriteTable(conn = SQLiteConnection, name = "EDAdmit", value = aQuery, append = TRUE)
dbDisconnect(conn = SQLiteConnection)
SQLiteConnection<-dbConnect(drv=SQLite(),dbname="patient1.sqlite")
#E score
sqlStatement<-"select pe.*,
case when pe.encounter_type = 48 then 1 else 0 end as EDVisits
from EDAdmit as ed, patient_encounter as pe
where pe.patientID = ed.patientID and
date(pe.Actual_date) < date(ed.Admit_date, '-180 day')"
eQuery<-dbGetQuery(SQLiteConnection, sqlStatement)
eQuery[1:10,]
dbWriteTable(conn = SQLiteConnection, name = "e48", value = eQuery, append = TRUE)
dbDisconnect(conn = SQLiteConnection)
SQLiteConnection<-dbConnect(drv=SQLite(),dbname="patient1.sqlite")
#count ED visits 
sqlStatement<-"select patientID,
case when count(EDVisits)>4 then 4 else count(EDVisits)
end as Escore
from (select pe.*,
case when pe.encounter_type = 48 then 1 else 0 end as EDVisits
from EDAdmit as ed, patient_encounter as pe
where pe.patientID = ed.patientID and
date(pe.Actual_date) < date(ed.Admit_date, '-180 day'))
group by patientID"
eeQuery<-dbGetQuery(SQLiteConnection, sqlStatement)
eeQuery[1:10,]
dbWriteTable(conn = SQLiteConnection, name = "EDValue", value = eeQuery, append = TRUE)
dbDisconnect(conn = SQLiteConnection)
SQLiteConnection<-dbConnect(drv=SQLite(),dbname="patient1.sqlite")
#left join tables
sqlStatement<-"select ed.*, e.Escore
from EDValue as e 
left join EDAdmit as ed 
on ed.patientID = e.patientID"
esQuery<-dbGetQuery(SQLiteConnection, sqlStatement)
esQuery[1:10,]
dbWriteTable(conn = SQLiteConnection, name = "LAE", value = esQuery, append = TRUE)
dbDisconnect(conn = SQLiteConnection)
SQLiteConnection<-dbConnect(drv=SQLite(),dbname="patient1.sqlite")