# clear workspace
rm(list = ls())

#getting packages installed/loaded
packages <- c("rvest", "stringi", "stringr", "downloader", "insol")
if (length(setdiff(packages, rownames(installed.packages()))) > 0) {
  install.packages(setdiff(packages, rownames(installed.packages())))  
}

####### INPUT REQUIRED ############

# specify the start and end dates for the results ('yyyy-mm-dd')
start_date <- '1900-01-01'
end_date <- '2016-12-31'

# setting the work directory 
setwd("//netid.washington.edu/wfs/EvansEPAR/Project/EPAR/Working Files/372 - EPAR Tools Development/_TOOLS_Main_Folder/pdf_extractor")

# reading the file with urls
url_file <- read.csv("web_input_search_terms2.csv") 

####################################

# loading packages
library(rvest)
library(stringi)
library(stringr)
library(downloader)
library(insol)

# creating a relevant date range for google query
sdate <- as.POSIXct(strptime(start_date, "%Y-%m-%d"))
edate <- as.POSIXct(strptime(end_date, "%Y-%m-%d"))
sdate_jd <- round(JD(sdate, inverse=FALSE))
edate_jd <- round(JD(edate, inverse=FALSE))
daterange_query <- paste0('+daterange:', sdate_jd, '-', edate_jd)

# downloading the top 10 results (within "web_results" folder)
# deleting it first
unlink("web_results", recursive = TRUE)
dir.create("web_results")

# assigning a column name to the url file
colnames(url_file) <- "urls"

# specifiying a function to download the files from the web
downloadUrl <- function(url){
  out <- tryCatch(
    {
      # isolating the filename
      filename <- tail(unlist(strsplit(url, "/", fixed = TRUE)), n = 1)
      # hitting the url and downloading the file
      download(url, paste0(down_path, "/", file_url, filename), mode = "wb")
      # sleep for some seconds
      Sys.sleep(sample(10:250, 1) * 0.1)
    },
    error = function(cond){
      message("Encountered an error:")
      message(cond)
    }
  )
  if(inherits(out, "error")) next
}

# assigning unique id to every url
unq_id_url <- as.vector(seq(from = 1, to = length(url_file$urls)))
unq_id_url <- sprintf("url_%03d", unq_id_url)

# initialzing the counter
cntr <- 0
# taking urls one-by-one
len_url <- length(url_file$urls)
for (i in 1:len_url){
  cntr <- cntr + 1
  # progress counter
  prog <- (cntr/len_url)*100
  # printing progress
  print (paste0(round(prog,2), "% of search terms processed..."))
  url <- as.character(url_file[i,])
  # printing the urls
  print (url)
  # assigning the url ids
  url_id <- unq_id_url[i]
  # making the url in the right format
  # only retreiving pdf filetypes for the search query
  squery <- str_replace_all(url,"[\\s]+","+")
  # handling queries in single quotes
  squery <- gsub("'", "%22", squery)
  # getting only pdf results
  squery <- paste0(squery, "+filetype:pdf", daterange_query)
  squery <- paste0("http://www.google.com/search?q=", squery)
  
  # getting cleaned results from the first page
  html_s <- read_html(squery)
  vector_links <- html_s %>% html_nodes(xpath='//h3/a') %>% html_attr('href')
  vector_links <- gsub('/url\\?q=','',sapply(strsplit(vector_links[as.vector(grep('url', vector_links))],split='&'),'[',1))
  
  # initializing vector to save cleaned (http) links only
  vector_clean <- vector(mode = "character")
  # checking the resulting vector has all elements in the http format
  for (j in 1:length(vector_links)){
    if (grepl("http", vector_links[j]) == TRUE){
      vector_clean <- append(vector_clean, vector_links[j])
    }
  }
  
  # appending url string in front of every file
  file_url <- str_replace_all(url_id,"[\\s]+","_")
  file_url <- paste0(file_url, '#$')
  
  # downloading the results now
  down_path <- paste0(getwd(), "/web_results")
  lapply(vector_clean, downloadUrl)
  
  # sleep for some seconds
  Sys.sleep(sample(5:50, 1) * 0.1)
}

# reading the downloaded files
pdf_path <- paste0(getwd(),'/web_results/') 
pdf_files <- list.files(path = pdf_path, pattern = ".pdf$",  full.names = FALSE)

