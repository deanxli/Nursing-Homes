* Goal: Generate a master PBJ dataset overtime with geographic xwalk and linked to large group 
* Generate monthly and quarterly level of data

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
* Construct large group affiliation over time using CHOW data, link to provider number
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

* If ccn is unique we can just reshape the data 
reshape long enrollmentid npi associateid, i(ccn yearmonth) j(owner) string
replace yearmonth = yearmonth - 1 if owner == "seller" // owned a month ago 

gen year = year(dofm(yearmonth))
gen month = month(dofm(yearmonth))

* Merge enrollmentid of CHOW to that of large group file 
merge 1:1 enrollmentid using "${file_path_owner}/oct_enrollment.dta", keep(master matched) ///
		keepusing(affiliationentityid affiliationentityname)
// Note: As expected, we can only match the buyers because seller enrollmentid not in data
		
* Affiliation entity is the large group
rename affiliationentityid large_group_id
rename affiliationentityname large_group_name

* See for each date, how many acquisitions a large groups does
bys owner date large_group_id: gen num_acq = _N
sum num_acq if !mi(large_group_id)

* For each date, how many SNFs seller with same PAC ID sells 
bys owner date associateid: gen num_pac = _N
sum num_pac if owner == "seller"

* Save as temp file 
tempfile chow_big_gp
save `chow_big_gp'

* ==============================================================================
* What if we tried merging on PAC ID (ie associate ID)? 
/* Problem: PAC IDs have many large group affiliations (individuals?)
So we don't want to do that. Maybe we can see over time how each PAC ID gets more. 
We don't use PAC IDs to merge for now. Still a lot of PAC IDs that are not in current data.
*/
* ==============================================================================
use "${file_path_owner}/oct_enrollment.dta", clear 

* Use PAC ID 
keep associateid affiliationentity* 
duplicates drop

* How many big groups to each PAC ID? 
bys associateid: gen num_gp = _N
sort num associateid affiliation*

* Keep as a flag for now and see if we can merge everyone. 
keep associateid num_gp 
duplicates drop 
isid associateid 

* See if we can merge to the CHOW 
merge 1:m associateid using `chow_big_gp', keep(using matched) nogen

* How many SNFs per associate id 
bys associateid: gen num_snfs = _N 
sort num_snfs associateid ccn

* Is it true that if same PAC ID and change on same day --> same owner? 
* Example of three SNFs in one chain seemingly "split" into 3 owners: 
* In this case, even though no large group and diff PAC IDs from the name it's the same!
keep if inlist(ccn, "525424", "525490", "525600") // 3 SNFs
keep if keep if inlist(ccn, "366217", "366224", "366171", "365717") // 11 SNFs 
