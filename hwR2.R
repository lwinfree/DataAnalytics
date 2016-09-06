install.packages("RSQLite")
library(RSQLite)
#load all files to database
SQLiteConnection<-dbConnect(drv=SQLite(), dbname="patient1.sqlite")
patient<-read.table("RawSyntheticData/patient.txt", header = TRUE, sep = "|")
dbWriteTable(conn = SQLiteConnection, name = "patient", value = patient)
patient_encounter_hosp<-read.table("RawSyntheticData/patient_encounter_hosp.txt", header = TRUE, sep = "|")
dbWriteTable(conn = SQLiteConnection, name = "patient_encounter_hosp", value = patient_encounter_hosp)
patient_encounter<-read.table("RawSyntheticData/patient_encounter.txt", header = TRUE, sep = "|")
dbWriteTable(conn = SQLiteConnection, name = "patient_encounter", value = patient_encounter)
patient_diagnosis<-read.table("RawSyntheticData/patient_diagnosis.txt", header = TRUE, sep = "|")
dbWriteTable(conn = SQLiteConnection, name = "patient_diagnosis", value = patient_diagnosis)
race<-read.table("RawSyntheticData/race.txt", header = TRUE, sep = "|")
dbWriteTable(conn = SQLiteConnection, name = "race", value = race)
t_encounter_reason<-read.table("RawSyntheticData/t_encounter_reason.txt", header = TRUE, sep = "|")
dbWriteTable(conn = SQLiteConnection, name = "t_encounter_reason", value = t_encounter_reason)
t_encounter_type<-read.table("RawSyntheticData/t_encounter_type.txt", header = TRUE, sep = "|")
dbWriteTable(conn = SQLiteConnection, name = "t_encounter_type", value = t_encounter_type)
dbDisconnect(SQLiteConnection)

#self join
SQLiteConnection<-dbConnect(drv=SQLite(),dbname="patient1.sqlite")
sqlStatement <- "select peh.patientid as pehPatientID, peh.Event_ID as pehEventID,
peh.Admit_date as pehAdmitDate, peh2.patientid as peh2PatientID,
peh2.Event_ID as peh2EventID, peh2.Admit_date as peh2AdmitDate
from patient_encounter_hosp peh 
left join patient_encounter_hosp peh2 on
peh.patientID=peh2.patientID
and date(peh2.admit_date) < date(peh.admit_date)"
queryResult<-dbGetQuery(SQLiteConnection, sqlStatement)
queryResult[1:15,]

#nulls are index cases
#make case statement to add these to peh table
sqlStatement<-"select peh.*, 
case when peh2.admit_date is null then 1 else 0 end as index_admit
from patient_encounter_hosp peh
left join patient_encounter_hosp peh2 on
peh.patientID=peh2.patientID and
date(peh2.admit_date)<date(peh.admit_date)"
queryResult2<-dbGetQuery(SQLiteConnection, sqlStatement)
queryResult2[1:15,]

#save table
dbWriteTable(conn = SQLiteConnection, name = "indexAdmit", value = queryResult2, append = TRUE)
dbDisconnect(conn=SQLiteConnection)
SQLiteConnection<-dbConnect(drv=SQLite(),dbname="patient1.sqlite")

#combine
sqlStatement<-"select i.*, case when date(i2.admit_date) < date(i.admit_date, '+30 day') 
then 1 else 0 end as readmit30
from indexAdmit i
left join indexAdmit i2 on
i.patientID=i2.patientID and
date(i2.admit_date)>date(i.admit_date)"
queryResult5<-dbGetQuery(SQLiteConnection, sqlStatement)
queryResult5[1:15,]

#how many readmissions were for more than 30 days?
table(queryResult2$index_admit, queryResult5$readmit30)
readMore30=3494/(31038+3494)
readMore30
#save table
dbWriteTable(conn = SQLiteConnection, name = "Admit", value = queryResult5, append = TRUE)
dbDisconnect(conn=SQLiteConnection)
SQLiteConnection<-dbConnect(drv=SQLite(),dbname="patient1.sqlite")
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

