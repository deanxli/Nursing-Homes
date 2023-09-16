* Goal: Does number of beds vary within SNF? Does capital or only labor? 

* ==============================================================================
* Globals
* ==============================================================================

global file_path_pos "${dropbox}/Nursing Homes/Nursing Homes Data/Staffing Data/POS Yearly"
global file_path_pbj "${dropbox}/Nursing Homes/Nursing Homes Data/Staffing Data/PBJ Nurse Staffing Quarterly"

global derived "${dropbox}/Nursing Homes/Derived/Production Function"

* ==============================================================================
* Load POS data and look at variation in beds within SNF
* ==============================================================================
use "$file_path_pos/pos_database_nh.dta", clear
ren fyear year 

* Calculate percentage of certified beds from total beds
gen perc_crtfd_bed = 100 * (crtfd_bed  / bed)
assert perc_crtfd_bed <= 100 

******* Declare data to be panel and look at within vs. between variation
egen prov_id = group(prvdr_num)

xtset prov_id year 
xtsum *bed

* Only look at post 2006 which is start of wage data 
keep if year >= 2006

xtsum *bed 

******* NOTE: There is much less variation, in terms of beds, it's mostly between 
******* Furthermore, there is even less within variation for certified beds than total beds. 
******* Of course, there is still some variation across time. 

* Collapse and compare last year and first year of beds 
foreach var in bed crtfd_bed {
	
	* Get first and last to calculate the pure Delta change 
	gen `var'_first = `var'
	gen `var'_last = `var'
	
	* Get the mean and sd 
	gen `var'_sd = `var'
	gen `var'_mean = `var'
	
	* XX CONSTRUCT Z-SCORE
}

sort prvdr_num year 
collapse (mean) *_mean (firstnm) *_first (lastnm) *_last (sd) *_sd (count) num = prov_id, by(prvdr_num)

* What is the distribution of changes on average?
foreach var in bed crtfd_bed { 
	gen `var'_delta = `var'_last - `var'_first
	
	sum `var'_delta, d
	sum `var'_sd, d
}

* Indicator for balanced panel
egen max_num = max(num) 
gen balance_panel = (num == max_num)
tab balance_panel 

* Now we only restrict to balanced panel to avoid selection problems 
foreach var in bed crtfd_bed { 
	sum `var'_delta if balance_panel, d
	sum `var'_sd if balance_panel, d
}

******* Generally not too bad, it seems like we do need to winsorize 1% and 99% in terms of Delta_bed



