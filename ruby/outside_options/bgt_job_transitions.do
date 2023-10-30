version 15
set more off

global file_path_bgt "${dropbox}/Nursing Homes/Nursing Homes Data/Occ Transitions Public Data Set (Jan 2021)/"

******* Load Data
use "${file_path_bgt}/occupation_transitions_public_data_set.dta", clear

** RN: 29-1141
** LPN: 29-2061 
** CNA: 31-1014

* Where do CNAs, LPNs, and RNs come from? (not very informative)
preserve 

keep if inlist(soc2, "29-1141", "29-2061", "31-1014")
gsort soc2 -transition_share 
keep if transition_share > 0.005

restore

* Where do CNAs, LPNs, and RNs go? 
keep if inlist(soc1, "29-1141", "29-2061", "31-1014")
gsort soc1 -transition_share 
keep if transition_share > 0.005 

replace transition_share = 100 * transition_share

** Results: TL;DR nurses mostly move up the ranks to CNA/LPN --> RNs and with RNs --> managers. 
** PROBLEM: We cannot tell where they work (ie whether it's hospital or nursing home. Only the type of occupation.)

