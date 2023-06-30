version 15
set more off

global file_path_pos "${dropbox}/Nursing Homes/Data/Staffing Data/POS Yearly/"
global file_path_pbj "${dropbox}/Nursing Homes/Data/Staffing Data/PBJ Nurse Staffing Quarterly/"

******* Load Data 
* We use random sample of daily data since the goal is to get a sense of demand fluctuations
use "${file_path_pbj}/random_sample_daily_agg.dta", clear

* Merge in POS data on number of beds (yearly) 
ren provnum prvdr_num 
ren year fyear	

* Note: this currently only goes up to 2017 
merge m:1 prvdr_num fyear using "${file_path_pos}/pos_database_nh.dta", ///
	keep(master matched) keepusing(*bed) nogen

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
bys fyear: xtsum mdscensus bed frac_occ // mostly between fluctuation

******* How stable is substitution between RNs, LPNs, CNAs? 
* Now we do it for nursing home hours 
xtsum hrs_rn hrs_rn_emp hrs_rn_ctr 
xtsum hrs_lpn hrs_lpn_emp hrs_lpn_ctr 
xtsum hrs_cna hrs_cna_emp hrs_cna_ctr 

* Is fraction out of total hours relatively stable? (ie substitution between types)
foreach var in rn lpn cna {
	gen frac_`var' = hrs_`var' / (hrs_rn + hrs_lpn + hrs_cna)
	gen frac_`var'_emp = hrs_`var'_emp / (hrs_rn_emp + hrs_lpn_emp + hrs_cna_emp)
	gen frac_`var'_ctr = hrs_`var'_ctr / (hrs_rn_ctr + hrs_lpn_ctr + hrs_cna_ctr)
}

* Expected it to be stable but actually large within fluctuations for fraction contracting
xtsum frac_rn frac_rn_emp frac_rn_ctr 
xtsum frac_lpn frac_lpn_emp frac_lpn_ctr 
xtsum frac_cna frac_cna_emp frac_cna_ctr 

******* How do nursing hours track demand fluctuations? 

* Share of contract nurse hours for each type (larger within as opposed to between fluctuations)
xtsum share_*

* Correlate demand and contract hours fraction usage (very small)
pwcorr mdscensus share_rn share_lpn share_cna

* Correlate demand and fulltime hours fraction usage 
pwcorr mdscensus frac_rn frac_lpn frac_cna
pwcorr mdscensus frac_rn_emp frac_lpn_emp frac_cna_emp
pwcorr mdscensus frac_rn_ctr frac_lpn_ctr frac_cna_ctr

** Results: insignificant negative correlations of mdscensus and contract shares 
* However, 0.12 corr of frac_cna and -0.15 corr of frac_rn (ie shift rn to cna)

********************************************
* Provider-level fluctuations
********************************************

* Construct provider x year level s.d. of patients and hours 
collapse (sd) mdscensus hrs_* *bed (sum) total_mds = mdscensus (mean) mean_mds = mdscensus ///
	, by(prvdr_num provname city state county_name county_fips fyear)

* Adjusting for nursing home size 
pwcorr *mds* // mean and sum are corr 0.93
// sd of mdscensus is positively correlated with total/mean! i would've expected the opposite.
sum total_mds mean_mds, d

xtile size_quart = mean_mds, nq(4)

* Correlate demand and contract hours variability
bys size_quart: pwcorr mdscensus hrs_rn_ctr hrs_lpn_ctr hrs_cna_ctr 

* Correlate demand and fulltime hours variability
bys size_quart: pwcorr mdscensus hrs_rn hrs_lpn hrs_cna hrs_rn_emp hrs_lpn_emp hrs_cna_emp

* Correlate fulltime and contract hour fluctuations for same subset of obs 
bys size_quart: corr mdscensus hrs_rn_ctr hrs_lpn_ctr hrs_cna_ctr hrs_rn_emp hrs_lpn_emp hrs_cna_emp

** Results: Large fluctuations in mdscensus correlates strongly to correlations with full time hrs and weakly correlates with contracting hours...this means a fair bit of movement in fulltime hours?
** Seems like fluctuations are really accounted for fluctuations in CNA (not contract workers), esp for smaller nursing homes. This holds if we isolate to SNFs with contract hours (not so much bigger).

//XXX: plot county level maps of fluctuations (which are high counties? does it change over time?)