# removing the files smaller than 10 KB
pdf_size <- list.files(path = pdf_path, pattern = ".pdf$",  full.names = TRUE)
files_keep <- pdf_size[sapply(pdf_size, file.size) > 10000]
all_files <- list.files(path = pdf_path, full.names = TRUE)
files_remove <- all_files[-pmatch(files_keep,all_files)]
for (i in files_remove){
  if (file.exists(i)) {
    file.remove(i)
  }
}

# reading all pdf files afresh
pdf_files <- list.files(path = pdf_path, pattern = ".pdf$",  full.names = FALSE)

# splitting the file names to seperate ids and file names
file_split <- stri_split_fixed(pdf_files, "#$")
ids <- vector(mode="character")
files <- vector(mode="character")
for (i in 1:length(file_split)){
  id_l <- file_split[[i]][1]
  file_l <- file_split[[i]][2]
  # appending both things to the initialized vectors
  ids <- append(ids, id_l)
  files <- append(files, file_l)
}

# for every query we assign associated files
unique_ids <- (unique(ids))
unique_files <- unique(files)

# attaching queries to ids
unique_queries <- vector(mode="character")
for (i in unique_ids){
  num_id <- as.integer(str_split(i, "_")[[1]][2])
  curr_ele <- as.character(url_file$urls[num_id])
  unique_queries <- append(unique_queries, curr_ele)
}

queries <- vector(mode="character")
for (i in ids){
  num_id <- as.integer(str_split(i, "_")[[1]][2])
  curr_ele <- as.character(url_file$urls[num_id])
  queries <- append(queries, curr_ele)
}

# detecting duplicate downloaded files (if any)
for (i in 1:length(unique_queries)){
  assign(paste0('query',i), unique_queries[i])
  match_indexes <- which(queries %in% get(paste0('query',i)))
  assign(paste0('file',i), files[min(match_indexes):max(match_indexes)])
  assign(paste0('vec_',i), vector())
}

# for every unique file, does it appear for the query? 
for (i in 1:length(unique_files)){
  curr_file <- unique_files[i]
  # going through all files
  for (j in 1:length(unique_queries))
  {
    assign(paste0('present',j), (curr_file %in% get(paste0('file',j))))
    temp_flag <- append(get(paste0('vec_',j)), get(paste0('present',j)))
    assign(paste0('vec_',j), temp_flag*1)
  }
} 

# creating a matrix to indicate if a file is attached to a query
# creating a data frame with the requisite information
# initializing the data frame with the first query results
df <- as.data.frame(cbind(unique_files, vec_1))
# renaming the column for the added query result
names(df)[2] <- query1
for (i in 2:length(unique_queries)){
  # adding the subsequent columns
  df <- cbind(df, get(paste0('vec_',i)))
  # renaming the columns
  names(df)[i+1] <- get(paste0('query',i))
}

# cleaning up the downloaded files
# create a new folder (unique_files)
unlink("unique_files", recursive = TRUE)
dir.create("unique_files")
# copying files to the new location
file.copy(file.path(pdf_path, pdf_files), paste0(getwd(),"/unique_files"))

# keeping only the unique files
old_names <- list.files(paste0(getwd(),"/unique_files"), full.names = FALSE)
# splitting the file names to seperate file name and file names
file_split <- stri_split_fixed(old_names, "#$")
new_names <- vector(mode="character")
unq_file_names <- vector(mode="character")
for (i in 1:length(file_split)){
  file_l <- file_split[[i]][2]
  # appending both things to the initialized vectors
  new_names <- append(new_names, file_l)
}

# "uniqueify" the files in the directory
file.rename(from = file.path(paste0(getwd(),"/unique_files"), old_names), to = file.path(paste0(getwd(),"/unique_files"), new_names))

# remove the web results folder
unlink("web_results", recursive = TRUE)

# prioritize the resultant dataframe
temp_df <- df
temp_df$unique_files <- NULL
# converting all columns into numeric
num_col <- dim(temp_df)[2]
for (i in 1:num_col){
  temp_df[,i] <- as.numeric(as.character(temp_df[,i]))
}

# sorting documents (appear most queries)
sum_rows <- rowSums(temp_df)
df$commonality <- sum_rows
df <- df[order(-df$commonality),] 
df$commonality <- NULL
