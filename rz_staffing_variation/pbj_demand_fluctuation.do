version 15
set more off

global file_path_pos "${dropbox}/Nursing Homes/Data/Staffing Data/POS Yearly/"
global file_path_pbj "${dropbox}/Nursing Homes/Data/Staffing Data/PBJ Nurse Staffing Quarterly/"

******* Load Data
use "${file_path_pbj}/random_sample_daily_agg.dta", clear

* Merge in POS data on number of beds (yearly) 
ren provnum prvdr_num 
ren year fyear	

* Note: this currently only goes up to 2017 
merge m:1 prvdr_num fyear using "${file_path_pos}/pos_database_nh.dta", ///
	keep(master matched) keepusing(*bed) 

******* Fraction of occupancy rate 
pwcorr *bed
gen frac_occ = mdscensus / bed 

sum frac_occ, detail

kdensity frac_occ // greater than 1 for ~1% of the data 

* What kind of beds are doubling? 
sum bed if frac_occ > 1
sum bed if frac_occ > 1.5 // 610 obs
sum bed if frac_occ > 2 // 174 obs 

******* Declare data to be panel and look at within vs. between 
egen prov_id = group(prvdr_num)

xtset prov_id workdate 
xtsum mdscensus bed frac_occ
bys fyear: xtsum mdscensus bed frac_occ

* Now we do it for nursing home hours 
xtsum hrs_rn hrs_rn_emp hrs_rn_ctr 
xtsum hrs_lpn hrs_lpn_emp hrs_lpn_ctr 
xtsum hrs_cna hrs_cna_emp hrs_cna_ctr 
// cehck the shares of each -- should be more stable!

* Share of contract nurse hours 
xtsum share_*

******* How do nursing hours track demand fluctuations? 

* Do counties with higher demand fluctuations also have higher contract nurse fluctuations?
