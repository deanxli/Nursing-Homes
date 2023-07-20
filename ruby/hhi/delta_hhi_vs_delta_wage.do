* Goal: Compare Delta HHI and Delta Wages across CZs 

* First pass at look at changes in HHI vs. wages. 
* But how do we think about the fact that different mix of workers will be used?

* ==============================================================================
* Globals
* ==============================================================================

global file_path_pos "${dropbox}/Nursing Homes/Data/Staffing Data/POS Yearly/"
global file_path_pbj "${dropbox}/Nursing Homes/Data/Staffing Data/PBJ Nurse Staffing Quarterly/"
global crosswalk "${dropbox}/Nursing Homes/Data/Crosswalks"

global wage_data "${github}/Nursing-Homes/connie/clean_hcris/output/"

global map "${dropbox}/Nursing Homes/Data/GIS"
global figures "${dropbox}/Nursing Homes/Derived/Concentration"

set scheme white_tableau  // for bimap 
* ==============================================================================
* Clean HCRIS data 
* ==============================================================================
* Unclear what ID is but we will take the last ID! (defs not unique on CCN and year...maybe multiple entries a year?)
use "${wage_data}/nh_hcris_wages.dta", clear 
ren ccn provnum 
ren yr year 

sort provnum year id

drop c_* 
drop if mi(rn_wage) & mi(lpn_wage) & mi(cna_wage) 

* Collapse and ignore observations with missing values
collapse (mean) *_wage, by(provnum year) cw

keep if year >= 2017 & year <= 2021

tempfile yearly_wage
save `yearly_wage'

* ==============================================================================
* Load PBJ and merge to HCRIS wage data 
* ==============================================================================
use "${file_path_pbj}/master_quarterly_agg.dta", clear 

* Time variables
gen year = ceil(date / 4) + 2016
gen quarter = mod(date, 4)
replace quarter = 4 if quarter == 0

* Keep 2017 to 2021 
keep if year >= 2017 & year <= 2021

* Merge wage data
merge m:1 provnum year using `yearly_wage', nogen keep(master matched)

* Generate FTE counts a la Prager Schmitt (2021) -- assume 40 hour work week (leave out contract)
foreach var in rn lpn cna {
	gen num_`var'_emp = hrs_`var'_emp / (13 * 40) // assume cost report days = 91 days
}

* Use mdscensus (patient days) to generate patient counts
gen num_mds = mdscensus / 91 

* ==============================================================================
* Calculate HHI
* ==============================================================================
preserve 

* Generate HHI for CZ
	
collapse (sum) num_* (mean) cz_pop2000, by(cz date large_group_id)

foreach var in rn_emp lpn_emp cna_emp mds {

	bys date cz: egen tot_`var' = total(num_`var')
	gen share_`var' = (num_`var' / tot_`var') * 100
	gen sharesq_`var' = share_`var'^2 
	
}

collapse (sum) sharesq_* num_* (mean) cz_pop2000 , by(cz date)

ren sharesq_* hhi_*

* How correlated are numbers with population? 
pwcorr *_pop2000 num_* 

* Collapse to first and last HHI to calculate change
foreach var in rn_emp lpn_emp cna_emp mds {
	gen first_hhi_`var' = hhi_`var'
	gen last_hhi_`var' = hhi_`var'
}

collapse (mean) hhi_* cz_pop2000 (firstnm) first_hhi_* (lastnm) last_hhi_*, by(cz)

* Delta HHI for each employer type and MDS
foreach var in rn_emp lpn_emp cna_emp mds {

	gen delta_hhi_`var' = last_hhi_`var' - first_hhi_`var'
	
}

drop if mi(cz)

tempfile delta_hhi 
save `delta_hhi'

restore 

* ==============================================================================
* Calculate Wage change
* ==============================================================================
* Only keep CZ x year 
keep provnum year *_wage cz cz_pop2000
duplicates drop 

* Create standard deviation of wages
foreach var in rn lpn cna {
	gen sd_`var'_wage = `var'_wage 
	ren `var'_wage mean_`var'_wage
}

* Collapse to CZ x year 
collapse (mean) mean*_wage cz_pop2000 (sd) sd_*wage, by(cz year)

* Collapse to first and last HHI to calculate change
foreach var in rn lpn cna {
	gen first_mean_`var' = mean_`var'_wage
	gen last_mean_`var' = mean_`var'_wage 
	
	gen first_sd_`var' = sd_`var'_wage
	gen last_sd_`var' = sd_`var'_wage
}

* Collapse to first and last to calculate change
sort cz year 
collapse (mean) *wage* cz_pop2000 (firstnm) first_* (lastnm) last_*, by(cz)

* Delta mean and sd of wage 
foreach var in rn lpn cna {
	gen delta_mean_`var' = last_mean_`var' - first_mean_`var'
	gen delta_sd_`var' = last_sd_`var' - first_sd_`var'
}

drop if mi(cz)

* ==============================================================================
* Merge delta wage and delta HHI data to plot bivar maps
* ==============================================================================
* Merge to HHI data 
merge 1:1 cz using `delta_hhi', nogen 

* Merge to plot maps
merge 1:m cz using "$map/cz", nogen

cd "$map"

foreach var in rn lpn cna {
	
	* Plot bivar map of delta HHI and delta mean wage 
	bimap delta_hhi_`var' delta_mean_`var' using cz_shp , cut(pctile) palette(pinkgreen) ///
		 texty("Delta HHI") textx("Delta Wage") texts(3.5) textlabs(3) values count ///
		 ocolor(gs7) osize(none) ///
		 ndfcolor(gs4) ndocolor(gs7) ndsize(0.03) ///
		 polygon(data(state_shp) ocolor(gs8) osize(0.15))

	graph export "$figures/bimap_delta_hhi_vs_delta_wage_`var'_cz.pdf",replace 
		
	* Plot bivar map of delta HHI and delta SD wage 
	bimap delta_hhi_`var' delta_sd_`var' using cz_shp , cut(pctile) palette(pinkgreen) ///
		 texty("Delta HHI") textx("Delta SD Wage") texts(3.5) textlabs(3) values count ///
		 ocolor(gs7) osize(none) ///
		 ndfcolor(gs4) ndocolor(gs7) ndsize(0.03) ///
		 polygon(data(state_shp) ocolor(gs8) osize(0.15))

	graph export "$figures/bimap_delta_hhi_vs_delta_sd_wage_`var'_cz.pdf",replace 
		
}

foreach var in rn lpn cna {
	pwcorr delta_hhi_`var' delta_mean_`var' delta_sd_`var'
	pwcorr delta_hhi_`var' delta_mean_`var' delta_sd_`var' [w = cz_pop2000]
}
