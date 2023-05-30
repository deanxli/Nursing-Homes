* Goal: Generate a master PBJ dataset overtime with geographic xwalk and linked to large group. 

* Since we cannot link sellers credibly to a large group, we approximate with a lower bound on grouping. 
* In terms of delta HHI, it will generate an upper bound. 
* Ultimately, we want to run the affiliation algorithm as outlined by CMS.

* Generate monthly and quarterly level of data. 

* ==============================================================================
* Globals
* ==============================================================================

global file_path_pos "${dropbox}/Nursing Homes/Data/Staffing Data/POS Yearly"
global file_path_pbj "${dropbox}/Nursing Homes/Data/Staffing Data/PBJ Nurse Staffing Quarterly"
global file_path_owner "${dropbox}/Nursing Homes/Data/2022 Oct Ownership/derived"
global crosswalk "${dropbox}/Nursing Homes/Data/Crosswalks"

global derived "${dropbox}/Nursing Homes/Derived/Concentration"

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
* Clean large group affiliation data
* ==============================================================================
use "${file_path_owner}/oct_enrollment.dta", clear 

* Some of the CCNs have a letter or 001 at the end. Should not be the case. 
gen ccn_org = ccn
replace ccn = substr(ccn, 1, 6)
sort ccn ccn_org
by ccn: gen num_npi = _N
tab num_npi

* 6 SNFs with two enrollmentid and NPIs. Keep the first and make a note.
by ccn: gen num = _n 
keep if num == 1 
drop num 

isid ccn 

tempfile cleaned_oct_big_group
save `cleaned_oct_big_group'

* ==============================================================================
* Construct large group affiliation over time using CHOW data
* ==============================================================================
* Load CHOW data and create panel of ownership data
use "${file_path_owner}/sep_2022_chow.dta", clear

* Date variables 
gen date = date(effectivedate, "MDY")
format date %td

gen yearmonth = mofd(date)
format yearmonth %tm

* Keep only the IDs 
keep yearmonth date enrollmentid* npi* ccn* associateid*

* Check that ccn is the same and stable (CCN corresponds to provider ID in PBJ)
gen ccn = ccnseller 
replace ccn = ccnbuyer if mi(ccn) // Replace with ccnbuyer only if missing, 3 cases
drop ccnbuyer ccnseller 

* Merge enrollmentid of buyer because we cant match the seller 
ren enrollmentidbuyer enrollmentid
merge 1:1 enrollmentid using `cleaned_oct_big_group', keep(master matched) ///
		keepusing(affiliationentityid affiliationentityname num_npi organizationname)

* See for each date, how many acquisitions a large group does
bys date affiliationentityid: gen num_acq = _N
sum num_acq if !mi(affiliationentityid)
sort num_acq date affiliationentityid

* For each date, how many SNFs seller with same PAC ID sells 
bys date associateidseller: gen num_pac_sell = _N

****** Problem 1: Grouping together nursing homes w/ missing large group id
* If SNFs bought on same day and sold by a single PAC ID, assume one chain 
* Note: if we assume same owner does not sell to multiple, this is reasonable
* Negative so we know it's inferred 

egen affiliationid_infer = group(date associateidseller) if mi(affiliationentityid)
replace affiliationentityid = -affiliationid_infer if mi(affiliationentityid) 
drop affiliationid_infer

****** Problem 2: Inferring which sellers were part of the same "large group"
* If bought by a large group on same day, assume it is sold as one chain 
* Note: If we assume entire chains are bought and sold, this is reasonable
* Also no multiple transactions on one day.

egen affiliationentityidseller = group(date affiliationentityid)

* How many large seller group for a single seller PAC ID?
* 2 seller groups at the 95% percentile (can this be grouped?)
preserve 
keep associateidseller affiliationentityidseller
duplicates drop 
bys associateidseller (affiliationentityidseller): gen num_gp  = _N
sum num_gp, d
restore 

* I can do an additional step of grouping large seller groups if same PAC ID (don't for now)

****** 

* Reshape data to make panel 
drop date _merge num_acq num_pac_sell 
ren affiliationentityid affiliationentityidbuyer 
ren affiliationentityname affiliationentitynamebuyer
ren enrollmentid enrollmentidbuyer
gen affiliationentitynameseller = ""

reshape long enrollmentid npi associateid affiliationentityid affiliationentityname, ///
	i(ccn yearmonth) j(owner) string
replace yearmonth = yearmonth - 1 if owner == "seller" // owned a month ago 

* Generate year and month
gen year = year(dofm(yearmonth))
gen month = month(dofm(yearmonth))

* Make sure nothing is empty (will create filling back problems)
assert !mi(affiliationentityid)
replace affiliationentityname = "NaN" if mi(affiliationentityname)

* Save as temp file 
tempfile chow_big_gp
save `chow_big_gp'

* ==============================================================================
* Crosswalk PBJ data to large group affiliations
* ==============================================================================
* Load PBJ data over time and keep provnum and and month 
use "${file_path_pbj}/monthly_agg.dta", clear 
isid provnum year month 
ren provnum ccn

* Merge onto the CHOW data 
merge 1:1 ccn year month using `chow_big_gp', keep(matched master) nogen

* Fill missing values 
foreach var in enrollmentid npi associateid affiliationentityid affiliationentityname {
	* seller carried backward
	gsort ccn -year -month
	by ccn: replace `var' = `var'[_n-1] if mi(`var') 
	
	* buyer carried forward
	sort ccn year month
	by ccn: replace `var' = `var'[_n-1] if mi(`var') 
	
}

* Fill in for nursing homes who didn't undergo merger activity (update but do not replace)
merge m:1 ccn using `cleaned_oct_big_group', ///
	keepusing(affiliationentityid affiliationentityname enrollmentid npi associateid num_npi organizationname) update
	
drop if _merge == 2 
gen unmatched = (_merge == 1) 
drop _merge 

* Relabel empty affiliation entity
replace affiliationentityname = "NaN" if mi(affiliationentityname)

* Relabel empty affiliation IDs 
egen min_affid = min(affiliationentityid)
egen affiliationid_infer = group(ccn) if mi(affiliationentityid)
replace affiliationentityid = -affiliationid_infer + min_affid if mi(affiliationentityid) 
drop affiliationid_infer min_affid

* Affiliation entity is the large group
rename affiliationentityid large_group_id
rename affiliationentityname large_group_name 

* ==============================================================================
* Crosswalk PBJ data to geographic data 
* ==============================================================================
* Merge in CZs to county_fips data with county population
merge m:1 state county_fips using `cty_cz_xwalk', nogen keep(master matched) ///
	keepusing(cz county county_pop2000)
	
* Merge in CZ population data 
merge m:1 cz using "$crosswalk/cz_characteristics_withnames.dta", nogen keep(master matched) ///
	keepusing(czname pop2000) 
ren pop2000 cz_pop2000

* Save master dataset with large group affiliationentity 
save "${file_path_pbj}/master_monthly_agg.dta", replace
