#setwd("/Users/stephan/Dropbox/Projekte/UNdataViz")
library(xlsx)
library(reshape2)
library(plyr)
library(stringr)

d <- read.xlsx("WHS/Master.xlsx", sheetIndex=1, stringsAsFactors=FALSE)
docCodes <- read.xlsx("WHS/codes.xlsx", sheetIndex=1, stringsAsFactors=FALSE)
#save(d, file="WHS/d.RData")
#load(file="data/d.RData")


#transform rear part of table containing document classification
document <- d[, names(d)[!grepl("^X", names(d))]]
docs <- subset(melt(document, "Filename"), !is.na(value))
docs$variable <- as.character(docs$variable)
docs$doctype <- gsub("[.][.].*$", "",docs$variable)
docs$doctypevar <- gsub("[.]"," ", gsub("^.*[.][.]", "",docs$variable))
docs$doctype[docs$doctypevar %in% c("WCA Documents","NSEA Documents","ESA Documents","EOG Documents","MENA Documents","LAC Documents","Pacific Region","SCA Documents","Global Documents")] <- "Regional.Context" #Document type is missing in original Column names of excel sheet. correct this 
docs <- dcast(docs, Filename~doctype,function(x)x[1],value.var="doctypevar")
docs$National.Context[docs$National.Context=="Syria 1"] <- "Syria" # set "Syria 1" to Sysria which was probably (hopefully) a mistake
docs <- rbind.fill(docs, data.frame(Filename=unique(subset(d, !Filename %in% docs$Filename)$Filename)))
docs$All <- "-"
# axis
tax <- read.csv("WHS/taxonomy.csv", sep=";", stringsAsFactors=FALSE) #taxonomy was extracted from pdf by hand
tax$numeric_codeid <- 1:nrow(tax)
xAxs <- tax

#yAxis
x <- sort(unique(subset(docs, !is.na(National.Context))$National.Context))
National.Context <- data.frame(numeric_id=1:length(x), doctype=x, stringsAsFactors=FALSE)
x <- sort(unique(subset(docs, !is.na(Public.Input))$Public.Input))
Public.Input <- data.frame(numeric_id=1:length(x), doctype=x, stringsAsFactors=FALSE)
x <- sort(unique(subset(docs, !is.na(Regional.Context))$Regional.Context))
Regional.Context <- data.frame(numeric_id=1:length(x), doctype=x, stringsAsFactors=FALSE)
x <- sort(unique(subset(docs, !is.na(Stakeholder.Group))$Stakeholder.Group))
Stakeholder.Group <- data.frame(numeric_id=1:length(x), doctype=x, stringsAsFactors=FALSE)
x <- sort(unique(subset(docs, !is.na(WHS.Output))$WHS.Output))
WHS.Output <- data.frame(numeric_id=1:length(x), doctype=x, stringsAsFactors=FALSE)

All <- data.frame(numeric_id=1, doctype="-", stringsAsFactors=FALSE)

yAxs <- list(National.Context=National.Context,  Public.Input=Public.Input, Regional.Context=Regional.Context, Stakeholder.Group=Stakeholder.Group, WHS.Output=WHS.Output, All=All)




#create a data.frame containing each single quotation and transfrom data
#only keep codes with citations and transpose to long format
d$document_id <- as.numeric(as.factor(d$Filename)) #Filename Column Contains duplicate Filenames. Not sure if those are meant to be the same documents. Treating them as such 
content <- d[, c("document_id", "Filename", names(d)[grepl("^X", names(d))])] #select content fields
content_long <-  subset(melt(content, c("document_id", "Filename")), value!="") #convert to long format
row.names(content_long) <- NULL #reset row.names
#split paragraphs and create a new longer data frame while forlooping over rows (very hacky and superslow) 
citations <- data.frame()
for(i in row.names(content_long)){
    if(as.numeric(i)%%500==0){cat("Line",  i, "of", nrow(content_long), fill=TRUE)}
    cits <- strsplit(content_long[i, "value"], "\n\nPg. ")[[1]]
    cits <- gsub("^Pg[.] ", "", cits)
    pgs <- str_extract(cits, "^[0-9,-]*/[0-9,-]*")
    cits <- gsub("^[0-9,-]*/[0-9,-]*: ", "", cits)
    citations <- rbind(citations, data.frame(
                                             document_id=content_long[i, "document_id"], 
                                             document=content_long[i, "Filename"], 
                                             code_name=content_long[i, "variable"], 
                                             code_category=paste("c", substring(content_long[i, "variable"], 2,2), sep=""), 
                                             code_id=tolower(substring(gsub("[..].*$","" , content_long[i,"variable"]), 2)),
                                             code_label=str_replace(str_replace_all(substring(str_extract(content_long[i, "variable"], "[..].*$"),3), "[.]", " "), "[ ]$", ""),
                                             pages=pgs, 
                                             citations=cits, 
                                             stringsAsFactors=FALSE))
}

#save(citations, file="data/citations.RData")
#load(file="data/citations.RData")
citations$category_label <- revalue(citations$code_category, c("c1"="1 Empower Affected People", "c2"="2 Humanitarian Law", "c3"="3 Localize Response", "c4"="4 Crisis Managment", "c5"="5 Humanitarian System","c6"="6 Finance Gap", "c7"="7 Innovation", "c8"="8 Gender"))
db <- merge(citations, docs, by.x="document", by.y="Filename", all=TRUE, sort=FALSE)
db <- subset(db, !is.na(pages))
db <- subset(db, citations!="")
db <- db[!duplicated(db), ]
db$pgs <- "p."
db$pgs[grepl("-",db$pages)] <- "pp."
db$pages <- paste(db$pgs, db$pages)
db$js_color <- revalue(db$code_category,c('c1'='rgba(255, 0, 0, .5)', 
                                          'c2'='rgba(255, 153, 0, .5)', 
                                          'c3'='rgba(255, 255, 0, .5)', 
                                          'c4'='rgba(204, 255, 5, .5)', 
                                          'c5'='rgba(51, 204, 0, .5)', 
                                          'c6'='rgba(61, 161, 131, .5)', 
                                          'c7'='rgba(34, 58, 189, .5)', 
                                          'c8'='rgba(166, 0, 166, .5)'))



save(db,xAxs,yAxs, file="visualizeChange/db.RData")
