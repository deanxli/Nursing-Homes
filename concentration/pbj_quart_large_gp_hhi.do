* Goal: Generate levels of HHI over time for 1) patients 2) working hours from PBJ
* We use large group affiliations to provider xwalk for now, 
* and counties/CZ as the relevant market.

* ==============================================================================
* Globals
* ==============================================================================

global file_path_pos "${dropbox}/Nursing Homes/Data/Staffing Data/POS Yearly/"
global file_path_pbj "${dropbox}/Nursing Homes/Data/Staffing Data/PBJ Nurse Staffing Quarterly/"
global crosswalk "${dropbox}/Nursing Homes/Data/Crosswalks"

global figures "${dropbox}/Nursing Homes/Derived/Concentration"

* ==============================================================================
* County to CZ Crosswalk: construct to have county and state like PBJ data
* ==============================================================================
* Save state fips and abbreviations
use "$crosswalk/county_characteristics.dta", clear

drop state 
ren stateabbrv state 
gen state_fips = floor(county / 1000)

gen county_fips = county - (state_fips * 1000)
ren cty_pop2000 county_pop2000

tempfile cty_cz_xwalk
save `cty_cz_xwalk'

* ==============================================================================
* Crosswalk PBJ data to 1) large group affiliation 2) POS data on SNF attributes
* ==============================================================================
use "${file_path_pbj}/quarterly_agg.dta", clear 

* Time variables
gen year = ceil(date / 4) + 2016
gen quarter = mod(date, 4)
replace quarter = 4 if quarter == 0

* Merge provnum to large group affiliations ***** XXX: changed in actual analysis to owner assignment!
merge m:1 provnum using "$crosswalk/temporary_pbj_large_group_xw.dta", nogen keep(master matched)

* Generate negative "large group ids" for SNFs without one
egen smallgpids = group(provnum) if mi(large_group_id)
replace large_group_id = -smallgpids if mi(large_group_id)

* Merge in CZs to county_fips data with county population
merge m:1 state county_fips using `cty_cz_xwalk', nogen keep(master matched) ///
	keepusing(cz county county_pop2000)
	
* Merge in CZ population data 
merge m:1 cz using "$crosswalk/cz_characteristics_withnames.dta", nogen keep(master matched) ///
	keepusing(czname pop2000) 
ren pop2000 cz_pop2000

* Merge in POS data (SNF x 2017) -- missing for 2.7% of providers for zip and HSA
ren provnum prvdr_num
gen fyear = 2017 // POS has max 2017 data 
merge m:1 prvdr_num fyear using "$file_path_pos/pos_database_nh.dta", nogen keep(master matched) ///
	keepusing(zip_cd hsanum) update
	
ren hsanum hsa 

* ==============================================================================
* Construct outcome variables and HHI to observe concentration by county, CZ, HSA
* ==============================================================================
* Quarter: 13 weeks, 91 days

* Generate FTE counts a la Prager Schmitt (2021) -- assume 40 hour work week (leave out contract)
foreach var in rn lpn cna {
	gen num_`var'_emp = hrs_`var'_emp / (13 * 40) // assume cost report days = 91 days
}

* Use mdscensus (patient days) to generate patient counts
gen num_mds = mdscensus / 91 

* Generate HHI for each geography: county, CZ, HSA
gen hsa_pop2000 = 1 // since we don't have this info for now 

foreach geo in county cz hsa {	 
	
	preserve 
	
	collapse (sum) num_* (mean) `geo'_pop2000 , by(`geo' date large_group_id)

	foreach var in rn_emp lpn_emp cna_emp mds {

		bys date `geo': egen tot_`var' = total(num_`var')
		gen share_`var' = (num_`var' / tot_`var') * 100
		gen sharesq_`var' = share_`var'^2 
		
	}

	collapse (sum) sharesq_* num_* (mean) `geo'_pop2000 , by(`geo' date)

	ren sharesq_* hhi_*
	
	* How correlated are numbers with population? 
	pwcorr *_pop2000 num_* 

	tempfile `geo'_hhi_quarter 
	save ``geo'_hhi_quarter'
	
	restore
}

* ==============================================================================
* Figures
* ============================================================================== 

* Plots over time 
foreach geo in county cz hsa {
	use ``geo'_hhi_quarter', clear 
	
	* Is most of the variation from across geos or quarters? 
	xtset `geo' date
	xtsum hhi_*
		
	* What is the average and 95% HHI intervals over time? (Weighted by population)
	foreach var in rn_emp lpn_emp cna_emp mds {
		gen sd_`var' = hhi_`var'
	}
	
	* Unweighted 
	preserve 
		collapse (mean) hhi_* (sd) sd_* , by(date)
				
		foreach var in rn_emp lpn_emp cna_emp mds {
			gen ll_`var' = hhi_`var' - sd_`var'
			gen ul_`var' = hhi_`var' + sd_`var'

			tw ///
				(connected hhi_`var' date, lpattern(dash) lcolor(gs10)) ///
				(rcap ll_`var' ul_`var' date, ///
				msize(small) lcolor(maroon%70) lpattern(dash) lwidth(thin)) ///
				, ///
				xtitle("Quarters since 2017 Q1") ///
				ytitle("Average HHI of `var' (unwted)") ///
				legend(off) ///
				ylabel(0(2000)10000, nogrid) 
				
			graph export "$figures/graph_hhi_`var'_`geo'_over_time_unwt.pdf", replace 
		}
	restore 
	
	* Weighted by population
	preserve 
		collapse (mean) hhi_* (sd) sd_*  [fw = `geo'_pop2000], by(date)
		
		foreach var in rn_emp lpn_emp cna_emp mds {
			gen ll_`var' = hhi_`var' - sd_`var'
			gen ul_`var' = hhi_`var' + sd_`var'
			
			tw ///
				(connected hhi_`var' date, lpattern(dash) lcolor(gs10)) ///
				(rcap ll_`var' ul_`var' date, ///
				msize(small) lcolor(maroon%70) lpattern(dash) lwidth(thin)) ///
				, ///
				xtitle("Quarters since 2017 Q1") ///
				ytitle("Average HHI of `var' (pop wted)") ///
				legend(off) ///
				ylabel(0(2000)10000, nogrid)
				
			graph export "$figures/graph_hhi_`var'_`geo'_over_time_popwt.pdf",replace 
		}		
	restore 	

}

* Plot average HHI of geos (exclude HSA, hard to map)
foreach geo in county cz {

	use ``geo'_hhi_quarter', clear 
	
	collapse (mean) hhi_*, by(`geo')
	
	foreach var in rn_emp lpn_emp cna_emp mds {
		
		maptile hhi_`var', geography(`geo'1990) savegraph("$figures/map_`geo'_hhi_`var'.pdf") replace
	}
		
}







