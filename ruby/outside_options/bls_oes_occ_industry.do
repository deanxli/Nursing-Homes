version 15
set more off

global file_path_bls "${dropbox}/Nursing Homes/Nursing Homes Data/BLS OEWS 2021"

******* Load Data
import delimited "${file_path_bls}/all_data_M_2021.csv", clear

** RN: 29-1141
** LPN: 29-2061 
** CNA: 31-1131

keep if inlist(occ_code, "29-1141", "29-2061", "31-1131")

* Keep national or state level 
keep if inlist(area_type, 1, 2)

* turn following columns into numeric 
replace tot_emp = subinstr(tot_emp,",","",.)
destring tot_emp emp_prse pct_total jobs_1000, replace force

* Keep necessary columns 
drop h_* a_*
********************************************
* National Data
********************************************

keep if area_type == 1 

* Where do CNAs, LPNs, and RNs work? 
gsort occ_code -tot_emp

** However, we still don't know the transition probabilties (ie are they the same kind of RNs?). LPNs and CNAs mostly in nursing homes (esp CNAs). 

** Since we have MSA level data we can see how much RNs in hospital/SNFs in local labor mkt. We can get a rough calculation of HHI based on this? Though we really can't account for SNF vs. hospital selection.

********************************************
* State Level data
********************************************
keep if area_type == 2

