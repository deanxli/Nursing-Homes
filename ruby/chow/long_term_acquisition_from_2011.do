* Goal: See what acquisitions are like from 2011, and how many are sole proprietor to large chains.

* ==============================================================================
* Globals
* ==============================================================================

global file_path_pos "${dropbox}/Nursing Homes/Data/Staffing Data/POS Yearly/"
global file_path_pbj "${dropbox}/Nursing Homes/Data/Staffing Data/PBJ Nurse Staffing Quarterly/"
global dean_file "${dropbox}/Nursing Homes/Data/Dean GitHub Output/Extension Back To 2011/"
global crosswalk "${dropbox}/Nursing Homes/Data/Crosswalks"

global map "${dropbox}/Nursing Homes/Data/GIS"
global figures "${dropbox}/Nursing Homes/Derived/CHOW Maps"

* ==============================================================================
* See CHOWs in PBJ data 2017-2021: Each provnum only goes through one CHOW
* ==============================================================================
use "${file_path_pbj}/master_quarterly_agg.dta", clear 

* Time variables
gen year = ceil(date / 4) + 2016
gen quarter = mod(date, 4)
replace quarter = 4 if quarter == 0

* Look at CHOW events (see if large group ID changes compared to the previous date)
sort provnum date
by provnum: gen large_group_prev = large_group_id[_n-1]

gen chow = (large_group_prev != large_group_id) ///
		& !mi(large_group_prev) & !mi(large_group_id)

* CHOWs of sole proprietorship to chain vs. chain to chain 
gen chow_sole = (chow == 1) & (large_group_prev < 0) & (large_group_id > 0)

* How many CHOWs? 
tab chow chow_sole 

* For a given provider, would more than one CHOW happen in a year? 
preserve 

collapse (sum) chow chow_sole, by(provnum year)
tab chow chow_sole

* For a given provider, would more than one CHOW happen? 
collapse (sum) chow chow_sole, by(provnum) 
tab chow chow_sole

restore

* NOTE: There's NO sole proprietorship! Might be how I cleaned the data...(ie tried to infer acquisitions from CHOW file)

* How many SNFs do large groups own? 
keep if large_group_id > 0 
gen snf = 1 

collapse (count) snf, by(provnum year large_group_id) 
collapse (count) snf, by(year large_group_id) 

bys year: sum snf, d

* ==============================================================================
* Test out the large group acquisition starting 2011 
* ==============================================================================
use "$dean_file/full_2011_2016.dta", clear

ren prvdr_num provnum 
ren affiliationentityid large_group_id 
ren affiliationentityname large_group_name 
ren year date

* If group ID is -1, assume that it's a sole proprietorship
replace large_group_id = -1 if mi(large_group_id)

* Look at CHOW events (see if large group ID changes compared to the previous date)
sort provnum date
by provnum: gen large_group_prev = large_group_id[_n-1]
by provnum: gen large_group_prev2 = large_group_id[_n-2]

gen chow = (large_group_prev != large_group_id) ///
		& !mi(large_group_prev) & !mi(large_group_id) 

gen chow_sus = (chow == 1) & (large_group_prev2 == large_group_id)

* CHOWs of sole proprietorship to chain vs. chain to chain 
gen chow_sole = (chow == 1) & (large_group_prev == -1) & (large_group_id > 0)

* How many CHOWs? 
tab chow chow_sole 
tab chow chow_sus // 187 CHOWs are a bit sus, which is not a lot. Keep in mind though.

* For a given provider, would more than one CHOW happen? 
preserve 

collapse (sum) chow chow_sole chow_sus, by(provnum) 
tab chow chow_sole
tab chow chow_sus

restore

* NOTE: There's a lot of sole proprietorship! How reliable is this measure though vs. not matching?
* Maybe don't use CHOWs due to empty 

* How many SNFs do large groups own? 
keep if large_group_id > 0 
gen snf = 1 

collapse (count) snf, by(provnum date large_group_id) 
collapse (count) snf, by(date large_group_id) 

bys date: sum snf, d
