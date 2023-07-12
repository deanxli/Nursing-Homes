* Goal: Maps of in vs. out of market aquisitions over entire time period 

* Note: CZ does not align 1:1 with states! 128 CZs span two to three states
* 589 belong in one

* ==============================================================================
* Globals
* ==============================================================================

global file_path_pos "${dropbox}/Nursing Homes/Data/Staffing Data/POS Yearly/"
global file_path_pbj "${dropbox}/Nursing Homes/Data/Staffing Data/PBJ Nurse Staffing Quarterly/"
global crosswalk "${dropbox}/Nursing Homes/Data/Crosswalks"

global map "${dropbox}/Nursing Homes/Data/GIS"
global figures "${dropbox}/Nursing Homes/Derived/CHOW Maps"

set scheme white_tableau  // for bimap

* ==============================================================================
* Create panel data of date x large group x CZ (that they own SNFs in)
* ==============================================================================
use "${file_path_pbj}/master_quarterly_agg.dta", clear 

* Collapse to date x large group x CZ 
gen snf_cz = 1
collapse (count) snf_cz, by(date large_group_id cz)

* Shift the date variable (by a given date, what did nursing home own in t-1 date)
replace date = date + 1

* Save file 
tempfile large_group_panel_cz
save `large_group_panel_cz'

* ==============================================================================
* Create panel data of date x large group x state (that they own SNFs in)
* ==============================================================================
use "${file_path_pbj}/master_quarterly_agg.dta", clear 

* Collapse to date x large group x state
gen snf_state = 1
collapse (count) snf_state, by(date large_group_id state)

* Shift the date variable (by a given date, what did nursing home own in t-1 date)
replace date = date + 1

* Save file 
tempfile large_group_panel_state
save `large_group_panel_state'

* ==============================================================================
* Load master quarterly PBJ data 
* ==============================================================================
use "${file_path_pbj}/master_quarterly_agg.dta", clear 

* Time variables
gen year = ceil(date / 4) + 2016
gen quarter = mod(date, 4)
replace quarter = 4 if quarter == 0

* Look at CHOW events (see if large group ID changes compared to the previous date)
sort provnum date
by provnum: gen large_group_prev = large_group_id[_n-1]

gen chow = 1 if large_group_prev != large_group_id ///
		& !mi(large_group_prev) & !mi(large_group_id)

* Isolate to CHOW events 
keep if chow == 1

* Merge to large groups by CZ 
merge m:1 date large_group_id cz using `large_group_panel_cz', keep(master matched) gen(same_cz)

* Merge to large groups by state 
merge m:1 date large_group_id state using `large_group_panel_state', keep(master matched) gen(same_state)

* Relabel merge variables to indicator var (0 = not same, 1 = same)
replace same_cz = (same_cz - 1) / 2
replace same_state = (same_state - 1) / 2

* Now we collapse to how many in vs. out of state CHOWs for each CZ and plot maps
preserve 
	
	collapse (count) chow (mean) cz_pop2000, by(cz same_state) 
	reshape wide chow, i(cz) j(same_state)
	
	* Is it the same CZs that experience in vs. out of market acquisitions? 
	pwcorr chow*
	pwcorr chow* [fw = cz_pop2000]
	
	* Plot maps
	*maptile chow0, geography(cz1990) fcolor("BuPu") n(8) savegraph("$figures/chow_diff_state_by_cz.pdf") replace
	*maptile chow1, geography(cz1990) fcolor("BuPu") n(8) savegraph("$figures/chow_same_state_by_cz.pdf") replace
	
	/* Merge and try out spmap
	merge 1:m cz using "$map/cz", nogen
	
	cd "$map"
	bimap chow0 chow1 using cz_shp , cut(pctile) palette(pinkgreen) ///
		 texty("Out of Market") textx("In Market") texts(3.5) textlabs(3) values count ///
		 ocolor(gs7) osize(none) ///
		 ndfcolor(gs4) ndocolor(gs7) ndsize(0.03) ///
		 polygon(data(state_shp) ocolor(gs8) osize(0.15))

	graph export "$figures/bimap_chow_in_vs_out_cz.pdf",replace 	
	*/
	* Save to merge later 
	ren chow0 chow_cz_out
	ren chow1 chow_cz_in
	
	tempfile cz_mkt_numbers
	save `cz_mkt_numbers'
	
restore 

* Now we collapse to how many in vs. out of CZ CHOWs for each CZ and plot maps
preserve 
	
	collapse (count) chow (mean) cz_pop2000, by(cz same_cz) 
	reshape wide chow, i(cz) j(same_cz)
	
	* Is it the same CZs that experience in vs. out of market acquisitions? 
	pwcorr chow*
	pwcorr chow* [fw = cz_pop2000]
	
	* Plot maps
	*maptile chow0, geography(cz1990) fcolor("BuPu") n(8) savegraph("$figures/chow_diff_cz_by_cz.pdf") replace
	*maptile chow1, geography(cz1990) fcolor("BuPu") n(8) savegraph("$figures/chow_same_cz_by_cz.pdf") replace
	
	/* Merge and try out spmap
	merge 1:m cz using "$map/cz", nogen
	
	cd "$map"
	bimap chow0 chow1 using cz_shp , cut(pctile) palette(pinkgreen) ///
		 texty("Out of Market") textx("In Market") texts(3.5) textlabs(3) values count ///
		 ocolor(gs7) osize(none) ///
		 ndfcolor(gs4) ndocolor(gs7) ndsize(0.03) ///
		 polygon(data(state_shp) ocolor(gs8) osize(0.15))

	graph export "$figures/bimap_chow_in_vs_out_state.pdf",replace 	
	*/
	* Save to merge later 
	ren chow0 chow_st_out 
	ren chow1 chow_st_in
	
	tempfile st_mkt_numbers
	save `st_mkt_numbers'
restore 

* Now we collapse and plot total CHOW for each CZ 
collapse (count) chow (mean) cz_pop2000, by(czname cz)
drop if mi(cz)
isid cz

/* Get breakpoints from maptile
qui maptile chow, geography(cz1990)
local n_col = rowsof(r(breaks))
forvalues i = 1/`n_col'{
	local val = r(breaks)[`i', 1]
	local cuts `cuts' `val'
}
qui sum chow 
local max = r(max)
local cuts `cuts' `max'

* Plot using spmap 
merge 1:m cz using "$map/cz", nogen
cd "$map"
spmap chow using cz_shp, id(_ID) clm(custom) clb(`cuts') fcolor(BuPu) ///
	  ocolor(gs4 ..) osize(0.02 ..) ndfcolor(gs12 ..) ndocolor(gs12 ..) ndsize(0.03 ..) /// 
	  polygon(data(state_shp) ocolor(gs5) osize(0.15)) ///
	  legend(pos(5) size(2.5)) legstyle(2)
graph export "$figures/chow_total_by_cz.pdf",replace 	
*/  
* Merge and see what the top CZs in CHOWs are 
merge 1:1 cz using `cz_mkt_numbers', nogen 
merge 1:1 cz using `st_mkt_numbers', nogen 

gsort -chow

* Save excel table of the largest 20 CZs in number of CHOWs
drop _ID-_CY
export excel "$figures/top_20_cz_by_chow.xlsx", firstrow(variables) replace
