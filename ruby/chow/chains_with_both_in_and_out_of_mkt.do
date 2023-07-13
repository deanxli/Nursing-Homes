* Goal: Find specific chains that undergo both in and out of market acquisitions.

* ==============================================================================
* Globals
* ==============================================================================

global file_path_pos "${dropbox}/Nursing Homes/Data/Staffing Data/POS Yearly/"
global file_path_pbj "${dropbox}/Nursing Homes/Data/Staffing Data/PBJ Nurse Staffing Quarterly/"
global crosswalk "${dropbox}/Nursing Homes/Data/Crosswalks"

global map "${dropbox}/Nursing Homes/Data/GIS"
global figures "${dropbox}/Nursing Homes/Derived/CHOW Maps"

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
		
replace chow = 0 if mi(chow)

* Merge to large groups by CZ 
merge m:1 date large_group_id cz using `large_group_panel_cz', keep(master matched) gen(same_cz)

* Merge to large groups by state 
merge m:1 date large_group_id state using `large_group_panel_state', keep(master matched) gen(same_state)

* Relabel merge variables to indicator var (0 = not same, 1 = same)
replace same_cz = (same_cz - 1) / 2
replace same_state = (same_state - 1) / 2

tempfile chow_panel 
save `chow_panel'
* ==============================================================================
* Which chains have both in and out of market acquisitions? by CZ
* ==============================================================================
use `chow_panel', clear 

drop if mi(large_group_prev) | mi(large_group_id)

keep if chow == 1 

* In the same quarter for a given large group, do they undergo both within and out of CZ acquisitions?
collapse (sum) chow, by(date large_group_id large_group_name same_cz)
reshape wide chow, i(date large_group_id large_group_name) j(same_cz)
isid date large_group_id

* Duplicate CHOW variable so we can collapse later
gen num_gp0 = chow0 
gen num_gp1 = chow1 

* Replace missing
replace chow0 = 0 if mi(chow0)
replace chow1 = 0 if mi(chow1)

gen total_chow = chow0 + chow1 
gen both_chow = (chow0 > 0) & (chow1 > 0) // has both in and out of market CHOWs
replace both_chow = 0 if mi(both_chow)

* Number of SNFs in a single CHOW
sum *chow*, d 

* Plot of in vs. out of market acquisitions as a bar graph
preserve 

collapse (sum) *chow* (count) num_gp*, by(date)

replace chow0 = -chow0
replace num_gp0 = -num_gp0

tw ///
	(bar chow0 date) ///
	(bar chow1 date) ///
	(bar num_gp0 date) ///
	(bar num_gp1 date) ///
	, ///
	ytitle("Number of CHOWs") ///
	legend(order(1 "Out of CZ (SNF)" 2 "In CZ (SNF)" 3 "Out of CZ (Group)" 4 "In CZ (Group)" ) ///
	pos(11) ring(0) row(2)) ///
	ylabel(, nogrid) ylab(-150(50)150) ///
	xtitle("Quarters since 2017 Q1") xlab(1(4)21) ///
	xlabel(, valuelabel nogrid ) 
	
graph export "$figures/num_chow_by_diff_same_cz_over_time.pdf",replace 	

restore 

* Collapse to group ID level: how many times they acquired both in and out of market 
collapse (sum) both_chow total_chow, by(large_group_id large_group_name)
gsort -total_chow

* Sort by frequency of acquiring both types of nursing homes 
gsort -both_chow

* ==============================================================================
* Which chains have both in and out of market acquisitions? by in vs out of state
* ==============================================================================
use `chow_panel', clear

drop if mi(large_group_prev) | mi(large_group_id)

keep if chow == 1 

* In the same quarter for a given large group, do they undergo both within and out of state acquisitions?
collapse (sum) chow, by(date large_group_id large_group_name same_state)
reshape wide chow, i(date large_group_id large_group_name) j(same_state)
isid date large_group_id

* Duplicate CHOW variable so we can collapse later
gen num_gp0 = chow0 
gen num_gp1 = chow1 

* Replace missing
replace chow0 = 0 if mi(chow0)
replace chow1 = 0 if mi(chow1)

gen total_chow = chow0 + chow1 
gen both_chow = (chow0 > 0) & (chow1 > 0) // has both in and out of market CHOWs
replace both_chow = 0 if mi(both_chow)

* Number of SNFs in a single CHOW
sum *chow*, d 

* Plot of in vs. out of market acquisitions as a bar graph
preserve 

collapse (sum) *chow* (count) num_gp*, by(date)

replace chow0 = -chow0
replace num_gp0 = -num_gp0

tw ///
	(bar chow0 date) ///
	(bar chow1 date) ///
	(bar num_gp0 date) ///
	(bar num_gp1 date) ///
	, ///
	ytitle("Number of CHOWs") ///
	legend(order(1 "Out of State (SNF)" 2 "In State (SNF)" 3 "Out of State (Group)" 4 "In State (Group)" ) ///
	pos(11) ring(0) row(2)) ///
	ylabel(, nogrid) ylab(-50(50)200) ///
	xtitle("Quarters since 2017 Q1") xlab(1(4)21) ///
	xlabel(, valuelabel nogrid ) 
	
graph export "$figures/num_chow_by_diff_same_state_over_time.pdf",replace 	

restore 

* Collapse to group ID level: how many times they acquired both in and out of market 
collapse (sum) both_chow chow0 chow1 total_chow, by(large_group_id large_group_name)
gsort -total_chow

* Sort by frequency of acquiring both types of nursing homes 
gsort -both_chow
