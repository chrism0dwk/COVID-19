# LOAD REQUIRED PACKAGES AND FUNCTIONS -----------------------------------------
if (!require("pacman")) install.packages("pacman")
pkgs = c("dplyr") # package names
pacman::p_load(pkgs, character.only = T)

library(tidyverse)

#=======#### DOWNLOAD DATA FROM PHE ####=======#

# Link to historical cumalative daily cases for UTLA
url <- "https://fingertips.phe.org.uk/documents/Historic%20COVID-19%20Dashboard%20Data.xlsx"

# Download file and load it in R
download.file(url, destfile = "data/original/PHE_main_data.xlsx")

# LOAD FROM PHE
UK_total <- readxl::read_xlsx(path = "data/original/PHE_main_data.xlsx", 
                           sheet = 2, 
                           skip = 10)
UK_by_country_deaths <- readxl::read_xlsx(path = "data/original/PHE_main_data.xlsx", 
                                      sheet = 3, 
                                      skip = 7)

UK_by_country_cases <- readxl::read_xlsx(path = "data/original/PHE_main_data.xlsx", 
                                         sheet = 4, 
                                         skip = 9)

england_region <- readxl::read_xlsx(path = "data/original/PHE_main_data.xlsx", 
                                    sheet = 5, 
                                    skip = 7)

england_countyUA <- readxl::read_xlsx(path = "data/original/PHE_main_data.xlsx", 
                                    sheet = 6, 
                                    skip = 7)
UK_total_original <- read_csv("data/original/UK_total.csv")
UK_total_original$date <- as.Date(UK_total_original$date, "%d/%m/%Y")

#=======#### DATA PROCESSING ####=======#

### 1. UK_total ###
UK_total <- UK_total %>%
  rename(date = Date, total_cases = `Cumulative Cases`)
dat <- data.frame(date=UK_total$date[UK_total$date>"2020-03-13"], total_cases = UK_total$total_cases[UK_total$date>"2020-03-13"],
                  total_deaths=UK_by_country_deaths$UK[UK_by_country_deaths$Date>"2020-03-13"])

UK_total <- rbind(UK_total_original,dat)
UK_total$new_cases <- c(0,diff(UK_total$total_cases))
UK_total$new_deaths <- c(0,diff(UK_total$total_deaths))

UK_total <- UK_total %>%
  gather(value="number", key="type", -date)


### 2. UK countries ###
# UK_countries_deaths
UK_by_country_deaths <- UK_by_country_deaths %>%
  select(-Deaths)

# UK_countries_cases
UK_by_country_cases <- UK_by_country_cases %>%
  select(-`Area Code`, country = `Area Name`) %>%
  filter(country!= "UK") %>%
  tidyr::gather(key="date", value="total_cases", -country) %>%
  mutate(date=as.Date(as.numeric(date), origin="1899-12-30"))

UK_by_country_pop <- data.frame(country=c("England","Scotland","Wales","Northern Ireland"), pop=c(55980000,5438000,3139000,1882000))
UK_by_country_cases$pop <- UK_by_country_pop$pop

UK_by_country_deaths <- UK_by_country_deaths[,c(1,3:6)]
UK_by_country_deaths <- UK_by_country_deaths %>%
  rename(date=Date) %>%
  gather(key="country", value="total_deaths", -date) %>%
  mutate(date=as.Date(date, "%Y-%m-%d"))
  
UK_by_country <- left_join(UK_by_country_cases,UK_by_country_deaths,by=c("date","country"))
UK_by_country <- UK_by_country[order(UK_by_country$country),]

out.cases <- c()
out.deaths <- c()
for (i in 1:nrow(UK_by_country_pop)){
  x <- UK_by_country[UK_by_country$country==UK_by_country_pop$country[order(UK_by_country_pop$country)][i],]
  out.cases <- c(out.cases,0,diff(x$total_cases))
  out.deaths <- c(out.deaths,NA,diff(x$total_deaths))
}
UK_by_country$new_cases <- out.cases
UK_by_country$new_deaths <- out.deaths

