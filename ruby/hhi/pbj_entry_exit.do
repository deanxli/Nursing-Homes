* Goal: Examine SNF exit and entry by year from PBJ data

* ==============================================================================
* Globals
* ==============================================================================

global file_path_pos "${dropbox}/Nursing Homes/Data/Staffing Data/POS Yearly"
global file_path_pbj "${dropbox}/Nursing Homes/Data/Staffing Data/PBJ Nurse Staffing Quarterly"

* ==============================================================================
* Entry and Exit in PBJ
* ==============================================================================
* Load PBJ data over time and keep provnum and and month 
use "${file_path_pbj}/monthly_agg.dta", clear 

keep provnum year 
duplicates drop 

bys provnum: egen first_yr = min(year) 
bys provnum: egen last_yr = max(year) 

* num SNFs 
distinct provnum 

* first year 
tab year if year == first_yr 

* last year 
tab year if year == last_yr

* SNFs in the whole data period 
distinct provnum if first_yr == 2017 & last_yr == 2022
