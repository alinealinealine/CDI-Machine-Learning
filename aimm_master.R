library(tidyverse)
library(readxl)
library(janitor)
library(skimr)
library(lubridate)
library(writexl)
library(readr)
library(countrycode)

#this file is to prepare the master data file for the machine learning project. 

### Project level data ----
#IFC Disclosure (from 2018/1/1 - 2020/10/1. 1555 projects), mostly text data, not included in the master data file
spi_1_ <-read_csv("Raw Data/spi(1).csv")
spi_2_ <-read_csv("Raw Data/spi(2).csv")

ifc_dis <- spi_1_ %>% 
  bind_rows(spi_2_) %>%
  clean_names() %>%
  unique() %>%
  mutate(iso_3 = countrycode(country_description,
                             origin = 'country.name',
                             destination = 'iso3c',
                             custom_match = c('Turkiye' = 'TUR',
                                              'Kosovo' = 'XXK')
                             )
         )

ifc_dis %>% filter(is.na(iso_3))%>%count(country_description) #iso 3c is missing for region project 

##IFC Portfolio data: IFC Portfolio and Disclosure
ifc_port <- read_csv("Raw Data/IFC_Program_and_Pipeline_Extract (11).csv") %>%
  clean_names() 

ifc_port_clear <- ifc_port %>%
  select(-fin_report_month,-commitment_actual_posting_date,-matches("fiscal")) %>% #multiple entry for these variables
  filter(!duplicated(ifc_port$project_id)) 

#AIMM database
aimm <- read_excel("Raw Data/2021-10 aimm database_8.29.2022.xlsx",
                   sheet = "scoring database",
                   skip = 8) %>%
  clean_names() %>%
  mutate(validation_date = as.Date(validation_date))%>%
  mutate(validation_year = year(validation_date)) %>%
  mutate(validation_fy = case_when(
    month(validation_date) >= 7 ~ validation_year +1,
    month(validation_date) < 7 ~ validation_year))%>%
  mutate(iso_3 = countrycode(project_country_name,
                             origin = 'country.name',
                             destination = 'iso3c',
                             custom_match = c('Turkiye' = 'TUR',
                                              'Kosovo' = 'XXK')
                             )) %>%
  filter(!is.na(project_id))
aimm %>% filter(is.na(iso_3))%>%count(project_country_name) #iso 3c is missing for region project (833 is missing country tag)


#claim inventory (not included in this database as it's text data and only available for the 2022 monitored projects)
claim <- read_excel("Raw Data/2021-12-06 claim_inventory_draft.xlsx",
                    sheet = "claim inventory",
                    skip = 1) %>%
  clean_names() %>%
  mutate(project_id = as.numeric(project_id))

#Master IFC data
ifc_master <- ifc_port_clear%>%
  right_join(aimm,by = c("project_id")) %>%
  mutate(validation_year = as.character(validation_year))%>%
  rename( year = validation_year) 

ctr_yr_id <- ifc_master %>%
  distinct(iso_3,year)



#### Gap data ----
#WDI data
wdi <- read_excel("Raw Data/WDIEXCEL.xlsx") %>%
  clean_names() %>%
  select(matches("country|indicator|2018|2019|2020|2021|2022")) %>%
  pivot_longer(matches("2018|2019|2020|2021|2022"),names_to = "year", values_to = "value") %>%
  mutate(year = substr(year,2,5)) %>%
  right_join(ctr_yr_id,by = c("country_code"="iso_3","year")) %>%
  select(-indicator_name) %>%
  pivot_wider(names_from = indicator_code,values_from = value)
  
wdi_ref <- read_excel("Raw Data/WDIEXCEL.xlsx") %>%
    clean_names() %>%
    distinct(indicator_name, indicator_code)
  
#gap data
gap <- read_excel("Raw Data/Gap-data-2022-04-25.xlsx")%>%
  clean_names() %>%
  mutate(year = paste0("20",substr(year,3,4))) %>%
  select(iso_3,year,fcs_dummy,sub_region,indicator_name,value) %>%
  distinct() %>%
  pivot_wider(names_from = indicator_name, values_from = value) %>%
  clean_names()

gap_ref <- read_excel("Raw Data/Gap-data-2022-04-25.xlsx")%>%
  clean_names() %>%
  distinct(indicator_code,indicator_name)

#master WDI and Gap
gap_master <- gap %>%
  right_join(wdi,by = c("iso_3" = "country_code","year"))
  
#### Master data ----
master <- ifc_master %>%
  left_join(gap_master,by = c("iso_3","year")) 

write_csv(master,"Data/master.csv")
write_csv(wdi_ref,"Data/wdi_indicator_reference.csv")
