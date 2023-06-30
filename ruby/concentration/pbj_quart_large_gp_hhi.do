* Goal: Generate levels of HHI over time for 1) patients 2) working hours from PBJ
* We back-propagate large group affiliations using Sept 2022 CHOW and Oct 2022 Large Groups. 
* We count counties/CZ as the relevant market. We do not use zip code/HSA (from POS) for now.

* The following figures are made: 
* - Scatter plot of avg HHI over time (pop wt and unwt)
* - Maps of average HHI
* - Maps of delta HHI 
* - Histogram of delta HHI (pop wt and unwt)

* NOTE: As a data choice we do not plot HHI or Delta HHI = 10000 sinceit's meaningless

* ==============================================================================
* Globals
* ==============================================================================

global file_path_pos "${dropbox}/Nursing Homes/Data/Staffing Data/POS Yearly/"
global file_path_pbj "${dropbox}/Nursing Homes/Data/Staffing Data/PBJ Nurse Staffing Quarterly/"
global crosswalk "${dropbox}/Nursing Homes/Data/Crosswalks"

global figures "${dropbox}/Nursing Homes/Derived/Concentration"

global geo_list cz //county

* ==============================================================================
* Load master quarterly PBJ data 
* ==============================================================================
use "${file_path_pbj}/master_quarterly_agg.dta", clear 

* Time variables
gen year = ceil(date / 4) + 2016
gen quarter = mod(date, 4)
replace quarter = 4 if quarter == 0

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
foreach geo in $geo_list {	 
	
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
* Plots of concentration over time
* ============================================================================== 

* Plots over time 
foreach geo in $geo_list {
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

* ==============================================================================
* Maps of HHI over time & Histograms of delta HHI
* ============================================================================== 

* Plot average HHI of geos across all time periods
foreach geo in $geo_list {

	use ``geo'_hhi_quarter', clear 
	
	sort `geo' date
	
	foreach var in rn_emp lpn_emp cna_emp mds {
		gen first_hhi_`var' = hhi_`var'
		gen last_hhi_`var' = hhi_`var'
	}
	
	collapse (mean) hhi_* `geo'_pop2000 (first) first_hhi_* (last) last_hhi_*, by(`geo')
	
	foreach var in rn_emp lpn_emp cna_emp mds {
		
		* Map of average HHI across time (do not plot if 10000) 
		maptile hhi_`var' if abs(hhi_`var' < 10000), geography(`geo'1990) ///
			savegraph("$figures/map_`geo'_hhi_`var'.pdf") replace
		
		* Map of change in HHI (do not plot if 10000) 
		gen delta_hhi_`var' = last_hhi_`var' - first_hhi_`var'
		maptile delta_hhi_`var' if abs(delta_hhi_`var' < 10000), geography(`geo'1990) ///
			savegraph("$figures/map_`geo'_delta_hhi_`var'.pdf") replace
		
	}
	
	* Histogram of changes (do not plot if 10000)
	tw /// 
		(histogram delta_hhi_rn_emp if abs(delta_hhi_rn_emp < 10000), color(maroon%40)) ///
		(histogram delta_hhi_lpn_emp if abs(delta_hhi_lpn_emp < 10000), color(lavender%40)) ///
		(histogram delta_hhi_cna_emp if abs(delta_hhi_cna_emp < 10000), color(eltgreen%40)) ///
	, ///
	legend(order(1 "RN" 2 "LPN" 3 "CNA") col(1))
		
	graph export "$figures/hist_delta_hhi_`geo'_unwt.pdf",replace 
	
		
}
