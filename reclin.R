setwd("D:/Work/Project/record linkage")

# Exploring data
## Load data
revenue <- read.csv("datasets/revenue.csv")
profile <- read.csv("datasets/profile.csv")

print(revenue)
print(profile)

# Knowing string distance
## Import stringdist library
library(stringdist)

## How string distance work
stringdist('Walmart', 'walmart', method = 'dl') # substitution 'W' with 'w'
stringdist('Walmart', 'wal-mart', method = 'dl') # + addition '-'
stringdist('Walmart', 'wal-mrt', method = 'dl') # + deletion 'a'
stringdist('Walmart', 'wla-mrt', method = 'dl') # + transposition 'l' and 'a' 

## Compare Damerau-Levenshtein with LCS
stringdist('cat', 'hat', method = 'dl') # 1 edit -> substitution 'c' with 'h'
stringdist('cat', 'hat', method = 'lcs') # 2 edit -> deletion 'c', addition 'h'

# Preprocessing
str(revenue)
str(profile)

## Create function convert factor to char
tochar <- function(df){
  for (i in colnames(df)){
    if(class(df[[i]]) == "factor"){
      df[[i]] <- as.character(df[[i]])
    }
  }
  df
}

## Convert dataframe column to the proper type
revenue <- tochar(revenue)
profile <- tochar(profile)

str(revenue)
str(profile)

## Import some libraries for data cleaning
library(dplyr)
library(stringr)

## Preprocessing revenue
revenue1 <- revenue %>%
  # change to lowercase
  mutate(company = tolower(company), hq = tolower(hq)) %>%
  # trim (eliminate extra spaces)
  mutate(company = str_trim(company), hq = str_trim(hq))

## Preprocessing profile
profile1 <- profile %>%
  # change to lowercase
  mutate(company = tolower(company), hq = tolower(hq)) %>%
  # remove 'inc.' word
  mutate(company = str_remove_all(company, 'inc.')) %>%
  # remove ',' (comma)
  mutate(company = str_remove_all(company, ',')) %>%
  # remove 'corporation' word
  mutate(company = str_remove_all(company, 'corporation')) %>%
  # trim (eliminate extra spaces)
  mutate(company = str_trim(company), hq = str_trim(hq)) %>%
  # eliminate city from hq (extract only the state)
  mutate(hq = sapply(str_split(hq, ", "), "[", 2)) 

# Fuzzy Join
## Import fuzzyjoin library
library(fuzzyjoin)

## Apply fuzzy join with company as identifier, and set max dist of 6
fuzjoin1 <- revenue1 %>%
  stringdist_left_join(profile1,
                       by=c('company'),
                       method = 'lcs',
                       max_dist = 6,
                       distance_col = 'dist') %>%
  select(company.x, company.y, dist, hq.x, hq.y)
print(fuzjoin1)

## Apply fuzzy join with company & hq as identifier, and set max dist of 8
fuzjoin2 <- revenue1 %>%
  stringdist_left_join(profile1,
                       by=c('company','hq'),
                       method = 'lcs',
                       max_dist = 8,
                       distance_col = 'dist') %>%
  select(company.x, company.y, company.dist, hq.x, hq.y, hq.dist)
print(fuzjoin2)

# Record Linkage
library(reclin)
## Generate pairs
pair <- pair_blocking(revenue1, profile1, blocking_var = 'sector')
print(pair)

## Compare pairs
pair <- compare_pairs(pair, by = c('company', 'hq'),
                           default_comparator = lcs())
print(pair)

## Score pairs
### Score pairs, with sum all of similarity score
pair_simsum <- score_simsum(pair)

print(pair_simsum)

### Score pairs, with linkage probability
pair_problink <- score_problink(pair, var="problink")

print(pair_problink)

### Score pairs with simple weighting
pair$score <- (pair$company*0.7)+(pair$hq*0.3)

print(pair)

## Select pairs
pair_final <- select_threshold(pair, 'score', threshold = 0.5)

## Add some column
pair_final <- add_from_x(pair_final, company_revn = 'company')
pair_final <- add_from_y(pair_final, company_prfl = 'company')

## Link data 
revenue_profile <- link(pair_final)

print(select(revenue_profile, company.x, company.y))

## Putting it together
reclin <- function(w1, w2, th){
  pair <- pair_blocking(revenue1, profile1, blocking_var = 'sector') %>%
    compare_pairs(by = c('company', 'hq'), default_comparator = lcs())
  
  pair$score <- (pair$company*w1)+(pair$hq*w2)
  
  pair_final <- select_threshold(pair, 'score', threshold = th) %>%
    link()
  
  pair_final
}

reclin(0.7, 0.3, 0.5)
