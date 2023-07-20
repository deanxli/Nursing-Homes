* Goal: Generate a master yearly dataset 2011-2022 with geographic xwalk and linked to large group. 
* Include staffing (POS + PBJ) and wage (HCRIS) data 

* CHOWs + staffing 2011-2016 is using dean's data + POS 
* CHOWs+ staffing 2017-2022 is using PBJ (which is already merged)

* ==============================================================================
* Globals
* ==============================================================================

global file_path_pos "${dropbox}/Nursing Homes/Data/Staffing Data/POS Yearly"
global file_path_pbj "${dropbox}/Nursing Homes/Data/Staffing Data/PBJ Nurse Staffing Quarterly"
global dean_file "${dropbox}/Nursing Homes/Data/Dean GitHub Output/Extension Back To 2011/"
global wage_data "${github}/Nursing-Homes/connie/clean_hcris/output/"

global crosswalk "${dropbox}/Nursing Homes/Data/Crosswalks"

global derived "${dropbox}/Nursing Homes/Derived/Concentration"

* ==============================================================================
* Zip code to county and CZ xwalk for yearly POS data 
* ==============================================================================
* Save state fips and abbreviations
use "$crosswalk/county_characteristics.dta", clear

gen fips_state_cd = floor(county / 1000)

gen fips_cnty_cd = county - (fips_state_cd * 1000)
ren cty_pop2000 county_pop2000

tempfile cty_cz_xwalk
save `cty_cz_xwalk'

* ==============================================================================
* Clean HCRIS to yearly data to merge later 
* ==============================================================================
use "${wage_data}/nh_hcris_wages.dta", clear 
ren ccn provnum 
ren yr year 

sort provnum year id

* Collapse by mean (not unique on ccn x year)
collapse (mean) rn_* lpn_* cna_* c_*, by(provnum year)

tempfile yearly_wage
save `yearly_wage'

* ==============================================================================
* PBJ Data to Yearly
* ==============================================================================
use "${file_path_pbj}/master_quarterly_agg.dta", clear

* Time variables
gen year = ceil(date / 4) + 2016
gen quarter = mod(date, 4)
replace quarter = 4 if quarter == 0

* Relabel large group ID to -1 if group name is "NaN" 
replace large_group_id = -1 if large_group_name == "NaN"

* Look at CHOW events (see if large group ID changes compared to the previous date)
sort provnum date
by provnum: gen large_group_prev = large_group_id[_n-1]

gen chow = (large_group_prev != large_group_id) ///
		& !mi(large_group_prev) & !mi(large_group_id)

* Collapse to annual data 
collapse (sum) hrs_* mdscensus chow (lastnm) city state county cz county_pop2000 cz_pop2000 czname ///
	enrollmentid npi associateid num_npi unmatched organizationname ///
	large_group_id large_group_name large_group_prev, by(provnum year)
	
tempfile pbj_annual 
save `pbj_annual'

* ==============================================================================
* Load POS data to merge historical ownership file 
* ==============================================================================
use "$file_path_pos/pos_database_nh.dta", clear
ren fyear year 
drop if year < 2011 // as far back as ownership data goes 

* Merge in ownership file from Dean (2011-2016)
merge 1:1 year prvdr_num using "$dean_file/full_2011_2016.dta", keep(master matched) nogen 

ren affiliationentityname large_group_name
ren affiliationentityid large_group_id
ren prvdr_num provnum 
ren fac_name organizationname

* Relabel large group name as "NaN" if missing 
replace large_group_name = "NaN" if mi(large_group_name)

* Relable all ID with "NaN" as -1 for simplicity
replace large_group_id = -1 if large_group_name == "NaN"

* Look at CHOW events (see if large group ID changes compared to the previous date)
sort provnum year
by provnum: gen large_group_prev = large_group_id[_n-1]

gen chow = (large_group_prev != large_group_id) ///
		& !mi(large_group_prev) & !mi(large_group_id) 

* ==============================================================================
* Start merging in files 
* ==============================================================================
* Merge in CZs to county_fips data with county population
merge m:1 fips_state_cd fips_cnty_cd using `cty_cz_xwalk', nogen keep(master matched) ///
	keepusing(cz county county_pop2000)
	
* Merge in CZ population data 
merge m:1 cz using "$crosswalk/cz_characteristics_withnames.dta", nogen keep(master matched) ///
	keepusing(czname pop2000) 
ren pop2000 cz_pop2000

* Rename the previous 
ren large_group_prev large_group_prev_pos

* Merge PBJ annual data (all the updates are because of organization name)
merge 1:1 provnum year using `pbj_annual', update replace 
ren _merge pos_pbj_merge

* Merge wage data
merge 1:1 provnum year using `yearly_wage', nogen keep(master matched)

* ==============================================================================
* Generate variables for indicators and flags of suspicious data
* ==============================================================================
* Generate number of distinct SNFs owned by large groups every year 
bys large_group_id year: egen large_group_snfs = count(provnum)
bys large_group_prev year: egen large_group_prev_snfs = count(provnum)

* Label -1 as only one SNF 
replace large_group_snfs = 1 if large_group_id == -1 
replace large_group_prev_snfs = 1 if large_group_prev == -1

* Label a CHOW as sole proprietor to large chain 

* Label a CHOW as suspicious (if ownership flip back and forth)
sort provnum year
by provnum: gen large_group_prev2 = large_group_id[_n-2]
gen chow_sus = (chow == 1) & (large_group_prev2 == large_group_id)

* Check what doesn't match between previous large group for both POS and PBJ in 2017
replace large_group_prev = . if large_group_prev == -1 
replace large_group_prev_pos = . if large_group_prev_pos == -1 

gen gp_prev_match = 2 if (large_group_prev == large_group_prev_pos) & !mi(large_group_prev_pos) & !mi(large_group_prev) & (year == 2017)
replace gp_prev_match = 1 if (large_group_prev != large_group_prev_pos) & !mi(large_group_prev_pos) & !mi(large_group_prev) & (year == 2017)
replace gp_prev_match = -1 if mi(large_group_prev) & !mi(large_group_prev_pos) & (year == 2017)
replace gp_prev_match = -2 if mi(large_group_prev_pos) & !mi(large_group_prev) & (year == 2017)
replace gp_prev_match = 0 if mi(large_group_prev_pos) & mi(large_group_prev) & (year == 2017)

tab gp_prev_match

label var gp_prev_match "2 = POS and PBJ match, 1 = not match, 0 = both missing, -1 = PBJ missing, -2 = POS missing"

* Save master annual dataset with ownership 
save "${file_path_pos}/master_pos_pbj_hcris_2011_2022_ownership.dta", replace