#analysis
analytic<-read.delim("RawSyntheticData/readmit_analytic.txt", header=TRUE, sep="|")
analytic$A<-factor(analytic$A)
readLscoreTab<-table(analytic$readmit30, analytic$L)
readLscoreTab
readLscoreTab[2,]/readLscoreTab[1,]
readAscoreTab<-table(analytic$readmit30, analytic$A)
readAscoreTab[2,]/readAscoreTab[1,]
readCscoreTab<-table(analytic$readmit30, analytic$C)
readCscoreTab[2,]/readCscoreTab[1,]
readEscoreTab<-table(analytic$readmit30, analytic$E)
readEscoreTab[2,]/readEscoreTab[1,]
#get test and train sets
dataSize<-nrow(analytic)
testSize<-floor(0.1*dataSize)
testSize
testIndex<-sample(dataSize, size=testSize, replace=FALSE)
testIndex[1:10]
length(testIndex)
#build testSet
testSet<-analytic[testIndex,]
nrow(testSet)
#build trainSet
trainSet<-analytic[-testIndex]
nrow(trainSet)
colnames(trainSet)
laModel<-glm(readmit30 ~ L + A, family="binomial", data=trainSet)
summary(laModel)
coef(laModel)
lcModel<-glm(readmit30 ~ L + C, family="binomial", data=trainSet)
summary(lcModel)
coef(lcModel)
acModel<-glm(readmit30 ~ A + C, family="binomial", data=trainSet)
summary(acModel)
coef(acModel)
leModel<-glm(readmit30 ~ L + E, family="binomial", data=trainSet)
summary(leModel)
coef(leModel)
aeModel<-glm(readmit30 ~ A + E, family="binomial", data=trainSet)
summary(aeModel)
coef(aeModel)
ceModel<-glm(readmit30 ~ C + E, family="binomial", data=trainSet)
summary(ceModel)
coef(ceModel)
laeModel<-glm(readmit30 ~ L + A + C, family="binomial", data=trainSet)
summary(laeModel)
coef(laeModel)
laceModel<-glm(readmit30 ~ L + A + C + E, family="binomial", data=trainSet)
summary(laceModel)
coef(laceModel)
#transform coeffs by exponentiating them
coefs<-coef(laModel)
expCoefs<-exp(coefs)
expCoefs
modelPredProb<-predict(laModel, newdata=testSet, type="response")
testSet<-data.frame(testSet, predProb=modelPredProb)
plot(testSet$L, testSet$predProb, col=testSet$A)
#check other models
coefs<-coef(laceModel)
expCoefs<-exp(coefs)
expCoefs

coefs<-coef(ceModel)
expCoefs<-exp(coefs)
expCoefs

modelPredLogOR<-predict(laModel, newdata = testSet)
modelPredOR<-exp(modelPredLogOR)
testSetPred<-data.frame(testSetPred, predOR=modelPredOR)
plot(testSetPred$L, testSetPred$predOR, col=testSetPred$A, ylab="Predicted Odds Ratio", xlab="L score")

#prediction time
#hist of predicted probabilites 
hist(modelPredProb)
#set threshold at 0.225
modelPred<-ifelse(modelPredProb<0.225,0,1)
modelPred[1:10]
#crosstab
truthPred<-table(testSet$readmit30, modelPred)
truthPred
#calculate accuracy
totalCases<-sum(truthPred)
misclass<-truthPred[1,2]+truthPred[2,1]
misclass
accuracy<-(totalCases-misclass)/totalCases
accuracy
#greater than 75% accuracy!
#ROC Curve analysis:
install.packages("ROCR")
library(ROCR)
pr<-prediction(modelPredProb, testSet$readmit30)
prf<-performance(pr, measure="tpr", x.measure = "fpr")
plot(prf, main="ROC Curve")
#measure area under curve to summ model performance
auc<-performance(pr, measure = "auc")
auc<-auc@y.values[[1]]
auc