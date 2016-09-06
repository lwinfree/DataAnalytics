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