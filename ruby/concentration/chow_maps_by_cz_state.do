* Goal: Maps of in vs. out of market aquisitions over entire time period 

* Note: CZ does not align 1:1 with states! 128 CZs span two to three states
* 589 belong in one

* ==============================================================================
* Globals
* ==============================================================================

global file_path_pos "${dropbox}/Nursing Homes/Data/Staffing Data/POS Yearly/"
global file_path_pbj "${dropbox}/Nursing Homes/Data/Staffing Data/PBJ Nurse Staffing Quarterly/"
global crosswalk "${dropbox}/Nursing Homes/Data/Crosswalks"

global figures "${dropbox}/Nursing Homes/Derived/CHOW Maps"

* ==============================================================================
* Create panel data of date x large group x CZ (that they own SNFs in)
* ==============================================================================
use "${file_path_pbj}/master_quarterly_agg.dta", clear 

* Collapse to date x large group x CZ 
gen snf_cz = 1
collapse (count) snf_cz, by(date large_group_id cz)

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

gen chow = 0 
drop if mi(large_group_prev) | mi(large_group_id)
replace chow = 1 if large_group_prev != large_group_id 

* Isolate to CHOW events 
keep if chow = 1
