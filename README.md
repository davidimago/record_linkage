Record Linkage
================

## Introduction

One of the most challenging obstacle in data analysis is to ensure the data quality. However in the real cases, there is a high probability that the data is untidy, unstandardized, and unidentified.

This time, I would like to show some ways to handle unstandardized data.

Let's take a look at the dataset we want to use. This is not real data, but slightly modified from the real data. There are 2 data,

1.  **revenue**, representing the revenue of every company in some region in US.

2.  **profile**, representing the profile data of every company.

``` r
revenue <- read.csv("datasets/revenue.csv")
profile <- read.csv("datasets/profile.csv")

print(revenue)
```

    ##             company    region revenue         hq                        sector
    ## 1           Walmart     South  288838  Arkansass                     Retailing
    ## 2            Walmrt   Midwest  197035    Arkansa                     Retailing
    ## 3             Apple      West  143810  Californa                    Technology
    ## 4              Aple Northeast   71829 California                    Technology
    ## 5  21st Century Fox Northeast   17022    New Yor                         Media
    ## 6               Fox   Midwest   10304    Nw York                         Media
    ## 7               IBM Northeast   79919   New York                    Technology
    ## 8               MCD   Midwest   12505  Illinouis Hotels, Restaurants & Leisure
    ## 9               MCD      West   12117   Illinois Hotels, Restaurants & Leisure
    ## 10           Disney      West   37519  Califrnia                         Media
    ## 11           Disniy     South   18113 California                         Media
    ## 12         Starbuck      West   21316  Wasington Hotels, Restaurants & Leisure
    ## 13           Warner Northeast   29318   New York                         Media
    ## 14               HP      West   50123 California                    Technology
    ## 15          Bestbuy   Midwest   39403   Minesota                     Retailing

``` r
print(profile)
```

    ##                                        company                      hq
    ## 1                        Wal-Mart Stores, Inc.   Bentonville, Arkansas
    ## 2                                  Apple, Inc.   Cupertino, California
    ## 3               Twenty-First Century Fox, Inc. New York City, New York
    ## 4  International Business Machines Corporation        Armonk, New York
    ## 5                       McDonald's Corporation     Oak Brook, Illinois
    ## 6                      The Walt Disney Company     Burbank, California
    ## 7                        Starbucks Corporation     Seattle, Washington
    ## 8                             Time Warner Inc. New York City, New York
    ## 9           Hewlett Packard Enterprise Company   Palo Alto, California
    ## 10                          Best Buy Co., Inc.    Richfield, Minnesota
    ##                           sector employee
    ## 1                      Retailing  2300000
    ## 2                     Technology   116000
    ## 3                          Media    21500
    ## 4                     Technology   414400
    ## 5  Hotels, Restaurants & Leisure   375000
    ## 6                          Media   195000
    ## 7  Hotels, Restaurants & Leisure   254000
    ## 8                          Media    25000
    ## 9                     Technology   195000
    ## 10                     Retailing   125000

Notice that there is no identifier (id) between those data. The potential identifier that we can use is company name. But the company name between those data has different format, the revenue data has short name and the other has long name. Also, there is some typos in revenue data.

So, there are some issues we have to tackle if we want to join those data.

There are 2 ways that we are gonna use to solve this problem,

1.  **Fuzzy Join**

