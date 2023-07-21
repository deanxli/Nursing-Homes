* Goal: CHOW maps of acquisitions from sole proprietor to chain. 
* County is the market

* ==============================================================================
* Globals
* ==============================================================================

global file_path_pos "${dropbox}/Nursing Homes/Data/Staffing Data/POS Yearly/"
global file_path_pbj "${dropbox}/Nursing Homes/Data/Staffing Data/PBJ Nurse Staffing Quarterly/"
global crosswalk "${dropbox}/Nursing Homes/Data/Crosswalks"

global map "${dropbox}/Nursing Homes/Data/GIS"
global figures "${dropbox}/Nursing Homes/Derived/CHOW Maps"

* ==============================================================================
* Create panel data of year x large group x county (that they own SNFs in)
* ==============================================================================
use "${file_path_pos}/master_pos_pbj_hcris_2011_2022_ownership.dta", clear 

keep if !mi(county) 

* Collapse to date x large group x county
gen snf_cty = 1
collapse (count) snf_cty, by(year large_group_id county)

* Shift the date variable (by a given date, what did nursing home own in t-1 date)
replace year = year + 1

* Save file 
tempfile large_group_panel_cty
save `large_group_panel_cty'

* ==============================================================================
* Load master annual 2011-2022 data
* ==============================================================================
use "${file_path_pos}/master_pos_pbj_hcris_2011_2022_ownership.dta", clear 

keep if !mi(county)

* Merge to large groups by county
merge m:1 year large_group_id county using `large_group_panel_cty', keep(master matched) gen(same_cty)

* Relabel merge variables to indicator var (0 = not same, 1 = same)
replace same_cty = (same_cty - 1) / 2

* Label years as 2011-2016 as 0 & 2017-2021 as 1
gen period = (year >= 2017)

* Collapse to the county level 
gen num_snf = 1
collapse (sum) num_snf chow* (mean) county_pop2000 (firstnm) state, by(period county same_cty)

gen state_fips = floor(county / 1000)

reshape wide num_snf chow*, i(county period) j(same_cty)

foreach x in num_snf chow chow_sole {
	replace `x'0 = 0 if mi(`x'0)
	replace `x'1 = 0 if mi(`x'1)
}

* Generate totals 
gen total_snf = num_snf0 + num_snf1 
gen total_chow = chow0 + chow1 
gen total_chow_sole = chow_sole0 + chow_sole1 

* Percent of SNFs undergoing CHOW 
gen perc_chow_total = 100 * (total_chow / total_snf)
gen perc_chow_sole_total = 100 * (total_chow_sole / total_snf) 
gen perc_chow_sole = 100 * (total_chow_sole / total_chow) 

* ==============================================================================
* Plot maps 
* ==============================================================================
* Percent of SNFs undergoing CHOW
foreach var in total sole_total sole {
	
	replace perc_chow_`var' = 0 if mi(perc_chow_`var')
	
	maptile perc_chow_`var' if period == 0, geography(county1990) fcolor("BuPu") stateoutline(thin) ///
		savegraph("$figures/perc_snf_chow_`var'_county_2011_2016.pdf") replace
		
	maptile perc_chow_`var' if period == 1, geography(county1990) fcolor("BuPu") stateoutline(thin) ///
		savegraph("$figures/perc_snf_chow_`var'_county_2017_2022.pdf") replace	
}

* ==============================================================================
* Collapse to State
* ==============================================================================
collapse (sum) num_snf* chow* (firstnm) state, by(period state_fips)

* Generate totals 
gen total_snf = num_snf0 + num_snf1 
gen total_chow = chow0 + chow1 
gen total_chow_sole = chow_sole0 + chow_sole1 

* Percent of SNFs undergoing CHOW 
gen perc_chow_total = 100 * (total_chow / total_snf)
gen perc_chow_sole_total = 100 * (total_chow_sole / total_snf) 
gen perc_chow_sole = 100 * (total_chow_sole / total_chow)  

* Reshape on period 
keep period state* total_* perc_* 

reshape wide total* perc*, i(state) j(period) 

* Plot percentage CHOW based on period 
maptile perc_chow_total0, geography(state) fcolor("BuPu") ///
		savegraph("$figures/perc_snf_chow_total_state_2011_2016.pdf") replace
		
maptile perc_chow_total1, geography(state) fcolor("BuPu") ///
	savegraph("$figures/perc_snf_chow_total_state_2017_2022.pdf") replace	

* Sort based on 2017-2022 stats 
gsort -perc_chow_total1 

order state state_fips total_snf1 perc_chow_total1 total_snf0 perc_chow_total0 *1 *0

export excel "$figures/top_states_chow.xlsx", firstrow(variables) replace
