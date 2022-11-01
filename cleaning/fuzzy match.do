**** clean org names

* import data 
use "$nh_data/Ownership/owners.dta", clear

* standardize firm names 
gen norm_name = lower(owner_org_name)
replace norm_name = subinstr(norm_name,".","",.)
replace norm_name = subinstr(norm_name,",","",.)
replace norm_name = subinstr(norm_name," inc","",.)
replace norm_name = subinstr(norm_name," ltd","",.)
replace norm_name = subinstr(norm_name," llc","",.)

* holdco is holdings company
* trust also appears a lot 

tempfile ownership 
save `ownership'

**** we cycle through each state and see if we get some matches

** New York 
import excel "$nh_data/DnB Nursing Home List/New York.xlsx", firstrow clear 

* standardize firm names 
gen norm_db = lower(CompanyName)
replace norm_db = subinstr(norm_db,".","",.)
replace norm_db = subinstr(norm_db,",","",.)
replace norm_db = subinstr(norm_db," inc","",.)
replace norm_db = subinstr(norm_db," ltd","",.)
replace norm_db = subinstr(norm_db," llc","",.)

ren StateOrProvince state 

keep CompanyName UltimateParentCompany norm_db state

duplicates drop 
 
* joinby in the owners and do jaro winkler