UK_by_country <- UK_by_country %>%
  gather(key="type", value="number", -date, -pop, -country)

UK_by_country$date <- as.Date(UK_by_country$date, "%Y-%m-%d")

### 3. England NHS Regions ###
data.region <- england_region %>%
  select(-`Area Code`, region = `Area Name`) %>%
  filter(region!= "England",is.na(region)==FALSE) %>%
  tidyr::gather(key="date", value="total_cases", -region) %>%
  mutate(date=as.Date(as.numeric(date), origin="1899-12-30"))

data.region <- data.region[order(data.region$region),]

# calculate new daily cases
data.region$new_case <- c()
uni.region <- unique(data.region$region)
out <- c()
for (i in 1:length(uni.region)){
  x <- data.region[data.region$region==uni.region[i],]
  out <- c(out,0,diff(x$total_cases))
}
data.region$new_cases <- out

# get per 100,000 population results
region.pop.data <- read_csv("https://raw.githubusercontent.com/maxeyre/COVID-19/master/Data%20visualisation/UK%20data/NHS_england_regions_pop.csv")

data.region.pop <- left_join(data.region,region.pop.data, by="region")
data.region.pop <- data.region.pop %>%
  mutate(total_cases = 100000*total_cases/pop, new_cases=100000*new_cases/pop)

data.region <- data.region %>%
  gather(key="type",value="number",-region, -date)
data.region.pop <- data.region.pop %>%
  gather(key="type",value="number",-region,-date,-pop)


### 2. England Local Authorities ###
england_countyUA <- england_countyUA %>%
  select(-`Area Code`, county_UA = `Area Name`) %>%
  filter(county_UA!= "Unconfirmed",county_UA!= "England") %>%
  tidyr::gather(key="date", value="total_cases", -county_UA) %>%
  mutate(date=as.Date(as.numeric(date), origin="1899-12-30"))

england_countyUA <- england_countyUA [order(england_countyUA$county_UA),]

# calculate new daily cases
england_countyUA$new_case <- c()
uni.county <- unique(england_countyUA$county_UA)
out <- c()
for (i in 1:length(uni.county)){
  x <- england_countyUA[england_countyUA$county_UA==uni.county[i],]
  out <- c(out,0,diff(x$total_cases))
}
england_countyUA$new_cases <- out

england_countyUA <- england_countyUA %>%
  gather(key="type",value="number",-county_UA,-date)

#=======#### DATA OUTPUTTING ####=======#
readr::write_csv(UK_total, "data/processed/UK_total.csv")
readr::write_csv(UK_by_country, "data/processed/UK_by_country.csv")
readr::write_csv(data.region, "data/processed/NHS_england_regions.csv")
readr::write_csv(data.region.pop, "data/processed/NHS_england_regions_pop.csv")
readr::write_csv(england_countyUA, "data/processed/england_UTLA.csv")


# # Convert to long format and 
# cases_long <- cases %>% 
#   filter(area_name != "England") %>% 
#   tidyr::gather(key = "date", value = "cum_cases", -area_code, -area_name)
# 
# # Covert date from excel format to standard format
# cases_long$date <- as.Date(as.numeric(cases_long$date), origin = "1899-12-30")
# 
# # Convert gain to wide format
# cases_wide <- cases_long %>% 
#   tidyr::spread(key = date, value = cum_cases)
# 
# # SAVE OUTPUT ------------------------------------------------------------------
# 
# # last_day <- names(cases_wide)[ncol(cases_wide)]
# 
# readr::write_csv(cases_long, 
#                  paste0("data/processed/cases_long.csv"))
# 
# readr::write_csv(cases_wide, 
#                  paste0("data/processed/cases_wide.csv"))

# DELETE OLD VERSIOSN ----------------------------------------------------------
# case_data_files <- list.files("data/processed/", 
# 															pattern = ".csv",
# 															full.names = T)
# to_delete <- case_data_files[!grepl(last_day, case_data_files)]
# file.remove(to_delete)