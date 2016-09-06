library(RSQLite)
#load all files to database
SQLiteConnection<-dbConnect(drv=SQLite(), dbname="gene.sqlite")
infiniti_genotype<-read.table("RawSyntheticData/infiniti_genotype.txt", header = TRUE, sep = "|")
dbWriteTable(conn = SQLiteConnection, name = "infiniti_genotype", value = infiniti_genotype)
medraw<-read.table("RawSyntheticData/medraw.txt", header = TRUE, sep = "|")
dbWriteTable(conn = SQLiteConnection, name = "medraw", value = medraw)
dbDisconnect(SQLiteConnection)
SQLiteConnection<-dbConnect(drv=SQLite(), dbname="gene.sqlite")
sqlStatement<-"select ig.*, m.DrugClass
from medraw m
left join infiniti_genotype ig
on ig.patientid = m.patientid"
Query<-dbGetQuery(SQLiteConnection, sqlStatement)
Query[1:10,]
dbWriteTable(conn = SQLiteConnection, name = "gene_drug", value = Query, append = TRUE)
dbDisconnect(conn = SQLiteConnection)
SQLiteConnection<-dbConnect(drv=SQLite(),dbname="gene.sqlite")
#not looking at *1 allele since it is not associated with increased bleeding w warfarin
sqlStatement<-"select gd.*, case
when DrugClass = 'Warfarin' then 1
else 0 end as DrugScore,
case when infiniti_genotype like '%*2%' then 1 
when infiniti_genotype like '%*3%' then 1
else 0 end as GeneScore
from gene_drug as gd"
Query1<-dbGetQuery(SQLiteConnection, sqlStatement)
Query1[1:10,]
dbWriteTable(conn = SQLiteConnection, name = "gene_drug_score", value = Query1, overwrite = TRUE)
dbDisconnect(conn = SQLiteConnection)
SQLiteConnection<-dbConnect(drv=SQLite(),dbname="gene.sqlite")
table<-table(Query1$GeneScore, Query1$DrugScore)
9895/(9895+6279)
#there are 9895 patients on Warfarin that have CYP2C9*2 or CYP2C9*3 annotation
#61.18% of patients with the CYP2C9*2 or CYP2C9*3 annotation were on Warfarin at discharge
#add in readmit data for analysis:
SQLiteConnection<-dbConnect(drv=SQLite(),dbname="gene.sqlite")
readmit<-read.table("RawSyntheticData/readmit_analytic.txt", header = TRUE, sep = "|")
dbWriteTable(conn = SQLiteConnection, name = "readmit", value = readmit)
dbDisconnect(conn = SQLiteConnection)
SQLiteConnection<-dbConnect(drv=SQLite(),dbname="gene.sqlite")
sqlStatement<-"select gds.*, r.readmit30
from readmit r
left join gene_drug_score gds
on gds.patientid = r.patientid"
Query2<-dbGetQuery(SQLiteConnection, sqlStatement)
Query2[1:10,]

dataSize<-nrow(Query2)
testSize<-floor(0.1*dataSize)
testIndex<-sample(dataSize, size = testSize, replace = FALSE)
testSet<-Query2[testIndex,]
trainSet<-Query2[-testIndex,]
model<-glm(readmit30 ~ GeneScore + DrugScore, family = "binomial", data = trainSet)
summary(model)
coefs<-coef(model)
expCoefs<-exp(coefs)
expCoefs
#1.116 means there is about a %11.6 increase in likelihood the patient will be on readmitted if they are on Warfarin
#1.048 means there is about a %4.8 increase in likelihood the patient will be on readmitted if they have CYP2C9*2 or CYP2C9*3 annotation
modelPredProbs<-predict(model, newdata = testSet, type = "response")
testSet<-data.frame(testSet, prepProb=modelPredProbs)
plot(testSet$GeneScore, testSet$predProd, col=testSet$DrugScore)
#that wasn't the most useful plot...let's look at log odds ratios
modelPredLOR<-predict(model, newdata = testSet)
testSetPred<-data.frame(testSet, predLogit=modelPredLOR)
plot(testSetPred$DrugScore, testSetPred$predLogit, col=testSetPred$GeneScore)
modelPredOR<-exp(modelPredLOR)
modelPredOR[1:10]
testSetPred<-data.frame(testSetPred, predOR=modelPredOR)
plot(testSetPred$DrugScore, testSetPred$predOR, col=testSetPred$GeneScore, ylab='Predicted Odds Ratio', xlab='Drug Score')