2.  **Record Linkage** (we're gonna dive deep in this method)

## String Distance

Before starting to implement those methods, there is a fundamental thoery we have to know. When we face data that the identifier has some typos, we can implement string distance.

**String distance** is method that measure how similar or different (edit distance) one string to another. There are 4 component to measure edit distance. There are *insertion*, *deletion*, *substitution*, and *transposition*.

Types of algorithm of edit distance :

-   **Damerau-Levenshtein** : insertion, deletion, substitution, and transposition.
-   **Levenshtein** : insertion, deletion, and substitution.
-   **LCS (Longest Common Subsequence)** : insertion and deletion.
-   **Jaro-Winkler** : specific formula
-   and any others...

``` r
# Import stringdist library
library(stringdist)

# How string distance work, with Damerau-Levenshtein

# substitution 'W' with 'w'
stringdist('Walmart', 'walmart', method = 'dl')
```

    ## [1] 1

``` r
# + addition '-'
stringdist('Walmart', 'wal-mart', method = 'dl')
```

    ## [1] 2

``` r
# + deletion 'a'
stringdist('Walmart', 'wal-mrt', method = 'dl')
```

    ## [1] 3

``` r
# + transposition 'l' and 'a'
stringdist('Walmart', 'wla-mrt', method = 'dl')
```

    ## [1] 4

Let's try to compare any methods, and see how they work.

``` r
# Compare Damerau-Levenshtein with LCS

# Damerau-Levenshtein has 4 component
# 1 edit -> substitution 'c' with 'h'
stringdist('cat', 'hat', method = 'dl')
```

    ## [1] 1

``` r
# LCS only has 2 component, insertion and deletion
# 2 edit -> deletion 'c', addition 'h'
stringdist('cat', 'hat', method = 'lcs')
```

    ## [1] 2

## Preprocessing

Now, let's preprocess the data so that it can be processed in the next step. First, we need to look the structure of the data.

``` r
str(revenue)
```

    ## 'data.frame':    15 obs. of  5 variables:
    ##  $ company: Factor w/ 14 levels "21st Century Fox",..: 12 13 3 2 1 7 9 10 10 5 ...
    ##  $ region : Factor w/ 4 levels "Midwest","Northeast",..: 3 1 4 2 2 1 2 1 4 4 ...
    ##  $ revenue: int  288838 197035 143810 71829 17022 10304 79919 12505 12117 37519 ...
    ##  $ hq     : Factor w/ 12 levels "Arkansa","Arkansass",..: 2 1 3 4 9 11 10 7 6 5 ...
    ##  $ sector : Factor w/ 4 levels "Hotels, Restaurants & Leisure",..: 3 3 4 4 2 2 4 1 1 2 ...

``` r
str(profile)
```

    ## 'data.frame':    10 obs. of  4 variables:
    ##  $ company : Factor w/ 10 levels "Apple, Inc.",..: 10 1 9 4 5 7 6 8 3 2
    ##  $ hq      : Factor w/ 9 levels "Armonk, New York",..: 2 4 5 1 6 3 9 5 7 8
    ##  $ sector  : Factor w/ 4 levels "Hotels, Restaurants & Leisure",..: 3 4 2 4 1 2 1 2 4 3
    ##  $ employee: int  2300000 116000 21500 414400 375000 195000 254000 25000 195000 125000

As we can see, that any columns is typed as factor, where it should be typed as char or string. So we have to cast the data type/class to the correct type/class.

``` r
# Create function that convert factor to char
tochar <- function(df){
  for (i in colnames(df)){
    if(class(df[[i]]) == "factor"){
      df[[i]] <- as.character(df[[i]])
    }
  }
  df
}

# Convert dataframe column to the proper type
revenue <- tochar(revenue)
profile <- tochar(profile)
```

``` r
str(revenue)
```

    ## 'data.frame':    15 obs. of  5 variables:
    ##  $ company: chr  "Walmart" "Walmrt" "Apple" "Aple" ...
    ##  $ region : chr  "South" "Midwest" "West" "Northeast" ...
    ##  $ revenue: int  288838 197035 143810 71829 17022 10304 79919 12505 12117 37519 ...
    ##  $ hq     : chr  "Arkansass" "Arkansa" "Californa" "California" ...
    ##  $ sector : chr  "Retailing" "Retailing" "Technology" "Technology" ...

``` r
str(profile)
```

    ## 'data.frame':    10 obs. of  4 variables:
    ##  $ company : chr  "Wal-Mart Stores, Inc." "Apple, Inc." "Twenty-First Century Fox, Inc." "International Business Machines Corporation" ...
    ##  $ hq      : chr  "Bentonville, Arkansas" "Cupertino, California" "New York City, New York" "Armonk, New York" ...
    ##  $ sector  : chr  "Retailing" "Technology" "Media" "Technology" ...
    ##  $ employee: int  2300000 116000 21500 414400 375000 195000 254000 25000 195000 125000

Next, we have to clean the data as much as we can, so it can be affected to the better accuracy of the model we're going to build. In this case, we want to clean the company and hq (head quarter) column as they have some typos and we want to use them as identifier.

We can lowercase the columns, also eliminate common words and unnecessary words.

``` r
# Import some libraries for data cleaning
library(dplyr)
library(stringr)

# Preprocessing revenue
revenue1 <- revenue %>%
  # change to lowercase
  mutate(company = tolower(company), hq = tolower(hq)) %>%
  # trim (eliminate extra spaces)
  mutate(company = str_trim(company), hq = str_trim(hq))

# Preprocessing profile
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
```

## Fuzzy Join

Fuzzy join is similar with the normal join. The difference between them is that fuzzy join can apply join operation with non-exact identifier. So, this is the shortest way to solve our problem.

As we learn before, in fuzzy join we can apply several string distance method and set the threshold by defining the maximum distance.

In this case, we want **only use the LCS method** and then compare the model from fuzzy join with model from record linkage.

### Model 1

In the first model we apply,

-   **identifer** = *company*
-   **max\_dist** = 6

``` r
# Import fuzzyjoin library
library(fuzzyjoin)

# Apply fuzzy join with company as identifier, and set max dist of 6
fuzjoin1 <- revenue1 %>%
  stringdist_left_join(profile1,
                       by=c('company'),
                       method = 'lcs',
                       max_dist = 6,
                       distance_col = 'dist') %>%
  select(company.x, company.y, dist, hq.x, hq.y)
```

The reason why maximun distance is set with 6, is because 6 is the optimal distance that can match the most correct rows. If we apply max dist of 7, there has already duplicated rows so it's not the best solution yet.

``` r
print(fuzjoin1)
```

    ##           company.x    company.y dist       hq.x       hq.y
    ## 1           walmart         <NA>   NA  arkansass       <NA>
    ## 2            walmrt         <NA>   NA    arkansa       <NA>
    ## 3             apple        apple    0  californa california
    ## 4              aple        apple    1 california california
    ## 5  21st century fox         <NA>   NA    new yor       <NA>
    ## 6               fox         <NA>   NA    nw york       <NA>
    ## 7               ibm         <NA>   NA   new york       <NA>
    ## 8               mcd         <NA>   NA  illinouis       <NA>
    ## 9               mcd         <NA>   NA   illinois       <NA>
    ## 10           disney         <NA>   NA  califrnia       <NA>
    ## 11           disniy         <NA>   NA california       <NA>
    ## 12         starbuck    starbucks    1  wasington washington
    ## 13           warner  time warner    5   new york   new york
    ## 14               hp        apple    5 california california
    ## 15          bestbuy best buy co.    5   minesota  minnesota

The result is :

| predicted true      | 5   |
|---------------------|-----|
| **predicted false** | 1   |
| **unpredicted**     | 9   |

-   **Acuraccy** = 5/15 = **33%**
-   **Precision** = 5/6 = **83%**

### Model 2

In the second model we apply,

-   **identifer** = *company*, *hq*
-   **max\_dist** = 8

``` r
# Apply fuzzy join with company & hq as identifier, and set max dist of 8
fuzjoin2 <- revenue1 %>%
  stringdist_left_join(profile1,
                       by=c('company','hq'),
                       method = 'lcs',
                       max_dist = 8,
                       distance_col = 'dist') %>%
  select(company.x, company.y, company.dist, hq.x, hq.y, hq.dist)
```

The reason why maximum distance is set with 8, is similiar with the previous model. Max dist of 8 is the optimal distance that can match the most correct rows. If we apply more of it, there has already duplicated rows so it's not the best solution yet.

``` r
print(fuzjoin2)
```

    ##           company.x       company.y company.dist       hq.x       hq.y hq.dist
    ## 1           walmart wal-mart stores            8  arkansass   arkansas       1
    ## 2            walmrt            <NA>           NA    arkansa       <NA>      NA
    ## 3             apple           apple            0  californa california       1
    ## 4              aple           apple            1 california california       0
    ## 5  21st century fox            <NA>           NA    new yor       <NA>      NA
    ## 6               fox            <NA>           NA    nw york       <NA>      NA
    ## 7               ibm            <NA>           NA   new york       <NA>      NA
    ## 8               mcd      mcdonald's            7  illinouis   illinois       1
    ## 9               mcd      mcdonald's            7   illinois   illinois       0
    ## 10           disney            <NA>           NA  califrnia       <NA>      NA
    ## 11           disniy            <NA>           NA california       <NA>      NA
    ## 12         starbuck       starbucks            1  wasington washington       1
    ## 13           warner     time warner            5   new york   new york       0
    ## 14               hp           apple            5 california california       0
    ## 15          bestbuy    best buy co.            5   minesota  minnesota       1

The result is :

| predicted true      | 8   |
|---------------------|-----|
| **predicted false** | 1   |
| **unpredicted**     | 6   |

-   **Acuraccy** = 8/15 = **53%**
-   **Precision** = 8/9 = **88%**

### Conclusion

The best model with fuzzy join method is **the model 2**. Model 2 has higher both acuraccy and precision than the model 1.

But notice that, *max\_dist* applied both in comparing *company* and comparing *hq*. We can't specify different *max\_dist* for every compared pairs.

Therefore, this model (model 2) is still not the best model. Not only because the acuraccy is still low, but also the model is not flexible spesifically for applying multiple threshold (*max\_dist*).

## Record Linkage

Record linkage is pretty similar with fuzzy join. But in record linkage, we can set any configuration to be more detail than fuzzy join.

### Step 1. Generate Pairs

First step, let's generate pairs. Pairs is resulted from all combination rows of each data (same as *cross join*). So, we can imagine if *revenue* data has 15 rows and *profile* data has 10 rows, it will result 150 pairs.

In order to reduce the number of pairs, we have to specify the *blocking variable*. With *blocking variable*, the number of pairs will reduce because algorithm will only compare rows with the same *blocking variable*.

*Blocking variable* must be exactly the same between 2 data. In this case, we specify **sector** as *blocking variable*.


``` r
# Import reclin library
library(reclin)

# Generate pairs
pair <- pair_blocking(revenue1, profile1, blocking_var = 'sector')

print(pair)
```

    ## Simple blocking
    ##   Blocking variable(s): sector
    ##   First data set:  15 records
    ##   Second data set: 10 records
    ##   Total number of pairs: 39 pairs
    ## 
    ## ldat with 39 rows and 2 columns
    ##     x  y
    ## 1   1  1
    ## 2   1 10
    ## 3   2  1
    ## 4   2 10
    ## 5   3  2
    ## 6   3  4
    ## 7   3  9
    ## 8   4  2
    ## 9   4  4
    ## 10  4  9
    ## :   :  :
    ## 30 12  5
    ## 31 12  7
    ## 32 13  3
    ## 33 13  6
    ## 34 13  8
    ## 35 14  2
    ## 36 14  4
    ## 37 14  9
    ## 38 15  1
    ## 39 15 10

As we can see here, that total number of pairs is only 39 pairs. We still can run the algorithm if we won't to set the *blocking variable*. But of course, it will make the model less reliable.

-   *x*, representing the row index of *revenue* data
-   *y*, representing the row index of *profile* data

### Step 2. Compare Pairs

In the second step, we want to compare pairs. We need to specify the columns that we want to compare, of course the columns is the identifier we want to use. So, we set *company* and *hq* as compared columns.

As we state before, we want **only use the LCS method** and then compare the model from fuzzy join with model from record linkage.

``` r
# Compare pairs
pair <- compare_pairs(pair, by = c('company', 'hq'),
                           default_comparator = lcs())

print(pair)
```

    ## Compare
    ##   By: company, hq
    ## 
    ## Simple blocking
    ##   Blocking variable(s): sector
    ##   First data set:  15 records
    ##   Second data set: 10 records
    ##   Total number of pairs: 39 pairs
    ## 
    ## ldat with 39 rows and 4 columns
    ##     x  y    company        hq
    ## 1   1  1 0.63636364 0.9411765
    ## 2   1 10 0.10526316 0.3333333
    ## 3   2  1 0.57142857 0.9333333
    ## 4   2 10 0.11111111 0.3750000
    ## 5   3  2 1.00000000 0.9473684
    ## 6   3  4 0.16666667 0.2352941
    ## 7   3  9 0.15384615 0.9473684
    ## 8   4  2 0.88888889 1.0000000
    ## 9   4  4 0.17142857 0.2222222
    ## 10  4  9 0.15789474 1.0000000
    ## :   :  :          :         :
    ## 30 12  5 0.11111111 0.3529412
    ## 31 12  7 0.94117647 0.9473684
    ## 32 13  3 0.26666667 1.0000000
    ## 33 13  6 0.27586207 0.2222222
    ## 34 13  8 0.70588235 1.0000000
    ## 35 14  2 0.28571429 1.0000000
    ## 36 14  4 0.06060606 0.2222222
    ## 37 14  9 0.11111111 1.0000000
    ## 38 15  1 0.18181818 0.3750000
    ## 39 15 10 0.73684211 0.9411765

The number representing the similarity between the compared columns. **Zero** (0) representing that the compared columns is absolutely different, **one** (1) representing the compared columns is exactly similar.

### Step 3. Score Pairs

Now, let's score the overall similarity of the compared rows (pairs). Record linkage has several method to do this.

The first method is called `score_simsum()`. This method is simply summing all the score of compared columns.

``` r
# Score pairs, with sum all of similarity score
pair_simsum <- score_simsum(pair)

print(pair_simsum)
```

    ## Compare
    ##   By: company, hq
    ## 
    ## Simple blocking
    ##   Blocking variable(s): sector
    ##   First data set:  15 records
    ##   Second data set: 10 records
    ##   Total number of pairs: 39 pairs
    ## 
    ## ldat with 39 rows and 5 columns
    ##     x  y    company        hq    simsum
    ## 1   1  1 0.63636364 0.9411765 1.5775401
    ## 2   1 10 0.10526316 0.3333333 0.4385965
    ## 3   2  1 0.57142857 0.9333333 1.5047619
    ## 4   2 10 0.11111111 0.3750000 0.4861111
    ## 5   3  2 1.00000000 0.9473684 1.9473684
    ## 6   3  4 0.16666667 0.2352941 0.4019608
    ## 7   3  9 0.15384615 0.9473684 1.1012146
    ## 8   4  2 0.88888889 1.0000000 1.8888889
    ## 9   4  4 0.17142857 0.2222222 0.3936508
    ## 10  4  9 0.15789474 1.0000000 1.1578947
    ## :   :  :          :         :         :
    ## 30 12  5 0.11111111 0.3529412 0.4640523
    ## 31 12  7 0.94117647 0.9473684 1.8885449
    ## 32 13  3 0.26666667 1.0000000 1.2666667
    ## 33 13  6 0.27586207 0.2222222 0.4980843
    ## 34 13  8 0.70588235 1.0000000 1.7058824
    ## 35 14  2 0.28571429 1.0000000 1.2857143
    ## 36 14  4 0.06060606 0.2222222 0.2828283
    ## 37 14  9 0.11111111 1.0000000 1.1111111
    ## 38 15  1 0.18181818 0.3750000 0.5568182
    ## 39 15 10 0.73684211 0.9411765 1.6780186

In many cases, `score_simsum()` is not recommended because this method treat all the compared column similarly.

In this case, *company* should be treated more 'special' than *hq*. So, we use the other method. The other method is `score_problink()`. This method use probabilistic scoring with EM-algorithm.

``` r
problink_em(pair)
```

    ## M- and u-probabilities estimated by the EM-algorithm:
    ##  Variable M-probability U-probability
    ##   company     0.5946395  0.0003486086
    ##        hq     0.9998003  0.4702257833
    ## 
    ## Matching probability: 0.1289908.

We can see that the method treat the compared column differently.

``` r
# Score pairs, with linkage probability
pair_problink <- score_problink(pair, var="problink")

print(pair_problink)
```

    ## Compare
    ##   By: company, hq
    ## 
    ## Simple blocking
    ##   Blocking variable(s): sector
    ##   First data set:  15 records
    ##   Second data set: 10 records
    ##   Total number of pairs: 39 pairs
    ## 
    ## ldat with 39 rows and 5 columns
    ##     x  y    company        hq    problink
    ## 1   1  1 0.63636364 0.9411765  1.05483439
    ## 2   1 10 0.10526316 0.3333333 -1.16838389
    ## 3   2  1 0.57142857 0.9333333  0.85767213
    ## 4   2 10 0.11111111 0.3750000 -1.03663558
    ## 5   3  2 1.00000000 0.9473684  8.13540417
    ## 6   3  4 0.16666667 0.2352941 -1.42979597
    ## 7   3  9 0.15384615 0.9473684  0.02737821
    ## 8   4  2 0.88888889 1.0000000  2.39332173
    ## 9   4  4 0.17142857 0.2222222 -1.48062347
    ## 10  4  9 0.15789474 1.0000000  0.09463376
    ## :   :  :          :         :           :
    ## 30 12  5 0.11111111 0.3529412 -1.09981218
    ## 31 12  7 0.94117647 0.9473684  2.98293978
    ## 32 13  3 0.26666667 1.0000000  0.27909480
    ## 33 13  6 0.27586207 0.2222222 -1.30180253
    ## 34 13  8 0.70588235 1.0000000  1.35953326
    ## 35 14  2 0.28571429 1.0000000  0.31327757
    ## 36 14  4 0.06060606 0.2222222 -1.65520375
    ## 37 14  9 0.11111111 1.0000000  0.02003337
    ## 38 15  1 0.18181818 0.3750000 -0.92287683
    ## 39 15 10 0.73684211 0.9411765  1.41339969

If you don't really understand about the algorithm behind it and not really sure about it, then we use the simple weighting. We can specifically specify the weight we want to apply for every compared column.

As we mention before, *company* should be treated more 'special' than *hq*. So, we set **70%** of weight to *company* and **30%** of weight to *hq*.

``` r
# Score pairs with simple weighting
pair$score <- (pair$company*0.7)+(pair$hq*0.3)

print(pair)
```

    ## Compare
    ##   By: company, hq
    ## 
    ## Simple blocking
    ##   Blocking variable(s): sector
    ##   First data set:  15 records
    ##   Second data set: 10 records
    ##   Total number of pairs: 39 pairs
    ## 
    ## ldat with 39 rows and 5 columns
    ##     x  y    company        hq     score
    ## 1   1  1 0.63636364 0.9411765 0.7278075
    ## 2   1 10 0.10526316 0.3333333 0.1736842
    ## 3   2  1 0.57142857 0.9333333 0.6800000
    ## 4   2 10 0.11111111 0.3750000 0.1902778
    ## 5   3  2 1.00000000 0.9473684 0.9842105
    ## 6   3  4 0.16666667 0.2352941 0.1872549
    ## 7   3  9 0.15384615 0.9473684 0.3919028
    ## 8   4  2 0.88888889 1.0000000 0.9222222
    ## 9   4  4 0.17142857 0.2222222 0.1866667
    ## 10  4  9 0.15789474 1.0000000 0.4105263
    ## :   :  :          :         :         :
    ## 30 12  5 0.11111111 0.3529412 0.1836601
    ## 31 12  7 0.94117647 0.9473684 0.9430341
    ## 32 13  3 0.26666667 1.0000000 0.4866667
    ## 33 13  6 0.27586207 0.2222222 0.2597701
    ## 34 13  8 0.70588235 1.0000000 0.7941176
    ## 35 14  2 0.28571429 1.0000000 0.5000000
    ## 36 14  4 0.06060606 0.2222222 0.1090909
    ## 37 14  9 0.11111111 1.0000000 0.3777778
    ## 38 15  1 0.18181818 0.3750000 0.2397727
    ## 39 15 10 0.73684211 0.9411765 0.7981424

### Step 4. Select Pairs

Next step, we specify the threshold we want to apply. We use `select_threshold()` to apply this.

If in other case, we face with one-to-one relation between 2 data, we can apply `select_n_to_m()`. `select_n_to_m()` automatically choose the highest score of every pairs.

``` r
# Select pairs
pair_final <- select_threshold(pair, 'score', threshold = 0.5)

print(pair_final)
```

    ## Compare
    ##   By: company, hq
    ## 
    ## Simple blocking
    ##   Blocking variable(s): sector
    ##   First data set:  15 records
    ##   Second data set: 10 records
    ##   Total number of pairs: 39 pairs
    ## 
    ## ldat with 39 rows and 6 columns
    ##     x  y    company        hq     score select
    ## 1   1  1 0.63636364 0.9411765 0.7278075   TRUE
    ## 2   1 10 0.10526316 0.3333333 0.1736842  FALSE
    ## 3   2  1 0.57142857 0.9333333 0.6800000   TRUE
    ## 4   2 10 0.11111111 0.3750000 0.1902778  FALSE
    ## 5   3  2 1.00000000 0.9473684 0.9842105   TRUE
    ## 6   3  4 0.16666667 0.2352941 0.1872549  FALSE
    ## 7   3  9 0.15384615 0.9473684 0.3919028  FALSE
    ## 8   4  2 0.88888889 1.0000000 0.9222222   TRUE
    ## 9   4  4 0.17142857 0.2222222 0.1866667  FALSE
    ## 10  4  9 0.15789474 1.0000000 0.4105263  FALSE
    ## :   :  :          :         :         :      :
    ## 30 12  5 0.11111111 0.3529412 0.1836601  FALSE
    ## 31 12  7 0.94117647 0.9473684 0.9430341   TRUE
    ## 32 13  3 0.26666667 1.0000000 0.4866667  FALSE
    ## 33 13  6 0.27586207 0.2222222 0.2597701  FALSE
    ## 34 13  8 0.70588235 1.0000000 0.7941176   TRUE
    ## 35 14  2 0.28571429 1.0000000 0.5000000  FALSE
    ## 36 14  4 0.06060606 0.2222222 0.1090909  FALSE
    ## 37 14  9 0.11111111 1.0000000 0.3777778  FALSE
    ## 38 15  1 0.18181818 0.3750000 0.2397727  FALSE
    ## 39 15 10 0.73684211 0.9411765 0.7981424   TRUE

The best threshold is 0.5, because it can generate the maximum matched rows. If lower than that, we will find the duplicated rows so it's not the best solution yet.

In other to check that the index truly belong to the correct rows, we can use `add_from_x()` and `add_from_x()`.

``` r
# Add some columns
pair_final <- add_from_x(pair_final, company_revn = 'company')
pair_final <- add_from_y(pair_final, company_prfl = 'company')

print(pair_final)
```

    ## Compare
    ##   By: company, hq
    ## 
    ## Simple blocking
    ##   Blocking variable(s): sector
    ##   First data set:  15 records
    ##   Second data set: 10 records
    ##   Total number of pairs: 39 pairs
    ## 
    ## ldat with 39 rows and 8 columns
    ##     x  y    company        hq     score select company_revn
    ## 1   1  1 0.63636364 0.9411765 0.7278075   TRUE      walmart
    ## 2   1 10 0.10526316 0.3333333 0.1736842  FALSE      walmart
    ## 3   2  1 0.57142857 0.9333333 0.6800000   TRUE       walmrt
    ## 4   2 10 0.11111111 0.3750000 0.1902778  FALSE       walmrt
    ## 5   3  2 1.00000000 0.9473684 0.9842105   TRUE        apple
    ## 6   3  4 0.16666667 0.2352941 0.1872549  FALSE        apple
    ## 7   3  9 0.15384615 0.9473684 0.3919028  FALSE        apple
    ## 8   4  2 0.88888889 1.0000000 0.9222222   TRUE         aple
    ## 9   4  4 0.17142857 0.2222222 0.1866667  FALSE         aple
    ## 10  4  9 0.15789474 1.0000000 0.4105263  FALSE         aple
    ## :   :  :          :         :         :      :            :
    ## 30 12  5 0.11111111 0.3529412 0.1836601  FALSE     starbuck
    ## 31 12  7 0.94117647 0.9473684 0.9430341   TRUE     starbuck
    ## 32 13  3 0.26666667 1.0000000 0.4866667  FALSE       warner
    ## 33 13  6 0.27586207 0.2222222 0.2597701  FALSE       warner
    ## 34 13  8 0.70588235 1.0000000 0.7941176   TRUE       warner
    ## 35 14  2 0.28571429 1.0000000 0.5000000  FALSE           hp
    ## 36 14  4 0.06060606 0.2222222 0.1090909  FALSE           hp
    ## 37 14  9 0.11111111 1.0000000 0.3777778  FALSE           hp
    ## 38 15  1 0.18181818 0.3750000 0.2397727  FALSE      bestbuy
    ## 39 15 10 0.73684211 0.9411765 0.7981424   TRUE      bestbuy
    ##                          company_prfl
    ## 1                     wal-mart stores
    ## 2                        best buy co.
    ## 3                     wal-mart stores
    ## 4                        best buy co.
    ## 5                               apple
    ## 6     international business machines
    ## 7  hewlett packard enterprise company
    ## 8                               apple
    ## 9     international business machines
    ## 10 hewlett packard enterprise company
    ## :                                   :
    ## 30                         mcdonald's
    ## 31                          starbucks
    ## 32           twenty-first century fox
    ## 33            the walt disney company
    ## 34                        time warner
    ## 35                              apple
    ## 36    international business machines
    ## 37 hewlett packard enterprise company
    ## 38                    wal-mart stores
    ## 39                       best buy co.

### Step 5. Link

The final step is to create the linked data set.

``` r
# Link data 
revenue_profile <- link(pair_final)

print(select(revenue_profile, company.x, company.y))
```

    ##           company.x                          company.y
    ## 1           walmart                    wal-mart stores
    ## 2            walmrt                    wal-mart stores
    ## 3             apple                              apple
    ## 4              aple                              apple
    ## 5  21st century fox           twenty-first century fox
    ## 6               mcd                         mcdonald's
    ## 7               mcd                         mcdonald's
    ## 8            disney            the walt disney company
    ## 9            disniy            the walt disney company
    ## 10         starbuck                          starbucks
    ## 11           warner                        time warner
    ## 12          bestbuy                       best buy co.
    ## 13              fox                               <NA>
    ## 14              ibm                               <NA>
    ## 15               hp                               <NA>
    ## 16             <NA>    international business machines
    ## 17             <NA> hewlett packard enterprise company

The result is :

| predicted true      | 12  |
|---------------------|-----|
| **predicted false** | 0   |
| **unpredicted**     | 3   |

-   **Acuraccy** = 12/15 = **80%**
-   **Precision** = 12/12 = **100%**

### Putting it together

To make the model more compact and readable, we can apply pipe operators from dplyr library.

``` r
# Putting it together
reclin <- function(w1, w2, th){
  pair <-
    pair_blocking(revenue1, profile1, blocking_var = 'sector') %>%
    compare_pairs(by = c('company', 'hq'), default_comparator = lcs())
  
  pair$score <- (pair$company*w1)+(pair$hq*w2)
  
  pair_final <-
    select_threshold(pair, 'score', threshold = th) %>%
    link()
  
  pair_final
}

reclin(0.7, 0.3, 0.5)
```

    ##           company.x    region revenue       hq.x                      sector.x                           company.y       hq.y                      sector.y  employee
    ## 1           walmart     South  288838  arkansass                     Retailing                     wal-mart stores   arkansas                     Retailing   2300000
    ## 2            walmrt   Midwest  197035    arkansa                     Retailing                     wal-mart stores   arkansas                     Retailing   2300000
    ## 3             apple      West  143810  californa                    Technology                               apple california                    Technology    116000
    ## 4              aple Northeast   71829 california                    Technology                               apple california                    Technology    116000
    ## 5  21st century fox Northeast   17022    new yor                         Media            twenty-first century fox   new york                         Media     21500
    ## 6               mcd   Midwest   12505  illinouis Hotels, Restaurants & Leisure                          mcdonald's   illinois Hotels, Restaurants & Leisure    375000
    ## 7               mcd      West   12117   illinois Hotels, Restaurants & Leisure                          mcdonald's   illinois Hotels, Restaurants & Leisure    375000
    ## 8            disney      West   37519  califrnia                         Media             the walt disney company california                         Media    195000
    ## 9            disniy     South   18113 california                         Media             the walt disney company california                         Media    195000
    ## 10         starbuck      West   21316  wasington Hotels, Restaurants & Leisure                           starbucks washington Hotels, Restaurants & Leisure    254000
    ## 11           warner Northeast   29318   new york                         Media                         time warner   new york                         Media     25000
    ## 12          bestbuy   Midwest   39403   minesota                     Retailing                        best buy co.  minnesota                     Retailing    125000
    ## 13              fox   Midwest   10304    nw york                         Media                                <NA>       <NA>                          <NA>        NA
    ## 14              ibm Northeast   79919   new york                    Technology                                <NA>       <NA>                          <NA>        NA
    ## 15               hp      West   50123 california                    Technology                                <NA>       <NA>                          <NA>        NA
    ## 16             <NA>      <NA>      NA       <NA>                          <NA>     international business machines   new york                    Technology    414400
    ## 17             <NA>      <NA>      NA       <NA>                          <NA>  hewlett packard enterprise company california                    Technology    195000


## Conclusion

The best model to solve this problem is record linkage. Record linkage provide more detail and flexible solution than the fuzzy join method. As we can specify weight in any compared column. Also, in other to make model more efficient, we can specify *blocking variable*.

| Model                    | Acuraccy | Precision |
|--------------------------|----------|-----------|
| **Record Linkage**       | 80%      | 100%      |
| **Fuzzy Join - Model 1** | 53%      | 88%       |
| **Fuzzy Join - Model 2** | 33%      | 83%       |
